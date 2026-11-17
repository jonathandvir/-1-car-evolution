-- Draws each gate's sign with this player's own cost and reward, opens the gates
-- they've passed (only for them), and asks the server to pass a gate when they walk into it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local course = workspace:WaitForChild("Map"):WaitForChild("Course")
local gatesFolder = course:WaitForChild("Gates")

local gates = {} -- [index] = { Barrier, Title, Cost, Reward }

local function text(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		label[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end

for i = 1, Config.Course.GatesPerLevel do
	local gate = gatesFolder:WaitForChild("Gate" .. i)
	local sign = gate:WaitForChild("Sign")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = sign
	-- the sign is drawn as a rounded, outlined board instead of a flat block
	sign.Transparency = 1
	local board = Instance.new("Frame")
	board.Size = UDim2.new(1, -16, 1, -16)
	board.Position = UDim2.fromOffset(8, 8)
	board.BackgroundColor3 = Color3.new(1, 1, 1)
	board.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 40)
	corner.Parent = board
	local outline = Instance.new("UIStroke")
	outline.Thickness = 8
	outline.Color = Color3.fromRGB(28, 18, 48)
	outline.Parent = board
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(110, 90, 255), Color3.fromRGB(60, 30, 160))
	gradient.Rotation = 90
	gradient.Parent = board
	gates[i] = {
		Barrier = gate:WaitForChild("Barrier"),
		Title = text(board, { Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.07), TextColor3 = Color3.fromRGB(255, 255, 255) }),
		Cost = text(board, { Size = UDim2.fromScale(0.9, 0.4), Position = UDim2.fromScale(0.05, 0.33), TextColor3 = Color3.fromRGB(255, 230, 60) }),
		Reward = text(board, { Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.75), TextColor3 = Color3.fromRGB(255, 200, 70) }),
	}
end

local function refresh()
	local level = player:GetAttribute("Level") or 1
	local nextGate = player:GetAttribute("NextGate") or 1
	local energy = player:GetAttribute("Energy") or 0
	for i, g in gates do
		local passed = i < nextGate
		local cost = Config.gateCost(level, i)
		g.Title.Text = if passed then "Passed!" else `Gate {i}`
		g.Cost.Text = Format.short(cost) .. " Wins"
		g.Cost.TextColor3 = if passed or energy >= cost then Color3.fromRGB(110, 255, 120) else Color3.fromRGB(255, 100, 100)
		g.Reward.Text = "+" .. Format.short(Config.gateWins(level, i)) .. " Wins"
		g.Barrier.CanCollide = not passed
		g.Barrier.Transparency = if passed then 1 else 0.35
		g.Barrier.Color = if i == nextGate and energy >= cost then Color3.fromRGB(90, 255, 120) else Color3.fromRGB(60, 170, 255)
	end
end

local function isMe(hit)
	local character = player.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

local lastAsk = 0
for i, g in gates do
	g.Barrier.Touched:Connect(function(hit)
		if not isMe(hit) or i ~= (player:GetAttribute("NextGate") or 1) or os.clock() - lastAsk < 0.6 then
			return
		end
		lastAsk = os.clock()
		remotes.PassGate:FireServer(i)
	end)
end

local lastFinish = 0
course:WaitForChild("Finish").Touched:Connect(function(hit)
	if not isMe(hit) or os.clock() - lastFinish < 2 then
		return
	end
	if (player:GetAttribute("NextGate") or 1) > Config.Course.GatesPerLevel then
		lastFinish = os.clock()
		remotes.Finish:FireServer()
	end
end)

---------------------------------------------------------------- bursts
-- A burst of sparks from a point, in the given colours
local function sparks(position, colors, count, speed)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colors[1], colors[2])
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	game:GetService("Debris"):AddItem(holder, 1.5)
end

-- A quick shake of the camera
local function shake(strength, time)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < time do
			local fade = 1 - (os.clock() - started) / time
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength * fade
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- The gate flashes white and breaks apart, whatever order the updates arrive in
local function breakGate(index)
	local barrier = gates[index] and gates[index].Barrier
	if not barrier then
		return
	end
	local ghost = barrier:Clone()
	ghost:ClearAllChildren()
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(200, 255, 220)
	ghost.Transparency = 0.1
	ghost.Parent = workspace
	local tween = TweenService:Create(ghost, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = ghost.Size * Vector3.new(1.15, 1.15, 6), Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		ghost:Destroy()
	end)
	sparks(barrier.Position, { Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 240, 90) }, 70, 45)
	shake(0.6, 0.25)
end

remotes.Notice.OnClientEvent:Connect(function(notice)
	if notice.Kind == "GatePassed" then
		breakGate(notice.Gate)
	elseif notice.Kind == "LevelComplete" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			sparks(root.Position + Vector3.new(0, 3, 0), { Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 255, 255) }, 140, 60)
		end
		shake(1, 0.4)
	end
end)

player.AttributeChanged:Connect(function(name)
	if name == "Level" or name == "NextGate" or name == "Energy" then
		refresh()
	end
end)
refresh()

return {}
