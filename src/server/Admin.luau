-- Admins (Config.Admin): the Admin Panel's tools, the [DEV] chat tag and "An admin has joined".
--   Global messages, Admin Abuse (any mix of boosts, for a set time, now or scheduled),
--   the owner's Requests list, teleports (go to a stage or a player; the owner can also bring
--   and kick), each admin's own ALL PASSES switch, and their saved Favorites.
-- The server checks every action. The owner's messages and abuses go out at once; other
-- admins' go to the owner's Requests list (saved, so it reaches the owner in any server).
-- Messages and abuses reach every server through MessagingService; abuses are also saved, so
-- a server that opens mid-abuse picks them up. In Studio everyone counts as the owner, and
-- nothing is sent to or saved for the live game.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)

local Admin = {}

local A = Config.Admin
local TOPIC_ANNOUNCE = "AdminAnnounce"
local TOPIC_EVENTS = "AdminEvents"
local TOPIC_REQUESTS = "AdminRequests"
local MAX_REQUESTS = 30
local MAX_DELAY = 24 * 60 -- an abuse can be scheduled up to a day ahead (minutes)
local MAX_FAVORITES = 30
local MAX_FEEDBACK = 300 -- the newest ones kept
local FEEDBACK_LENGTH = 300 -- characters per message
local FEEDBACK_GAP = 60 -- seconds between one player's messages
local FEEDBACK_PER_VISIT = 5
local FEEDBACK_KINDS = { Bug = true, Idea = true, Other = true }

local store
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "AdminPanel")
	store = ok and result or nil
end
-- player feedback from Settings. In Studio it's kept in memory only, so tests never reach the real list.
local feedbackStore
if not RunService:IsStudio() then
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "Feedback")
	feedbackStore = ok and result or nil
end
local studioFeedback = {}
local feedbackSent = {} -- [player] = { Count, Last }

local announceRemote -- server -> all clients: { Name, Text }
local requestsChanged -- server -> owner clients: refresh the Requests list
local notice
local hooks = { publish = function() end, moveTo = function() end }

function Admin.isOwner(player)
	return player.UserId == A.Owner or RunService:IsStudio()
end

function Admin.isAdmin(player)
	return Admin.isOwner(player) or table.find(A.Admins, player.UserId) ~= nil
end

local function eventInfo(key)
	for _, e in A.Events do
		if e.Key == key then
			return e
		end
	end
	return nil
end

local function namesOf(keys)
	local names = {}
	for _, key in keys do
		table.insert(names, eventInfo(key).Name)
	end
	return table.concat(names, " + ")
end

---------------------------------------------------------------- Admin Abuse
-- events[key] = { Start = os.time(), End = os.time() }; it boosts while Start <= now < End.
-- Workspace attributes Event_<Key> (end) and EventStart_<Key> (start) let clients count down.
local events = {}

local function showEvents()
	for _, e in A.Events do
		local ev = events[e.Key]
		local live = ev and ev.End > os.time()
		workspace:SetAttribute("Event_" .. e.Key, if live then ev.End else nil)
		workspace:SetAttribute("EventStart_" .. e.Key, if live then ev.Start else nil)
	end
end

-- 2 while that Admin Abuse boost is running, else 1
function Admin.eventMultiplier(key)
	local ev = events[key]
	local now = os.time()
	return if ev and ev.Start <= now and now < ev.End then 2 else 1
end

local function saveEvents()
	if store and not RunService:IsStudio() then -- a Studio test never switches abuses on in the live game
		pcall(store.SetAsync, store, "Events", events)
	end
end

local function broadcast(topic, message, fallback)
	-- a Studio test only talks to itself, never to live servers
	local ok = not RunService:IsStudio() and pcall(MessagingService.PublishAsync, MessagingService, topic, message)
	if not ok and fallback then
		fallback(message) -- MessagingService unavailable (some Studio tests): this server only
	end
end

local function applyEvents(message)
	if type(message) ~= "table" then
		return
	end
	events = {}
	for key, ev in message do
		if eventInfo(key) and type(ev) == "table" and type(ev.Start) == "number" and type(ev.End) == "number" then
			events[key] = { Start = ev.Start, End = ev.End }
		end
	end
	showEvents()
end

local function shareEvents()
	showEvents()
	saveEvents()
	task.spawn(broadcast, TOPIC_EVENTS, events, applyEvents)
end

