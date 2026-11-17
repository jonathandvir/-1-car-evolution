-- Builds the 15 stages, running straight out from the cliff edge of the base (+Z).
--
-- Each stage is a wide strip of land with tall walls far out on both sides. Down the
-- middle runs the track: platforms with gaps between them (bridged by the player's road),
-- wiggling left and right, with moving bits on later stages. The land either side is
-- scenery for that stage's theme, and invisible walls along the track's edges keep cars
-- on the track. Each stage starts with a see-through wall showing the level it needs.
--
-- Moving parts are tagged "Mover" and animated on each client (Controllers.Movers) from
-- the server clock, so they look smooth and carry the player's car properly.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Course = {}

local INK = Color3.fromRGB(22, 22, 32)
local WHITE = Color3.new(1, 1, 1)
-- the track blocks: light checkered tops on chunky blue-grey sides
local BLOCK_TOP_A = Color3.fromRGB(236, 238, 243)
local BLOCK_TOP_B = Color3.fromRGB(214, 218, 226)
local BLOCK_SIDE = Color3.fromRGB(112, 126, 152)
-- the floor of the pits between blocks: falling in sends you back to the stage start
local PIT_A = Color3.fromRGB(255, 200, 45)
local PIT_B = Color3.fromRGB(255, 170, 30)

local HALF_WIDTH = 96 -- the outer walls stand this far either side of the middle (set by build)
local WALL_HEIGHT = 48
local DEPTH = 14 -- how deep the track blocks go
local LAND_Y = -10 -- the scenery land and the pit floors sit this far below the track, so the blocks stand up
local LANE_LIMIT = 40 -- how far the track can wander from the middle

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Each stage's look. Props are scattered over its land; Pieces are a couple of big
-- set pieces; Water is the colour of its ponds.
local THEMES = {
	{ Name = "Green Meadow", Top = rgb(95, 215, 85), Side = rgb(125, 85, 50), Accent = rgb(255, 80, 80), Decor = rgb(50, 160, 60), Props = { "Tree", "Bush", "Flower" }, Pieces = { "Barn", "Pond" }, Water = rgb(70, 170, 255) },
	{ Name = "Autumn Woods", Top = rgb(235, 160, 70), Side = rgb(120, 75, 45), Accent = rgb(255, 230, 120), Decor = rgb(215, 95, 40), Props = { "Tree", "Tree", "Rock", "Pumpkin" }, Pieces = { "Cabin", "Pond" }, Water = rgb(80, 150, 200) },
	{ Name = "Dusty Desert", Top = rgb(238, 208, 135), Side = rgb(195, 145, 85), Accent = rgb(255, 120, 60), Decor = rgb(90, 175, 80), Props = { "Cactus", "Rock", "Cactus" }, Pieces = { "Pyramid", "Pyramid" } },
	{ Name = "Red Canyon", Top = rgb(210, 100, 65), Side = rgb(150, 65, 45), Accent = rgb(255, 215, 150), Decor = rgb(175, 85, 55), Props = { "Rock", "Rock", "Cactus" }, Pieces = { "Mesa", "Mesa" } },
	{ Name = "Sunny Beach", Top = rgb(250, 228, 165), Side = rgb(205, 170, 110), Accent = rgb(255, 90, 120), Decor = rgb(60, 200, 120), Props = { "Palm", "Umbrella", "Palm" }, Pieces = { "Pond", "Hut" }, Water = rgb(60, 200, 230) },
	{ Name = "Jungle Ruins", Top = rgb(70, 170, 75), Side = rgb(110, 105, 95), Accent = rgb(255, 210, 60), Decor = rgb(30, 125, 50), Props = { "Tree", "Bush", "Ruin" }, Pieces = { "Temple", "Pond" }, Water = rgb(70, 160, 130) },
	{ Name = "Snowy Peaks", Top = rgb(242, 248, 255), Side = rgb(150, 170, 200), Accent = rgb(90, 160, 255), Decor = rgb(60, 130, 90), Props = { "Pine", "Pine", "Snowman" }, Pieces = { "Mountain", "Mountain" } },
	{ Name = "Frozen Lake", Top = rgb(175, 228, 255), Side = rgb(110, 160, 220), Accent = rgb(255, 255, 255), Decor = rgb(200, 240, 255), Props = { "Crystal", "Pine", "Snowman" }, Pieces = { "Pond", "Mountain" }, Water = rgb(150, 215, 255), Material = Enum.Material.Ice },
	{ Name = "Candy Land", Top = rgb(255, 175, 215), Side = rgb(255, 245, 250), Accent = rgb(120, 220, 255), Decor = rgb(255, 90, 140), Props = { "Lollipop", "Gumdrop", "Candy" }, Pieces = { "Gumdrops", "Pond" }, Water = rgb(150, 90, 60) },
	{ Name = "Spooky Swamp", Top = rgb(95, 125, 75), Side = rgb(65, 55, 65), Accent = rgb(180, 120, 255), Decor = rgb(70, 90, 50), Props = { "DeadTree", "Rock", "Mushroom" }, Pieces = { "Pond", "Hut" }, Water = rgb(80, 110, 60) },
	{ Name = "Lava Volcano", Top = rgb(75, 65, 65), Side = rgb(45, 38, 38), Accent = rgb(255, 120, 30), Decor = rgb(255, 80, 20), Props = { "Rock", "Crystal", "Rock" }, Pieces = { "Volcano", "LavaPool" }, Water = rgb(255, 100, 20), NeonAccent = true },
	{ Name = "Neon City", Top = rgb(45, 50, 75), Side = rgb(28, 28, 45), Accent = rgb(0, 255, 230), Decor = rgb(255, 60, 200), Props = { "Tower", "Tower", "Lamp" }, Pieces = { "Skyscraper", "Skyscraper" }, NeonAccent = true },
	{ Name = "Moon Base", Top = rgb(195, 195, 205), Side = rgb(120, 120, 135), Accent = rgb(255, 220, 80), Decor = rgb(150, 150, 165), Props = { "Crater", "Rock", "Dish" }, Pieces = { "Rocket", "Dome" } },
	{ Name = "Outer Space", Top = rgb(85, 55, 155), Side = rgb(40, 25, 90), Accent = rgb(255, 255, 120), Decor = rgb(150, 90, 255), Props = { "Crystal", "Crater", "Crystal" }, Pieces = { "Planet", "Planet" }, NeonAccent = true },
	{ Name = "Golden Sky", Top = rgb(255, 215, 95), Side = rgb(225, 165, 45), Accent = rgb(255, 255, 255), Decor = rgb(255, 240, 180), Props = { "Cloud", "Pillar", "Crystal" }, Pieces = { "Statue", "Cloud" } },
}
Course.Themes = THEMES

local rng = Random.new(2026) -- fixed seed, so the course is the same in every server

----------------------------------------------------------------- helpers
local function part(parent, props, class)
	local p = Instance.new(class or "Part")
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

local function ball(parent, size, pos, color, props)
	local p = part(parent, { Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = pos, Color = color })
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder (which lies along x) upright

local function disc(parent, diameter, height, pos, color, props)
	local p = part(parent, { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = CFrame.new(pos) * UPRIGHT, Color = color })
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return p
end

-- a block between two x values and two z values (top surface at y)
local function slab(parent, name, x0, x1, z0, z1, top, thickness, color, props)
	if x1 - x0 < 0.05 or z1 - z0 < 0.05 then
		return nil
	end
	local p = part(parent, {
		Name = name,
		Size = Vector3.new(x1 - x0, thickness, z1 - z0),
		Position = Vector3.new((x0 + x1) / 2, top - thickness / 2, (z0 + z1) / 2),
		Color = color,
	})
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return p
end

local function invisibleWall(parent, x0, x1, z0, z1)
	-- at least a stud thick in both directions, from the ground up high
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = math.max(1, x1 - x0), math.max(1, z1 - z0)
	-- from below the land up high, so nobody slips out of a pit underneath it either
	local wall = part(parent, { Name = "LaneWall", Size = Vector3.new(w, 72, d), Position = Vector3.new(cx, LAND_Y - 2 + 36, cz), Transparency = 1, CanQuery = false, CastShadow = false })
	CollectionService:AddTag(wall, "LaneWall") -- Server.Roads keeps roads inside these too
end

local function mover(p, kind, settings)
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Home", p.CFrame)
	for k, v in settings do
		p:SetAttribute(k, v)
	end
	CollectionService:AddTag(p, "Mover")
end

local function label(parent, text, color, height, order)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3 -- a thin outline, like the reference signs
	stroke.Color = INK
	stroke.Parent = l
	return l
end

----------------------------------------------------------------- track pieces
-- Studded checker tiles covering x0..x1, z0..z1 with their tops at y (edge tiles are cut short)
local function checker(parent, name, x0, x1, z0, z1, y, thickness, colorA, colorB, tile)
	local ix = 0
	local x = x0
	while x < x1 - 0.05 do
		local xe = math.min(x + tile, x1)
		local iz = 0
		local z = z0
		while z < z1 - 0.05 do
			local ze = math.min(z + tile, z1)
			local t = slab(parent, name, x, xe, z, ze, y, thickness, if (ix + iz) % 2 == 0 then colorA else colorB)
			if t then
				t.TopSurface = Enum.SurfaceType.Studs
			end
			z = ze
			iz += 1
		end
		x = xe
		ix += 1
	end
end

-- A chunky track block filling x0..x1, z0..z1: checkered top, blue-grey sides
-- A racing-curb trim around a platform's top edge in the stage's accent colour and white.
-- It's flat paint (no collision), so cars and roads never bump on it.
local TRIM_WIDTH, TRIM_SEGMENT = 1.4, 6
local function trim(parent, theme, x0, x1, z0, z1)
	local accent = if theme.Accent == WHITE then theme.Decor else theme.Accent
	-- a pale accent next to white would hardly show: pair it with the stage's darker colour
	local brightness = accent.R * 0.3 + accent.G * 0.59 + accent.B * 0.11
	local second = if brightness > 0.72 then theme.Side else WHITE
	local function run(ax, az, bx, bz)
		local along = Vector3.new(bx - ax, 0, bz - az)
		local length = along.Magnitude
		local count = math.max(1, math.floor(length / TRIM_SEGMENT + 0.5))
		local step = length / count
		for i = 0, count - 1 do
			local mid = Vector3.new(ax, 0.06, az) + along.Unit * (step * (i + 0.5))
			local size = if math.abs(along.X) > 0 then Vector3.new(step, 0.12, TRIM_WIDTH) else Vector3.new(TRIM_WIDTH, 0.12, step)
			part(parent, {
				Name = "Trim",
				Size = size,
				Position = mid,
				Color = if i % 2 == 0 then accent else second,
				Material = if theme.NeonAccent and i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
		end
	end
	local h = TRIM_WIDTH / 2
	run(x0, z0 + h, x1, z0 + h) -- near edge
	run(x0, z1 - h, x1, z1 - h) -- far edge
	run(x0 + h, z0 + TRIM_WIDTH, x0 + h, z1 - TRIM_WIDTH) -- left side
	run(x1 - h, z0 + TRIM_WIDTH, x1 - h, z1 - TRIM_WIDTH) -- right side
end

local function platform(parent, theme, x0, x1, z0, z1)
	-- the sides take the stage's colour (a touch darker), so every stage looks its own
	slab(parent, "Block", x0, x1, z0, z1, -0.6, DEPTH - 0.6, theme.Side:Lerp(BLOCK_SIDE, 0.25))
	checker(parent, "BlockTop", x0, x1, z0, z1, 0, 0.6, BLOCK_TOP_A, BLOCK_TOP_B, 8)
	trim(parent, theme, x0, x1, z0, z1)
end

-- The floor of a pit: orange checker at the bottom. Touching it sends you to the stage start.
local function pit(parent, x0, x1, z0, z1, start)
	local floor = Instance.new("Folder")
	floor.Name = "Pit"
	floor.Parent = parent
	checker(floor, "PitFloor", x0, x1, z0, z1, LAND_Y, 2, PIT_A, PIT_B, 8)
	for _, tile in floor:GetChildren() do
		tile:SetAttribute("Start", start)
		CollectionService:AddTag(tile, "Pit")
	end
end

-- A block that moves: "Slide" goes side to side, "Lift" goes up and down.
local function movingPlatform(parent, theme, cx, width, z0, z1, kind, amp)
	local len = z1 - z0
	local p = part(parent, { Name = "MovingPlatform", Size = Vector3.new(width, 3, len), Position = Vector3.new(cx, -1.5, (z0 + z1) / 2), Color = BLOCK_TOP_A })
	p.TopSurface = Enum.SurfaceType.Studs
	-- a glowing rim underneath so it reads as "this one moves"
	local rim = part(parent, { Name = "MovingRim", Size = Vector3.new(width + 0.6, 1, len + 0.6), Position = Vector3.new(cx, -3.4, (z0 + z1) / 2), Color = theme.Accent, Material = Enum.Material.Neon, CanCollide = false })
	local settings = { Amp = amp, Period = if kind == "Lift" then 5 else 5.5, Phase = rng:NextNumber(0, 6) }
	mover(p, kind, settings)
	mover(rim, kind, settings)
end

-- Blocks that slide across the platform
local function sliders(parent, theme, cx, width, z0, z1, d)
	local len = z1 - z0
	local count = 1 + math.floor(d * 2.5 + rng:NextNumber())
	for i = 1, count do
		local z = z0 + len * (i / (count + 1))
		local block = part(parent, { Name = "Slider", Size = Vector3.new(4, 3, 4), Position = Vector3.new(cx, 1.5, z), Color = theme.Accent, Material = if theme.NeonAccent then Enum.Material.Neon else Enum.Material.Plastic })
		local stripe = part(parent, { Name = "SliderStripe", Size = Vector3.new(4.1, 0.8, 4.1), Position = block.Position, Color = INK, CanCollide = false })
		local settings = { Amp = width / 2 - 3, Period = rng:NextNumber(3.5, 5) - d, Phase = rng:NextNumber(0, 6) }
		mover(block, "Slide", settings)
		mover(stripe, "Slide", settings)
	end
end

-- A low bar turning slowly around a post in the middle (hop over it or wait for a gap)
local function sweeper(parent, theme, cx, width, z, d)
	disc(parent, 2.4, 3, Vector3.new(cx, 1.5, z), INK)
	local bar = part(parent, { Name = "Sweeper", Size = Vector3.new(width - 3, 1.2, 1.2), Position = Vector3.new(cx, 1.4, z), Color = theme.Accent, Material = if theme.NeonAccent then Enum.Material.Neon else Enum.Material.Plastic })
	mover(bar, "Spin", { Speed = (0.7 + d * 0.6) * (if rng:NextNumber() < 0.5 then -1 else 1) })
end

-- A little bump: up a short ramp, across, and down again.
-- A wedge is low at its front (-Z), so the far ramp is turned round to slope back down.
local function bump(parent, theme, cx, width, z)
	local rise = 2.5
	local at = CFrame.new(cx, 0, z)
	part(parent, { Name = "Ramp", Size = Vector3.new(width - 2, rise, 6), CFrame = at * CFrame.new(0, rise / 2, -7), Color = theme.Accent }, "WedgePart")
	part(parent, { Name = "Bump", Size = Vector3.new(width - 2, rise, 8), CFrame = at * CFrame.new(0, rise / 2, 0), Color = theme.Accent })
	part(parent, { Name = "Ramp", Size = Vector3.new(width - 2, rise, 6), CFrame = at * CFrame.new(0, rise / 2, 7) * CFrame.Angles(0, math.pi, 0), Color = theme.Accent }, "WedgePart")
end

----------------------------------------------------------------- scenery: small props
local PROPS = {}

-- Blocky tiered tree: square layers stepping in, with a flat top (not a point)
-- a few shapes (classic, bushy, tall) so the scenery doesn't repeat
local TREE_SHAPES = {
	{ Trunk = 3, Widths = { 9, 7, 5, 3 } },
	{ Trunk = 2.5, Widths = { 11.5, 10, 8, 5.5, 3.5 } },
	{ Trunk = 5, Widths = { 7.5, 7, 6, 5, 3.5, 2.5 } },
}
local TIER_HEIGHT = 3.2
local function tieredTree(p, t, at, s, snow)
	local shape = TREE_SHAPES[rng:NextInteger(1, #TREE_SHAPES)]
	local trunk = shape.Trunk * s
	part(p, { Name = "Trunk", Size = Vector3.new(1.6 * s, trunk, 1.6 * s), Position = at + Vector3.new(0, trunk / 2, 0), Color = rgb(110, 70, 40) })
	local shade = rng:NextNumber(-0.12, 0.12)
	local base = if shade < 0 then t.Decor:Lerp(Color3.new(0, 0, 0), -shade) else t.Decor:Lerp(WHITE, shade)
	local light = base:Lerp(WHITE, 0.15)
	for i, w in shape.Widths do
		local y = trunk + (i - 0.5) * TIER_HEIGHT * s
		part(p, { Name = "Leaves", Size = Vector3.new(w * s, TIER_HEIGHT * s, w * s), Position = at + Vector3.new(0, y, 0), Color = if i % 2 == 1 then base else light })
		if snow then
			part(p, { Name = "Snow", Size = Vector3.new(w * 0.85 * s, 0.5 * s, w * 0.85 * s), Position = at + Vector3.new(0, y + TIER_HEIGHT * s / 2 + 0.2 * s, 0), Color = WHITE, CanCollide = false })
		end
	end
end

function PROPS.Tree(p, t, at, s)
	tieredTree(p, t, at, s, false)
end

function PROPS.Pine(p, t, at, s)
	tieredTree(p, t, at, s, true)
end

function PROPS.Bush(p, t, at, s)
	ball(p, 5 * s, at + Vector3.new(0, 1.8 * s, 0), t.Decor)
	ball(p, 3.6 * s, at + Vector3.new(2.4 * s, 1.4 * s, 0.5 * s), t.Decor:Lerp(WHITE, 0.1))
end

function PROPS.Flower(p, t, at, s)
	for i = 1, 4 do
		local spot = at + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)) * s
		part(p, { Name = "Stem", Size = Vector3.new(0.3, 1.6, 0.3), Position = spot + Vector3.new(0, 0.8, 0), Color = rgb(60, 150, 60), CanCollide = false })
		ball(p, 1.1, spot + Vector3.new(0, 1.8, 0), ({ rgb(255, 90, 120), rgb(255, 230, 80), WHITE, rgb(170, 120, 255) })[i], { CanCollide = false })
	end
end

function PROPS.Rock(p, t, at, s)
	local size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(3, 6), rng:NextNumber(4, 7)) * s
	part(p, { Name = "Rock", Size = size, CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = t.Side:Lerp(rgb(140, 140, 150), 0.4) })
end

function PROPS.Pumpkin(p, t, at, s)
	ball(p, 3.4 * s, at + Vector3.new(0, 1.6 * s, 0), rgb(255, 140, 30))
	part(p, { Name = "Stalk", Size = Vector3.new(0.5, 1, 0.5) * s, Position = at + Vector3.new(0, 3.4 * s, 0), Color = rgb(90, 140, 50) })
end

function PROPS.Cactus(p, t, at, s)
	part(p, { Name = "Cactus", Size = Vector3.new(2, 9, 2) * s, Position = at + Vector3.new(0, 4.5 * s, 0), Color = t.Decor })
	part(p, { Name = "Arm", Size = Vector3.new(3, 1.4, 1.4) * s, Position = at + Vector3.new(1.8, 4.5, 0) * s, Color = t.Decor })
	part(p, { Name = "Arm", Size = Vector3.new(1.4, 3, 1.4) * s, Position = at + Vector3.new(2.6, 6, 0) * s, Color = t.Decor })
	part(p, { Name = "Arm", Size = Vector3.new(3, 1.4, 1.4) * s, Position = at + Vector3.new(-1.8, 3, 0) * s, Color = t.Decor })
	part(p, { Name = "Arm", Size = Vector3.new(1.4, 2.4, 1.4) * s, Position = at + Vector3.new(-2.6, 4.2, 0) * s, Color = t.Decor })
end

function PROPS.Palm(p, t, at, s)
	local h = rng:NextNumber(8, 11) * s
	part(p, { Name = "Trunk", Size = Vector3.new(1.4, h, 1.4) * Vector3.new(s, 1, s), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(6)), Color = rgb(170, 120, 70) })
	for a = 0, 4 do
		part(p, { Name = "Leaf", Size = Vector3.new(7, 0.6, 2.2) * s, CFrame = CFrame.new(at + Vector3.new(-0.5, h, 0)) * CFrame.Angles(0, a * math.pi * 2 / 5, math.rad(-18)) * CFrame.new(3 * s, 0, 0), Color = t.Decor })
	end
	ball(p, 1.2 * s, at + Vector3.new(-0.3, h - 0.8, 0.8), rgb(120, 80, 40))
end

function PROPS.Umbrella(p, t, at, s)
	part(p, { Name = "Pole", Size = Vector3.new(0.4, 7, 0.4) * Vector3.new(s, 1, s), Position = at + Vector3.new(0, 3.5, 0), Color = WHITE })
	disc(p, 8 * s, 0.6, at + Vector3.new(0, 7, 0), t.Accent)
	disc(p, 4 * s, 0.7, at + Vector3.new(0, 7.1, 0), WHITE)
	part(p, { Name = "Towel", Size = Vector3.new(3, 0.2, 6) * s, Position = at + Vector3.new(3 * s, 0.1, 0), Color = rgb(80, 180, 255), CanCollide = false })
end

function PROPS.Ruin(p, t, at, s)
	local stone = rgb(150, 145, 130)
	for _, x in { -3, 3 } do
		local h = rng:NextNumber(4, 9) * s
		part(p, { Name = "Column", Size = Vector3.new(2.4, h, 2.4) * Vector3.new(s, 1, s), Position = at + Vector3.new(x * s, h / 2, 0), Color = stone })
		ball(p, 2 * s, at + Vector3.new(x * s, h + 0.4, 0), t.Decor)
	end
	part(p, { Name = "Block", Size = Vector3.new(4, 2, 3) * s, CFrame = CFrame.new(at + Vector3.new(0, 1, 3 * s)) * CFrame.Angles(0, 0.4, 0.2), Color = stone })
end

function PROPS.Snowman(p, t, at, s)
	ball(p, 5 * s, at + Vector3.new(0, 2.3 * s, 0), WHITE)
	ball(p, 3.6 * s, at + Vector3.new(0, 5.8 * s, 0), WHITE)
	ball(p, 2.6 * s, at + Vector3.new(0, 8.4 * s, 0), WHITE)
	part(p, { Name = "Nose", Size = Vector3.new(0.4, 0.4, 1.4) * s, Position = at + Vector3.new(0, 8.4 * s, -1.6 * s), Color = rgb(255, 140, 30) })
	part(p, { Name = "Hat", Size = Vector3.new(2, 1.6, 2) * s, Position = at + Vector3.new(0, 10.2 * s, 0), Color = INK })
	part(p, { Name = "Scarf", Size = Vector3.new(3.2, 0.7, 3.2) * s, Position = at + Vector3.new(0, 7.2 * s, 0), Color = t.Accent })
end

function PROPS.Crystal(p, t, at, s)
	for i = 1, 3 do
		local h = rng:NextNumber(4, 10) * s
		part(p, { Name = "Crystal", Size = Vector3.new(2 * s, h, 2 * s), CFrame = CFrame.new(at + Vector3.new((i - 2) * 2.2 * s, h / 2, rng:NextNumber(-1, 1))) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad((i - 2) * 14)), Color = t.Decor, Material = Enum.Material.Neon })
	end
