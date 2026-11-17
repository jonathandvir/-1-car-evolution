-- Builds the outdoor base: a big studded green field ringed by tall blocky hills with
-- pine trees and mushrooms, a blue launch pad in the middle, training pads down the
-- right side, a shop stall, leaderboards and a worlds portal at the back.
-- The front edge is a cliff looking out over a valley, where roads will be built.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CarLooks = require(ReplicatedStorage.Shared.CarLooks)
local Course = require(script.Parent.Course)

local Map = {}

local FIELD = Vector2.new(192, 192) -- width (x), depth (z); multiples of 48 so tiles and hills line up
Map.HalfWidth = FIELD.X / 2 -- the stages are as wide as the lobby

-- Is this position on the lobby field (not out on the stages)?
function Map.inLobby(pos)
	return math.abs(pos.X) <= FIELD.X / 2 + 4 and pos.Z >= -FIELD.Y / 2 - 4 and pos.Z <= FIELD.Y / 2 and pos.Y > -20
end
local X0, X1 = -FIELD.X / 2, FIELD.X / 2
local Z0, Z1 = -FIELD.Y / 2, FIELD.Y / 2 -- Z1 is the open front edge
local TILE = 16
local ROOF_Y = 248 -- the invisible roof over the lobby and the whole course (the top of the stages' high walls)

Map.LaunchPosition = Vector3.new(0, 0, 40)
Map.SpawnPosition = Vector3.new(0, 4, -20)

local C = {
	GrassA = Color3.fromRGB(75, 220, 70),
	GrassB = Color3.fromRGB(100, 236, 90),
	Dirt = Color3.fromRGB(150, 95, 60),
	DirtDark = Color3.fromRGB(120, 72, 45),
	HillTop = Color3.fromRGB(70, 200, 70),
	Pine = Color3.fromRGB(40, 150, 60),
	PineLight = Color3.fromRGB(60, 175, 70),
	Trunk = Color3.fromRGB(110, 70, 40),
	PadA = Color3.fromRGB(40, 160, 255),
	PadB = Color3.fromRGB(80, 195, 255),
	Ink = Color3.fromRGB(22, 22, 32),
}

local rng = Random.new(7) -- fixed seed, so the hills and trees are the same every time

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function studded(p)
	p.TopSurface = Enum.SurfaceType.Studs
	return p
end

-- Outlined text floating in the world
local function billboard(adornee, lines, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(220, 90)
	gui.StudsOffsetWorldSpace = offset or Vector3.new(0, 8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = adornee
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, line.Height or 0.34, 0)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = line.Text
		label.TextColor3 = line.Color or Color3.new(1, 1, 1)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = C.Ink
		stroke.Parent = label
	end
	return gui
end

---------------------------------------------------------------- sky and light
local function buildSky()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 170, 240)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Threshold = 2.5
	bloom.Parent = Lighting
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = workspace.Terrain
end

---------------------------------------------------------------- decorations
-- Blocky trees in a few shapes, so a forest doesn't look copy-pasted
local TREE_SHAPES = {
	Classic = { Trunk = 6, Layer = 4.5, Widths = { 13, 10, 7, 4 } },
	Bushy = { Trunk = 4, Layer = 4.2, Widths = { 17, 15, 12.5, 9.5, 6 } },
	Tall = { Trunk = 9, Layer = 4.4, Widths = { 11, 10, 8.5, 7, 5.5, 3.5 } },
}
local DARK_PINE = Color3.fromRGB(25, 115, 45)
local LIGHT_PINE = Color3.fromRGB(100, 205, 85)

-- a random look: shape, shade (-1 dark .. 1 light) and a slight turn
local function treeLook()
	local roll = rng:NextNumber()
	return {
		Shape = if roll < 0.35 then "Classic" elseif roll < 0.72 then "Bushy" else "Tall",
		Shade = rng:NextNumber(-1, 1),
		Turn = rng:NextNumber(-0.25, 0.25),
	}
end

local function pine(parent, base, scale, look)
	scale = scale or 1
	look = look or treeLook()
	local shape = TREE_SHAPES[look.Shape]
	local tint = if look.Shade < 0 then DARK_PINE else LIGHT_PINE
	local dark = C.Pine:Lerp(tint, math.abs(look.Shade) * 0.45)
	local light = C.PineLight:Lerp(tint, math.abs(look.Shade) * 0.45)
	local turn = CFrame.Angles(0, look.Turn, 0)
	local trunk = part(parent, { Name = "Trunk", Size = Vector3.new(2.5, shape.Trunk + 1, 2.5) * scale, Color = C.Trunk })
	trunk.CFrame = CFrame.new(base + Vector3.new(0, (shape.Trunk + 1) / 2 * scale, 0)) * turn
	for i, w in shape.Widths do
		local leaves = part(parent, { Name = "Leaves", Size = Vector3.new(w, shape.Layer, w) * scale, Color = if i % 2 == 0 then light else dark })
		leaves.CFrame = CFrame.new(base + Vector3.new(0, (shape.Trunk + (i - 0.5) * shape.Layer) * scale, 0)) * turn
	end
end

-- A low clump of leafy blocks at the foot of the hills
local function bush(parent, base, scale, side)
	for i, o in { Vector3.new(0, 1.6, 0), Vector3.new(2.6 * side, 1.1, 1.5), Vector3.new(-1.8 * side, 1, -2) } do
		part(parent, { Name = "Bush", Size = Vector3.new(4.4, 3.2, 4.4) * (if i == 1 then 1 else 0.75) * scale, Position = base + o * scale, Color = if i == 2 then C.PineLight else C.Pine })
	end
end

local function mushroom(parent, base, scale)
	scale = scale or 1
	part(parent, { Name = "Stalk", Size = Vector3.new(2.4, 7, 2.4) * scale, Position = base + Vector3.new(0, 3.5 * scale, 0), Color = Color3.fromRGB(245, 235, 215) })
	local cap = part(parent, { Name = "Cap", Size = Vector3.new(11, 3, 11) * scale, Position = base + Vector3.new(0, 8 * scale, 0), Color = Color3.fromRGB(220, 50, 60) })
	part(parent, { Name = "CapTop", Size = Vector3.new(7, 2, 7) * scale, Position = cap.Position + Vector3.new(0, 2.4 * scale, 0), Color = Color3.fromRGB(220, 50, 60) })
	for _, o in { Vector3.new(3.5, 1.6, 2), Vector3.new(-2.5, 1.6, -3.5), Vector3.new(-3.8, 1.6, 2.6), Vector3.new(1, 3.5, -1) } do
		part(parent, { Name = "Spot", Size = Vector3.new(1.6, 0.4, 1.6) * scale, Position = cap.Position + o * scale, Color = Color3.new(1, 1, 1) })
	end
end

-- A chunky stepped hill: a dirt block with a grass cap, sometimes a smaller step on top
local function hill(parent, x, z, w, d, height)
	local body = part(parent, { Name = "Hill", Size = Vector3.new(w, height, d), Position = Vector3.new(x, height / 2 - 0.5, z), Color = C.Dirt })
	-- a darker band of dirt for that layered look
	part(parent, { Name = "Band", Size = Vector3.new(w + 0.2, height * 0.18, d + 0.2), Position = body.Position - Vector3.new(0, height * 0.22, 0), Color = C.DirtDark, CanCollide = false })
	studded(part(parent, { Name = "HillTop", Size = Vector3.new(w + 1, 3, d + 1), Position = Vector3.new(x, height + 1, z), Color = C.HillTop }))
	return Vector3.new(x, height + 2.5, z)
end

-- The terraced cliff down each side: steps rising away from the field, covered in trees
local TERRACES = {
	{ From = 0, To = 10, Share = 0.4, Trees = true },
	{ From = 10, To = 20, Share = 0.7, Trees = true },
	{ From = 20, To = 32, Share = 1, Trees = true },
	{ From = 32, To = 60, Share = 1.3, Trees = false },
}

local function ringOfHills(parent)
	local cell = 24
	local half = cell / 2
	-- the back: two rows of chunky hills
	local function strip(fromX, toX, z, inner)
		for x = fromX, toX, cell do
			local top = hill(parent, x, z, cell, cell, if inner then rng:NextInteger(18, 34) else rng:NextInteger(40, 70))
			if rng:NextNumber() < 0.55 then
				pine(parent, top + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), rng:NextNumber(1, 1.6))
			end
		end
	end
	strip(X0 + half, X1 - half, Z0 - half, true)
	strip(X0 - half - 2 * cell, X1 + half + 2 * cell, Z0 - half - cell, false)

	-- the sides: the same terraced cliff mirrored on both, sloping down toward the front
	local STEP = 12
	local SLOPE_FROM, SLOPE_TO = -40, Z1 - 24
	local FRONT = Z1 - 24 -- the side cliffs stop here; the curve takes over
	for z = Z0 - 18, FRONT - STEP / 2, STEP do
		local t = math.clamp((z - SLOPE_FROM) / (SLOPE_TO - SLOPE_FROM), 0, 1)
		local height = 44 + (10 - 44) * t + rng:NextNumber(-2, 2)
		-- pick everything once, then build both sides from the same picks
		local bumps, picks = {}, {}
		for k, terrace in TERRACES do
			bumps[k] = rng:NextNumber(-1.5, 2.5) -- each step a little uneven
			picks[k] = {}
			if terrace.Trees then
				-- higher steps get bigger trees; sometimes two share a step
				local trees = if rng:NextNumber() < 0.85 then (if rng:NextNumber() < 0.3 then 2 else 1) else 0
				for n = 1, trees do
					table.insert(picks[k], {
						Dx = rng:NextNumber(-2.5, 2.5),
						Dz = if trees == 2 then (n - 1.5) * 6 else rng:NextNumber(-3, 3),
						Scale = rng:NextNumber(0.85, 1.15) + (k - 1) * 0.15,
						Look = treeLook(),
					})
				end
			end
		end
		-- (not along the car showroom, which stands against the left side)
		local bushAt = if rng:NextNumber() < 0.35 and math.abs(z) > 56 then rng:NextNumber(-4, 4) else nil
		for _, side in { -1, 1 } do
			for k, terrace in TERRACES do
				local x = side * (FIELD.X / 2 + (terrace.From + terrace.To) / 2)
				local top = hill(parent, x, z, terrace.To - terrace.From, STEP, math.max(3, height * terrace.Share + bumps[k]))
				for _, pick in picks[k] do
					local look = table.clone(pick.Look)
					look.Turn *= side -- mirrored
					pine(parent, top + Vector3.new(side * pick.Dx, 0, pick.Dz), pick.Scale, look)
				end
			end
			if bushAt then
				bush(parent, Vector3.new(side * (FIELD.X / 2 - 2.5), 0, z + bushAt), 1, side)
			end
		end
	end

	-- at the front, the same terraces curve in from each side to the ends of Stage 1's wall,
	-- getting lower all the way
	local wallEnd = Course.WallWidth / 2 + 5
	local count = 18
	for i = 0, count - 1 do
		local t = i / (count - 1)
		local angle = t * math.pi / 2
		local height = 10 - 5 * t
		local looks, bumps = {}, {}
		for k = 1, 3 do
			looks[k] = treeLook()
			bumps[k] = rng:NextNumber(-0.8, 1.2)
		end
		local tree = rng:NextNumber()
		for _, side in { -1, 1 } do
			local x = side * (wallEnd + (FIELD.X / 2 - 5 - wallEnd) * math.cos(angle))
			local z = FRONT + 2 + 16 * math.sin(angle)
			local out = Vector3.new(side * math.cos(angle), 0, math.sin(angle)) -- away from the field
			for k = 1, 3 do
				local terrace = TERRACES[k]
				local at = Vector3.new(x, 0, z) + out * (k - 1) * 10
				if at.Z <= Z1 - 5 and math.abs(at.X) <= FIELD.X / 2 then
					local top = hill(parent, at.X, at.Z, 10, 10, math.max(2.5, height * terrace.Share + bumps[k]))
					-- full, bushy trees all along the curve, bigger further back
					if k > 1 or i % 2 == 0 then
						local look = table.clone(looks[k])
						look.Turn *= side
						pine(parent, top, 0.7 + 0.2 * k + 0.15 * tree, look)
					end
				end
			end
			-- an invisible wall over the first step, so the only way out is through the stage wall
			part(parent, { Name = "HillBlock", Size = Vector3.new(10, ROOF_Y, 10), Position = Vector3.new(x, ROOF_Y / 2, z), Transparency = 1, CanQuery = false })
		end
	end
	-- and invisible walls along both side edges of the field and across the back, right up
	-- to the roof
	for _, side in { -1, 1 } do
		part(parent, { Name = "HillBlock", Size = Vector3.new(2, ROOF_Y, FIELD.Y + 4), Position = Vector3.new(side * (FIELD.X / 2 + 1), ROOF_Y / 2, 0), Transparency = 1, CanQuery = false })
	end
	part(parent, { Name = "HillBlock", Size = Vector3.new(FIELD.X + 4, ROOF_Y, 2), Position = Vector3.new(0, ROOF_Y / 2, Z0 - 1), Transparency = 1, CanQuery = false })
