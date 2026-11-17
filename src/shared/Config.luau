-- Every number in the game lives here, so balancing never means touching logic.
local Config = {}

Config.Energy = {
	BasePerClick = 1,
	MaxClicksPerSecond = 20, -- the server ignores clicks above this (auto-clicker cap)
	PassiveTick = 1, -- seconds between farm payouts
	CritChance = 0.04, -- chance each click is a Critical
	CritMultiplier = 10, -- a Critical click is worth this many clicks
}

-- The course: each level is a row of gates. Costs grow along the row and with each level.
Config.Course = {
	GatesPerLevel = 10,
	GateSpacing = 44, -- studs between gates
	FirstGateCost = 10,
	GateGrowth = 1.55, -- each gate costs this much more than the one before
	LevelGrowth = 6, -- each new level's gates cost this much more
	GateWinsBase = 1, -- Wins for passing a gate: (base + index) x level
	LevelWinsBonus = 10, -- extra Wins for reaching the finish, x level
	MaxLevel = 15,
}

function Config.gateCost(level, gate)
	local c = Config.Course
	return math.floor(c.FirstGateCost * c.GateGrowth ^ (gate - 1) * c.LevelGrowth ^ (level - 1))
end

function Config.gateWins(level, gate)
	return (Config.Course.GateWinsBase + gate - 1) * level
end

function Config.levelWins(level)
	return Config.Course.LevelWinsBonus * level
end

-- Equipment: bought with Wins and shown on your farm. Each can be bought several times.
-- PerClick adds to Energy per click; Passive is Energy per second from the farm.
Config.Equipment = {
	{ Id = "SolarBasic", Name = "Basic Solar Panel", Price = 10, PerClick = 1, Passive = 1, Max = 5, Color = Color3.fromRGB(70, 140, 255) },
	{ Id = "SolarAdvanced", Name = "Advanced Solar Panel", Price = 80, PerClick = 5, Passive = 2, Max = 5, Color = Color3.fromRGB(40, 220, 255) },
	{ Id = "Wind", Name = "Wind Turbine", Price = 500, PerClick = 25, Passive = 10, Max = 5, Color = Color3.fromRGB(235, 245, 255) },
	{ Id = "WindAdvanced", Name = "Advanced Wind Turbine", Price = 3000, PerClick = 120, Passive = 50, Max = 5, Color = Color3.fromRGB(120, 255, 170) },
	{ Id = "Nuclear", Name = "Nuclear Generator", Price = 20000, PerClick = 700, Passive = 300, Max = 5, Color = Color3.fromRGB(150, 255, 60) },
	{ Id = "Fusion", Name = "Fusion Reactor", Price = 150000, PerClick = 5000, Passive = 2000, Max = 5, Color = Color3.fromRGB(255, 80, 230) },
}
Config.PriceGrowth = 1.6 -- each extra copy of the same equipment costs this much more

function Config.equipment(id)
	for _, item in Config.Equipment do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Config.equipmentPrice(item, owned)
	return math.floor(item.Price * Config.PriceGrowth ^ owned)
end

Config.Plots = 6

