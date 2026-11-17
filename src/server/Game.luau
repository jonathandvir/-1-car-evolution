-- The core loop, all on the server: treadmills give Horsepower (which sets your level),
-- roads (Server.Roads) take you across the stages for Wins, and Wins unlock cars.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Admin = require(script.Parent.Admin)
local Course = require(script.Parent.Course)
local Data = require(script.Parent.Data)
local Farms = require(script.Parent.Farms)
local Map = require(script.Parent.Map)
local PlayerCars = require(script.Parent.PlayerCars)
local Roads = require(script.Parent.Roads)
local Store = require(script.Parent.Store)

local Game = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local BuyRemote = remote("Buy") -- client -> server: equipment id
local NoticeRemote = remote("Notice") -- server -> client: { Kind, ... } for popups
local RebirthRemote = remote("Rebirth") -- client -> server: rebirth now
local DailyRemote = remote("ClaimDaily") -- client -> server: claim today's daily reward
local SettingsRemote = remote("SaveSettings") -- client -> server: { MusicVolume, EffectsVolume, MusicMuted, EffectsMuted }
Store.start(remotes, NoticeRemote) -- adds the Purchase remote
remotes.Parent = ReplicatedStorage

local lastPadWarn = {} -- [player] = os.clock() of the last "locked treadmill" notice

---------------------------------------------------------------- falling and respawning
local fellOn = {} -- [player] = the stage they last fell on (cleared once they respawn there)
Players.PlayerRemoving:Connect(function(player)
	fellOn[player] = nil
end)

local function moveTo(player, cframe)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

-- fell off: back to the lobby, with a "RESPAWN AT STAGE N?" offer if it was out on a stage
local function sendToLobby(player, stage)
	-- falling off after reaching a stage's Wins pads (into the gap before the next stage)
	-- isn't a failed stage 1: offer the next stage instead
	if stage and Roads.finished(player, stage) and stage < #Config.Stages.RequiredLevel then
		stage += 1
	end
	moveTo(player, CFrame.lookAt(Map.SpawnPosition, Map.SpawnPosition + Vector3.new(0, 0, 1))) -- facing the stages
	NoticeRemote:FireClient(player, { Kind = "BackToLobby" })
	if stage then
		fellOn[player] = stage
		NoticeRemote:FireClient(player, { Kind = "Fell", Stage = stage })
	end
end

-- put a player at the start of the stage they fell on
local function respawnAtStage(player)
	local stage = fellOn[player]
	local model = stage and workspace.Map.Course:FindFirstChild("Stage" .. stage)
	local start = model and model:GetAttribute("Start")
	if typeof(start) ~= "CFrame" then
		return false
	end
	fellOn[player] = nil
	moveTo(player, start * CFrame.new(0, 5, 6))
	return true
end

-- everything that multiplies Horsepower you gain: your car, your rebirths, x2 Horsepower, VIP
-- and a running 2x Horsepower Admin Abuse event
function Game.boost(data)
	return (Config.Cars.Boosts[data.EquippedCar] or 1)
		* Admin.eventMultiplier("DoubleHorsepower")
		* Data.boostMultiplier(data, "DoubleHorsepower")
		* Config.rebirthBoost(data.Rebirths)
		* (if Store.has(data, "DoubleHorsepower") then 2 else 1)
		* (if Store.has(data, "Vip") then Config.VipBoost else 1)
end

-- can this save use a treadmill tier?
local function canUsePad(data, pad)
	if pad.Pass then
		return Store.has(data, pad.Pass)
	end
	return data.Rebirths >= pad.Rebirths
end

-- Horsepower per second on a treadmill tier: PerSecond x treadmill boost x your boosts
-- (x2 more with Fast Training)
function Game.trainRate(data, tier)
	local pad = Config.Training.Pads[tier] or Config.Training.Pads[1]
	local fast = if Store.has(data, "FastTraining") then Config.Training.FastTraining else 1
	return Config.Training.PerSecond * pad.Boost * Game.boost(data) * fast
end