end

---------------------------------------------------------------- the field
local function buildField(map)
	local field = Instance.new("Folder")
	field.Name = "Field"
	field.Parent = map
	-- two-tone studded grass tiles
	for ix = 0, FIELD.X / TILE - 1 do
		for iz = 0, FIELD.Y / TILE - 1 do
			studded(part(field, {
				Name = "Grass",
				Size = Vector3.new(TILE, 4, TILE),
				Position = Vector3.new(X0 + ix * TILE + TILE / 2, -2, Z0 + iz * TILE + TILE / 2),
				Color = if (ix + iz) % 2 == 0 then C.GrassA else C.GrassB,
			}))
		end
	end
	-- the cliff under the front edge, in dirt layers
	for i, color in { C.Dirt, C.DirtDark, C.Dirt, C.DirtDark } do
		part(field, { Name = "Cliff", Size = Vector3.new(FIELD.X + 2, 40, 8), Position = Vector3.new(0, -4 - (i - 0.5) * 40, Z1 - 4), Color = color })
	end
	-- grass lip along the edge
	studded(part(field, { Name = "Edge", Size = Vector3.new(FIELD.X, 1, 4), Position = Vector3.new(0, 0.5, Z1 - 2), Color = C.HillTop }))

	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = map
	ringOfHills(hills)

	-- a few trees and mushrooms dotted on the field near the hills
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = map
	for _, spot in {
		Vector3.new(-48, 0, -86), Vector3.new(48, 0, -86),
	} do
		pine(deco, spot, 1.2)
	end
	for _, spot in { Vector3.new(-48, 0, 58) } do
		mushroom(deco, spot, 1.3)
	end