end

function PROPS.Lollipop(p, t, at, s)
	part(p, { Name = "Stick", Size = Vector3.new(0.8, 9, 0.8) * Vector3.new(s, s, s), Position = at + Vector3.new(0, 4.5 * s, 0), Color = WHITE })
	local sweet = part(p, { Name = "Sweet", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 6, 6) * s, CFrame = CFrame.new(at + Vector3.new(0, 10 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = t.Decor })
	part(p, { Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 3, 3) * s, CFrame = sweet.CFrame, Color = WHITE })
end

function PROPS.Gumdrop(p, t, at, s)
	local colors = { rgb(255, 90, 140), rgb(120, 220, 255), rgb(255, 230, 80), rgb(150, 230, 110) }
	ball(p, 5 * s, at + Vector3.new(0, 1.2 * s, 0), colors[rng:NextInteger(1, 4)])
end

function PROPS.Candy(p, t, at, s)
	-- a candy cane
	part(p, { Name = "Cane", Size = Vector3.new(1.2, 9, 1.2) * s, Position = at + Vector3.new(0, 4.5 * s, 0), Color = WHITE })
	for i = 0, 3 do
		part(p, { Name = "Stripe", Size = Vector3.new(1.3, 0.7, 1.3) * s, CFrame = CFrame.new(at + Vector3.new(0, (1.2 + i * 2) * s, 0)) * CFrame.Angles(0, 0, 0.4), Color = rgb(255, 60, 80) })
	end
	part(p, { Name = "Hook", Size = Vector3.new(3, 1.2, 1.2) * s, Position = at + Vector3.new(1.2 * s, 9 * s, 0), Color = rgb(255, 60, 80) })
