-- Animates the course's moving parts (tagged "Mover" by Server.Course) on this client,
-- timed from the server clock so every player sees them in the same place.
--   Slide: side to side along the part's own X, Lift: up and down, Spin: turns around Y.
-- Moving platforms also get a matching velocity, so a car standing on one rides along.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local movers = {}

local function add(p)
	if p:IsA("BasePart") and typeof(p:GetAttribute("Home")) == "CFrame" then
		movers[p] = {
			Kind = p:GetAttribute("Kind"),
			Home = p:GetAttribute("Home"),
			Amp = p:GetAttribute("Amp") or 0,
			Period = math.max(0.5, p:GetAttribute("Period") or 4),
			Phase = p:GetAttribute("Phase") or 0,
			Speed = p:GetAttribute("Speed") or 1,
		}
	end
end

CollectionService:GetInstanceAddedSignal("Mover"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Mover"):Connect(function(p)
	movers[p] = nil
end)
for _, p in CollectionService:GetTagged("Mover") do
	add(p)
end

RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	for p, m in movers do
		if m.Kind == "Spin" then
			p.CFrame = m.Home * CFrame.Angles(0, (t * m.Speed) % (math.pi * 2), 0)
			p.AssemblyAngularVelocity = Vector3.new(0, m.Speed, 0)
		else
			local w = math.pi * 2 / m.Period
			local offset = math.sin(t * w + m.Phase) * m.Amp
			local speed = math.cos(t * w + m.Phase) * m.Amp * w
			if m.Kind == "Lift" then
				p.CFrame = m.Home + Vector3.new(0, offset, 0)
				p.AssemblyLinearVelocity = Vector3.new(0, speed, 0)
			else
				p.CFrame = m.Home * CFrame.new(offset, 0, 0)
				p.AssemblyLinearVelocity = m.Home.RightVector * speed
			end
		end
	end
end)

return nil
