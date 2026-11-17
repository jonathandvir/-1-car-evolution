-- Spins and bobs the Horsepower cans on the stages, and hides a can you've just grabbed
-- (Hud sets its "HiddenUntil" attribute) until it comes back for you. Only on this client.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local cans = {} -- [can model] = { Parts = { [part] = { Offset, Transparency } }, Home, Gui }

local function track(can)
	local body = can.PrimaryPart or can:WaitForChild("Body", 5)
	if not body or cans[can] then
		return
	end
	local parts = {}
	for _, p in can:GetDescendants() do
		if p:IsA("BasePart") then
			parts[p] = { Offset = body.CFrame:ToObjectSpace(p.CFrame), Transparency = p.Transparency }
		end
	end
	cans[can] = { Parts = parts, Home = body.CFrame, Gui = body:FindFirstChildOfClass("BillboardGui") }
end

for _, can in CollectionService:GetTagged("HorsepowerCan") do
	task.spawn(track, can)
end
CollectionService:GetInstanceAddedSignal("HorsepowerCan"):Connect(function(can)
	task.spawn(track, can)
end)
CollectionService:GetInstanceRemovedSignal("HorsepowerCan"):Connect(function(can)
	cans[can] = nil
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for can, info in cans do
		if not can.Parent then
			cans[can] = nil
			continue
		end
		local hidden = (can:GetAttribute("HiddenUntil") or 0) > t
		local spin = info.Home * CFrame.new(0, math.sin(t * 2.5) * 0.4, 0) * CFrame.Angles(0, t * 1.8, 0)
		for p, part in info.Parts do
			p.CFrame = spin * part.Offset
			p.Transparency = if hidden then 1 else part.Transparency
		end
		if info.Gui then
			info.Gui.Enabled = not hidden
		end
	end
end)

return {}