end

function PROPS.DeadTree(p, t, at, s)
	local wood = rgb(70, 60, 55)
	part(p, { Name = "Trunk", Size = Vector3.new(1.6, 9, 1.6) * Vector3.new(s, s, s), Position = at + Vector3.new(0, 4.5 * s, 0), Color = wood })
	part(p, { Name = "Branch", Size = Vector3.new(4, 0.8, 0.8) * s, CFrame = CFrame.new(at + Vector3.new(1.6 * s, 7 * s, 0)) * CFrame.Angles(0, 0, 0.6), Color = wood })
	part(p, { Name = "Branch", Size = Vector3.new(3, 0.8, 0.8) * s, CFrame = CFrame.new(at + Vector3.new(-1.2 * s, 5.5 * s, 0)) * CFrame.Angles(0, 0, -0.7), Color = wood })
	ball(p, 0.8, at + Vector3.new(0.3 * s, 8 * s, -0.9 * s), t.Accent, { Material = Enum.Material.Neon, CanCollide = false })
end

function PROPS.Mushroom(p, t, at, s)
	part(p, { Name = "Stem", Size = Vector3.new(1.6, 3, 1.6) * s, Position = at + Vector3.new(0, 1.5 * s, 0), Color = rgb(235, 225, 210) })
	disc(p, 5 * s, 1.4 * s, at + Vector3.new(0, 3.4 * s, 0), t.Accent)