-- Horsepower per second on the best treadmill you can use (the Starter Pack gives minutes of it)
local function packRate(data)
	local best = 0
	for tier, pad in Config.Training.Pads do
		if canUsePad(data, pad) then
			best = math.max(best, Game.trainRate(data, tier))
		end
	end
	return best
end

-- the most Horsepower you can hold: enough for your level cap, no more
local function horsepowerCap(data)
	return Config.levelNeed(Config.levelCap(data.Rebirths))
end

local function publish(player, data)
	if data.EquippedCar == Config.Cars.VipTier and not Store.has(data, "Vip") then
		data.EquippedCar = data.Cars
	end
	data.Energy = math.min(data.Energy, horsepowerCap(data))
	data.Level = Config.levelFor(data.Energy)
	Data.publish(player)
	player:SetAttribute("CarBoost", Config.Cars.Boosts[data.EquippedCar] or 1)
	player:SetAttribute("Vip", Store.has(data, "Vip") or nil) -- the [VIP] chat tag
end

-- adds Horsepower (up to your level cap), and tells the player when it takes them up a level
local function addHorsepower(player, data, amount)
	local before = data.Energy
	data.Energy = math.min(data.Energy + amount, horsepowerCap(data))
	if data.Energy == before then
		return 0
	end
	player:SetAttribute("Energy", data.Energy)
	local level = Config.levelFor(data.Energy)
	if level > data.Level then
		data.Level = level
		player:SetAttribute("Level", level)
		NoticeRemote:FireClient(player, { Kind = "LevelUp", Level = level, Max = level >= Config.levelCap(data.Rebirths) })
	end
	return data.Energy - before
end

-- Rebirth: only at your level cap. Horsepower goes back to 0 (so level 1), the cap rises by
-- 10 and the Horsepower boost grows. Wins, cars and Rebirths themselves are kept.
-- Skip Rebirth (a developer product) does it without the level.
local function rebirth(player, data)
	data.Rebirths += 1
	data.Energy = 0
	publish(player, data)
	NoticeRemote:FireClient(player, { Kind = "Rebirthed", Rebirths = data.Rebirths })
end

RebirthRemote.OnServerEvent:Connect(function(player)
	local data = Data.get(player)
	if not data or data.Rebirths >= Config.Rebirths.Max then
		return
	end
	if Config.levelFor(data.Energy) < Config.levelCap(data.Rebirths) then
		NoticeRemote:FireClient(player, { Kind = "NeedLevel", Level = Config.levelCap(data.Rebirths) })
		return
	end
	rebirth(player, data)
end)

---------------------------------------------------------------- what each purchase does
-- a Horsepower pack: bigger the more Horsepower you have (Config.packAmount)
local function addPack(player, data, key)
	local amount = Config.packAmount(key, data.Energy, Store.has(data, "DoubleHorsepower"))
	local gained = addHorsepower(player, data, amount)
	NoticeRemote:FireClient(player, { Kind = "PackGiven", Amount = gained })
end

for _, key in Config.PackOrder do
	Store.onProduct(key, function(player, data)
		addPack(player, data, key)
	end, function(player, data)
		if data.Energy >= horsepowerCap(data) then
			NoticeRemote:FireClient(player, { Kind = "AtCap" })
			return false
		end
		return true
	end)
end

Store.onProduct("SkipRebirth", function(player, data)
	if data.Rebirths >= Config.Rebirths.Max then
		-- bought in two servers at once: a Medium pack's worth instead, so it's never wasted
		addPack(player, data, "PackMedium")
	else
		rebirth(player, data)
	end
end, function(_, data)
	return data.Rebirths < Config.Rebirths.Max
end)

Store.onProduct("Respawn", function(player)
	if not respawnAtStage(player) then
		-- they rejoined or already got back on their own: send them to stage 1's start
		fellOn[player] = 1
		respawnAtStage(player)
	end
end, function(player)
	return fellOn[player] ~= nil
end)

