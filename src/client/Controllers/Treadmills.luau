-- Treadmills, on this client only (the server decides who is on one):
--   * the belts' stripes slide along and wrap round, so they look like they're rolling
--   * any car locked on a treadmill (its player's Treadmill attribute) spins its wheels in
--     place: spokes turn on each wheel and dust puffs out behind
--   * steering (keys or joystick) gets your own car off again
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SPEED = 9 -- studs per second the stripes slide
local SPACING = 2.8 -- the gap between stripes (matches Server.Map)
local SPIN = 26 -- radians per second the wheels turn

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

---------------------------------------------------------------- rolling belts
local belts = {} -- [pad model] = { Belt, Stripes = { { Part, Offset } } }

local function track(pad)
	local belt = pad:FindFirstChild("Belt")
	if not belt or belts[pad] then
		return
	end
	local stripes = {}
	for _, child in pad:GetChildren() do
		if child.Name == "Stripe" and child:IsA("BasePart") then
			table.insert(stripes, { Part = child, Offset = belt.CFrame:PointToObjectSpace(child.Position).X })
		end
	end
	belts[pad] = { Belt = belt, Stripes = stripes, Height = belt.Size.Y / 2 + 0.04 }
end

task.spawn(function()
	local folder = workspace:WaitForChild("Map"):WaitForChild("TrainingPads")
	local function add(pad)
		-- with streaming on, a pad's parts can arrive a moment after the pad itself
		task.delay(0.5, track, pad)
	end
	for _, pad in folder:GetChildren() do
		add(pad)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(pad)
		belts[pad] = nil
	end)
end)

---------------------------------------------------------------- spinning wheels
local spinning = {} -- [player] = { Car, Wheels = { { Wheel, Spokes, Side } }, Dust }

local function stopSpin(who)
	local s = spinning[who]
	if not s then
		return
	end
	spinning[who] = nil
	for _, w in s.Wheels do
		for _, spoke in w.Spokes do
			spoke:Destroy()
		end
	end
	if s.Dust then
		s.Dust:Destroy()
	end
end

local function startSpin(who)
	stopSpin(who)
	local character = who.Character
	local car = character and character:FindFirstChild("PlayerCar")
	local body = car and car.PrimaryPart
	if not body then
		return
	end
	local s = { Car = car, Wheels = {} }
	for _, wheel in car:GetChildren() do
		if wheel.Name == "Wheel" and wheel:IsA("BasePart") then
			-- the outer face of the wheel: away from the middle of the car
			local side = if body.CFrame:PointToObjectSpace(wheel.Position).X < 0 then -1 else 1
			local spokes = {}
			for i = 0, 1 do
				local spoke = Instance.new("Part")
				spoke.Name = "Spoke"
				spoke.Anchored = true
				spoke.CanCollide = false
				spoke.CanQuery = false
				spoke.CanTouch = false
				spoke.CastShadow = false
				spoke.Material = Enum.Material.SmoothPlastic
				spoke.Color = Color3.fromRGB(30, 30, 38)
				spoke.Size = Vector3.new(0.12, wheel.Size.Y * 0.8, 0.28)
				spoke:SetAttribute("Turn", i * math.pi / 2)
				spoke.Parent = workspace
				table.insert(spokes, spoke)
			end
			table.insert(s.Wheels, { Wheel = wheel, Spokes = spokes, Side = side })
		end
	end
	-- a puff of dust out from behind the car
	local dust = Instance.new("Attachment")
	dust.Name = "TreadmillDust"
	dust.Position = Vector3.new(0, -body.Size.Y / 2, body.Size.Z / 2 + 1)
	dust.Parent = body
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Rate = 18
	emitter.Parent = dust
	s.Dust = dust
	spinning[who] = s
end

local function watch(who)
	local function update()
		if who:GetAttribute("Treadmill") then
			-- the server puts the car in place first; give it a moment to arrive
			task.delay(0.15, function()
				if who:GetAttribute("Treadmill") then
					startSpin(who)
				end
			end)
		else
			stopSpin(who)
		end
	end
	who:GetAttributeChangedSignal("Treadmill"):Connect(update)
	who.CharacterAdded:Connect(function()
		stopSpin(who)
	end)
	update()
end
for _, who in Players:GetPlayers() do
	watch(who)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(stopSpin)

---------------------------------------------------------------- getting off
local lastLeave = 0

-- Roblox's own controls (keys, thumbstick, gamepad), read directly: a car held in place on
-- a treadmill doesn't report the steering through its Humanoid
local controls
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)):GetControls()
	end)
	controls = ok and module or nil
end)
local function steering()
	if controls then
		local ok, vector = pcall(controls.GetMoveVector, controls)
		if ok and vector then
			return vector.Magnitude
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid.MoveDirection.Magnitude else 0
end
local function leave()
	if player:GetAttribute("Treadmill") and os.clock() - lastLeave > 0.5 then
		lastLeave = os.clock()
		remotes:WaitForChild("LeaveTreadmill"):FireServer()
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local shift = now * SPEED
	for pad, info in belts do
		if not info.Belt.Parent then
			belts[pad] = nil
			continue
		end
		local half = info.Belt.Size.X / 2
		local length = #info.Stripes * SPACING
		for _, stripe in info.Stripes do
			-- slide toward the belt's -X end, wrapping back to the +X end
			local x = (stripe.Offset - shift + half) % length - half
			stripe.Part.CFrame = info.Belt.CFrame * CFrame.new(x, info.Height, 0)
			stripe.Part.Transparency = if math.abs(x) > half - 0.4 then 1 else 0
		end
	end
	for who, s in spinning do
		if not s.Car.Parent then
			stopSpin(who)
			continue
		end
		for _, w in s.Wheels do
			-- a cross of spokes turning on the outside of each wheel
			local face = w.Wheel.CFrame * CFrame.new(w.Side * (w.Wheel.Size.X / 2 + 0.09), 0, 0)
			for _, spoke in w.Spokes do
				spoke.CFrame = face * CFrame.Angles(-now * SPIN + spoke:GetAttribute("Turn"), 0, 0)
			end
		end
	end
	-- your own car: steering gets you off
	if player:GetAttribute("Treadmill") and steering() > 0.1 then
		leave()
	end
end)

return { leave = leave }
