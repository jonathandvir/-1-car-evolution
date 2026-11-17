-- Gives each player a plot and shows the equipment they own on it.
-- Each kind of equipment has its own row, one copy per slot along it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EquipmentLooks = require(ReplicatedStorage.Shared.EquipmentLooks)

local Farms = {}
local owners = {} -- [plot] = player
local plotOf = {} -- [player] = plot

function Farms.plotOf(player)
	return plotOf[player]
end

-- Rebuilds the plot's equipment from what the player owns
function Farms.refresh(player, data)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local items = plot.Items
	items:ClearAllChildren()
	local base = plot.PrimaryPart
	local facing = plot:GetAttribute("Facing")
	local rows = #Config.Equipment
	local spacing = 6.8
	for r, item in Config.Equipment do
		local count = data.Equipment[item.Id] or 0
		for c = 1, count do
			-- rows run front to back across the plot, copies run side to side
			local localX = (c - 3) * spacing * -facing
			local localZ = (r - (rows + 1) / 2) * spacing
			local floor = base.Position + Vector3.new(localX, 0.5, localZ)
			local cf = CFrame.lookAt(floor, floor + Vector3.new(facing, 0, 0))
			local model = Instance.new("Model")
			model.Name = item.Id .. "_" .. c
			EquipmentLooks.build(item, model, cf)
			model.Parent = items
		end
	end
end

local function claim(player)
	for _, plot in workspace.Map.Plots:GetChildren() do
		if not owners[plot] then
			owners[plot] = player
			plotOf[player] = plot
			plot.Sign.SurfaceGui.Owner.Text = player.DisplayName .. "'s Farm"
			player:SetAttribute("Plot", plot.Name)
			return plot
		end
	end
	return nil
end

function Farms.start(Data)
	Data.onLoaded(function(player, data)
		if claim(player) then
			Farms.refresh(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local plot = plotOf[player]
		if plot then
			plot.Items:ClearAllChildren()
			plot.Sign.SurfaceGui.Owner.Text = "EMPTY FARM"
			owners[plot] = nil
			plotOf[player] = nil
		end
	end)
end

return Farms
