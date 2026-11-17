-- Road building, all on the server. Road mode starts a new road under the car; the client
-- then keeps asking for one more tile, and the road's tip shoots ahead toward where the
-- camera faces, bending gently as the player steers. Each road can only be Config.Road.Meter
-- studs long. Once its tip has crossed open air and met solid ground (or the meter runs
-- out) the car drives along it (Controllers.Hud).
-- A stage only lets you build once your Horsepower reaches its "Horsepower Needed".
-- Each stage's Wins pads pay once per run; going back to the lobby (or respawning) clears
-- your road and starts a new run.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Course = require(script.Parent.Course)
local Data = require(script.Parent.Data)
local Store = require(script.Parent.Store)
local Admin = require(script.Parent.Admin)
local Map = require(script.Parent.Map)
local PlayerCars = require(script.Parent.PlayerCars)

local Roads = {}

local R = Config.Road
local ASPHALT = Color3.fromRGB(62, 64, 72)
local EDGE = Color3.fromRGB(255, 215, 30)
local DASH = Color3.fromRGB(255, 215, 30)

local folder -- workspace.Roads
local state = {} -- [player] = { Tiles, End, Dir, Allowance, Last, Claimed, Away, LastWarn }
local notice -- RemoteEvent for popups

-- The stages' invisible lane walls (tagged LaneWall by Server.Course) keep the car on the
-- course, so roads must stay inside them too. Each is kept as a flat box { X0, X1, Z0, Z1 }.
local laneWalls
local function wallBoxes()
	if not laneWalls then
		laneWalls = {}
		for _, wall in CollectionService:GetTagged("LaneWall") do
			local half = wall.Size / 2
			local p = wall.Position
			table.insert(laneWalls, { p.X - half.X, p.X + half.X, p.Z - half.Z, p.Z + half.Z })
		end
	end
	return laneWalls
end

-- does the flat line from a to b cross the box?
local function crosses(a, b, box)
	local t0, t1 = 0, 1
	for axis = 1, 2 do
		local from = if axis == 1 then a.X else a.Z
		local delta = (if axis == 1 then b.X else b.Z) - from
		local lo, hi = box[axis * 2 - 1], box[axis * 2]
		if math.abs(delta) < 1e-6 then
			if from < lo or from > hi then
				return false
			end
		else
			local ta, tb = (lo - from) / delta, (hi - from) / delta
			if ta > tb then
				ta, tb = tb, ta
			end
			t0, t1 = math.max(t0, ta), math.min(t1, tb)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

-- would a tile from start to finish (heading yaw) poke through a lane wall? Its middle line
-- and its far edge are checked (the curbs may just touch a wall)
-- (the Stage 1 wall counts too: roads never reach back over the lobby)
local function hitsWall(start, finish, yaw, boxes)
	local side = Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) * (R.TileWidth / 2 - 1.5)
	if math.min((finish - side).Z, (finish + side).Z) < Course.RoadsFrom then
		return true
	end
	for _, box in boxes or wallBoxes() do
		if crosses(start, finish, box) or crosses(finish - side, finish + side, box) then
			return true
		end
	end
	return false
end

-- the lane walls within range of a point (the look-ahead only needs the nearby ones)
local function wallsNear(at, range)
	local near = {}
	for _, box in wallBoxes() do
		if box[2] > at.X - range and box[1] < at.X + range and box[4] > at.Z - range and box[3] < at.Z + range then
			table.insert(near, box)
		end
	end
	return near
end

-- one tile on from start, heading yawTry at pitch: never higher than the walls or down into the pits
local function aimFrom(start, yawTry, pitch)
	local d = Vector3.new(math.sin(yawTry) * math.cos(pitch), math.sin(pitch), math.cos(yawTry) * math.cos(pitch))
	local f = start + d * R.TileLength
	if f.Y > R.MaxHeight or f.Y < R.MinHeight then
		pitch = 0
		d = Vector3.new(math.sin(yawTry), 0, math.cos(yawTry))
		f = start + d * R.TileLength
	end
	return d, f, pitch
end

local function tileFits(start, finish, yawTry, boxes)
	return math.abs(finish.X) <= Map.HalfWidth - R.TileWidth / 2 and not hitsWall(start, finish, yawTry, boxes)
end