-- passes: the Starter Pack is handed out once; VIP puts you in the VIP Cruiser
Store.onPass(function(player, data, key, isNew)
	if key == "StarterPack" and not data.StarterGiven then
		local pack = Config.StarterPack
		data.StarterGiven = true
		data.Wins += pack.Wins
		if data.Cars < pack.Car then
			data.Cars = pack.Car
			if data.EquippedCar < pack.Car then
				data.EquippedCar = pack.Car
				PlayerCars.attach(player, pack.Car)
			end
		end
		publish(player, data)
		addHorsepower(player, data, pack.Minutes * 60 * packRate(data))
	elseif key == "Vip" and isNew then
		data.EquippedCar = Config.Cars.VipTier
		PlayerCars.attach(player, Config.Cars.VipTier)
	end
	publish(player, data)
end)

---------------------------------------------------------------- daily rewards
-- One gift a day along a 7-day streak (Config.Daily). Days start at midnight UTC; claiming
-- the day after your last claim carries the streak on, a missed day starts it again at day 1.
local function utcDay()
	return os.time() // 86400
end

-- Settings: the volume sliders and mute buttons, saved with the player's progress
SettingsRemote.OnServerEvent:Connect(function(player, settings)
	local data = Data.get(player)
	if not data or type(settings) ~= "table" then
		return
	end
	for _, key in { "MusicVolume", "EffectsVolume" } do
		local v = tonumber(settings[key])
		if v and v == v then
			data[key] = math.clamp(math.round(v * 100) / 100, 0, 1)
			player:SetAttribute(key, data[key])
		end
	end
	for _, key in { "MusicMuted", "EffectsMuted" } do
		if type(settings[key]) == "boolean" then
			data[key] = settings[key]
			player:SetAttribute(key, data[key])
		end
	end
end)

DailyRemote.OnServerEvent:Connect(function(player)
	local data = Data.get(player)
	if not data or data.DailyLast >= utcDay() then
		return -- not loaded yet, or already claimed today (repeated clicks land here)
	end
	local day = if data.DailyLast == utcDay() - 1 then data.DailyDay % #Config.Daily + 1 else 1
	local reward = Config.Daily[day]
	data.DailyDay = day
	data.DailyLast = utcDay()
	local wins = Config.dailyWins(day, data.Level)
	data.Wins += wins
	if reward.Boost then
		data.Boosts[reward.Boost] = math.max(data.Boosts[reward.Boost] or 0, os.time()) + reward.Minutes * 60
	end
	publish(player, data)
	local horsepower = 0
	if reward.Horsepower then
		horsepower = addHorsepower(player, data, reward.Horsepower * 60 * packRate(data))
	end
	NoticeRemote:FireClient(player, { Kind = "DailyClaimed", Day = day, Wins = wins, Horsepower = horsepower, Boost = reward.Boost, Minutes = reward.Minutes, WantedHorsepower = reward.Horsepower ~= nil })
	task.spawn(Data.saveNow, player)
end)

local function rootNear(player, position, range)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - position).Magnitude <= range
end

BuyRemote.OnServerEvent:Connect(function(player, id)
	local data = Data.get(player)
	local item = type(id) == "string" and Config.equipment(id)
	if not data or not item then
		return
	end
	local owned = data.Equipment[id] or 0
	if owned >= item.Max then
		return
	end
	local price = Config.equipmentPrice(item, owned)
	if data.Wins < price then
		NoticeRemote:FireClient(player, { Kind = "NeedWins", Need = price - data.Wins })
		return
	end
	data.Wins -= price
	data.Equipment[id] = owned + 1
	publish(player, data)
	Farms.refresh(player, data)
	NoticeRemote:FireClient(player, { Kind = "Bought", Name = item.Name })
end)

-- Car stands: hold the prompt at the next car's stand to unlock it with Wins.
-- Cars unlock in order, so the server only accepts the one after the last owned
-- (which also makes a repeated request do nothing).
local function useCar(player, tier)
	local data = Data.get(player)
	if not data then
		return
	end
	if tier == Config.Cars.VipTier then
		-- the VIP Cruiser comes with the VIP pass
		if not Store.has(data, "Vip") then
			Store.buyPass(player, "Vip")
		elseif data.EquippedCar ~= tier then
			data.EquippedCar = tier
			publish(player, data)
			PlayerCars.attach(player, tier)
		end
		return
	end
	if tier <= data.Cars then
		-- already unlocked: drive it
		if data.EquippedCar ~= tier then
			data.EquippedCar = tier
			publish(player, data)
			PlayerCars.attach(player, tier)
		end
		return
	end
	if tier > data.Cars + 1 then
		NoticeRemote:FireClient(player, { Kind = "NeedCar", Tier = data.Cars + 1 })
		return
	end
	local price = Config.Cars.Prices[tier]
	if not price then
		return
	end
	if data.Wins < price then
		NoticeRemote:FireClient(player, { Kind = "NeedWins", Need = price - data.Wins })
		return
	end
	data.Wins -= price
	data.Cars = tier
	data.EquippedCar = tier
	publish(player, data)
	PlayerCars.attach(player, tier)
	NoticeRemote:FireClient(player, { Kind = "CarUnlocked", Tier = tier })