-- The 15 stages out over the valley (built by Server.Course). Each starts with a
-- see-through wall showing the level it needs. Levels are placeholders until we balance them.
-- Levels come from your total Horsepower (it's never spent). Going from level L to L + 1
-- takes First x Growth^(L - 1) Horsepower, so each level needs 24% more than the last.
Config.Levels = {
	First = 15,
	Growth = 1.24,
	Max = 200,
}

-- total Horsepower needed to be at a level
function Config.levelNeed(level)
	if level <= 1 then
		return 0
	end
	local L = Config.Levels
	return math.floor(L.First * (L.Growth ^ (level - 1) - 1) / (L.Growth - 1) + 1e-6)
end

-- the level a Horsepower total puts you at
function Config.levelFor(horsepower)
	local level = 1
	while level < Config.Levels.Max and Config.levelNeed(level + 1) <= horsepower do
		level += 1
	end
	return level
end

-- Rebirths: your level stops at a cap (10 at first, +10 for each rebirth). At the cap you
-- can rebirth: Horsepower goes back to 0, the cap rises and your Horsepower boost grows.
-- Boosts[r + 1] is the boost with r rebirths.
Config.Rebirths = {
	Max = 10,
	CapStep = 10,
	Boosts = { 1, 1.25, 2, 4, 6, 8, 12, 16, 24, 32, 50 },
}

function Config.levelCap(rebirths)
	return Config.Rebirths.CapStep * (rebirths + 1)
end

function Config.rebirthBoost(rebirths)
	local boosts = Config.Rebirths.Boosts
	return boosts[rebirths + 1] or boosts[#boosts]
end

-- Treadmills in the lobby: stand on one to gain Horsepower every Tick seconds.
-- Gain per second = PerSecond x the treadmill's Boost x your car's Boost.
Config.Training = {
	Tick = 0.5,
	PerSecond = 2,
	Pads = {
		{ Name = "Starter", Boost = 1, Rebirths = 0 },
		{ Name = "Turbo", Boost = 2.5, Rebirths = 1 },
		{ Name = "Nitro", Boost = 5, Rebirths = 3 },
		{ Name = "Rocket", Boost = 10, Rebirths = 5 },
		{ Name = "Mega", Boost = 20, Rebirths = 7 },
		{ Name = "Ultra", Boost = 40, Rebirths = 10 },
		-- the paid one: needs the Golden Treadmill pass instead of rebirths
		{ Name = "Golden", Boost = 25, Rebirths = 0, Pass = "GoldenTreadmill" },
	},
	FastTraining = 2, -- the Fast Training pass multiplies treadmill Horsepower by this
}

Config.Stages = {
	-- the level each stage asks for; its "Horsepower Needed" is that level's Horsepower
	RequiredLevel = { 1, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42 },
}
Config.FallHeight = -60 -- below this, a player has fallen off and goes back to base

-- Robux store. Ids come from the Creator Dashboard; while an Id is 0 it isn't made yet: in
-- Studio buying it is free (for testing), in a live game its button does nothing.
-- Prices here are only shown until Roblox reports the real ones.
Config.GamePasses = {
	DoubleWins = { Id = 2089223491, Name = "x2 Wins", Price = 149, Text = "Double the Wins from every stage!" },
	DoubleHorsepower = { Id = 2089061455, Name = "x2 Horsepower", Price = 199, Text = "Double all the Horsepower you get!" },
	FastTraining = { Id = 2089373455, Name = "Fast Training", Price = 99, Text = "Treadmills give x2 Horsepower!" },
	StarterPack = { Id = 2089847452, Name = "Starter Pack", Price = 39, Text = "Go-Kart, 250 Wins and 15 min of Horsepower!" },
	Vip = { Id = 2087981490, Name = "VIP", Price = 299, Text = "VIP car, gold chat tag and +10% Horsepower!" },
	GoldenTreadmill = { Id = 2088983531, Name = "Golden Treadmill", Price = 149, Text = "A x25 treadmill, no rebirths needed!" },
}
Config.PassOrder = { "DoubleWins", "DoubleHorsepower", "FastTraining", "StarterPack", "Vip", "GoldenTreadmill" }

-- what the Starter Pack gives, once
Config.StarterPack = { Car = 2, Wins = 250, Minutes = 15 }
Config.VipBoost = 1.1 -- VIP pass: +10% Horsepower from everything

-- Developer products (bought again and again). Horsepower packs grow with your Horsepower
-- (see Config.packAmount), so they always help; the Robux price never changes.
Config.Products = {
	PackSmall = { Id = 3732423334, Name = "Small Horsepower Pack", Price = 29, Share = 0.5 },
	PackMedium = { Id = 3732423492, Name = "Medium Horsepower Pack", Price = 79, Share = 2 },
	PackBig = { Id = 3732423774, Name = "Big Horsepower Pack", Price = 199, Share = 8 },
	PackHuge = { Id = 3732423935, Name = "Huge Horsepower Pack", Price = 449, Share = 25 },
	Respawn = { Id = 3732424083, Name = "Respawn at Stage", Price = 9 }, -- after falling: back to the start of that stage
	SkipRebirth = { Id = 3732424231, Name = "Skip Rebirth", Price = 49 }, -- rebirth now, without the level
}
Config.PackOrder = { "PackSmall", "PackMedium", "PackBig", "PackHuge" }

-- Pack size steps up each time your Horsepower passes the next power of ten (100, 1K, 10K ...
-- into the billions): a pack gives its Share x that step, doubled with x2 Horsepower. At 1M
-- Horsepower the packs give 500K, 2M, 8M and 25M. Packs still stop at your max level.
Config.Packs = { MinStep = 100 }

function Config.packStep(horsepower)
	local step = Config.Packs.MinStep
	while step * 10 <= (horsepower or 0) do
		step *= 10
	end
	return step
end

function Config.packAmount(key, horsepower, doubled)
	local product = Config.Products[key]
	return math.floor((product and product.Share or 0) * Config.packStep(horsepower) * (if doubled then 2 else 1))
end

-- Walk speed: quick in the lobby so everything is close. Out on the stages your car drives
-- at Stages + your level (level 15 drives at 60), up to StagesMax.
Config.WalkSpeed = {
	Lobby = 50,
	Stages = 45,
	StagesMax = 90,
}

function Config.stageSpeed(level)
	return math.min(Config.WalkSpeed.Stages + level, Config.WalkSpeed.StagesMax)
end

-- What each stage's wall shows: "Recommended Level : RequiredLevel[N]" and
-- "Horsepower Needed: HorsepowerNeeded[N]". You can only build roads on a stage once
-- your Horsepower reaches its HorsepowerNeeded.
Config.Stages.HorsepowerNeeded = {}
for stage, level in Config.Stages.RequiredLevel do
	Config.Stages.HorsepowerNeeded[stage] = Config.levelNeed(level)
end
-- Each stage ends in a row of Wins pads. The first pays Wins[stage]; the others pay that
-- times their share (so stage 1's pads pay 3, 4, 6 and 8). Each pays once per run out
-- from the lobby.
Config.Stages.Wins = { 3, 6, 10, 16, 25, 40, 60, 90, 135, 200, 300, 450, 700, 1000, 1500 }
Config.Stages.WinsPads = { 1, 1.34, 2, 2.67 }

function Config.stagePadWins(stage, index)
	local base = Config.Stages.Wins[stage] or 0
	return math.floor(base * (Config.Stages.WinsPads[index] or 1) + 0.5)
end

-- Daily rewards (Server.Game): one gift a day along a 7-day streak, better each day, with a big
-- one on day 7; after day 7 it goes round again. New days start at midnight UTC, and missing
-- a day starts the streak again at day 1. First-pass numbers to tune in playtests.
--   Wins: that many times the Wins of the furthest stage your level is recommended for
--   Horsepower: that many minutes of training on your best treadmill
--   Boost: a personal x2 (DoubleWins or DoubleHorsepower) for Minutes; claiming more adds time
Config.Daily = {
	{ Wins = 5 },
	{ Horsepower = 5 },
	{ Boost = "DoubleHorsepower", Minutes = 15 },
	{ Wins = 10 },
	{ Horsepower = 10 },
	{ Boost = "DoubleWins", Minutes = 15 },
	{ Wins = 25, Horsepower = 20 },
}

function Config.dailyWins(day, level)
	local reward = Config.Daily[day]
	if not reward or not reward.Wins then
		return 0
	end
	local stage = 1
	for s, required in Config.Stages.RequiredLevel do
		if (level or 1) >= required then
			stage = math.max(stage, s)
		end
	end
	return reward.Wins * (Config.Stages.Wins[stage] or 1)
end

-- Horsepower cans lying on the stage platforms: driving over one gives Can x stage^Growth
-- Horsepower (times your boosts), and it comes back for you after Respawn seconds
Config.Cans = {
	Base = 6,
	Growth = 1.8,
	Respawn = 30,
	Chance = 0.6, -- chance each platform has one
}

function Config.canHorsepower(stage)
	return math.floor(Config.Cans.Base * stage ^ Config.Cans.Growth)
end

-- Roads: click or press Space to lay a tile of road in front of your car, toward where the
-- camera faces. Building is free, but a stage only lets you build once your Horsepower
-- reaches its "Horsepower Needed".
Config.Road = {
	TileLength = 6, -- studs each click adds
	TileWidth = 16, -- about two cars wide
	CurbWidth = 1.6, -- the raised yellow edges
	CurbHeight = 1, -- how far the edges stand above the road
	Meter = 100, -- studs of road each build can lay; refills once you're back on solid ground
	MaxTurn = 30, -- degrees a road can bend sideways from one tile to the next
	MaxSlope = 30, -- steepest up or down the road can go, in degrees
	LevelPitch = -18, -- the camera's usual downward tilt behind the car counts as "level"
	FlatZone = 9, -- within this many degrees of that keeps the road flat
	StartBehind = 4, -- a new road starts this far behind the car, so the car is already on it
	MaxBend = 12, -- degrees it can tilt up or down from one tile to the next
	MaxHeight = 60, -- roads level out instead of going above this...
	MinHeight = -6, -- ...or below this (the pits are at -10)
	Reach = 30, -- you keep extending your road while you're this close to its end
	MaxTiles = 80, -- each player's oldest tiles disappear past this
	PerSecond = 12, -- the server ignores build requests above this rate
	BuildEvery = 0.1, -- the client asks for a tile this often, so the tip moves 60 studs a second
}

-- Cars: unlocked one after another with Wins at the car stands. Car 1 is free.
-- Prices are placeholders until we balance them. The looks live in Shared.CarLooks.
Config.Cars = {
	Prices = { 0, 20, 75, 250, 800, 2500, 7500, 20000, 50000, 120000 },
	-- the equipped car multiplies the Horsepower you gain on the treadmills
	Boosts = { 1, 1.5, 2, 3, 5, 8, 12, 20, 35, 60, 12 },
	VipTier = 11, -- the VIP Cruiser: car 11, comes with the VIP pass instead of Wins
}


-- Admins: the panel (ADMIN button), the [DEV] chat tag and "An admin has joined" all go by
-- user ID (an ID never changes, a username can). The owner approves admins' requests.
Config.Admin = {
	Owner = 3633562079, -- nvmrylen
	Admins = {
		2221607880, -- Lionboygetyouroar
		2285211122, -- Littlewil16
		3633546969, -- quack_arcturus27
		6189384506, -- quack_oliver
	},
	MaxMessage = 150, -- characters in a global message
	MessageGap = 3, -- seconds between messages from one person
	MaxEventMinutes = 180,
	-- the Admin Abuse boosts (each doubles its thing everywhere while it runs)
	Events = {
		{ Key = "DoubleHorsepower", Name = "2x Horsepower" },
		{ Key = "DoubleWins", Name = "2x Wins" },
	},
}

return Config