end

---------------------------------------------------------------- launch pad
-- A blue checkered plus shape with white arrows pointing out over the cliff
local function buildLaunchPad(map)
	local pad = Instance.new("Model")
	pad.Name = "LaunchPad"
	local centre = Map.LaunchPosition
	local cell = 8
	local cells = {}
	for x = -2, 2 do
		for z = -4, 4 do
			if math.abs(x) <= 1 or math.abs(z) <= 1 then
				table.insert(cells, Vector2.new(x, z))
			end
		end
	end
	for _, c in cells do
		studded(part(pad, {
			Name = "Tile",
			Size = Vector3.new(cell, 1, cell),
			Position = centre + Vector3.new(c.X * cell, 0.5, c.Y * cell),
			Color = if (c.X + c.Y) % 2 == 0 then C.PadA else C.PadB,
		}))
	end
	-- arrows: a white bar with a wedge tip, pointing toward the cliff (+z)
	for _, z in { -24, -6, 12 } do
		local base = centre + Vector3.new(0, 1.15, z)
		part(pad, { Name = "Arrow", Size = Vector3.new(2.5, 0.3, 7), Position = base, Color = Color3.new(1, 1, 1), CanCollide = false })
		local tip = Instance.new("WedgePart")
		tip.Anchored = true
		tip.CanCollide = false
		tip.Color = Color3.new(1, 1, 1)
		tip.Material = Enum.Material.Plastic
		tip.Size = Vector3.new(7, 0.3, 5)
		tip.CFrame = CFrame.new(base + Vector3.new(0, 0, 6)) * CFrame.Angles(0, math.pi, 0)
		tip.Parent = pad
	end
	-- a sign floating above
	local anchor = part(pad, { Name = "SignAnchor", Size = Vector3.new(1, 1, 1), Position = centre + Vector3.new(0, 4, -36), Transparency = 1, CanCollide = false })
	billboard(anchor, {
		{ Text = "Build a Road!", Height = 0.5 },
		{ Text = "Click or press Space", Color = Color3.fromRGB(255, 222, 50), Height = 0.3 },
	}, UDim2.fromScale(26, 8), Vector3.new(0, 6, 0))
	pad.Parent = map