-- Look-ahead: can the road still carry on for this many more tiles from here? Roads that
-- head into the wall at the start of the next platform bend early instead of stopping a
-- stud short of it with the car left at the edge.
local LOOK_TURNS = { 0, 15, -15, 30, -30 }
local function roomAhead(from, yawNow, pitch, depth, boxes)
	if depth <= 0 then
		return true
	end
	for _, deg in LOOK_TURNS do
		local yawTry = yawNow + math.rad(math.min(math.abs(deg), R.MaxTurn) * math.sign(deg))
		local _, f, p = aimFrom(from, yawTry, pitch)
		if tileFits(from, f, yawTry, boxes) and roomAhead(f, yawTry, p, depth - 1, boxes) then
			return true
		end
	end
	return false
end
local LOOK_AHEAD = 4 -- tiles

local function stateOf(player)
	local s = state[player]
	if not s then
		s = { Tiles = {}, Allowance = R.PerSecond, Last = os.clock(), Claimed = {}, Away = false, LastWarn = 0, Used = 0, Empty = false }
		state[player] = s
	end
	return s
end

-- removes the player's road (fade: shrink the tiles away instead of popping them)
local function removeRoad(player, fade)
	local s = stateOf(player)
	for i, tile in s.Tiles do
		-- no longer part of this player's road, even while it fades (so a new road's path
		-- never picks up the old pieces)
		tile:SetAttribute("Index", nil)
		tile:SetAttribute("Owner", nil)
		if fade then
			task.delay(math.min(i * 0.02, 0.6), function()
				for _, p in tile:GetDescendants() do
					if p:IsA("BasePart") then
						p.CanCollide = false
						TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = p.Size * Vector3.new(0.2, 1, 0.2) }):Play()
					end
				end
				task.delay(0.4, tile.Destroy, tile)
			end)
		else
			tile:Destroy()
		end
	end
	s.Tiles = {}
	s.End = nil
	s.OverGap = false
	s.Reached = false
	player:SetAttribute("RoadEnd", nil)
	player:SetAttribute("RoadLeft", R.Meter)
end

local function clear(player)
	removeRoad(player, false)
	stateOf(player).Claimed = {}
end

local function yaw(dir)
	return math.atan2(dir.X, dir.Z)
end

