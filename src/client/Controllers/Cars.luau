-- The car showroom, as this player sees it: each pad shows EQUIPPED (green pad),
-- OWNED, the next car's price, or LOCKED for later ones, and the prompt says what
-- holding it will do. Only looks change here; the server checks every unlock and equip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local stands = workspace:WaitForChild("Map"):WaitForChild("CarStands")

local GREEN = Color3.fromRGB(120, 255, 130)
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 222, 50)
local RED = Color3.fromRGB(255, 110, 110)
local PAD = Color3.fromRGB(45, 48, 58)
local PAD_EQUIPPED = Color3.fromRGB(90, 225, 90)

local entries = {}
local refresh

-- stands can still be arriving from the server when this starts, so track late ones too
local function track(stand)
	local tier = stand:GetAttribute("Tier")
	if not tier then
		return
	end
	local base = stand:WaitForChild("Base")
	table.insert(entries, {
		Tier = tier,
		Pad = base,
		Status = base:WaitForChild("Sign"):WaitForChild("Status"),
		Prompt = base:WaitForChild("Unlock"),
	})
	refresh()
end

function refresh()
	local owned = player:GetAttribute("Cars") or 1
	local equipped = player:GetAttribute("EquippedCar") or 1
	for _, e in entries do
		local price = Format.short(Config.Cars.Prices[e.Tier] or 0) .. " Wins"
		e.Prompt.Enabled = e.Tier ~= equipped
		if e.Tier == Config.Cars.VipTier then
			-- the VIP stand keeps its gold pad; it comes with the VIP pass
			if e.Tier == equipped then
				e.Status.Text, e.Status.TextColor3 = "EQUIPPED", GREEN
			elseif player:GetAttribute("Vip") then
				e.Status.Text, e.Status.TextColor3 = "OWNED", WHITE
				e.Prompt.ActionText = "Equip"
			else
				e.Status.Text, e.Status.TextColor3 = "VIP PASS", YELLOW
				e.Prompt.ActionText = "Get VIP"
			end
			continue
		end
		e.Pad.Color = if e.Tier == equipped then PAD_EQUIPPED else PAD
		if e.Tier == equipped then
			e.Status.Text, e.Status.TextColor3 = "EQUIPPED", GREEN
		elseif e.Tier <= owned then
			e.Status.Text, e.Status.TextColor3 = "OWNED", WHITE
			e.Prompt.ActionText = "Equip"
		elseif e.Tier == owned + 1 then
			e.Status.Text, e.Status.TextColor3 = price, YELLOW
			e.Prompt.ActionText = "Unlock (" .. price .. ")"
		else
			e.Status.Text, e.Status.TextColor3 = price, RED
			e.Prompt.ActionText = "Unlock (" .. price .. ")"
		end
	end
end
player:GetAttributeChangedSignal("Cars"):Connect(refresh)
player:GetAttributeChangedSignal("EquippedCar"):Connect(refresh)
player:GetAttributeChangedSignal("Vip"):Connect(refresh)
stands.ChildAdded:Connect(track)
for _, stand in stands:GetChildren() do
	task.spawn(track, stand)
end

return nil