end

function PROPS.Tower(p, t, at, s)
	local h = rng:NextNumber(14, 28) * s
	part(p, { Name = "Tower", Size = Vector3.new(7, h, 7) * Vector3.new(s, 1, s), Position = at + Vector3.new(0, h / 2, 0), Color = t.Side })
	for y = 3, h - 2, 4 do
		part(p, { Name = "Window", Size = Vector3.new(7.2 * s, 0.6, 7.2 * s), Position = at + Vector3.new(0, y, 0), Color = if math.floor(y / 4) % 2 == 0 then t.Accent else t.Decor, Material = Enum.Material.Neon, CanCollide = false })
	end
end

function PROPS.Lamp(p, t, at, s)
	part(p, { Name = "Pole", Size = Vector3.new(0.6, 10, 0.6), Position = at + Vector3.new(0, 5, 0), Color = INK })
	part(p, { Name = "Light", Size = Vector3.new(2.4, 0.8, 1.2), Position = at + Vector3.new(0, 10, 0), Color = t.Accent, Material = Enum.Material.Neon })
end

function PROPS.Crater(p, t, at, s)
	disc(p, 10 * s, 0.8, at + Vector3.new(0, 0.3, 0), t.Side)
	disc(p, 7 * s, 0.9, at + Vector3.new(0, 0.35, 0), t.Top:Lerp(INK, 0.25))
end

function PROPS.Dish(p, t, at, s)
	part(p, { Name = "Leg", Size = Vector3.new(1, 4, 1) * s, Position = at + Vector3.new(0, 2 * s, 0), Color = rgb(200, 200, 210) })
	part(p, { Name = "Dish", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 7, 7) * s, CFrame = CFrame.new(at + Vector3.new(0, 5 * s, 0)) * CFrame.Angles(0, 0.6, math.rad(50)), Color = WHITE })
end

function PROPS.Cloud(p, t, at, s)
	local y = rng:NextNumber(4, 14)
	for i = -1, 1 do
		ball(p, (6 - math.abs(i) * 1.5) * s, at + Vector3.new(i * 3.5 * s, y, 0), WHITE, { CanCollide = false })
	end
end

function PROPS.Pillar(p, t, at, s)
	local h = rng:NextNumber(8, 14) * s
	disc(p, 3.4 * s, h, at + Vector3.new(0, h / 2, 0), t.Decor)
	part(p, { Name = "Cap", Size = Vector3.new(4.4, 1, 4.4) * s, Position = at + Vector3.new(0, h + 0.5, 0), Color = t.Top })
end

----------------------------------------------------------------- scenery: big set pieces
-- Each fills roughly a 30-stud square around `at` (ground level)
local PIECES = {}

local function pond(p, t, at, color, neon)
	disc(p, 30, 1, at + Vector3.new(0, 0.1, 0), t.Side)
	disc(p, 27, 1.1, at + Vector3.new(0, 0.15, 0), color, { Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic, Transparency = if neon then 0 else 0.1 })
	for i = 1, 5 do
		local a = i * 1.25
		PROPS.Rock(p, t, at + Vector3.new(math.cos(a) * 15, 0, math.sin(a) * 15), 0.6)
	end
end

function PIECES.Pond(p, t, at)
	pond(p, t, at, t.Water or rgb(70, 170, 255), false)
end

function PIECES.LavaPool(p, t, at)
	pond(p, t, at, t.Water or rgb(255, 100, 20), true)
end

local function house(p, t, at, wallColor, roofColor, w, d, h)
	part(p, { Name = "House", Size = Vector3.new(w, h, d), Position = at + Vector3.new(0, h / 2, 0), Color = wallColor })
	for _, side in { -1, 1 } do
		part(p, { Name = "Roof", Size = Vector3.new(w + 2, h * 0.5, d / 2 + 1), CFrame = CFrame.new(at + Vector3.new(0, h + h * 0.25, side * (d / 4 + 0.25))) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), Color = roofColor }, "WedgePart")
	end
	part(p, { Name = "Door", Size = Vector3.new(3.4, 6, 0.4), Position = at + Vector3.new(0, 3, -d / 2 - 0.2), Color = rgb(110, 70, 40) })
	for _, x in { -w / 3, w / 3 } do
		part(p, { Name = "Window", Size = Vector3.new(3, 3, 0.4), Position = at + Vector3.new(x, h * 0.6, -d / 2 - 0.2), Color = rgb(255, 230, 150), Material = Enum.Material.Neon })
	end
end