-- One tile: dark grey road with thick raised yellow curbs and a yellow dash down the middle
-- (the dash only on every other tile, so it reads as a dashed line)
-- joint (optional): { At = where it joins the tile before, Yaw/Pitch = that tile's heading }
local function makeTile(player, centre, dir, index, joint)
	-- centre is the middle of the road's top line; the slab hangs just below it
	local cf = CFrame.lookAt(centre, centre + dir) * CFrame.new(0, -0.45, 0)
	local model = Instance.new("Model")
	model.Name = "Road"
	local road = Instance.new("Part")
	road.Name = "Tile"
	road.Anchored = true
	road.Size = Vector3.new(R.TileWidth, 1, R.TileLength + 0.6) -- a little overlap hides the joins on bends
	road.CFrame = cf
	road.Color = ASPHALT
	road.Material = Enum.Material.SmoothPlastic
	road.TopSurface = Enum.SurfaceType.Smooth
	road.Parent = model
	for _, side in { -1, 1 } do
		local edge = Instance.new("Part")
		edge.Name = "Edge"
		edge.Anchored = true
		edge.CanCollide = false
		edge.CanQuery = false
		edge.Size = Vector3.new(R.CurbWidth, 1 + R.CurbHeight, R.TileLength + 0.6)
		edge.CFrame = cf * CFrame.new(side * (R.TileWidth / 2 - R.CurbWidth / 2), R.CurbHeight / 2, 0)
		edge:SetAttribute("Curb", true) -- a bend trims it back where it meets the next tile's
		edge.Color = EDGE
		edge.Material = Enum.Material.SmoothPlastic
		edge.Parent = model
	end
	if index % 2 == 1 then
		local dash = Instance.new("Part")
		dash.Name = "Dash"
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.Size = Vector3.new(0.7, 1.04, R.TileLength * 0.6)
		dash.CFrame = cf
		dash.Color = DASH
		dash.Material = Enum.Material.SmoothPlastic
		dash.Parent = model
	end
	-- the join with the tile before: on a bend the two straight tiles fan apart, so a round
	-- piece of road fills the wedge between them, and a short bridge joins each pair of curbs
	if joint then
		local turn = (math.atan2(dir.X, dir.Z) - joint.Yaw + math.pi) % (2 * math.pi) - math.pi
		if math.abs(turn) > math.rad(1) then
			-- the round fill only matters on a sideways bend. It lies tilted halfway between the two
			-- tiles' slopes, and sinks a little further when the slope changes, so its edge never
			-- sticks up above either tile (a flat one made steps on hills)
			local before = joint.Prev and joint.Prev.PrimaryPart and joint.Prev.PrimaryPart.CFrame.LookVector or dir.Unit
			local mid = (before + dir.Unit).Unit
			local slopeChange = math.abs(math.asin(math.clamp(dir.Unit.Y, -1, 1)) - math.asin(math.clamp(before.Y, -1, 1)))
			local sink = (R.TileWidth / 2) * math.sin(slopeChange / 2) + 0.05
			local disc = Instance.new("Part")
			disc.Name = "Joint"
			disc.Shape = Enum.PartType.Cylinder
			disc.Anchored = true
			disc.Size = Vector3.new(1, R.TileWidth, R.TileWidth)
			disc.CFrame = CFrame.lookAt(joint.At, joint.At + mid) * CFrame.new(0, -0.45 - sink, 0) * CFrame.Angles(0, 0, math.pi / 2) -- a round lying in the road's plane
			disc.Color = ASPHALT
			disc.Material = Enum.Material.SmoothPlastic
			disc.Parent = model
			local d = R.TileWidth / 2 - R.CurbWidth / 2 -- curb line's distance from the middle
			local flatNew = Vector3.new(dir.X, 0, dir.Z).Unit
			local flatOld = Vector3.new(math.sin(joint.Yaw), 0, math.cos(joint.Yaw))
			local innerDir = (flatNew - flatOld).Unit -- points to the inside of the bend
			-- inside of the bend: the two curbs cross, so each is cut back to where they meet
			local trim = d * math.tan(math.abs(turn) / 2) + 0.3
			local function cutBack(edge, fromEnd)
				-- fromEnd: +1 trims the far end (tile before), -1 the near end (this tile)
				local len = math.max(0.2, edge.Size.Z - trim)
				edge.CFrame = edge.CFrame * CFrame.new(0, 0, fromEnd * trim / 2) -- lookAt: -Z is forward
				edge.Size = Vector3.new(edge.Size.X, edge.Size.Y, len)
			end
			if joint.Prev then
				for _, e in joint.Prev:GetChildren() do
					if e:GetAttribute("Curb") and (e.Position - joint.At):Dot(innerDir) > 0 then
						cutBack(e, 1)
					end
				end
			end
			for _, e in model:GetChildren() do
				if e:GetAttribute("Curb") and (e.Position - joint.At):Dot(innerDir) > 0 then
					cutBack(e, -1)
				end
			end
			-- a little block where the inside curbs meet, so the corner is filled
			local corner = joint.At + innerDir * (d / math.cos(math.abs(turn) / 2))
			local block = Instance.new("Part")
			block.Name = "Edge"
			block.Anchored, block.CanCollide, block.CanQuery = true, false, false
			block.Size = Vector3.new(R.CurbWidth, 1 + R.CurbHeight, R.CurbWidth)
			block.CFrame = CFrame.lookAt(corner, corner + flatNew) * CFrame.new(0, -0.45 + R.CurbHeight / 2, 0)
			block.Color, block.Material = EDGE, Enum.Material.SmoothPlastic
			block.Parent = model
			-- outside of the bend: the curbs part, so short pieces follow the round edge between them
			local pieces = math.ceil(math.deg(math.abs(turn)) / 8)
			local outer = -innerDir
			local startSide = flatOld:Cross(Vector3.yAxis)
			if startSide:Dot(outer) < 0 then
				startSide = -startSide
			end
			local endSide = flatNew:Cross(Vector3.yAxis)
			if endSide:Dot(outer) < 0 then
				endSide = -endSide
			end
			local a0 = math.atan2(startSide.X, startSide.Z)
			local span = (math.atan2(endSide.X, endSide.Z) - a0 + math.pi) % (2 * math.pi) - math.pi
			local chord = 2 * d * math.sin(math.abs(span) / pieces / 2) + 0.4
			for i = 1, pieces do
				local a = a0 + span * (i - 0.5) / pieces
				local n = Vector3.new(math.sin(a), 0, math.cos(a))
				local at = joint.At + n * d
				local tangent = n:Cross(Vector3.yAxis)
				local piece = Instance.new("Part")
				piece.Name = "Edge"
				piece.Anchored, piece.CanCollide, piece.CanQuery = true, false, false
				piece.Size = Vector3.new(R.CurbWidth, 1 + R.CurbHeight, chord)
				piece.CFrame = CFrame.lookAt(at, at + tangent) * CFrame.new(0, -0.45 + R.CurbHeight / 2, 0)
				piece.Color, piece.Material = EDGE, Enum.Material.SmoothPlastic
				piece.Parent = model
			end
		end
	end
	model.PrimaryPart = road
	model:SetAttribute("Owner", player.UserId)
	model.Parent = folder
	return model
end

-- the ground right under a point, ignoring the player's own character
local function groundBelow(character, from, depth)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, folder }
	local hit = workspace:Raycast(from, Vector3.new(0, -(depth or 40), 0), params)
	return hit and hit.Position.Y
