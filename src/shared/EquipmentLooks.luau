-- How each piece of equipment looks, built from simple parts. Shared so the farm
-- (server) and the shop's little 3D previews (client) use the same designs.
local EquipmentLooks = {}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local GREY = Color3.fromRGB(120, 125, 140)
local DARK = Color3.fromRGB(45, 50, 70)

-- Builders: each returns a model centred on cf (the floor point), about 6 studs across
local builders = {}

local function solar(model, cf, item, big)
	local s = if big then 1.35 else 1
	part(model, { Size = Vector3.new(0.8, 3 * s, 0.8), CFrame = cf * CFrame.new(0, 1.5 * s, 0), Color = GREY })
	local panelCf = cf * CFrame.new(0, 3.2 * s, 0) * CFrame.Angles(math.rad(-30), 0, 0)
	part(model, { Size = Vector3.new(5 * s, 0.4, 3.6 * s), CFrame = panelCf, Color = DARK })
	part(model, { Size = Vector3.new(4.6 * s, 0.2, 3.2 * s), CFrame = panelCf * CFrame.new(0, 0.25, 0), Color = item.Color, Material = Enum.Material.Glass, Reflectance = 0.3 })
	for i = -1, 1 do
		part(model, { Size = Vector3.new(0.12, 0.25, 3.2 * s), CFrame = panelCf * CFrame.new(i * 1.5 * s, 0.3, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = if big then 0 else 0.4 })
	end
end
builders.SolarBasic = function(model, cf, item)
	solar(model, cf, item, false)
end
builders.SolarAdvanced = function(model, cf, item)
	solar(model, cf, item, true)
end

local function turbine(model, cf, item, big)
	local h = if big then 13 else 10
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.9, 0.9), CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 240, 245) })
	local hubCf = cf * CFrame.new(0, h, -0.8)
	local hub = part(model, { Name = "Hub", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = hubCf, Color = item.Color, Material = if big then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	hub:SetAttribute("Spin", if big then 4 else 2.5)
	local len = if big then 5.5 else 4.5
	for i = 0, 2 do
		local blade = part(model, { Name = "Blade", Size = Vector3.new(0.6, len, 0.15), CFrame = hubCf * CFrame.Angles(0, 0, math.rad(i * 120)) * CFrame.new(0, len / 2, 0), Color = Color3.fromRGB(250, 250, 255) })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hub
		weld.Part1 = blade
		weld.Parent = blade
	end
	part(model, { Size = Vector3.new(2.4, 0.6, 2.4), CFrame = cf * CFrame.new(0, 0.3, 0), Color = GREY })
end
builders.Wind = function(model, cf, item)
	turbine(model, cf, item, false)
end
builders.WindAdvanced = function(model, cf, item)
	turbine(model, cf, item, true)
end

builders.Nuclear = function(model, cf, item)
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 5, 5), CFrame = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(210, 210, 220) })
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5.3, 5.3), CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = item.Color, Material = Enum.Material.Neon })
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.4, 4.4), CFrame = cf * CFrame.new(0, 7.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 255, 80), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = item.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = model:FindFirstChildWhichIsA("BasePart")
end

builders.Fusion = function(model, cf, item)
	part(model, { Size = Vector3.new(5, 1.2, 5), CFrame = cf * CFrame.new(0, 0.6, 0), Color = DARK })
	local core = part(model, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(0, 4.5, 0), Color = item.Color, Material = Enum.Material.Neon })
	core:SetAttribute("Pulse", true)
	for i, rot in { CFrame.Angles(0, 0, 0), CFrame.Angles(math.rad(60), 0, 0), CFrame.Angles(math.rad(-60), 0, 0) } do
		local ring = part(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5.6, 5.6), CFrame = core.CFrame * rot * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Transparency = 0.35 })
		ring:SetAttribute("Spin", 1 + i * 0.6)
	end
	local light = Instance.new("PointLight")
	light.Color = item.Color
	light.Range = 14
	light.Brightness = 2.5
	light.Parent = core
end

-- Builds the item's model into `model`, standing on the floor point `cf`
function EquipmentLooks.build(item, model, cf)
	builders[item.Id](model, cf, item)
end

return EquipmentLooks