end

---------------------------------------------------------------- training pads
-- Boosts and rebirth needs come from Config.Training; the right side of the field, facing the middle
local PAD_COLORS = {
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 70, 80),
	Color3.fromRGB(80, 230, 90),
	Color3.fromRGB(255, 150, 220),
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(255, 200, 45), -- the Golden Treadmill (shiny metal, sparkles)
}
local GOLD_SHINE = { Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 }

-- Each treadmill, as the server needs it: the belt's area (who is on it), where a car locks
-- in while training, and where it is put when it gets off. { Min, Max, Tier, Lock, Exit }
local padRegions = {}

-- the treadmill tier a position is on, or nil
function Map.padAt(pos)
	for _, r in padRegions do
		if pos.X >= r.Min.X and pos.X <= r.Max.X and pos.Z >= r.Min.Z and pos.Z <= r.Max.Z and pos.Y >= r.Min.Y and pos.Y <= r.Max.Y then
			return r.Tier
		end
	end
	return nil
end

-- { Lock = CFrame on the belt facing the screen (ground level), Exit = CFrame off the front }
function Map.padInfo(tier)
	for _, r in padRegions do
		if r.Tier == tier then
			return r
		end
	end
	return nil
end

-- A slim car treadmill, like a gym treadmill made big: a low, thin frame in the pad's colour,
-- a dark rolling belt between slim rollers, thin side rails with a glowing edge, a little
-- ramp at the back, and two slim uprights at the front holding a handlebar and a tilted
-- screen that shows the boost. Cars drive on facing the screen.
local ROLLER = Color3.fromRGB(175, 182, 196)
local BELT = Color3.fromRGB(42, 45, 58)
local TREAD = { Length = 24, Width = 10.6, Height = 0.9, BeltLength = 19.6, BeltWidth = 8 }
local function buildTrainingPads(map)
	local folder = Instance.new("Folder")
	folder.Name = "TrainingPads"
	folder.Parent = map
	local x = X1 - 26
	for i, settings in Config.Training.Pads do
		local golden = settings.Pass ~= nil
		local info = {
			Name = settings.Name,
			Boost = "x" .. settings.Boost,
			Needs = if golden then "Game Pass" elseif settings.Rebirths == 0 then "Free" elseif settings.Rebirths == 1 then "1 Rebirth" else settings.Rebirths .. " Rebirths",
			Color = PAD_COLORS[i] or PAD_COLORS[#PAD_COLORS],
		}
		local light = info.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		local dark = info.Color:Lerp(Color3.new(0, 0, 0), 0.35)
		local z = Z0 + 41 + (i - 1) * 16 -- 16 apart, centred where the old wider row was
		local pad = Instance.new("Model")
		pad.Name = info.Name
		local shiny = {}
		local function add(props)
			local p = part(pad, props)
			if golden then
				table.insert(shiny, p)
			end
			return p
		end
		local L, W, H = TREAD.Length, TREAD.Width, TREAD.Height
		local front = x + L / 2 -- the screen end

		-- the low frame, with a darker trim along the bottom
		local base = add({ Name = "Base", Size = Vector3.new(L, H, W), Position = Vector3.new(x, H / 2, z), Color = info.Color })
		part(pad, { Name = "Trim", Size = Vector3.new(L + 0.3, 0.3, W + 0.3), Position = Vector3.new(x, 0.15, z), Color = dark })
		-- a little ramp up the back end
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Anchored = true
		ramp.Color = info.Color
		ramp.Size = Vector3.new(TREAD.BeltWidth, H, 3)
		ramp.CFrame = CFrame.new(x - L / 2 - 1.5, H / 2, z) * CFrame.Angles(0, math.rad(90), 0)
		ramp.Parent = pad
		if golden then
			table.insert(shiny, ramp)
		end

		-- the belt with sliding stripes (Controllers.Treadmills moves them) between slim rollers
		local belt = part(pad, { Name = "Belt", Size = Vector3.new(TREAD.BeltLength, 0.3, TREAD.BeltWidth), Position = Vector3.new(x - 0.6, H + 0.15, z), Color = BELT })
		for s = -3, 3 do
			part(pad, { Name = "Stripe", Size = Vector3.new(0.6, 0.08, TREAD.BeltWidth - 0.6), Position = belt.Position + Vector3.new(s * 2.8, 0.19, 0), Color = Color3.fromRGB(85, 90, 108), CanCollide = false })
		end
		for _, rx in { -1, 1 } do
			local roller = part(pad, { Name = "Roller", Shape = Enum.PartType.Cylinder, Size = Vector3.new(TREAD.BeltWidth + 0.2, 0.9, 0.9), Color = ROLLER, Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
			roller.CFrame = CFrame.new(belt.Position + Vector3.new(rx * (TREAD.BeltLength / 2 + 0.2), -0.05, 0)) * CFrame.Angles(0, math.rad(90), 0)
		end

		-- thin side rails, each with a glowing edge on the outside
		for _, side in { -1, 1 } do
			local railZ = z + side * (W / 2 - 0.6)
			add({ Name = "Rail", Size = Vector3.new(L - 1, 0.45, 1), Position = Vector3.new(x - 0.5, H + 0.22, railZ), Color = light })
			part(pad, { Name = "Glow", Size = Vector3.new(L - 2, 0.25, 0.12), Position = Vector3.new(x - 0.5, H / 2, z + side * (W / 2 + 0.06)), Color = light, Material = Enum.Material.Neon, CanCollide = false })
		end

		-- two slim uprights leaning back a little, a handlebar across them, and the screen
		local TOP = 7
		for _, side in { -1, 1 } do
			local bottom = Vector3.new(front - 0.6, H, z + side * (W / 2 - 0.6))
			local top = Vector3.new(front - 2.4, H + TOP, z + side * (W / 2 - 0.9))
			local post = add({ Name = "Post", Size = Vector3.new(0.55, 0.55, (top - bottom).Magnitude), Color = dark })
			post.CFrame = CFrame.lookAt((bottom + top) / 2, top)
			-- a short side handle sticking back toward the car
			add({ Name = "Handle", Size = Vector3.new(4, 0.45, 0.45), Position = Vector3.new(front - 4.2, H + TOP - 2.6, z + side * (W / 2 - 0.9)), Color = dark })
		end
		add({ Name = "Bar", Size = Vector3.new(0.5, 0.5, W - 1.2), Position = Vector3.new(front - 2.4, H + TOP, z), Color = dark })
		local console = add({ Name = "Console", Size = Vector3.new(0.5, 3.6, W - 2.4), Color = info.Color })
		console.CFrame = CFrame.new(front - 2.2, H + TOP + 1.9, z) * CFrame.Angles(0, 0, math.rad(-22))
		local screen = part(pad, { Name = "Screen", Size = Vector3.new(0.1, 3, W - 3.2), Color = Color3.fromRGB(25, 30, 45), Material = Enum.Material.SmoothPlastic })
		screen.CFrame = console.CFrame * CFrame.new(-0.3, 0, 0)
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Left
		surface.LightInfluence = 0
		surface.PixelsPerStud = 50
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.Parent = screen
		local boostText = Instance.new("TextLabel")
		boostText.BackgroundTransparency = 1
		boostText.Size = UDim2.fromScale(0.9, 0.8)
		boostText.Position = UDim2.fromScale(0.05, 0.1)
		boostText.Font = Enum.Font.GothamBlack
		boostText.TextScaled = true
		boostText.Text = info.Boost
		boostText.TextColor3 = if golden then Color3.fromRGB(255, 215, 70) else light
		boostText.Parent = surface
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = C.Ink
		stroke.Parent = boostText

		if golden then
			for _, p in shiny do
				p.Color = Color3.fromRGB(255, 200, 45)
				p.Material = GOLD_SHINE.Material
				p.Reflectance = GOLD_SHINE.Reflectance
			end
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Name = "Sparkles"
			sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120))
			sparkles.LightEmission = 1
			sparkles.Size = NumberSequence.new(0.6, 0)
			sparkles.Lifetime = NumberRange.new(0.8, 1.4)
			sparkles.Rate = 14
			sparkles.Speed = NumberRange.new(2, 4)
			sparkles.SpreadAngle = Vector2.new(60, 60)
			sparkles.EmissionDirection = Enum.NormalId.Top
			sparkles.Parent = base
		end

		billboard(console, {
			{ Text = info.Name, Height = 0.38 },
			{ Text = info.Boost .. " Horsepower", Color = Color3.fromRGB(255, 222, 50), Height = 0.32 },
			{ Text = info.Needs, Color = if golden then Color3.fromRGB(255, 200, 45) elseif info.Needs == "Free" then Color3.fromRGB(120, 255, 130) else Color3.fromRGB(255, 120, 120), Height = 0.28 },
		}, UDim2.fromScale(14, 7), Vector3.new(0, 6, 0))

		-- anyone whose root is over the belt (up to car height above it) is on it
		local beltTop = belt.Position.Y + belt.Size.Y / 2
		table.insert(padRegions, {
			Min = belt.Position - Vector3.new(belt.Size.X / 2, 0, belt.Size.Z / 2 + 1),
			Max = belt.Position + Vector3.new(belt.Size.X / 2, 10, belt.Size.Z / 2 + 1),
			Tier = i,
			Lock = CFrame.lookAt(Vector3.new(belt.Position.X, beltTop, z), Vector3.new(belt.Position.X + 1, beltTop, z)),
			Exit = CFrame.lookAt(Vector3.new(x - L / 2 - 8, 0, z), Vector3.new(x - L / 2 - 20, 0, z)),
		})
		pad:SetAttribute("Tier", i)
		pad.PrimaryPart = base
		pad.Parent = folder
	end
end

---------------------------------------------------------------- car stands
-- A long wooden showroom against the left side wall, facing the middle: cars 1-5 sit
-- on dark pads in a low front row, cars 6-10 on a raised back row behind them, with
-- sloped wooden ends. Each pad's colour, status line and prompt are changed per player by
-- the client (Controllers.Cars); the server builds them and handles unlock/equip (Game).
local SHOWROOM = {
	FrontX = X0 + 38, -- front lip of the showroom
	BackX = X0, -- back edge, against the side wall
	TierX = X0 + 18, -- where the raised back row starts
	Z0 = -46, Z1 = 46, -- along the side of the field
	TierHeight = 6,
	RowX = { X0 + 28, X0 + 9 }, -- pad centres of the front and back rows
	PadZ = { -36, -18, 0, 18, 36 },
}
local WOOD = Color3.fromRGB(214, 150, 85)
local WOOD_DARK = Color3.fromRGB(120, 75, 40)
Map.PadColor = Color3.fromRGB(45, 48, 58)
Map.PadEquippedColor = Color3.fromRGB(90, 225, 90)

local function buildCarStands(map)
	local s = SHOWROOM
	local folder = Instance.new("Folder")
	folder.Name = "CarStands"
	folder.Parent = map
	local length = s.Z1 - s.Z0
	local midZ = (s.Z0 + s.Z1) / 2
	local room = Instance.new("Model")
	room.Name = "Showroom"
	-- the deck, the raised back tier and its dark front face, and the front lip
	part(room, { Name = "Deck", Size = Vector3.new(s.FrontX - s.BackX, 1, length), Position = Vector3.new((s.FrontX + s.BackX) / 2, 0.5, midZ), Color = WOOD, Material = Enum.Material.Wood })
	part(room, { Name = "Tier", Size = Vector3.new(s.TierX - s.BackX, s.TierHeight, length), Position = Vector3.new((s.TierX + s.BackX) / 2, s.TierHeight / 2, midZ), Color = WOOD, Material = Enum.Material.Wood })
	part(room, { Name = "TierFace", Size = Vector3.new(0.3, s.TierHeight - 1, length), Position = Vector3.new(s.TierX + 0.15, 1 + (s.TierHeight - 1) / 2, midZ), Color = WOOD_DARK, Material = Enum.Material.Wood })
	part(room, { Name = "Lip", Size = Vector3.new(1.5, 2.4, length), Position = Vector3.new(s.FrontX - 0.75, 1.2, midZ), Color = WOOD_DARK, Material = Enum.Material.Wood })
	-- sloped wooden ends, high against the showroom and low on the outside
	for _, side in { -1, 1 } do
		local z = if side < 0 then s.Z0 - 2 else s.Z1 + 2
		local slope = Instance.new("WedgePart")
		slope.Name = "End"
		slope.Anchored = true
		slope.Material = Enum.Material.Wood
		slope.Color = WOOD
		slope.Size = Vector3.new(s.FrontX - s.BackX, s.TierHeight, 4)
		slope.CFrame = CFrame.new((s.FrontX + s.BackX) / 2, s.TierHeight / 2, z) * (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		slope.Parent = room
	end
	room.Parent = folder

	local facing = CFrame.Angles(0, math.rad(-90), 0) -- cars face +x, toward the middle
	for tier = 1, CarLooks.Count do
		local row = if tier <= 5 then 1 else 2
		local floorY = if row == 1 then 1 else s.TierHeight
		local at = Vector3.new(s.RowX[row], floorY, s.PadZ[(tier - 1) % 5 + 1])
		local info = CarLooks.info(tier)

		local stand = Instance.new("Model")
		stand.Name = "Stand" .. tier
		local pad = part(stand, { Name = "Base", Size = Vector3.new(15, 0.3, 12), Position = at + Vector3.new(0, 0.15, 0), Color = Map.PadColor })

		local car = CarLooks.build(tier, CFrame.new(at + Vector3.new(0, 0.3, 0)) * facing)
		car.Name = "Car"
		car.Parent = stand

		local sign = billboard(pad, {
			{ Text = info.Name, Height = 0.36 },
			{ Text = "x" .. Config.Cars.Boosts[tier] .. " Horsepower", Color = Color3.fromRGB(255, 222, 50), Height = 0.26 },
			{ Text = "", Height = 0.3 },
		}, UDim2.fromScale(14, 6), Vector3.new(0, 8.5, 0))
		sign.Name = "Sign"
		for _, child in sign:GetChildren() do
			if child:IsA("TextLabel") then
				child.Name = ({ "Title", "Boost", "Status" })[child.LayoutOrder]
			end
		end

		-- the prompt reaches the raised back row from the front of the showroom too
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Unlock"
		prompt.ActionText = "Unlock"
		prompt.ObjectText = info.Name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = if row == 1 then 16 else 32
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad

		stand:SetAttribute("Tier", tier)
		stand.PrimaryPart = pad
		stand.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client always needs every stand
		stand.Parent = folder
	end
end

-- The VIP Cruiser on its own round gold stage in front of the showroom, with gold posts
-- and sparkles. Tier 11, so the same unlock/equip code and status line handle it.
local VIP_AT = Vector3.new(X0 + 22, 0, 66)
local function buildVipStand(map)
	local tier = Config.Cars.VipTier
	local info = CarLooks.info(tier)
	local stand = Instance.new("Model")
	stand.Name = "StandVip"
	local stage = part(stand, { Name = "Stage", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 24, 24), CFrame = CFrame.new(VIP_AT + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 34, 52) })
	part(stand, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 25, 25), CFrame = stage.CFrame * CFrame.new(-0.1, 0, 0), Color = Color3.fromRGB(255, 200, 45), Material = GOLD_SHINE.Material, Reflectance = GOLD_SHINE.Reflectance })
	local pad = part(stand, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 18, 18), CFrame = CFrame.new(VIP_AT + Vector3.new(0, 2.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 215, 80), Material = GOLD_SHINE.Material, Reflectance = GOLD_SHINE.Reflectance })
	-- golden posts with neon tops on four corners
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local at = VIP_AT + corner * 8.5
		part(stand, { Name = "Post", Size = Vector3.new(1.2, 6, 1.2), Position = at + Vector3.new(0, 5, 0), Color = Color3.fromRGB(255, 200, 45), Material = GOLD_SHINE.Material, Reflectance = GOLD_SHINE.Reflectance })
		part(stand, { Name = "PostLight", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = at + Vector3.new(0, 8.6, 0), Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon })
	end
	local car = CarLooks.build(tier, CFrame.new(VIP_AT + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, math.rad(-90), 0))
	car.Name = "Car"
	car.Parent = stand
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.7, 0)
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Rate = 10
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(70, 70)
	sparkles.Parent = pad

	local sign = billboard(pad, {
		{ Text = "VIP", Color = Color3.fromRGB(255, 200, 45), Height = 0.3 },
		{ Text = info.Name, Height = 0.3 },
		{ Text = "x" .. Config.Cars.Boosts[tier] .. " Horsepower", Color = Color3.fromRGB(255, 222, 50), Height = 0.2 },
		{ Text = "", Height = 0.24 },
	}, UDim2.fromScale(16, 9), Vector3.new(0, 11, 0))
	sign.Name = "Sign"
	for _, child in sign:GetChildren() do
		if child:IsA("TextLabel") then
			child.Name = ({ "Vip", "Title", "Boost", "Status" })[child.LayoutOrder]
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Unlock"
	prompt.ActionText = "Get VIP"
	prompt.ObjectText = info.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	stand:SetAttribute("Tier", tier)
	stand:SetAttribute("Vip", true)
	stand.PrimaryPart = pad
	stand.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	stand.Parent = map:FindFirstChild("CarStands")
