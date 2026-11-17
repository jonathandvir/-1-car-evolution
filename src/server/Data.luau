-- Loads, holds and saves each player's progress, with session locking so two
-- servers never overwrite each other. Clients see values through Player attributes.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 45
local LOCK_STALE_SECONDS = 120 -- autosaves refresh a lock every 45 seconds, so 120 means its server is gone
local SESSION_ID = HttpService:GenerateGUID(false)

local Data = {}
local profiles = {} -- [player] = { Data, CanSave, Released }
local loadedCallbacks = {}

local store
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn(`DataStores unavailable, progress will not save: {result}`)
	end
end

local function defaults()
	return {
		Energy = 0, -- total Horsepower (never spent)
		Wins = 0,
		Level = 1, -- worked out from Horsepower (Config.levelFor)
		Rebirths = 0,
		NextGate = 1, -- the next gate they need to pass on that level
		BestLevel = 1,
		TotalClicks = 0,
		Equipment = {}, -- [equipment id] = how many owned
		Cars = 1, -- how many cars are unlocked (they unlock in order, Car 1 is free)
		EquippedCar = 1, -- the car the player drives (any unlocked one)
		Passes = {}, -- [pass key] = true for game passes owned (kept in case Roblox is slow to say)
		StarterGiven = false, -- has the Starter Pack been handed out
		Receipts = {}, -- the last developer product purchase ids handed out, so a retry never gives twice
		AllPasses = false, -- admins only: their ALL PASSES switch (every pass, free products)
		AdminFavorites = {}, -- admins only: the Admin Panel sections they starred
		DailyDay = 0, -- the streak day of the last daily reward claimed (1 to 7)
		DailyLast = -1, -- the UTC day number (os.time() // 86400) it was claimed on
		Boosts = {}, -- [DoubleWins / DoubleHorsepower] = os.time() a daily x2 boost runs until
		MusicVolume = 0.5, -- Settings: the music slider, 0 to 1 (0.5 is the normal level)
		EffectsVolume = 1, -- Settings: the sound effects slider, 0 to 1
		MusicMuted = false,
		EffectsMuted = false,
	}
end

local function reconcile(saved)
	local data = defaults()
	if type(saved) == "table" then
		for k, v in saved do
			if data[k] ~= nil and type(data[k]) == type(v) then
				data[k] = v
			end
		end
	end
	return data
end

local function key(player)
	return "Player_" .. player.UserId
end

local function load(player)
	if not store then
		return defaults(), false
	end
	-- Another server holding the save is usually just finishing its last save (seconds). One
	-- that crashed (or a Studio playtest that was stopped) never lets go, so keep trying until
	-- its lock goes stale and take it over, instead of giving up on a blank profile that
	-- can't save. In Studio only this playtest uses the save, so its lock is taken at once.
	local ignoreLocks = RunService:IsStudio()
	local failures = 0
	while player.Parent do
		local locked = false
		local ok, result = pcall(store.UpdateAsync, store, key(player), function(record)
			record = if type(record) == "table" then record else {}
			locked = not ignoreLocks and record.Session ~= nil and record.Session ~= SESSION_ID and os.time() - (record.SessionTime or 0) < LOCK_STALE_SECONDS
			if locked then
				return nil
			end
			record.Session = SESSION_ID
			record.SessionTime = os.time()
			return record
		end)
		if ok and not locked then
			return reconcile(result and result.Data), true
		end
		if not ok then
			failures += 1
			warn(`Loading {player.Name} failed (try {failures}): {result}`)
			if failures >= 6 then
				break -- DataStores are down: play on, but never save over real progress
			end
		end
		task.wait(if locked then 5 else failures)
	end
	return defaults(), false -- never save over real progress we couldn't load
end

local function save(player, profile, release)
	if not profile.CanSave or profile.Released then
		return false
	end
	if release then
		profile.Released = true
	end
	for attempt = 1, 3 do
		local lost = false
		local ok, err = pcall(store.UpdateAsync, store, key(player), function(record)
			record = if type(record) == "table" then record else {}
			lost = record.Session ~= nil and record.Session ~= SESSION_ID
			if lost then
				return nil
			end
			return { Data = profile.Data, Session = if release then nil else SESSION_ID, SessionTime = os.time() }
		end)
		if ok then
			if lost then
				profile.CanSave = false
			end
			return not lost
		end
		warn(`Saving {player.Name} failed (try {attempt}): {err}`)
		task.wait(attempt)
	end
	return false
end

-- Pushes the saved values the client needs onto Player attributes
function Data.publish(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local d = profile.Data
	player:SetAttribute("Energy", d.Energy)
	player:SetAttribute("Wins", d.Wins)
	player:SetAttribute("Level", d.Level)
	player:SetAttribute("Rebirths", d.Rebirths)
	player:SetAttribute("NextGate", d.NextGate)
	player:SetAttribute("Cars", d.Cars)
	player:SetAttribute("EquippedCar", d.EquippedCar)
	player:SetAttribute("Equipment", HttpService:JSONEncode(d.Equipment))
	local passes = d.Passes
	if d.AllPasses then
		passes = {}
		for key in Config.GamePasses do
			passes[key] = true
		end
	end
	player:SetAttribute("Passes", HttpService:JSONEncode(passes))
	player:SetAttribute("AllPasses", d.AllPasses or nil)
	player:SetAttribute("DailyDay", d.DailyDay)
	player:SetAttribute("DailyLast", d.DailyLast)
	player:SetAttribute("MusicVolume", d.MusicVolume)
	player:SetAttribute("EffectsVolume", d.EffectsVolume)
	player:SetAttribute("MusicMuted", d.MusicMuted)
	player:SetAttribute("EffectsMuted", d.EffectsMuted)
	for _, key in { "DoubleWins", "DoubleHorsepower" } do
		local untilTime = d.Boosts[key]
		if untilTime and untilTime <= os.time() then
			d.Boosts[key] = nil -- run out
			untilTime = nil
		end
		player:SetAttribute("Boost_" .. key, untilTime)
	end
end

-- 2 while that daily x2 boost (DoubleWins or DoubleHorsepower) is running, else 1
function Data.boostMultiplier(data, key)
	local untilTime = data.Boosts[key]
	return if untilTime and untilTime > os.time() then 2 else 1
end

function Data.get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Saves straight away (after a purchase). True once the save is safely stored; in Studio
-- without DataStore access (or a profile that can't save) it never is.
function Data.saveNow(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not store or not profile.CanSave then
		return RunService:IsStudio() -- a Studio test without DataStores: nothing to protect
	end
	return save(player, profile, false)
end

function Data.onLoaded(callback)
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

local function onJoin(player)
	local data, canSave = load(player)
	if not player.Parent then
		if canSave then
			save(player, { Data = data, CanSave = true }, true)
		end
		return
	end
	profiles[player] = { Data = data, CanSave = canSave }
	Data.publish(player)
	player:SetAttribute("Loaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

function Data.start()
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			save(player, profile, true)
			profiles[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, profile in profiles do
				task.spawn(save, player, profile, false)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1)
		end
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				save(player, profile, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait()
		end
	end)
end

return Data