function PIECES.Barn(p, t, at)
	house(p, t, at, rgb(200, 60, 50), rgb(240, 240, 240), 20, 16, 12)
	for i = -2, 2 do
		part(p, { Name = "Fence", Size = Vector3.new(0.6, 3, 0.6), Position = at + Vector3.new(i * 5, 1.5, -14), Color = WHITE })
	end
	part(p, { Name = "Rail", Size = Vector3.new(21, 0.6, 0.4), Position = at + Vector3.new(0, 2.4, -14), Color = WHITE })
end

function PIECES.Cabin(p, t, at)
	house(p, t, at, rgb(150, 95, 55), rgb(110, 60, 35), 16, 14, 10)
	part(p, { Name = "Chimney", Size = Vector3.new(2.4, 8, 2.4), Position = at + Vector3.new(5, 13, 3), Color = rgb(140, 130, 125) })
end

function PIECES.Hut(p, t, at)
	house(p, t, at, t.Side:Lerp(WHITE, 0.3), t.Decor, 14, 12, 8)
end

function PIECES.Pyramid(p, t, at)
	for i = 0, 5 do
		local w = 30 - i * 5
		part(p, { Name = "Step", Size = Vector3.new(w, 4, w), Position = at + Vector3.new(0, 2 + i * 4, 0), Color = t.Top:Lerp(t.Side, 0.25 + i * 0.05) })
	end
end

function PIECES.Temple(p, t, at)
	local stone = rgb(150, 145, 130)
	for i = 0, 3 do
		local w = 28 - i * 6
		part(p, { Name = "Step", Size = Vector3.new(w, 4, w), Position = at + Vector3.new(0, 2 + i * 4, 0), Color = stone:Lerp(t.Decor, i * 0.08) })
	end
	part(p, { Name = "Shrine", Size = Vector3.new(6, 5, 6), Position = at + Vector3.new(0, 18.5, 0), Color = stone })
	part(p, { Name = "Gem", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(at + Vector3.new(0, 22.5, 0)) * CFrame.Angles(0.6, 0.6, 0), Color = t.Accent, Material = Enum.Material.Neon })
end

function PIECES.Mesa(p, t, at)
	local h = rng:NextNumber(24, 36)
	part(p, { Name = "Mesa", Size = Vector3.new(26, h, 22), Position = at + Vector3.new(0, h / 2, 0), Color = t.Side })
	part(p, { Name = "MesaTop", Size = Vector3.new(27, 2, 23), Position = at + Vector3.new(0, h, 0), Color = t.Top })
	for i = 1, 3 do
		part(p, { Name = "Band", Size = Vector3.new(26.4, 1.5, 22.4), Position = at + Vector3.new(0, h * i / 4, 0), Color = t.Side:Lerp(t.Accent, 0.3) })
	end
end

local function mountain(p, t, at, color, capColor, h)
	for i = 0, 4 do
		local w = 30 - i * 6
		part(p, { Name = "Mountain", Size = Vector3.new(w, h / 5, w), CFrame = CFrame.new(at + Vector3.new(0, h / 10 + i * h / 5, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = if i >= 3 then capColor else color })
	end
end

function PIECES.Mountain(p, t, at)
	mountain(p, t, at, t.Side, WHITE, rng:NextNumber(30, 42))
end

function PIECES.Volcano(p, t, at)
	local h = 36
	mountain(p, t, at, t.Side, t.Side:Lerp(INK, 0.2), h)
	part(p, { Name = "Lava", Size = Vector3.new(7, 1, 7), Position = at + Vector3.new(0, h + 0.4, 0), Color = t.Accent, Material = Enum.Material.Neon })
	part(p, { Name = "LavaFlow", Size = Vector3.new(2.5, h * 0.9, 1), CFrame = CFrame.new(at + Vector3.new(0, h * 0.5, -9)) * CFrame.Angles(-0.35, 0, 0), Color = t.Accent, Material = Enum.Material.Neon, CanCollide = false })
end

function PIECES.Gumdrops(p, t, at)
	local colors = { rgb(255, 90, 140), rgb(120, 220, 255), rgb(255, 230, 80), rgb(150, 230, 110), rgb(190, 120, 255) }
	for i = 1, 5 do
		local a = i * 1.26
		ball(p, rng:NextNumber(8, 13), at + Vector3.new(math.cos(a) * 9, 2, math.sin(a) * 9), colors[i])
	end
	PROPS.Lollipop(p, t, at, 2.2)
end

function PIECES.Skyscraper(p, t, at)
	local h = rng:NextNumber(50, 80)
	part(p, { Name = "Skyscraper", Size = Vector3.new(16, h, 16), Position = at + Vector3.new(0, h / 2, 0), Color = t.Side })
	for y = 4, h - 3, 5 do
		part(p, { Name = "Windows", Size = Vector3.new(16.3, 1, 16.3), Position = at + Vector3.new(0, y, 0), Color = if math.floor(y / 5) % 3 == 0 then t.Decor else t.Accent, Material = Enum.Material.Neon, CanCollide = false })
	end
	part(p, { Name = "Antenna", Size = Vector3.new(0.6, 10, 0.6), Position = at + Vector3.new(0, h + 5, 0), Color = INK })
	ball(p, 1.4, at + Vector3.new(0, h + 10.5, 0), rgb(255, 60, 60), { Material = Enum.Material.Neon })
end

function PIECES.Rocket(p, t, at)
	disc(p, 6, 24, at + Vector3.new(0, 14, 0), WHITE)
	part(p, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), Position = at + Vector3.new(0, 26, 0), Color = rgb(255, 70, 70) })
	disc(p, 6.2, 1.4, at + Vector3.new(0, 20, 0), rgb(255, 70, 70))
	ball(p, 2.4, at + Vector3.new(0, 18, -2.6), rgb(120, 200, 255), { Material = Enum.Material.Glass })
	for a = 0, 2 do
		part(p, { Name = "Fin", Size = Vector3.new(0.8, 7, 5), CFrame = CFrame.new(at + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, a * math.pi * 2 / 3, 0) * CFrame.new(0, 0, 4), Color = rgb(255, 70, 70) })
	end
	disc(p, 18, 1, at + Vector3.new(0, 0.5, 0), rgb(90, 90, 100))
end

function PIECES.Dome(p, t, at)
	disc(p, 26, 1, at + Vector3.new(0, 0.5, 0), rgb(90, 90, 100))
	ball(p, 22, at + Vector3.new(0, 1, 0), rgb(170, 220, 255), { Material = Enum.Material.Glass, Transparency = 0.4, CanCollide = true })
	PROPS.Tree(p, { Decor = rgb(60, 180, 70) }, at, 1)
end

function PIECES.Planet(p, t, at)
	local y = rng:NextNumber(18, 30)
	local size = rng:NextNumber(14, 22)
	local planet = ball(p, size, at + Vector3.new(0, y, 0), t.Decor:Lerp(rgb(rng:NextInteger(0, 255), 120, 255), 0.4), { CanCollide = false })
	part(p, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, size * 1.8, size * 1.8), CFrame = CFrame.new(planet.Position) * CFrame.Angles(0.3, 0, math.rad(90)), Color = t.Accent, Material = Enum.Material.Neon, CanCollide = false })
end

function PIECES.Statue(p, t, at)
	local gold = rgb(255, 205, 50)
	part(p, { Name = "Plinth", Size = Vector3.new(12, 4, 12), Position = at + Vector3.new(0, 2, 0), Color = WHITE })
	-- a giant golden trophy
	part(p, { Name = "Base", Size = Vector3.new(7, 3, 7), Position = at + Vector3.new(0, 5.5, 0), Color = gold })
	part(p, { Name = "Stem", Size = Vector3.new(2.4, 6, 2.4), Position = at + Vector3.new(0, 10, 0), Color = gold })
	part(p, { Name = "Cup", Size = Vector3.new(10, 8, 10), Position = at + Vector3.new(0, 17, 0), Color = gold, Material = Enum.Material.SmoothPlastic })
	for _, side in { -1, 1 } do
		part(p, { Name = "Handle", Size = Vector3.new(2, 6, 1.4), Position = at + Vector3.new(side * 6.4, 17.5, 0), Color = gold })
	end