end

---------------------------------------------------------------- leaderboards, worlds portal
local function buildLeaderboards(map)
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	for i, title in { "Most Horsepower", "Most Wins", "Longest Road" } do
		local at = Vector3.new((i - 2) * 26, 0, Z0 + 18) -- centred on the back
		part(boards, { Name = "Stand", Size = Vector3.new(22, 1, 4), Position = at + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(70, 70, 90) })
		local board = part(boards, { Name = "Board", Size = Vector3.new(20, 24, 1.5), Position = at + Vector3.new(0, 13, 0), Color = Color3.fromRGB(150, 90, 50) })
		part(boards, { Name = "Inner", Size = Vector3.new(17, 20, 0.4), Position = board.Position + Vector3.new(0, 0, 0.9), Color = Color3.fromRGB(240, 230, 210) })
		-- simple rows to read as a list of names
		for r = 0, 6 do
			part(boards, { Name = "Row", Size = Vector3.new(14, 1.2, 0.2), Position = board.Position + Vector3.new(0, 6.5 - r * 2.4, 1.15), Color = if r % 2 == 0 then Color3.fromRGB(200, 180, 150) else Color3.fromRGB(215, 200, 175), CanCollide = false })
		end
		billboard(board, { { Text = title, Height = 0.9 } }, UDim2.fromScale(20, 3.6), Vector3.new(0, 14.5, 0))
	end
	boards.Parent = map