end

local function warn(player, s, kind, fields)
	if os.clock() - s.LastWarn < 1 then
		return
	end
	s.LastWarn = os.clock()
	fields.Kind = kind
	notice:FireClient(player, fields)
end

local function build(player, look, fresh)
	local data = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root or typeof(look) ~= "Vector3" then
		return
	end
	local s = stateOf(player)
	-- rate limit: a token bucket of PerSecond builds a second
	local now = os.clock()
	s.Allowance = math.min(R.PerSecond, s.Allowance + (now - s.Last) * R.PerSecond)
	s.Last = now
	if s.Allowance < 1 then
		return
	end
	s.Allowance -= 1

	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 or flat.Magnitude ~= flat.Magnitude or look.Y ~= look.Y then
		return
	end
	-- the camera steers left/right (yaw) and up/down (pitch, kept to a drivable slope)
	local wantYaw = yaw(flat)
	-- looking roughly level keeps the road flat; tilt further to climb or dive
	-- (the camera sits behind and above the car, so its normal tilt counts as level)
	local pitch = math.atan2(look.Y, flat.Magnitude) - math.rad(R.LevelPitch)
	local dead = math.rad(R.FlatZone)
	pitch = math.sign(pitch) * math.max(0, math.abs(pitch) - dead)
	local wantPitch = math.clamp(pitch, -math.rad(R.MaxSlope), math.rad(R.MaxSlope))

	-- carry on from the end of the road, or start a new one in front of the car
	-- (fresh: the player just switched road mode on, so always start a new road)
	if fresh == true then
		s.End = nil
		s.OverGap = false
		s.Reached = false
	end
	if s.Reached then
		return -- this road has reached solid ground; drive onto it
	end
	if s.End and s.Used + R.TileLength > R.Meter then
		-- the Road meter is empty: no more road until you're back on solid ground
		if not s.Empty then
			s.Empty = true
			notice:FireClient(player, { Kind = "RoadEmpty" })
		end
		return
	end
	local start, newYaw, newPitch
	local pos = root.Position
	if fresh ~= true and not s.End then
		return -- nothing to carry on from
	end
	if not s.End and pos.Z < Course.RoadsFrom then
		warn(player, s, "RoadLobby", {}) -- no roads in the lobby: through the Stage 1 wall first
		return
	end
	if s.End then
		-- the road's tip carries on from where it is (the Road meter limits how far it goes)
		start = s.End
		-- bend gently: at most MaxTurn degrees sideways and MaxBend up/down from the last tile
		local delta = (wantYaw - s.Yaw + math.pi) % (2 * math.pi) - math.pi
		newYaw = s.Yaw + math.clamp(delta, -math.rad(R.MaxTurn), math.rad(R.MaxTurn))
		newPitch = s.Pitch + math.clamp(wantPitch - s.Pitch, -math.rad(R.MaxBend), math.rad(R.MaxBend))
	else
		-- the ground under the car, or just behind it (a car parked right at an edge has its
		-- middle over the gap)
		local back = -Vector3.new(math.sin(wantYaw), 0, math.cos(wantYaw))
		local groundY
		for _, step in { 0, 3, 6 } do
			local y = groundBelow(character, pos + back * step)
			if y and y >= R.MinHeight then
				groundY = y
				break
			end
		end
		if not groundY then
			return -- in the air, or down in a pit
		end
		newYaw, newPitch = wantYaw, 0 -- a new road starts flat, a little behind the car so it's on it
		start = Vector3.new(pos.X, groundY, pos.Z) - Vector3.new(math.sin(newYaw), 0, math.cos(newYaw)) * R.StartBehind
		-- starting from solid ground fills the Road meter back up
		s.Used = 0
		s.Empty = false
		removeRoad(player, false)
	end
	local function aim(yawTry)
		return aimFrom(start, yawTry, newPitch)
	end
	local boxes = wallsNear(start, 60)
	-- how many tiles the Road meter has left after this one (the look-ahead needs no more)
	local depth = math.min(LOOK_AHEAD, math.floor((R.Meter - (if s.End then s.Used else 0)) / R.TileLength) - 1)
	local dir, finish
	if s.End then
		-- stay inside the lane walls: a road steered into one slides along it instead (turning
		-- back toward straight down the course); one that can't get past it stops there
		local options = { newYaw, s.Yaw }
		local toward = if math.abs(s.Yaw) > 1e-3 then -math.sign(s.Yaw) else 0
		for _, step in { 0.5, 1 } do
			local turned = s.Yaw + toward * math.min(math.abs(s.Yaw), math.rad(R.MaxTurn) * step)
			table.insert(options, turned)
		end
		-- still blocked (a wall straight across): bend along it, the way the player is
		-- steering first
		local steer = (wantYaw - s.Yaw + math.pi) % (2 * math.pi) - math.pi
		local first = if steer >= 0 then 1 else -1
		for _, step in { 0.5, 1 } do
			for _, sign in { first, -first } do
				table.insert(options, s.Yaw + sign * math.rad(R.MaxTurn) * step)
			end
		end
		-- first choice: a way that leaves room to carry on (so a wall coming up ahead is
		-- steered round in time); failing that, any way that fits for now
		local found = false
		for pass = 1, 2 do
			for _, yawTry in options do
				local d, f, p = aim(yawTry)
				if tileFits(start, f, yawTry, boxes) and (pass == 2 or roomAhead(f, yawTry, p, depth, boxes)) then
					dir, finish, newYaw, newPitch, found = d, f, yawTry, p, true
					break
				end
			end
			if found then
				break
			end
		end
		if not found then
			if not s.Empty then
				s.Empty = true
				notice:FireClient(player, { Kind = "RoadWall" })
			end
			return
		end
	else
		-- a new road: if the car is parked close to a wall, shift the road's start sideways
		-- just enough for the whole road to fit (and, if it can, to carry on past the walls ahead)
		local side = Vector3.new(math.cos(newYaw), 0, -math.sin(newYaw))
		local placed = false
		for pass = 1, 2 do
			for _, shift in { 0, 2, -2, 4, -4, 6, -6, 8, -8 } do
				local shifted = start + side * shift
				local d, f, p = aim(newYaw)
				f = f + side * shift
				if not hitsWall(shifted, f, newYaw, boxes) and (pass == 2 or roomAhead(f, newYaw, p, depth, boxes)) then
					start, dir, finish, newPitch, placed = shifted, d, f, p, true
					break
				end
			end
			if placed then
				break
			end
		end
		if not placed then
			return -- facing straight into a wall
		end
	end
	local centre = (start + finish) / 2
	-- enough Horsepower for the stage this tile is on?
	local stage = Course.stageAt(finish.Z)
	local needed = stage and Config.Stages.HorsepowerNeeded[stage] or 0
	if data.Energy < needed then
		warn(player, s, "RoadNeedPower", { Need = needed - data.Energy, Stage = stage })
		return
	end

	-- the tile's top runs along the line from start to finish
	s.Used += R.TileLength
	local index = math.floor(s.Used / R.TileLength + 0.5)
	local joint = if #s.Tiles > 0 and s.Yaw then { At = start, Yaw = s.Yaw, Pitch = s.Pitch, Prev = s.Tiles[#s.Tiles] } else nil
	local tile = makeTile(player, centre, dir, index, joint)
	tile:SetAttribute("Index", index) -- the client follows the tiles in this order
	table.insert(s.Tiles, tile)
	if #s.Tiles > R.MaxTiles then
		table.remove(s.Tiles, 1):Destroy()
	end
	player:SetAttribute("RoadLeft", math.max(0, R.Meter - s.Used))
	s.End = finish
	s.Yaw, s.Pitch = newYaw, newPitch
	player:SetAttribute("RoadEnd", finish) -- the client keeps building while the car nears it

	-- once the road has crossed open air and its end meets solid ground, it's done
	local ground = groundBelow(character, finish + Vector3.new(0, 3, 0), 6)
	if not ground then
		s.OverGap = true
	elseif s.OverGap and math.abs(ground - finish.Y) <= 1.5 then
		s.Reached = true
		notice:FireClient(player, { Kind = "RoadReached" })
	end