end

local function hookCarStands()
	local stands = workspace:WaitForChild("Map"):WaitForChild("CarStands")
	for _, stand in stands:GetChildren() do
		local tier = stand:GetAttribute("Tier")
		if tier then
			stand.Base.Unlock.Triggered:Connect(function(player)
				if rootNear(player, stand.Base.Position, 36) then
					useCar(player, tier)
				end
			end)
		end
	end
end

-- Studio-only test tools, run from the command bar during a playtest:
-- game.ServerStorage.DevTools:Invoke("Set", "Wins", 1000)  -- Energy (Horsepower, kept under the level cap), Wins, Rebirths, Cars
-- game.ServerStorage.DevTools:Invoke("Equip", { SolarBasic = 5, Fusion = 1 })
local function devTools()
	local tool = Instance.new("BindableFunction")
	tool.Name = "DevTools"
	tool.OnInvoke = function(command, a, b)
		local player = Players:GetPlayers()[1]
		local data = player and Data.get(player)
		if not data then
			return "no player loaded"
		end
		if command == "Set" and data[a] ~= nil then
			data[a] = b
		elseif command == "Equip" then
			data.Equipment = a
			Farms.refresh(player, data)
		else
			return "unknown command"
		end
		publish(player, data)
		return "ok"
	end
	tool.Parent = game:GetService("ServerStorage")
end