---------------------------------------------------------------- messages
local function deliverAnnouncement(message)
	if type(message) == "table" and type(message.Text) == "string" then
		announceRemote:FireAllClients({ Name = tostring(message.Name), Text = message.Text })
	end
end

local function sendAnnouncement(name, text)
	task.spawn(broadcast, TOPIC_ANNOUNCE, { Name = name, Text = text }, deliverAnnouncement)
end

local function startAbuse(keys, minutes, delay, announce, name)
	local start = os.time() + delay * 60
	for _, key in keys do
		events[key] = { Start = start, End = start + minutes * 60 }
	end
	shareEvents()
	if announce then
		local when = if delay > 0 then `starts in {delay} min` else "is ON"
		sendAnnouncement(name, `ADMIN ABUSE {when}! {namesOf(keys)} for {minutes} min!`)
	end
end

-- Roblox's text filter for something everyone will see (nil if it can't be checked)
local function filter(player, text)
	local ok, result = pcall(TextService.FilterStringAsync, TextService, text, player.UserId)
	if not ok then
		return nil
	end
	local ok2, clean = pcall(result.GetNonChatStringForBroadcastAsync, result)
	return if ok2 then clean else nil
end

---------------------------------------------------------------- the owner's request list
local function readRequests()
	if not store then
		return {}
	end
	local ok, list = pcall(store.GetAsync, store, "Requests")
	return if ok and type(list) == "table" then list else {}
end

local function tellOwners()
	for _, p in Players:GetPlayers() do
		if Admin.isOwner(p) then
			requestsChanged:FireClient(p)
		end
	end
end

-- change the saved list; edit(list) returns what to hand back
local function editRequests(edit)
	if not store then
		return nil
	end
	local out
	local ok = pcall(store.UpdateAsync, store, "Requests", function(list)
		list = if type(list) == "table" then list else {}
		out = edit(list)
		return list
	end)
	if ok then
		task.spawn(broadcast, TOPIC_REQUESTS, true, tellOwners)
	end
	return if ok then out else nil
end

local function addRequest(player, request)
	request.Id = HttpService:GenerateGUID(false)
	request.From = player.DisplayName
	request.FromId = player.UserId
	request.Time = os.time()
	return editRequests(function(list)
		table.insert(list, request)
		while #list > MAX_REQUESTS do
			table.remove(list, 1)
		end
		return true
	end)
end

local function takeRequest(id)
	return editRequests(function(list)
		for i, r in list do
			if r.Id == id then
				table.remove(list, i)
				return r
			end
		end
		return nil
	end)
end

---------------------------------------------------------------- player feedback
-- edit(list) changes the saved list and returns what to hand back
local function editFeedback(edit)
	if not feedbackStore then
		return edit(studioFeedback)
	end
	local out
	local ok = pcall(feedbackStore.UpdateAsync, feedbackStore, "List", function(list)
		list = if type(list) == "table" then list else {}
		out = edit(list)
		return list
	end)
	return if ok then out else nil
end

local function readFeedback()
	if not feedbackStore then
		return studioFeedback
	end
	local ok, list = pcall(feedbackStore.GetAsync, feedbackStore, "List")
	return if ok and type(list) == "table" then list else {}
end

local function sendFeedback(player, kind, message)
	if type(kind) ~= "string" or not FEEDBACK_KINDS[kind] or type(message) ~= "string" then
		return false, "Pick Bug, Idea or Other first"
	end
	message = message:gsub("^%s+", ""):gsub("%s+$", "")
	if #message < 3 then
		return false, "Write a little more first"
	end
	message = string.sub(message, 1, FEEDBACK_LENGTH)
	local sent = feedbackSent[player] or { Count = 0, Last = -math.huge }
	feedbackSent[player] = sent
	if sent.Count >= FEEDBACK_PER_VISIT then
		return false, "Thanks! That's all for this visit"
	end
	local wait = FEEDBACK_GAP - (os.clock() - sent.Last)
	if wait > 0 then
		return false, `You can send another in {math.ceil(wait)}s`
	end
	sent.Last = os.clock()
	sent.Count += 1
	local ok = editFeedback(function(list)
		table.insert(list, {
			Id = HttpService:GenerateGUID(false),
			Kind = kind,
			Text = message, -- filtered when the owner reads it
			From = player.Name,
			FromId = player.UserId,
			Time = os.time(),
		})
		while #list > MAX_FEEDBACK do
			table.remove(list, 1)
		end
		return true
	end)
	if not ok then
		sent.Count -= 1
		sent.Last = -math.huge
		return false, "Couldn't send it, try again soon"
	end
	print(`[Feedback] {kind} from {player.Name}`)
	return true, "Sent! Thanks for the feedback"