end

-- A landing burst: a white shockwave ring spreading over the ground and a puff of dust
local function landingEffect(at)
	local ring = Instance.new("Part")
	ring.Name = "LandingRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 4, 4)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }):Play()
	task.delay(0.55, ring.Destroy, ring)

	local puff = Instance.new("Part")
	puff.Name = "LandingDust"
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Transparency = 1
	puff.Size = Vector3.new(8, 1, 8)
	puff.Position = at + Vector3.new(0, 0.5, 0)
	puff.Parent = workspace
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(14, 24)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = puff
	dust:Emit(28)
	task.delay(1.2, puff.Destroy, puff)
end

-- The car rolled off the end of a finished road onto the ground: flip, land, road gone
local function landed(player)
	local s = stateOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- generous: the server sees the car a little behind or past where the player does (lag),
	-- and at top speed that is tens of studs
	if not s.Reached or not root or not s.End or ((root.Position - s.End) * Vector3.new(1, 0.5, 1)).Magnitude > 60 then
		return
	end
	local groundY = groundBelow(character, root.Position) or root.Position.Y - 3
	removeRoad(player, true)
	landingEffect(Vector3.new(root.Position.X, groundY, root.Position.Z))
	task.spawn(PlayerCars.flip, player)
end

-- Wins pads are checked by position, not Touched, because a car driving on its own road
-- passes just above the pad without touching it. Anyone over a pad (up to car height
-- above it, or a little after it, so a fast car can't skip it between checks) claims it.
local winsPads = {} -- { Pad, Stage, Index }

local function payWins(player, stage, index)
	local data = Data.get(player)
	local s = stateOf(player)
	local key = stage .. ":" .. index
	if not data or s.Claimed[key] then
		return
	end
	s.Claimed[key] = true
	local wins = Config.stagePadWins(stage, index) * (if Store.has(data, "DoubleWins") then 2 else 1) * Admin.eventMultiplier("DoubleWins") * Data.boostMultiplier(data, "DoubleWins")
	data.Wins += wins
	Data.publish(player)
	notice:FireClient(player, { Kind = "StageComplete", Stage = stage, Wins = wins })
end

-- has this player reached one of this stage's Wins pads on this run out from the lobby?
function Roads.finished(player, stage)
	for key in stateOf(player).Claimed do
		if string.match(key, "^(%d+):") == tostring(stage) then
			return true
		end
	end
	return false
end

local function overPad(pad, pos)
	local rel = pad.CFrame:PointToObjectSpace(pos)
	local half = pad.Size / 2
	return math.abs(rel.X) <= half.X + 1
		and rel.Z >= -half.Z - 1 and rel.Z <= half.Z + 3
		and rel.Y >= -1 and rel.Y <= 12
end

local function hookWinsPad(pad)
	local stage = pad:GetAttribute("Stage")
	if stage then
		table.insert(winsPads, { Pad = pad, Stage = stage, Index = pad:GetAttribute("Index") or 1 })
	end
end

function Roads.start(remotes, noticeRemote)
	notice = noticeRemote
	folder = Instance.new("Folder")
	folder.Name = "Roads"
	folder.Parent = workspace

	local remote = Instance.new("RemoteEvent")
	remote.Name = "BuildRoad"
	remote.Parent = remotes
	remote.OnServerEvent:Connect(build)
	local landedRemote = Instance.new("RemoteEvent")
	landedRemote.Name = "RoadLanded"
	landedRemote.Parent = remotes
	landedRemote.OnServerEvent:Connect(landed)

	for _, pad in CollectionService:GetTagged("WinsPad") do
		hookWinsPad(pad)
	end
	CollectionService:GetInstanceAddedSignal("WinsPad"):Connect(hookWinsPad)

	local function track(player)
		player.CharacterAdded:Connect(function()
			clear(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		state[player] = nil
	end)

	-- coming back to the lobby from the stages ends the run: road cleared, Wins pads ready again
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local s = stateOf(player)
					local inLobby = Map.inLobby(root.Position)
					if inLobby and s.Away then
						clear(player)
					end
					s.Away = not inLobby
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, entry in winsPads do
						if entry.Pad.Parent and overPad(entry.Pad, root.Position) then
							payWins(player, entry.Stage, entry.Index)
						end
					end
				end
			end
		end
	end)
end

return Roads