function Game.start()
	Admin.start(remotes, NoticeRemote, { publish = publish, moveTo = moveTo })
	if game:GetService("RunService"):IsStudio() then
		devTools()
	end
	hookCarStands()
	Roads.start(remotes, NoticeRemote)
	-- falling into a pit (or off the course) sends you back to the lobby, and offers to put
	-- you back at the start of the stage you fell on
	local lastPitAt = {}
	local function hookPit(tile)
		tile.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player or os.clock() - (lastPitAt[player] or 0) < 1 then
				return
			end
			lastPitAt[player] = os.clock()
			sendToLobby(player, Course.stageAt(tile.Position.Z))
		end)
	end
	for _, tile in CollectionService:GetTagged("Pit") do
		hookPit(tile)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPitAt[player] = nil
	end)
	-- everyone is a car from the moment they spawn, even before their save loads
	local function trackCar(player)
		PlayerCars.track(player, function()
			local d = Data.get(player)
			return d and d.EquippedCar or 1
		end)
	end
	for _, player in Players:GetPlayers() do
		trackCar(player)
	end
	Players.PlayerAdded:Connect(trackCar)
	Data.onLoaded(function(player, data)
		publish(player, data)
		-- swap in their equipped car once the save is in
		if data.EquippedCar ~= 1 then
			PlayerCars.attach(player, data.EquippedCar)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPadWarn[player] = nil
	end)
	-- fast walking in the lobby, normal on the stages; anyone who falls goes back to base
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid then
					local data = Data.get(player)
					local level = Config.levelFor(data and data.Energy or 0)
					humanoid.WalkSpeed = if Map.inLobby(root.Position) then Config.WalkSpeed.Lobby else Config.stageSpeed(level)
					if root.Position.Y < Config.FallHeight then
						sendToLobby(player, Course.stageAt(root.Position.Z))
					end
				end
			end
		end
	end)
	-- Horsepower cans on the stages: drive over one to grab it; it comes back for you later
	task.spawn(function()
		local taken = {} -- [player] = { [can] = os.clock() when taken }
		Players.PlayerRemoving:Connect(function(player)
			taken[player] = nil
		end)
		while true do
			task.wait(0.1)
			local cans = CollectionService:GetTagged("HorsepowerCan")
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if data and root then
					local mine = taken[player] or {}
					taken[player] = mine
					for _, can in cans do
						local body = can.PrimaryPart
						if body and (not mine[can] or os.clock() - mine[can] > Config.Cans.Respawn) then
							local offset = root.Position - body.Position
							if Vector3.new(offset.X, 0, offset.Z).Magnitude < 5 and math.abs(offset.Y) < 7 then
								mine[can] = os.clock()
								local stage = can:GetAttribute("Stage") or 1
								local gained = addHorsepower(player, data, Config.canHorsepower(stage) * Game.boost(data))
								NoticeRemote:FireClient(player, { Kind = "CanTaken", Can = can, Amount = gained, Respawn = Config.Cans.Respawn })
							end
						end
					end
				end
			end
		end
	end)
	-- Treadmills. Driving onto one you can use locks your car onto the belt, facing the
	-- screen, wheels spinning (Controllers.Treadmills), until you steer off (LeaveTreadmill).
	-- One you can't use says so in red, offers the Golden Treadmill pass, and puts you back
	-- off the front. Anyone locked on gains Horsepower every Tick.
	local leftAt = {} -- [player] = os.clock() they got off, so they aren't locked straight back on
	Players.PlayerRemoving:Connect(function(player)
		leftAt[player] = nil
	end)
	local function placeOn(character, cframe)
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(cframe * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		end
	end
	local function getOff(player)
		local tier = player:GetAttribute("Treadmill")
		player:SetAttribute("Treadmill", nil)
		player:SetAttribute("Training", nil)
		leftAt[player] = os.clock()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
			local info = tier and Map.padInfo(tier)
			if info then
				placeOn(character, info.Exit)
			end
		end
	end
	local leaveRemote = Instance.new("RemoteEvent")
	leaveRemote.Name = "LeaveTreadmill" -- client -> server: steered off the treadmill
	leaveRemote.Parent = remotes
	leaveRemote.OnServerEvent:Connect(function(player)
		if player:GetAttribute("Treadmill") then
			getOff(player)
		end
	end)
	-- getting on (checked often, so it feels instant)
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not data or not root then
					continue
				end
				local tier = Map.padAt(root.Position)
				local locked = player:GetAttribute("Treadmill")
				if locked then
					if tier ~= locked or not root.Anchored then
						-- respawned or moved away some other way
						player:SetAttribute("Treadmill", nil)
						player:SetAttribute("Training", nil)
					end
					continue
				end
				local pad = tier and Config.Training.Pads[tier]
				if not pad or os.clock() - (leftAt[player] or 0) < 1 then
					continue
				end
				local info = Map.padInfo(tier)
				if canUsePad(data, pad) then
					placeOn(character, info.Lock)
					root.Anchored = true
					player:SetAttribute("Treadmill", tier)
					player:SetAttribute("Training", tier)
				else
					placeOn(character, info.Exit)
					leftAt[player] = os.clock()
					if os.clock() - (lastPadWarn[player] or 0) > 2 then
						lastPadWarn[player] = os.clock()
						if pad.Pass then
							-- the Golden Treadmill: say so, and offer the pass
							NoticeRemote:FireClient(player, { Kind = "PadNeedsPass", Name = pad.Name, Pass = pad.Pass })
							if Config.GamePasses[pad.Pass].Id ~= 0 then
								Store.buyPass(player, pad.Pass) -- Roblox's "buy this pass?" box (until then the client opens the Shop)
							end
						else
							NoticeRemote:FireClient(player, { Kind = "PadLocked", Name = pad.Name, Rebirths = pad.Rebirths })
						end
					end
				end
			end
		end
	end)
	-- training
	task.spawn(function()
		local tick = Config.Training.Tick
		while true do
			task.wait(tick)
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				local tier = player:GetAttribute("Treadmill")
				if data and tier then
					addHorsepower(player, data, Game.trainRate(data, tier) * tick)
				end
			end
		end
	end)
end

return Game