end

---------------------------------------------------------------- checking what the panel sends
local function wholeNumber(value, low, high)
	local n = tonumber(value)
	if not n or n ~= n then
		return nil
	end
	n = math.floor(n)
	return if n >= low and n <= high then n else nil
end

-- a list of known, different boost keys (nil if anything is wrong)
local function boostList(value)
	if type(value) ~= "table" or #value == 0 or #value > #A.Events then
		return nil
	end
	local keys = {}
	for _, key in value do
		if type(key) ~= "string" or not eventInfo(key) or table.find(keys, key) then
			return nil
		end
		table.insert(keys, key)
	end
	return keys
end

local function rootOf(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function playerById(userId)
	return type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
end

---------------------------------------------------------------- actions from the panel
local lastMessage = {} -- [player] = os.clock()

local actions = {}

function actions.Announce(player, text)
	if type(text) ~= "string" then
		return false, "Type a message first"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text == 0 then
		return false, "Type a message first"
	end
	if #text > A.MaxMessage then
		return false, `That's too long (max {A.MaxMessage} characters)`
	end
	if os.clock() - (lastMessage[player] or 0) < A.MessageGap then
		return false, "Slow down a little!"
	end
	lastMessage[player] = os.clock()
	local clean = filter(player, text)
	if not clean then
		return false, "Couldn't check that message, try again"
	end
	print(`[Admin] {player.Name} ({player.UserId}) {if Admin.isOwner(player) then "announced" else "asked to announce"}: {clean}`)
	if Admin.isOwner(player) then
		sendAnnouncement(player.DisplayName, clean)
		return true, "Sent to every server!"
	end
	if addRequest(player, { Kind = "Announce", Text = clean }) then
		return true, "Sent to the owner for approval!"
	end
	return false, "Couldn't send it, try again"
end

-- boosts: list of keys; minutes: how long; delay: minutes until it starts (0 = now)
function actions.StartAbuse(player, boosts, minutesValue, delayValue, announce)
	local keys = boostList(boosts)
	if not keys then
		return false, "Pick at least one boost"
	end
	local minutes = wholeNumber(minutesValue, 1, A.MaxEventMinutes)
	if not minutes then
		return false, `How long? (1 to {A.MaxEventMinutes} min)`
	end
	local delay = wholeNumber(delayValue or 0, 0, MAX_DELAY)
	if not delay then
		return false, "When should it start?"
	end
	announce = announce == true
	print(`[Admin] {player.Name} ({player.UserId}) {if Admin.isOwner(player) then "started" else "asked for"} {namesOf(keys)} for {minutes} min, in {delay} min`)
	if Admin.isOwner(player) then
		startAbuse(keys, minutes, delay, announce, player.DisplayName)
		return true, if delay > 0 then `Scheduled: starts in {delay} min everywhere!` else `ADMIN ABUSE is on everywhere for {minutes} min!`
	end
	if addRequest(player, { Kind = "Abuse", Events = keys, Minutes = minutes, Delay = delay, Announce = announce }) then
		return true, "Sent to the owner for approval!"
	end
	return false, "Couldn't send it, try again"
end

function actions.StopAbuse(player)
	if not Admin.isOwner(player) then
		return false, "Only the owner can stop it"
	end
	print(`[Admin] {player.Name} stopped every Admin Abuse`)
	events = {}
	shareEvents()
	return true, "Stopped everywhere"
end

function actions.ListRequests(player)
	if not Admin.isOwner(player) then
		return false, "Owner only"
	end
	return true, readRequests()
end

function actions.Accept(player, id)
	if not Admin.isOwner(player) or type(id) ~= "string" then
		return false, "Owner only"
	end
	local r = takeRequest(id)
	if not r then
		return false, "That request is gone"
	end
	print(`[Admin] {player.Name} accepted {r.Kind} from {r.From}`)
	if r.Kind == "Announce" then
		sendAnnouncement(r.From, r.Text) -- already filtered when it was sent
		return true, "Sent to every server!"
	elseif r.Kind == "Abuse" then
		local keys = boostList(r.Events)
		local minutes = wholeNumber(r.Minutes, 1, A.MaxEventMinutes)
		if keys and minutes then
			-- a scheduled one keeps its time from when it was asked for, if that's still ahead
			local delay = math.max(0, math.ceil(((r.Time or os.time()) + (r.Delay or 0) * 60 - os.time()) / 60))
			startAbuse(keys, minutes, delay, r.Announce == true, r.From)
			return true, "ADMIN ABUSE accepted!"
		end
	end
	return false, "That request couldn't be used"
end

function actions.Decline(player, id)
	if not Admin.isOwner(player) or type(id) ~= "string" then
		return false, "Owner only"
	end
	local r = takeRequest(id)
	print(`[Admin] {player.Name} declined a request{if r then " from " .. r.From else ""}`)
	return true, "Declined"
end

-- the newest 50, filtered for the owner to read
function actions.ListFeedback(player)
	if not Admin.isOwner(player) then
		return false, "Owner only"
	end
	local list = readFeedback()
	local out = {}
	for i = #list, math.max(1, #list - 49), -1 do
		local f = list[i]
		local text = f.Text
		local ok, result = pcall(TextService.FilterStringAsync, TextService, f.Text, f.FromId or player.UserId)
		if ok then
			local ok2, clean = pcall(result.GetNonChatStringForUserAsync, result, player.UserId)
			text = if ok2 then clean else "(couldn't be checked)"
		else
			text = "(couldn't be checked)"
		end
		table.insert(out, { Id = f.Id, Kind = f.Kind, Text = text, From = f.From, Time = f.Time })
	end
	return true, out
end

function actions.DoneFeedback(player, id)
	if not Admin.isOwner(player) or type(id) ~= "string" then
		return false, "Owner only"
	end
	local found = editFeedback(function(list)
		for i, f in list do
			if f.Id == id then
				table.remove(list, i)
				return true
			end
		end
		return false
	end)
	return true, if found then "Done" else "Already gone"
end

function actions.SetAllPasses(player, on)
	local data = Data.get(player)
	if not data then
		return false, "Your save isn't loaded yet"
	end
	data.AllPasses = on == true
	print(`[Admin] {player.Name} turned ALL PASSES {if data.AllPasses then "on" else "off"}`)
	hooks.publish(player, data)
	return true, if data.AllPasses then "All passes on" else "All passes off"
end

-- where: "Lobby", "Finish" or a stage number
function actions.GoStage(player, where)
	if player:GetAttribute("Treadmill") then
		return false, "Get off the treadmill first"
	end
	local course = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Course")
	local cframe
	if where == "Lobby" then
		local spawn = workspace.Map:FindFirstChild("Spawn")
		cframe = spawn and CFrame.new(spawn.Position + Vector3.new(0, 4, 0))
	elseif where == "Finish" then
		local finish = course and course:FindFirstChild("Finish")
		cframe = finish and finish:GetPivot() + Vector3.new(0, 6, 0)
	else
		local stage = wholeNumber(where, 1, #Config.Stages.RequiredLevel)
		local model = stage and course and course:FindFirstChild("Stage" .. stage)
		local start = model and model:GetAttribute("Start")
		cframe = start and start + Vector3.new(0, 4, 0)
	end
	if not cframe then
		return false, "Couldn't find that place"
	end
	print(`[Admin] {player.Name} teleported to {where}`)
	hooks.moveTo(player, cframe)
	return true, "Teleported!"
end

function actions.GoTo(player, userId)
	local target = playerById(userId)
	local root = rootOf(target)
	if not root or target == player then
		return false, "They're not here"
	end
	if player:GetAttribute("Treadmill") then
		return false, "Get off the treadmill first"
	end
	print(`[Admin] {player.Name} went to {target.Name}`)
	hooks.moveTo(player, root.CFrame * CFrame.new(0, 0, 6))
	return true, `Went to {target.DisplayName}`
end

function actions.Bring(player, userId)
	if not Admin.isOwner(player) then
		return false, "Only the owner can bring players"
	end
	local target = playerById(userId)
	local root = rootOf(player)
	if not target or target == player or not root then
		return false, "They're not here"
	end
	if target:GetAttribute("Treadmill") then
		return false, "They're on a treadmill"
	end
	print(`[Admin] {player.Name} brought {target.Name}`)
	hooks.moveTo(target, root.CFrame * CFrame.new(0, 0, -6))
	return true, `Brought {target.DisplayName}`
end

function actions.Kick(player, userId)
	if not Admin.isOwner(player) then
		return false, "Only the owner can kick"
	end
	local target = playerById(userId)
	if not target or target == player then
		return false, "They're not here"
	end
	if target.UserId == A.Owner then
		return false, "The owner can't be kicked"
	end
	print(`[Admin] {player.Name} kicked {target.Name} ({target.UserId})`)
	target:Kick("You were kicked by an admin.")
	return true, `Kicked {target.DisplayName}`
end

function actions.GetFavorites(player)
	local data = Data.get(player)
	return true, if data then data.AdminFavorites else {}
end

function actions.SetFavorites(player, list)
	local data = Data.get(player)
	if not data or type(list) ~= "table" then
		return false, "Couldn't save that"
	end
	local clean = {}
	for _, id in list do
		if type(id) == "string" and #id <= 40 and #clean < MAX_FAVORITES and not table.find(clean, id) then
			table.insert(clean, id)
		end
	end
	data.AdminFavorites = clean
	return true, "Saved"
end

---------------------------------------------------------------- start
-- moreHooks.publish(player, data) republishes a player's values (after ALL PASSES changes);
-- moreHooks.moveTo(player, cframe) teleports a player
function Admin.start(remotes, noticeRemote, moreHooks)
	notice = noticeRemote
	hooks.publish = moreHooks.publish or hooks.publish
	hooks.moveTo = moreHooks.moveTo or hooks.moveTo
	workspace:SetAttribute("ServerStart", os.time())
	workspace:SetAttribute("ServerType", if RunService:IsStudio() then "STUDIO" elseif game.PrivateServerId ~= "" then "PRIVATE" else "PUBLIC")
	announceRemote = Instance.new("RemoteEvent")
	announceRemote.Name = "Announcement"
	announceRemote.Parent = remotes
	requestsChanged = Instance.new("RemoteEvent")
	requestsChanged.Name = "RequestsChanged"
	requestsChanged.Parent = remotes
	local adminRemote = Instance.new("RemoteFunction")
	adminRemote.Name = "Admin" -- client -> server: (action, ...) -> ok, result
	adminRemote.Parent = remotes
	adminRemote.OnServerInvoke = function(player, action, ...)
		local handler = type(action) == "string" and actions[action]
		if not handler or not Admin.isAdmin(player) then
			return false, "Not allowed"
		end
		return handler(player, ...)
	end
	local feedbackRemote = Instance.new("RemoteFunction")
	feedbackRemote.Name = "SendFeedback" -- anyone: (kind, message) -> ok, message
	feedbackRemote.Parent = remotes
	feedbackRemote.OnServerInvoke = sendFeedback

	-- other servers' messages, abuses and requests (in the background: subscribing can take a
	-- few seconds, and the rest of the game shouldn't wait for it)
	task.spawn(function()
		pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC_ANNOUNCE, function(m)
			deliverAnnouncement(m.Data)
		end)
		pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC_EVENTS, function(m)
			applyEvents(m.Data)
		end)
		pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC_REQUESTS, tellOwners)
	end)
	-- abuses already running (or scheduled) when this server opened
	task.spawn(function()
		if store and not RunService:IsStudio() then
			local ok, saved = pcall(store.GetAsync, store, "Events")
			if ok then
				applyEvents(saved)
			end
		end
	end)
	-- finished abuses drop off by themselves
	task.spawn(function()
		while true do
			task.wait(1)
			local changed = false
			for key, ev in events do
				if ev.End <= os.time() then
					events[key] = nil
					changed = true
				end
			end
			if changed then
				showEvents()
			end
		end
	end)

	-- admins: the [DEV] tag, "An admin has joined", and ALL PASSES only while they're one
	local function onJoin(player)
		if not Admin.isAdmin(player) then
			return
		end
		player:SetAttribute("Admin", true)
		player:SetAttribute("Owner", Admin.isOwner(player) or nil)
		player:SetAttribute("Dev", true)
		notice:FireAllClients({ Kind = "AdminJoined", Name = player.DisplayName })
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastMessage[player] = nil
		feedbackSent[player] = nil
	end)
	Data.onLoaded(function(player, data)
		if data.AllPasses and not Admin.isAdmin(player) then
			data.AllPasses = false -- no longer an admin
			hooks.publish(player, data)
		end
	end)
end

return Admin