end

local function buildPortal(map)
	local portal = Instance.new("Model")
	portal.Name = "WorldsPortal"
	-- in the back-left corner, turned 45 degrees to face the middle of the field
	local at = CFrame.new(X0 + 24, 0, Z0 + 24) * CFrame.Angles(0, math.rad(45), 0)
	-- a chunky stone arch
	for _, sx in { -1, 1 } do
		part(portal, { Name = "Pillar", Size = Vector3.new(5, 24, 6), CFrame = at * CFrame.new(sx * 10, 12, 0), Color = Color3.fromRGB(70, 60, 110) })
	end
	part(portal, { Name = "Top", Size = Vector3.new(25, 5, 6), CFrame = at * CFrame.new(0, 25.5, 0), Color = Color3.fromRGB(70, 60, 110) })
	part(portal, { Name = "Step", Size = Vector3.new(26, 1, 10), CFrame = at * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(90, 80, 130) })
	-- the swirl
	local swirl = part(portal, { Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 17, 15), CFrame = at * CFrame.new(0, 12, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(140, 60, 255), Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
	swirl:SetAttribute("Spin", 1.5)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 90, 255)
	light.Range = 20
	light.Brightness = 2
	light.Parent = swirl
	billboard(swirl, { { Text = "Worlds", Height = 0.55 }, { Text = "Coming soon", Color = Color3.fromRGB(255, 222, 50), Height = 0.4 } }, UDim2.fromScale(16, 6), Vector3.new(0, 17, 0))
	portal.Parent = map
end

---------------------------------------------------------------- the valley beyond the cliff
local function buildValley(map)
	local valley = Instance.new("Folder")
	valley.Name = "Valley"
	valley.Parent = map
	local floorY = -150
	studded(part(valley, { Name = "ValleyFloor", Size = Vector3.new(900, 4, 900), Position = Vector3.new(0, floorY - 2, Z1 + 450), Color = C.GrassA }))
	-- scattered hills and trees down in the valley
	for _ = 1, 26 do
		local x = rng:NextNumber(-380, 380)
		local z = rng:NextNumber(Z1 + 60, Z1 + 820)
		local w = rng:NextInteger(2, 4) * 16
		local h = rng:NextInteger(16, 60)
		local body = part(valley, { Name = "Hill", Size = Vector3.new(w, h, w), Position = Vector3.new(x, floorY + h / 2, z), Color = C.Dirt })
		studded(part(valley, { Name = "HillTop", Size = Vector3.new(w + 1, 3, w + 1), Position = body.Position + Vector3.new(0, h / 2 + 1, 0), Color = C.HillTop }))
		if rng:NextNumber() < 0.6 then
			pine(valley, body.Position + Vector3.new(0, h / 2 + 2.5, 0), 1.5)
		end
	end
	for _ = 1, 30 do
		pine(valley, Vector3.new(rng:NextNumber(-400, 400), floorY, rng:NextNumber(Z1 + 40, Z1 + 860)), rng:NextNumber(1.4, 2.2))
	end
	-- a river winding across the valley
	for i = 0, 9 do
		local z = Z1 + 140 + i * 70
		part(valley, { Name = "River", Size = Vector3.new(40, 1, 74), Position = Vector3.new(math.sin(i * 0.8) * 90, floorY + 0.3, z), Color = Color3.fromRGB(70, 170, 255), Material = Enum.Material.SmoothPlastic, Transparency = 0.1 })
	end
end

---------------------------------------------------------------- build it all
function Map.build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	for _, name in { "Baseplate", "SpawnLocation" } do
		local p = workspace:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	buildSky()
	local map = Instance.new("Folder")
	map.Name = "Map"
	buildField(map)
	task.wait()
	buildValley(map)
	task.wait()
	buildLaunchPad(map)
	buildTrainingPads(map)
	buildCarStands(map) -- the ten car stands, front-left
	buildVipStand(map)
	buildLeaderboards(map)
	buildPortal(map)
	Course.build(map, Vector3.new(0, 0, Z1), Map.HalfWidth) -- the 15 stages, out from the cliff edge

	-- an invisible roof over everything, so nobody can fly or glitch out over the walls
	-- (in pieces, since a part can only be 2048 studs long)
	local roofFrom, roofTo = Z0 - 4, Course.EndZ + 4
	for z = roofFrom, roofTo, 2000 do
		local len = math.min(2000, roofTo - z)
		part(map, { Name = "Roof", Size = Vector3.new(FIELD.X + 16, 4, len), Position = Vector3.new(0, ROOF_Y + 2, z + len / 2), Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- players spawn facing the way the spawn faces: out towards the stages (+Z), not the leaderboards
	spawn.CFrame = CFrame.lookAt(Map.SpawnPosition - Vector3.new(0, 3.5, 0), Map.SpawnPosition - Vector3.new(0, 3.5, 0) + Vector3.new(0, 0, 1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = map
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	map.Parent = workspace
	return map
end

-- Kept for the old gate code until the road system replaces it
function Map.gatePosition(index)
	return Vector3.new(0, 0, 10000 + index)
end
function Map.finishPosition()
	return Vector3.new(0, 0, 20000)
end

return Map