end

function PIECES.Cloud(p, t, at)
	for i = 1, 6 do
		ball(p, rng:NextNumber(8, 14), at + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(14, 22), rng:NextNumber(-8, 8)), WHITE, { CanCollide = false })
	end
end

----------------------------------------------------------------- stage gates
-- A see-through glassy panel across the track (teal fading to pink, with faint arrows),
-- and floating text: "Stage N", "Recommended Level : X", "Horsepower Needed: Y".
local WALL_TEAL = rgb(110, 225, 235)
local WALL_PINK = rgb(255, 170, 225)

-- a text line with a thin dark outline, like the reference signs; gradient = top/bottom colours
local function signLine(parent, text, color, height, order, gradient)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = if gradient then WHITE else color
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = rgb(30, 40, 30)
	stroke.Parent = l
	if gradient then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(gradient[1], gradient[2])
		g.Rotation = 90
		g.Parent = l
	end
	return l
end

-- A small see-through panel across the track at x = cx, with the words fixed flat on it
local WALL_WIDTH = 30
local FIRST_WALL_WIDTH = 76 -- Stage 1's wall runs further out along the lobby's front edge
local function stageWall(parent, stage, cx, z, width)
	local height = 4
	local level = Config.Stages.RequiredLevel[stage] or 1
	local needed = Config.Stages.HorsepowerNeeded[stage] or 0
	local wall = part(parent, { Name = "StageWall", Size = Vector3.new(width, height, 0.4), Position = Vector3.new(cx, height / 2, z), Color = WALL_TEAL, Material = Enum.Material.SmoothPlastic, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local glassGui = Instance.new("SurfaceGui")
	glassGui.Face = Enum.NormalId.Front
	glassGui.LightInfluence = 0
	glassGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	glassGui.CanvasSize = Vector2.new(200, 200)
	glassGui.Parent = wall
	local glass = Instance.new("Frame")
	glass.Size = UDim2.fromScale(1, 1)
	glass.BackgroundColor3 = WHITE
	glass.BorderSizePixel = 0
	glass.Parent = glassGui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(WALL_PINK, WALL_TEAL)
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(0.55)
	gradient.Parent = glass
	-- the words: a wider see-through sign just in front of the panel, so they never move
	local sign = part(parent, { Name = "StageText", Size = Vector3.new(48, 16, 0.2), Position = Vector3.new(cx, height + 8, z - 0.4), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(600, 200)
	gui.Parent = sign
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.03, 0)
	list.Parent = gui
	signLine(gui, "Stage " .. stage, nil, 0.44, 1, { rgb(215, 255, 60), rgb(110, 230, 50) })
	signLine(gui, "Recommended Level : " .. level, rgb(255, 196, 40), 0.2, 2)
	signLine(gui, "Horsepower Needed: " .. Format.short(needed), WHITE, 0.18, 3)
end

Course.WallWidth = FIRST_WALL_WIDTH -- the lobby's hills curve in to the ends of Stage 1's wall

-- Invisible walls from the pad's edges to the ends of the stage wall, so the only way on is through it
local function wallSides(parent, cx, x0, x1, zWall, width)
	local gap = width / 2
	if cx - gap > x0 - 1 then
		invisibleWall(parent, x0 - 1, cx - gap, zWall - 0.5, zWall + 0.5)
		invisibleWall(parent, cx + gap, x1 + 1, zWall - 0.5, zWall + 0.5)
	end
end

-- the stage's last platform, which holds its row of Wins pads
local WINS_PLATFORM = { Width = 50, Len = 44 }

----------------------------------------------------------------- planning a stage
-- d is how far through the course (0 on stage 1, 1 on stage 15)
local function gapLength(d)
	return 10 + d * 22 + rng:NextNumber(0, 6)
end

-- moves a built platform (and everything on it) up or down; its block grows down to the land
local function raise(holder, y)
	if y == 0 then
		return
	end
	for _, p in holder:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame += Vector3.new(0, y, 0)
			local home = p:GetAttribute("Home")
			if typeof(home) == "CFrame" then
				p:SetAttribute("Home", home + Vector3.new(0, y, 0))
			end
			if p.Name == "Block" and y > 0 then
				p.Size += Vector3.new(0, y, 0)
				p.CFrame -= Vector3.new(0, y / 2, 0)
			end
		end
	end
end
-- A stage is a list of pieces along z. Each has a lane (the part of the width that is
-- track rather than scenery): Pad and Platform pieces are solid road, Gap pieces are open.
local function planStage(stage, d, cx)
	local pieces = {}
	table.insert(pieces, { Kind = "Pad", Len = 40, Cx = cx, Width = 40 })
	local pool = { "Bump" }
	if stage >= 2 then
		table.insert(pool, "Sliders")
	end
	if stage >= 4 then
		table.insert(pool, "Sweeper")
	end
	if stage >= 5 then
		table.insert(pool, "Slide")
	end
	if stage >= 6 then
		table.insert(pool, "Narrow")
	end
	if stage >= 7 then
		table.insert(pool, "Lift")
	end
	local segments = 5 + math.floor(d * 3)
	local y = 0
	for s = 1, segments do
		-- gaps grow from about 10-16 studs on stage 1 to 32-38 on stage 15
		local gapLen = gapLength(d)
		table.insert(pieces, { Kind = "Gap", Len = gapLen })
		-- from stage 3 the platforms sit higher or lower, so roads have to climb and dive;
		-- each step is one a road can make across that gap
		if stage >= 3 then
			local rise = gapLen * 0.25
			y = math.clamp(y + rng:NextNumber(-rise, rise), -5, 4 + d * 14)
			y = math.floor(y * 2 + 0.5) / 2
		end
		-- the track wanders left and right, drifting back toward the middle
		local step = rng:NextNumber(6, 12 + d * 8) * (if rng:NextNumber() < 0.5 then -1 else 1)
		cx = math.clamp(cx + step - cx * 0.25, -LANE_LIMIT, LANE_LIMIT)
		local feature = nil
		if s > 1 and rng:NextNumber() < 0.35 + d * 0.5 then
			feature = pool[rng:NextInteger(1, #pool)]
		elseif s == 3 and stage == 1 then
			feature = "Bump" -- something small to do even on the first stage
		end
		if s == segments then
			feature = nil -- the last platform holds the Wins pad, so it stays plain and still
		end
		local width = if feature == "Narrow" then 12 else 26 - d * 8
		local piece = { Kind = "Platform", Len = rng:NextInteger(30, 46), Cx = cx, Width = width, Feature = feature, Y = y }
		if feature == "Slide" then
			piece.Amp = math.max(4, width * 0.45)
			piece.LaneWidth = width + piece.Amp * 2 + 2 -- room for it to slide
		elseif feature == "Narrow" then
			-- the platform is narrower than a road, so its lane is wider than it (open air each
			-- side, over a pit): roads can still reach it and start from it
			piece.LaneWidth = Config.Road.TileWidth + 4
		end
		table.insert(pieces, piece)
	end
	-- the last gap leads to the next stage's start pad, which is at height 0
	local finalLen = gapLength(d)
	local last = pieces[#pieces]
	last.Y = math.clamp(last.Y, -finalLen * 0.25, finalLen * 0.25)
	-- the last platform is a wide square for the row of Wins pads
	last.Width = WINS_PLATFORM.Width
	last.Len = WINS_PLATFORM.Len
	table.insert(pieces, { Kind = "Gap", Len = finalLen })
	-- each gap's lane covers both platforms around it, so a road can cross it at an angle
	for i, piece in pieces do
		if piece.Kind ~= "Gap" then
			local w = piece.LaneWidth or piece.Width
			piece.X0, piece.X1 = piece.Cx - w / 2, piece.Cx + w / 2
		end
	end
	return pieces, cx
end

----------------------------------------------------------------- Wins pads
Course.Bounds = {} -- [stage] = { Z0, Z1 }, filled in as the stages are built

-- the stage a point is on, or nil in the lobby / at the finish
function Course.stageAt(z)
	for stage, b in Course.Bounds do
		if z >= b.Z0 and z < b.Z1 then
			return stage
		end
	end
	return nil
end

-- Two pads across the end of a stage's last platform (Server.Roads hands them out): gold on
-- the left pays the stage's Wins, purple on the right offers double for Robux (StageWins2x).
-- Driving out, the stages run towards +Z, so the player's left is the +X side.
local PADS = {
	-- (Neon glows brighter than its colour, so these are darker than they look in game)
	{ Color = rgb(190, 110, 0), Title = "STAGE %d", Fill = { rgb(255, 235, 110), rgb(240, 170, 20) } }, -- gold, free
	{ Color = rgb(95, 25, 200), Title = "2x WINS!", Fill = { rgb(225, 170, 255), rgb(150, 70, 255) } }, -- purple, paid
}
local function winsPads(parent, stage, cx, width, z1, y)
	local gap = 2
	local padWidth = (width - gap * 3) / 2
	for i, look in PADS do
		-- pad 1 (gold) on the +X half, pad 2 (purple) on the -X half
		local x0 = if i == 1 then cx + gap / 2 else cx - gap / 2 - padWidth
		local wins = Config.stagePadWins(stage, i)
		local pad = slab(parent, "WinsPad", x0, x0 + padWidth, z1 - 16, z1 - 3, y + 0.8, 0.4, look.Color, { Material = Enum.Material.Neon })
		pad.Transparency = 0.1
		pad:SetAttribute("Stage", stage)
		pad:SetAttribute("Index", i)
		pad:SetAttribute("Wins", wins)
		CollectionService:AddTag(pad, "WinsPad")
		-- a little narrower than the pad, so the two signs never run into each other, and
		-- only shown up close so they don't cover the next stage's sign from afar
		local anchor = part(parent, { Name = "WinsSign", Size = Vector3.one, Position = pad.Position + Vector3.new(0, 4.5, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(math.min(9, padWidth - 1), 3.6)
		gui.LightInfluence = 0
		gui.MaxDistance = 140
		gui.Parent = anchor
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = gui
		signLine(gui, string.format(look.Title, stage), WHITE, 0.4, 1)
		signLine(gui, "+" .. Format.short(wins) .. " Wins", nil, 0.55, 2, look.Fill)
	end
end

-- A chunky red Horsepower can (a jerry can with a handle and a yellow cap), with "+N" over it.
-- Server.Game hands out the Horsepower; Controllers.Cans spins it and hides it once taken.
local function horsepowerCan(parent, stage, at)
	local model = Instance.new("Model")
	model.Name = "HorsepowerCan"
	local red = rgb(235, 45, 55)
	local body = part(model, { Name = "Body", Size = Vector3.new(2.6, 3.2, 1.4), Position = at + Vector3.new(0, 2.4, 0), Color = red, CanCollide = false, CanQuery = false, CanTouch = false })
	part(model, { Name = "Handle", Size = Vector3.new(1.6, 0.5, 0.6), Position = body.Position + Vector3.new(-0.3, 1.85, 0), Color = rgb(190, 30, 40), CanCollide = false, CanQuery = false, CanTouch = false })
	part(model, { Name = "Cap", Size = Vector3.new(0.6, 0.7, 0.6), Position = body.Position + Vector3.new(0.85, 1.9, 0), Color = rgb(255, 215, 40), CanCollide = false, CanQuery = false, CanTouch = false })
	part(model, { Name = "Stripe", Size = Vector3.new(2.7, 0.4, 1.5), Position = body.Position, Color = rgb(255, 235, 235), CanCollide = false, CanQuery = false, CanTouch = false })
	model.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Name = "Amount"
	gui.Size = UDim2.fromScale(5, 2)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = body
	signLine(gui, "+" .. Format.short(Config.canHorsepower(stage)), WHITE, 1, 1)
	model:SetAttribute("Stage", stage)
	CollectionService:AddTag(model, "HorsepowerCan")
	model.Parent = parent
	return model
end

----------------------------------------------------------------- building a stage
-- is this spot on the scenery land, clear of the lane and the outer walls?
local function onLand(pieces, x, z, margin)
	if math.abs(x) > HALF_WIDTH - margin then
		return false
	end
	for _, piece in pieces do
		if z >= piece.Z0 - margin and z < piece.Z1 + margin and x > piece.X0 - margin and x < piece.X1 + margin then
			return false
		end
	end
	return true
end

local function scatter(model, theme, pieces, z0, z1, keepOut)
	-- props on a loose grid over the whole stage, kept off the lane and the outer walls
	local spacing = 26
	for x = -HALF_WIDTH + spacing / 2, HALF_WIDTH - spacing / 2, spacing do
		for z = z0 + spacing / 2, z1 - spacing / 2, spacing do
			local spot = Vector3.new(x + rng:NextNumber(-8, 8), LAND_Y, z + rng:NextNumber(-8, 8))
			local clear = onLand(pieces, spot.X, spot.Z, 6)
			for _, box in keepOut do
				if math.abs(spot.X - box.X) < box.R and math.abs(spot.Z - box.Z) < box.R then
					clear = false
				end
			end
			if clear and rng:NextNumber() < 0.6 then
				local kind = theme.Props[rng:NextInteger(1, #theme.Props)]
				PROPS[kind](model, theme, spot, rng:NextNumber(0.9, 1.5))
			end
		end
	end
end

local function buildStage(folder, stage, theme, d, z, cx)
	local model = Instance.new("Model")
	model.Name = "Stage" .. stage
	model:SetAttribute("Stage", stage)
	local track = Instance.new("Folder")
	track.Name = "Track"
	track.Parent = model
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = model

	local pieces
	pieces, cx = planStage(stage, d, cx)
	local stageZ0 = z
	local landStrips = {} -- the scenery land each side, for scattering props

	for i, piece in pieces do
		local z0, z1 = z, z + piece.Len
		piece.Z0, piece.Z1 = z0, z1
		local x0, x1 = piece.X0, piece.X1
		if piece.Kind == "Gap" then
			local before, after = pieces[i - 1], pieces[i + 1] or pieces[i - 1]
			x0, x1 = math.min(before.X0, after.X0), math.max(before.X1, after.X1)
			piece.X0, piece.X1 = x0, x1
		end

		-- the land either side of the lane
		for _, strip in { { -HALF_WIDTH, x0 }, { x1, HALF_WIDTH } } do
			if strip[2] - strip[1] > 0.05 then
				slab(scenery, "Ground", strip[1], strip[2], z0, z1, LAND_Y - 0.6, DEPTH - 0.6, theme.Side)
				local top = slab(scenery, "Grass", strip[1], strip[2], z0, z1, LAND_Y, 0.6, theme.Top, { Material = theme.Material or Enum.Material.Plastic })
				top.TopSurface = Enum.SurfaceType.Studs
				table.insert(landStrips, { X0 = strip[1], X1 = strip[2], Z0 = z0, Z1 = z1 })
			end
		end
		-- invisible walls down both edges of the lane
		invisibleWall(track, x0 - 1, x0, z0, z1)
		invisibleWall(track, x1, x1 + 1, z0, z1)
		-- ...and across any step where the lane gets wider or narrower
		local prev = pieces[i - 1]
		if prev then
			if prev.X0 ~= x0 then
				invisibleWall(track, math.min(prev.X0, x0) - 1, math.max(prev.X0, x0), z0 - 0.5, z0 + 0.5)
			end
			if prev.X1 ~= x1 then
				invisibleWall(track, math.min(prev.X1, x1), math.max(prev.X1, x1) + 1, z0 - 0.5, z0 + 0.5)
			end
		end

		-- the track itself
		if piece.Kind == "Pad" then
			platform(track, theme, x0, x1, z0, z1)
			local wallWidth = if stage == 1 then FIRST_WALL_WIDTH else WALL_WIDTH
			stageWall(track, stage, piece.Cx, z0 + 1, wallWidth)
			wallSides(track, piece.Cx, x0, x1, z0 + 1, wallWidth)
			model:SetAttribute("Start", CFrame.new(piece.Cx, 0, z0 + piece.Len / 2))
		elseif piece.Kind == "Gap" then
			pit(track, x0, x1, z0, z1, model:GetAttribute("Start"))
		elseif piece.Kind == "Platform" then
			local px0, px1 = piece.Cx - piece.Width / 2, piece.Cx + piece.Width / 2
			-- built at height 0 in its own folder, then raised or lowered to its height
			local holder = Instance.new("Folder")
			holder.Name = "Platform"
			holder.Parent = track
			if piece.Feature == "Slide" or piece.Feature == "Lift" then
				movingPlatform(holder, theme, piece.Cx, piece.Width, z0, z1, piece.Feature, piece.Amp or 5)
				pit(track, x0, x1, z0, z1, model:GetAttribute("Start"))
			else
				platform(holder, theme, px0, px1, z0, z1)
				if piece.LaneWidth then
					pit(track, x0, x1, z0, z1, model:GetAttribute("Start")) -- under the open air beside a narrow platform
				end
				local mid = (z0 + z1) / 2
				if piece.Feature == "Sliders" then
					sliders(holder, theme, piece.Cx, piece.Width, z0, z1, d)
				elseif piece.Feature == "Sweeper" then
					sweeper(holder, theme, piece.Cx, piece.Width, mid, d)
				elseif piece.Feature == "Bump" then
					bump(holder, theme, piece.Cx, piece.Width, mid)
				end
				-- a Horsepower can on some plain platforms (not the Wins pad one)
				if i < #pieces - 1 and piece.Feature ~= "Sweeper" and piece.Feature ~= "Sliders" and rng:NextNumber() < Config.Cans.Chance then
					local x = piece.Cx + rng:NextNumber(-0.3, 0.3) * piece.Width
					local zc = z0 + rng:NextNumber(0.3, 0.7) * (z1 - z0)
					horsepowerCan(holder, stage, Vector3.new(x, 0.6, zc))
				end
			end
			raise(holder, piece.Y or 0)
		end
		z = z1
	end
	local stageZ1 = z

	-- tall walls far out on both sides, in the stage's colours
	for _, side in { -1, 1 } do
		local x = side * (HALF_WIDTH + 2)
		slab(scenery, "OuterWall", x - 2, x + 2, stageZ0, stageZ1, WALL_HEIGHT, WALL_HEIGHT + DEPTH, theme.Side)
		slab(scenery, "WallTop", x - 2.5, x + 2.5, stageZ0, stageZ1, WALL_HEIGHT + 1.5, 1.5, theme.Accent, {
			Material = if theme.NeonAccent then Enum.Material.Neon else Enum.Material.Plastic,
		})
		-- and invisible above them, so nobody gets out over the top
		part(scenery, { Name = "HighWall", Size = Vector3.new(4, 200, stageZ1 - stageZ0), Position = Vector3.new(x, WALL_HEIGHT + 100, (stageZ0 + stageZ1) / 2), Transparency = 1, CanQuery = false })
	end
	-- a low hedge across the land where this stage begins, with an invisible wall above it
	-- (on stage 1 that also keeps cars on the base from driving out onto the land)
	for _, strip in { { -HALF_WIDTH, pieces[1].X0 - 1 }, { pieces[1].X1 + 1, HALF_WIDTH } } do
		slab(scenery, "Hedge", strip[1], strip[2], stageZ0 - 1.5, stageZ0 + 1.5, LAND_Y + 4, 4, theme.Decor)
		invisibleWall(track, strip[1], strip[2], stageZ0 - 1.5, stageZ0 + 1.5)
	end

	-- scenery: a couple of big set pieces, then props scattered around them
	local keepOut = {}
	local wide = {}
	for _, s in landStrips do
		if s.X1 - s.X0 >= 50 and s.Z1 - s.Z0 >= 30 then
			table.insert(wide, s)
		end
	end
	for i, name in theme.Pieces do
		if #wide == 0 then
			break
		end
		local s = table.remove(wide, rng:NextInteger(1, #wide))
		-- set back from the track so it never hangs over the lane
		local nearLaneLeft = s.X1 < 0
		local x = if nearLaneLeft then s.X0 + 28 else s.X1 - 28
		local spot = Vector3.new(x, LAND_Y, (s.Z0 + s.Z1) / 2)
		PIECES[name](scenery, theme, spot)
		table.insert(keepOut, { X = spot.X, Z = spot.Z, R = 20 })
	end
	scatter(scenery, theme, pieces, stageZ0, stageZ1, keepOut)

	-- the row of Wins pads on the last platform
	local last = pieces[#pieces - 1]
	winsPads(track, stage, last.Cx, last.Width, last.Z1, last.Y or 0)
	Course.Bounds[stage] = { Z0 = stageZ0, Z1 = stageZ1 }

	model.Parent = folder
	return z, cx
end

----------------------------------------------------------------- finish
local function buildFinish(parent, z, cx)
	local gold = rgb(255, 205, 50)
	local theme = { Top = gold, Side = rgb(210, 150, 30), Accent = WHITE, Decor = gold }
	-- a big golden square across the whole width
	slab(parent, "Ground", -HALF_WIDTH, HALF_WIDTH, z, z + 80, -0.6, DEPTH - 0.6, theme.Side)
	local top = slab(parent, "Gold", -HALF_WIDTH, HALF_WIDTH, z, z + 80, 0, 0.6, gold)
	top.TopSurface = Enum.SurfaceType.Studs
	for _, side in { -1, 1 } do
		local x = side * (HALF_WIDTH + 2)
		slab(parent, "OuterWall", x - 2, x + 2, z, z + 80, WALL_HEIGHT, WALL_HEIGHT + DEPTH, theme.Side)
	end
	slab(parent, "BackWall", -HALF_WIDTH - 4, HALF_WIDTH + 4, z + 80, z + 84, WALL_HEIGHT, WALL_HEIGHT + DEPTH, theme.Side)
	local at = Vector3.new(cx, 0, z + 20)
	for _, side in { -1, 1 } do
		part(parent, { Name = "ArchPost", Size = Vector3.new(4, 30, 4), Position = at + Vector3.new(side * 22, 15, 0), Color = gold })
	end
	local arch = part(parent, { Name = "ArchTop", Size = Vector3.new(48, 6, 4), Position = at + Vector3.new(0, 33, 0), Color = gold })
	for i = 0, 11 do
		part(parent, { Name = "Check", Size = Vector3.new(4, 3, 4.2), Position = arch.Position + Vector3.new(-22 + i * 4, (i % 2) * 3 - 1.5, 0), Color = if i % 2 == 0 then INK else WHITE, CanCollide = false })
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(30, 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = arch
	label(gui, "FINISH!", gold, 1, 1)
	PIECES.Statue(parent, theme, Vector3.new(cx, 0, z + 55))
end

----------------------------------------------------------------- build it all
-- edge: the middle of the base's cliff edge, where Stage 1 begins
function Course.build(map, edge, halfWidth)
	HALF_WIDTH = halfWidth or HALF_WIDTH
	local folder = Instance.new("Folder")
	folder.Name = "Course"
	folder.Parent = map
	local z, cx = edge.Z, 0
	Course.RoadsFrom = z + 1 -- Stage 1's wall: roads can only be built past it
	workspace:SetAttribute("RoadsFrom", Course.RoadsFrom)
	for stage = 1, #THEMES do
		z, cx = buildStage(folder, stage, THEMES[stage], (stage - 1) / (#THEMES - 1), z, cx)
	end
	local finish = Instance.new("Model")
	finish.Name = "Finish"
	buildFinish(finish, z, cx)
	finish.Parent = folder
	Course.EndZ = z + 84 -- the finish's back wall
	return folder
end

return Course
