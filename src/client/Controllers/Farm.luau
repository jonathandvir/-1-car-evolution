-- Makes farm equipment feel alive on this screen only: turbines spin, fusion rings tumble, cores pulse.
local RunService = game:GetService("RunService")

local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")

local spinners = {} -- [part] = { Base, Speed, Children = { [part] = offset } }

local function register(part)
	if not part:IsA("BasePart") then
		return
	end
	local speed = part:GetAttribute("Spin")
	if speed then
		task.defer(function()
			local entry = { Base = part.CFrame, Speed = speed, Children = {} }
			if part.Name == "Hub" then
				for _, sibling in part.Parent:GetChildren() do
					if sibling.Name == "Blade" then
						entry.Children[sibling] = part.CFrame:ToObjectSpace(sibling.CFrame)
					end
				end
			end
			spinners[part] = entry
		end)
	elseif part:GetAttribute("Pulse") then
		spinners[part] = { Pulse = true, Size = part.Size }
	end
end

plots.DescendantAdded:Connect(register)
for _, d in plots:GetDescendants() do
	register(d)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for part, entry in spinners do
		if not part.Parent then
			spinners[part] = nil
		elseif entry.Pulse then
			part.Size = entry.Size * (1 + math.sin(t * 4) * 0.08)
		elseif part.Name == "Hub" then
			part.CFrame = entry.Base * CFrame.Angles(0, 0, t * entry.Speed)
			for blade, offset in entry.Children do
				blade.CFrame = part.CFrame * offset
			end
		else
			part.CFrame = entry.Base * CFrame.Angles(0, t * entry.Speed, 0)
		end
	end
end)

return {}
