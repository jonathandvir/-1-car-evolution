-- How each car evolution looks, built from simple chunky parts in code (no copied models).
-- Shared so the server (the player's car) and the client (Index / previews) use the same designs.
--
-- CarLooks.build(tier, cf) returns a Model. cf is the ground point under the middle of the
-- car, and the car faces cf.LookVector (-Z). Every part is welded to "Body" (the PrimaryPart),
-- which is anchored; unanchor Body to drive it.
-- Names are placeholders ("Car 1"...) until we pick real ones; Style says what each one is.
local CarLooks = {}

local INK = Color3.fromRGB(22, 22, 32)
local TYRE = Color3.fromRGB(35, 35, 42)
local GLASS = Color3.fromRGB(70, 110, 150)
local CHROME = Color3.fromRGB(205, 210, 220)
local LIGHT = Color3.fromRGB(255, 245, 190)
local TAIL = Color3.fromRGB(255, 50, 60)

----------------------------------------------------------------- building helpers
local function newCtx(model, cf)
	local ctx = { model = model, cf = cf }

	local function finish(p, props)
		p.Anchored = true
		p.CanCollide = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		p.Parent = model
		return p
	end

	-- a box centred at (x, y, z) in car space (y = 0 is the ground, -z is the front)
	function ctx.box(name, size, pos, color, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CFrame = cf * CFrame.new(pos) * ((props and props.Rot) or CFrame.identity)
		if props then
			props.Rot = nil
		end
		return finish(p, props)
	end

	-- a ramp: low at the front (-z), full height at the back. flip = true turns it round.
	function ctx.wedge(name, size, pos, color, flip, props)
		local p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CFrame = cf * CFrame.new(pos) * (if flip then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		return finish(p, props)
	end

	-- a cylinder lying along x (wheels, exhausts turned by Rot)
	function ctx.cyl(name, size, pos, color, props)
		local p = ctx.box(name, size, pos, color, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	return ctx
end

-- Four chunky wheels with hubcaps
local function wheels(ctx, s, hubColor)
	local r, w = s.WheelRadius, s.WheelWidth
	local front, back = s.FrontAxle or -s.Length * 0.32, s.BackAxle or s.Length * 0.32
	local x = s.Width / 2 - w * 0.2
	for _, z in { front, back } do
		for _, side in { -1, 1 } do
			local rBack = if z == back then (s.BackWheelScale or 1) * r else r
			ctx.cyl("Wheel", Vector3.new(w, rBack * 2, rBack * 2), Vector3.new(side * x, rBack, z), TYRE)
			ctx.cyl("Hub", Vector3.new(w + 0.1, rBack * 1.05, rBack * 1.05), Vector3.new(side * x, rBack, z), hubColor or CHROME)
		end
	end
end

-- Headlights at the front and tail lights at the back of the main body
local function lights(ctx, s, y, inset)
	local half = s.Length / 2
	inset = inset or 0
	for _, side in { -1, 1 } do
		ctx.box("Headlight", Vector3.new(s.Width * 0.2, 0.45, 0.2), Vector3.new(side * s.Width * 0.3, y, -half + inset - 0.05), LIGHT, { Material = Enum.Material.Neon })
		ctx.box("TailLight", Vector3.new(s.Width * 0.2, 0.35, 0.2), Vector3.new(side * s.Width * 0.3, y, half + 0.05), TAIL, { Material = Enum.Material.Neon })
	end
end

-- A cabin with dark windows on the front, back and both sides
local function cabin(ctx, s, len, h, z, y, color, slant)
	local w = s.Width * 0.82
	ctx.box("Cabin", Vector3.new(w, h, len), Vector3.new(0, y + h / 2, z), color)
	ctx.box("Windshield", Vector3.new(w * 0.86, h * 0.62, 0.15), Vector3.new(0, y + h * 0.52, z - len / 2 - 0.05), GLASS, { Material = Enum.Material.Glass, Transparency = 0.1 })
	ctx.box("BackWindow", Vector3.new(w * 0.8, h * 0.5, 0.15), Vector3.new(0, y + h * 0.56, z + len / 2 + 0.05), GLASS, { Material = Enum.Material.Glass, Transparency = 0.1 })
	for _, side in { -1, 1 } do
		ctx.box("SideWindow", Vector3.new(0.15, h * 0.55, len * 0.72), Vector3.new(side * (w / 2 + 0.05), y + h * 0.55, z), GLASS, { Material = Enum.Material.Glass, Transparency = 0.1 })
	end
	if slant then
		-- a sloped windscreen in front of the cabin
		ctx.wedge("Slope", Vector3.new(w, h, slant), Vector3.new(0, y + h / 2, z - len / 2 - slant / 2), color)
		ctx.wedge("SlopeGlass", Vector3.new(w * 0.86, h * 0.8, slant * 0.8), Vector3.new(0, y + h * 0.46, z - len / 2 - slant / 2 - 0.12), GLASS, false, { Material = Enum.Material.Glass, Transparency = 0.1 })
	end
end

local function spoiler(ctx, s, y, color, wide)
	local z = s.Length / 2 - 0.5
	for _, side in { -1, 1 } do
		ctx.box("SpoilerLeg", Vector3.new(0.3, 1, 0.4), Vector3.new(side * s.Width * 0.3, y + 0.5, z), INK)
	end
	ctx.box("Spoiler", Vector3.new(s.Width * (wide or 1), 0.25, 1.1), Vector3.new(0, y + 1.1, z + 0.1), color)
end

local function exhausts(ctx, s, y, count)
	for i = 1, count or 2 do
		local x = (i - (count or 2) / 2 - 0.5) * 0.7
		ctx.cyl("Exhaust", Vector3.new(0.8, 0.45, 0.45), Vector3.new(x, y, s.Length / 2 + 0.3), CHROME, { Rot = CFrame.Angles(0, math.rad(90), 0) })
	end
end

----------------------------------------------------------------- the cars
-- Each entry: the size table the helpers use, plus a draw function for its own details.
local CARS = {
	{
		Style = "Wooden box cart",
		Length = 6, Width = 3.6, WheelRadius = 0.8, WheelWidth = 0.6,
		Body = Color3.fromRGB(190, 130, 70), Accent = Color3.fromRGB(150, 95, 50),
		draw = function(ctx, s)
			-- a crate on wheels with plank lines, a stick to steer and a little flag
			ctx.box("Body", Vector3.new(s.Width, 1.6, s.Length), Vector3.new(0, 1.6, 0), s.Body, { Material = Enum.Material.Wood })
			for _, z in { -1.5, 0, 1.5 } do
				ctx.box("Plank", Vector3.new(s.Width + 0.1, 0.2, 0.3), Vector3.new(0, 1.9, z), s.Accent, { Material = Enum.Material.Wood })
			end
			ctx.box("Seat", Vector3.new(2.4, 0.6, 1.6), Vector3.new(0, 2.7, 1), Color3.fromRGB(220, 60, 60))
			ctx.box("Stick", Vector3.new(0.25, 1.6, 0.25), Vector3.new(0, 3.1, -1.5), s.Accent, { Rot = CFrame.Angles(math.rad(-25), 0, 0) })
			ctx.cyl("SteeringWheel", Vector3.new(0.2, 1.2, 1.2), Vector3.new(0, 3.8, -1.2), INK, { Rot = CFrame.Angles(0, math.rad(90), math.rad(65)) })
			ctx.box("FlagPole", Vector3.new(0.15, 3, 0.15), Vector3.new(1.4, 3.6, 2.6), INK)
			ctx.box("Flag", Vector3.new(0.1, 0.9, 1.2), Vector3.new(1.4, 4.6, 3.2), Color3.fromRGB(255, 220, 50))
			wheels(ctx, s, Color3.fromRGB(240, 200, 60))
		end,
	},
	{
		Style = "Go-kart",
		Length = 6.4, Width = 4, WheelRadius = 0.75, WheelWidth = 0.9, BackWheelScale = 1.15,
		Body = Color3.fromRGB(80, 210, 90), Accent = Color3.fromRGB(255, 255, 255),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(3, 0.6, s.Length), Vector3.new(0, 0.9, 0), s.Body)
			ctx.wedge("Nose", Vector3.new(3, 0.7, 1.4), Vector3.new(0, 1.55, -2.4), s.Body)
			ctx.box("Bumper", Vector3.new(s.Width + 0.4, 0.4, 0.4), Vector3.new(0, 0.8, -s.Length / 2 - 0.1), s.Accent)
			ctx.box("Seat", Vector3.new(1.8, 1.4, 0.5), Vector3.new(0, 1.9, 1.6), INK)
			ctx.box("SeatBase", Vector3.new(1.8, 0.4, 1.4), Vector3.new(0, 1.4, 1.1), INK)
			ctx.box("RollBar", Vector3.new(2.6, 0.3, 0.3), Vector3.new(0, 3.4, 2), s.Accent)
			for _, side in { -1, 1 } do
				ctx.box("RollPost", Vector3.new(0.3, 2.2, 0.3), Vector3.new(side * 1.15, 2.3, 2), s.Accent)
			end
			ctx.cyl("SteeringWheel", Vector3.new(0.2, 1.1, 1.1), Vector3.new(0, 2.1, -0.4), INK, { Rot = CFrame.Angles(0, math.rad(90), math.rad(60)) })
			ctx.box("Number", Vector3.new(0.1, 0.8, 0.8), Vector3.new(1.55, 1.1, 0), s.Accent)
			ctx.box("Number", Vector3.new(0.1, 0.8, 0.8), Vector3.new(-1.55, 1.1, 0), s.Accent)
			exhausts(ctx, s, 1.3, 1)
			wheels(ctx, s)
		end,
	},
	{
		Style = "Tiny hatchback",
		Length = 7, Width = 4.4, WheelRadius = 0.9, WheelWidth = 0.8,
		Body = Color3.fromRGB(255, 205, 50), Accent = Color3.fromRGB(255, 255, 255),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.8, s.Length), Vector3.new(0, 1.6, 0), s.Body)
			cabin(ctx, s, 3.6, 1.8, 0.8, 2.5, s.Body)
			ctx.box("Roof", Vector3.new(s.Width * 0.84, 0.2, 3.7), Vector3.new(0, 4.4, 0.8), s.Accent)
			ctx.box("Bumper", Vector3.new(s.Width, 0.5, 0.3), Vector3.new(0, 0.9, -s.Length / 2 - 0.1), CHROME)
			ctx.box("Bumper", Vector3.new(s.Width, 0.5, 0.3), Vector3.new(0, 0.9, s.Length / 2 + 0.1), CHROME)
			lights(ctx, s, 1.9)
			wheels(ctx, s)
		end,
	},
	{
		Style = "Pickup truck",
		Length = 8.4, Width = 4.8, WheelRadius = 1.2, WheelWidth = 1,
		Body = Color3.fromRGB(230, 60, 55), Accent = Color3.fromRGB(240, 240, 245),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.6, s.Length), Vector3.new(0, 2.2, 0), s.Body)
			cabin(ctx, s, 2.8, 2, -0.6, 3, s.Body)
			-- the open bed at the back
			for _, side in { -1, 1 } do
				ctx.box("BedSide", Vector3.new(0.3, 1, 3.2), Vector3.new(side * (s.Width / 2 - 0.15), 3.5, 2.5), s.Body)
			end
			ctx.box("Tailgate", Vector3.new(s.Width, 1, 0.3), Vector3.new(0, 3.5, s.Length / 2 - 0.15), s.Body)
			ctx.box("Cargo", Vector3.new(1.4, 1, 1.4), Vector3.new(0.6, 3.5, 2.4), Color3.fromRGB(190, 130, 70), { Material = Enum.Material.Wood })
			ctx.box("Grille", Vector3.new(s.Width * 0.6, 0.9, 0.2), Vector3.new(0, 2.3, -s.Length / 2 - 0.05), CHROME)
			ctx.box("Bumper", Vector3.new(s.Width + 0.2, 0.5, 0.4), Vector3.new(0, 1.4, -s.Length / 2 - 0.15), CHROME)
			ctx.box("RoofLights", Vector3.new(2, 0.3, 0.4), Vector3.new(0, 5.15, -1.6), LIGHT, { Material = Enum.Material.Neon })
			lights(ctx, s, 2.5)
			wheels(ctx, s, Color3.fromRGB(240, 240, 245))
		end,
	},
	{
		Style = "Muscle car",
		Length = 9, Width = 4.8, WheelRadius = 1, WheelWidth = 1.1, BackWheelScale = 1.1,
		Body = Color3.fromRGB(255, 140, 30), Accent = Color3.fromRGB(30, 30, 40),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.5, s.Length), Vector3.new(0, 1.65, 0), s.Body)
			cabin(ctx, s, 2.8, 1.5, 1.2, 2.4, s.Body, 1.2)
			-- two racing stripes over the hood, roof and boot
			for _, x in { -0.6, 0.6 } do
				ctx.box("Stripe", Vector3.new(0.6, 0.1, s.Length + 0.02), Vector3.new(x, 2.42, 0), s.Accent)
				ctx.box("Stripe", Vector3.new(0.6, 0.1, 2.82), Vector3.new(x, 3.92, 1.2), s.Accent)
			end
			ctx.box("Scoop", Vector3.new(1.6, 0.5, 1.6), Vector3.new(0, 2.6, -2.6), s.Accent)
			ctx.box("ScoopHole", Vector3.new(1.2, 0.3, 0.1), Vector3.new(0, 2.65, -3.42), INK)
			spoiler(ctx, s, 2.4, s.Accent, 0.8)
			exhausts(ctx, s, 1.2, 2)
			lights(ctx, s, 1.9)
			wheels(ctx, s, Color3.fromRGB(30, 30, 40))
		end,
	},
	{
		Style = "Rally car",
		Length = 8.6, Width = 5, WheelRadius = 1.3, WheelWidth = 1.1,
		Body = Color3.fromRGB(40, 120, 240), Accent = Color3.fromRGB(255, 255, 255),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.6, s.Length), Vector3.new(0, 2.3, 0), s.Body)
			cabin(ctx, s, 3.4, 1.8, 0.6, 3.1, s.Body, 1)
			ctx.box("Roof", Vector3.new(s.Width * 0.84, 0.2, 3.5), Vector3.new(0, 5, 0.6), s.Accent)
			-- a bar of spotlights on the roof
			ctx.box("LightBar", Vector3.new(3.4, 0.3, 0.3), Vector3.new(0, 5.3, -0.9), INK)
			for i = -1.5, 1.5 do
				ctx.box("Spot", Vector3.new(0.6, 0.6, 0.3), Vector3.new(i * 0.8, 5.55, -1.05), LIGHT, { Material = Enum.Material.Neon })
			end
			ctx.box("Skid", Vector3.new(s.Width * 0.8, 0.3, 1), Vector3.new(0, 1.3, -s.Length / 2 + 0.2), CHROME)
			-- a big number disc on each door
			for _, side in { -1, 1 } do
				ctx.cyl("Roundel", Vector3.new(0.1, 1.3, 1.3), Vector3.new(side * (s.Width / 2 + 0.05), 2.4, 0), s.Accent)
				ctx.box("MudFlap", Vector3.new(1, 1, 0.15), Vector3.new(side * (s.Width / 2 - 0.4), 1.2, s.Length * 0.32 + 1.4), INK)
			end
			spoiler(ctx, s, 3.1, s.Accent, 0.9)
			lights(ctx, s, 2.5)
			wheels(ctx, s, Color3.fromRGB(255, 220, 50))
		end,
	},
	{
		Style = "Sports car",
		Length = 9.4, Width = 5, WheelRadius = 1, WheelWidth = 1.1,
		Body = Color3.fromRGB(235, 35, 50), Accent = Color3.fromRGB(30, 30, 40),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.3, s.Length - 1.6), Vector3.new(0, 1.45, 0.8), s.Body)
			ctx.wedge("Nose", Vector3.new(s.Width, 1.3, 1.6), Vector3.new(0, 1.45, -s.Length / 2 + 0.8), s.Body)
			cabin(ctx, s, 2.4, 1.3, 1.6, 2.1, s.Body, 2)
			for _, side in { -1, 1 } do
				ctx.box("SideVent", Vector3.new(0.12, 0.5, 1.4), Vector3.new(side * (s.Width / 2 + 0.05), 1.5, 1.4), s.Accent)
			end
			spoiler(ctx, s, 2.1, s.Accent, 1)
			exhausts(ctx, s, 1.1, 2)
			lights(ctx, s, 1.6)
			wheels(ctx, s, Color3.fromRGB(30, 30, 40))
		end,
	},
	{
		Style = "Supercar",
		Length = 10, Width = 5.4, WheelRadius = 1.05, WheelWidth = 1.2, BackWheelScale = 1.1,
		Body = Color3.fromRGB(150, 235, 40), Accent = Color3.fromRGB(25, 25, 32),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.1, s.Length - 2.6), Vector3.new(0, 1.35, 1.3), s.Body)
			ctx.wedge("Nose", Vector3.new(s.Width, 1.1, 2.6), Vector3.new(0, 1.35, -s.Length / 2 + 1.3), s.Body)
			ctx.box("Splitter", Vector3.new(s.Width + 0.2, 0.2, 1), Vector3.new(0, 0.75, -s.Length / 2 + 0.4), s.Accent)
			cabin(ctx, s, 2, 1.1, 1.4, 1.9, s.Accent, 2.4)
			-- big side intakes behind the doors
			for _, side in { -1, 1 } do
				ctx.box("Intake", Vector3.new(0.6, 0.7, 1.6), Vector3.new(side * (s.Width / 2 + 0.1), 1.4, 2.4), s.Accent)
			end
			spoiler(ctx, s, 1.9, s.Accent, 1.1)
			exhausts(ctx, s, 1.1, 4)
			lights(ctx, s, 1.4, 1)
			wheels(ctx, s, Color3.fromRGB(25, 25, 32))
		end,
	},
	{
		Style = "Hypercar with underglow",
		Length = 10.6, Width = 5.6, WheelRadius = 1.05, WheelWidth = 1.2,
		Body = Color3.fromRGB(130, 60, 230), Accent = Color3.fromRGB(20, 20, 28),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.1, s.Length - 3), Vector3.new(0, 1.35, 1.5), s.Body)
			ctx.wedge("Nose", Vector3.new(s.Width, 1.1, 3), Vector3.new(0, 1.35, -s.Length / 2 + 1.5), s.Body)
			cabin(ctx, s, 2.2, 1, 1.4, 1.9, s.Accent, 2.6)
			-- a tall fin down the middle of the back, and glowing strips
			ctx.wedge("Fin", Vector3.new(0.3, 1.6, 3), Vector3.new(0, 2.7, 4), s.Body)
			for _, side in { -1, 1 } do
				ctx.box("GlowStrip", Vector3.new(0.12, 0.2, s.Length - 3), Vector3.new(side * (s.Width / 2 + 0.05), 1.6, 1.5), Color3.fromRGB(80, 230, 255), { Material = Enum.Material.Neon })
			end
			ctx.box("Underglow", Vector3.new(s.Width - 0.6, 0.15, s.Length - 1.6), Vector3.new(0, 0.7, 0), Color3.fromRGB(80, 230, 255), { Material = Enum.Material.Neon })
			spoiler(ctx, s, 1.9, s.Accent, 1.15)
			lights(ctx, s, 1.4, 1.2)
			wheels(ctx, s, Color3.fromRGB(80, 230, 255))
		end,
	},
	{
		Style = "Rocket car",
		Length = 11.4, Width = 5.6, WheelRadius = 1.1, WheelWidth = 1.2,
		Body = Color3.fromRGB(245, 245, 250), Accent = Color3.fromRGB(255, 200, 40),
		draw = function(ctx, s)
			ctx.box("Body", Vector3.new(s.Width, 1.3, s.Length - 3.2), Vector3.new(0, 1.5, 1.6), s.Body)
			ctx.wedge("Nose", Vector3.new(s.Width, 1.3, 3.2), Vector3.new(0, 1.5, -s.Length / 2 + 1.6), s.Body)
			ctx.box("Stripe", Vector3.new(1, 0.1, s.Length - 3.2), Vector3.new(0, 2.2, 1.6), s.Accent)
			cabin(ctx, s, 2.2, 1.1, 1, 2.15, s.Accent, 2.2)
			-- stubby wings and two big rocket boosters with flames
			for _, side in { -1, 1 } do
				ctx.wedge("Wing", Vector3.new(2, 0.3, 3), Vector3.new(side * (s.Width / 2 + 0.9), 1.6, 2.6), s.Accent)
				local x = side * 1.5
				ctx.cyl("Booster", Vector3.new(4, 1.5, 1.5), Vector3.new(x, 2.9, 3.8), Color3.fromRGB(200, 205, 215), { Rot = CFrame.Angles(0, math.rad(90), 0) })
				ctx.cyl("BoosterRing", Vector3.new(0.4, 1.7, 1.7), Vector3.new(x, 2.9, 5.6), s.Accent, { Rot = CFrame.Angles(0, math.rad(90), 0) })
				ctx.cyl("Flame", Vector3.new(1.4, 1.1, 1.1), Vector3.new(x, 2.9, 6.4), Color3.fromRGB(255, 150, 30), { Rot = CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon })
				ctx.cyl("FlameTip", Vector3.new(1, 0.6, 0.6), Vector3.new(x, 2.9, 7.4), Color3.fromRGB(255, 240, 120), { Rot = CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon })
			end
			lights(ctx, s, 1.6, 1.4)
			wheels(ctx, s, s.Accent)
		end,
	},
	{
		-- car 11, the VIP pass car (not on the normal stands)
		Style = "Golden VIP cruiser",
		Length = 10.4, Width = 5.4, WheelRadius = 1.05, WheelWidth = 1.1,
		Body = Color3.fromRGB(255, 200, 45), Accent = Color3.fromRGB(30, 26, 40),
		draw = function(ctx, s)
			local shine = { Material = Enum.Material.SmoothPlastic, Reflectance = 0.12 }
			ctx.box("Body", Vector3.new(s.Width, 1.3, s.Length - 2.4), Vector3.new(0, 1.45, 1.2), s.Body, shine)
			ctx.wedge("Nose", Vector3.new(s.Width, 1.3, 2.4), Vector3.new(0, 1.45, -s.Length / 2 + 1.2), s.Body, false, shine)
			ctx.box("Grille", Vector3.new(s.Width * 0.5, 0.5, 0.2), Vector3.new(0, 1.2, -s.Length / 2 - 0.02), CHROME)
			cabin(ctx, s, 3.6, 1.3, 1.6, 2.1, s.Accent, 1.6)
			-- a white racing stripe, gold side skirts and a crown on the roof
			ctx.box("Stripe", Vector3.new(0.9, 0.1, s.Length - 2.4), Vector3.new(0, 2.12, 1.2), Color3.fromRGB(255, 255, 255))
			for _, side in { -1, 1 } do
				ctx.box("Skirt", Vector3.new(0.3, 0.4, s.Length - 3.6), Vector3.new(side * (s.Width / 2 + 0.1), 0.95, 0.4), Color3.fromRGB(235, 160, 20), shine)
			end
			local roof = 2.1 + 1.3
			ctx.box("CrownBase", Vector3.new(2, 0.5, 1.4), Vector3.new(0, roof + 0.25, 1.6), s.Body, shine)
			for i = -1, 1 do
				ctx.box("CrownPoint", Vector3.new(0.45, 0.8, 0.45), Vector3.new(i * 0.75, roof + 0.85, 1.6), s.Body, shine)
				ctx.box("CrownGem", Vector3.new(0.3, 0.3, 0.1), Vector3.new(i * 0.75, roof + 0.3, 0.88), if i == 0 then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(80, 200, 255), { Material = Enum.Material.Neon })
			end
			spoiler(ctx, s, 2.1, s.Body, 1.05)
			exhausts(ctx, s, 1.1, 2)
			lights(ctx, s, 1.55, 1.2)
			wheels(ctx, s, s.Body)
		end,
	},
}

-- the cars on the stands (unlocked with Wins); the VIP Cruiser comes after them
CarLooks.Count = 10
CarLooks.VipTier = 11

-- the names on the car stands, in order (our own, no real brands)
local NAMES = { "Crate Cart", "Go-Kart", "Hatchback", "Pickup", "Muscle Car", "Rally Car", "Sports Car", "Supercar", "Hypercar", "Rocket Car", "VIP Cruiser" }

function CarLooks.info(tier)
	local s = CARS[tier]
	return s and { Name = NAMES[tier] or ("Car " .. tier), Style = s.Style, Length = s.Length, Width = s.Width }
end

function CarLooks.build(tier, cf)
	tier = math.clamp(tier, 1, #CARS)
	local s = CARS[tier]
	local model = Instance.new("Model")
	model.Name = "Car" .. tier
	local ctx = newCtx(model, cf or CFrame.identity)
	s.draw(ctx, s)
	local body = model:FindFirstChild("Body")
	model.PrimaryPart = body
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= body then
			p.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model:SetAttribute("Tier", tier)
	return model
end

return CarLooks

