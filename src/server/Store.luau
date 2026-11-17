-- The Robux store: game passes and developer products (Config.GamePasses / Config.Products).
-- Owned passes are saved in data.Passes, so a pass Roblox is slow to report after a rejoin
-- still works. Developer products go through ProcessReceipt the safe way: hand out, save,
-- then confirm, with each purchase id remembered in the save so a retry never gives twice.
-- While an Id is 0 (not made on the dashboard yet), buying is free in Studio for testing and
-- does nothing in a live game.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)

local Store = {}

local KEEP_RECEIPTS = 50
local handlers = {} -- [product key] = function(player, data) hands it out
local checks = {} -- [product key] = function(player, data) -> true if it can be bought right now
local passCallbacks = {} -- function(player, data, key, isNew) when a pass is owned
local notice -- the Notice remote

-- does this save own the pass?
function Store.has(data, key)
	return data ~= nil and (data.AllPasses == true or data.Passes[key] == true)
end

function Store.owns(player, key)
	return Store.has(Data.get(player), key)
end

function Store.onProduct(key, handler, check)
	handlers[key] = handler
	checks[key] = check
end

function Store.onPass(callback)
	table.insert(passCallbacks, callback)
end

local function keyFor(list, id)
	for key, item in list do
		if item.Id ~= 0 and item.Id == id then
			return key
		end
	end
	return nil
end

local function grantPass(player, key)
	local data = Data.get(player)
	if not data or not Config.GamePasses[key] then
		return
	end
	local isNew = data.Passes[key] ~= true
	data.Passes[key] = true
	Data.publish(player)
	for _, callback in passCallbacks do
		task.spawn(callback, player, data, key, isNew)
	end
	if isNew then
		notice:FireClient(player, { Kind = "PassOwned", Key = key })
	end
end

local function giveProduct(player, data, key)
	local handler = handlers[key]
	if not handler then
		return false
	end
	local ok, err = pcall(handler, player, data)
	if not ok then
		warn(`Handing out {key} to {player.Name} failed: {err}`)
		return false
	end
	notice:FireClient(player, { Kind = "ProductGiven", Key = key })
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again when they're back
	end
	local id = tostring(receipt.PurchaseId)
	if not table.find(data.Receipts, id) then
		local key = keyFor(Config.Products, receipt.ProductId)
		if not key or not giveProduct(player, data, key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(data.Receipts, id)
		while #data.Receipts > KEEP_RECEIPTS do
			table.remove(data.Receipts, 1)
		end
	end
	-- only confirm once what they got is saved; if the save fails, Roblox asks again and
	-- the remembered purchase id stops it being handed out twice
	if Data.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- client asked to buy a pass
function Store.buyPass(player, key)
	local pass = Config.GamePasses[key]
	if not pass or Store.owns(player, key) then
		return
	end
	if pass.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	elseif RunService:IsStudio() then
		grantPass(player, key) -- not made yet: free while testing in Studio
	end
end

-- client asked to buy a developer product
function Store.buyProduct(player, key)
	local product = Config.Products[key]
	local data = Data.get(player)
	if not product or not data then
		return
	end
	if checks[key] and not checks[key](player, data) then
		return
	end
	if data.AllPasses then
		giveProduct(player, data, key) -- an admin with ALL PASSES on: products are free
		return
	end
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif RunService:IsStudio() then
		giveProduct(player, data, key) -- not made yet: free while testing in Studio
	end
end

-- passes bought before this visit (or in another game server)
local function checkOwnedPasses(player, data)
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 and not data.Passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
	-- run the pass hooks for passes saved from before (Starter Pack, VIP tag...)
	for key in data.Passes do
		for _, callback in passCallbacks do
			task.spawn(callback, player, data, key, false)
		end
	end
end

function Store.start(remotes, noticeRemote)
	notice = noticeRemote
	local purchase = Instance.new("RemoteEvent")
	purchase.Name = "Purchase" -- client -> server: ("Pass" | "Product", key)
	purchase.Parent = remotes
	local lastAsk = {}
	purchase.OnServerEvent:Connect(function(player, kind, key)
		if type(key) ~= "string" or os.clock() - (lastAsk[player] or 0) < 0.5 then
			return
		end
		lastAsk[player] = os.clock()
		if kind == "Pass" then
			Store.buyPass(player, key)
		elseif kind == "Product" then
			Store.buyProduct(player, key)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = purchased and keyFor(Config.GamePasses, passId)
		if key then
			grantPass(player, key)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	Data.onLoaded(checkOwnedPasses)
end

return Store
