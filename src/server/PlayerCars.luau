-- Turns each player into their equipped car: the avatar is hidden and the car model
-- (Shared.CarLooks) is welded to the HumanoidRootPart, with its wheels on the ground.
-- The character still moves as normal underneath, so the car drives where they walk.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarLooks = require(ReplicatedStorage.Shared.CarLooks)

local PlayerCars = {}

local CAR_NAME = "PlayerCar"

local function hide(inst, character)
	local car = character:FindFirstChild(CAR_NAME)
	if car and (inst == car or inst:IsDescendantOf(car)) then
		return
	end
	if inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CastShadow = false
	elseif inst:IsA("Decal") then
		inst.Transparency = 1
	end
end

-- how far the root part sits above the ground
local function rootHeight(humanoid, root)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

function PlayerCars.attach(player, tier)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local old = character:FindFirstChild(CAR_NAME)
	if old then
		old:Destroy()
	end
	local ground = root.CFrame * CFrame.new(0, -rootHeight(humanoid, root), 0)
	local car = CarLooks.build(tier, ground)
	car.Name = CAR_NAME
	for _, p in car:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	-- a Weld (not a WeldConstraint) so the car can be spun for the landing flip
	local weld = Instance.new("Weld")
	weld.Name = "CarWeld"
	weld.Part0 = root
	weld.Part1 = car.PrimaryPart
	weld.C0 = root.CFrame:ToObjectSpace(car.PrimaryPart.CFrame)
	weld.Parent = car.PrimaryPart
	car:SetAttribute("RestC0", weld.C0)
	car.Parent = character
end

-- A quick hop and front flip of the car, for landing a road on solid ground
local flipping = {}
function PlayerCars.flip(player)
	local character = player.Character
	local car = character and character:FindFirstChild(CAR_NAME)
	local weld = car and car.PrimaryPart and car.PrimaryPart:FindFirstChild("CarWeld")
	local rest = car and car:GetAttribute("RestC0")
	if not weld or typeof(rest) ~= "CFrame" or flipping[player] then
		return
	end
	flipping[player] = true
	local duration = 0.65
	local started = os.clock()
	while os.clock() - started < duration and weld.Parent do
		local t = (os.clock() - started) / duration
		local spin = 1 - (1 - t) ^ 2 -- fast, then easing into the landing
		weld.C0 = rest * CFrame.new(0, math.sin(t * math.pi) * 5, 0) * CFrame.Angles(-spin * 2 * math.pi, 0, 0)
		RunService.Heartbeat:Wait()
	end
	if weld.Parent then
		weld.C0 = rest
	end
	flipping[player] = nil
end

-- Call when a player joins (before their data loads, so they're never their avatar);
-- getTier returns their equipped car, or 1 until the data is in.
function PlayerCars.track(player, getTier)
	local function onCharacter(character)
		character:WaitForChild("HumanoidRootPart")
		character:WaitForChild("Humanoid")
		for _, inst in character:GetDescendants() do
			hide(inst, character)
		end
		character.DescendantAdded:Connect(function(inst)
			hide(inst, character)
		end)
		PlayerCars.attach(player, getTier())
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return PlayerCars
