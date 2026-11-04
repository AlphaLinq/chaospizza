--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Config.Products)
local ReceiptLedger = require(ReplicatedStorage.Shared.Util.ReceiptLedger)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local MonetizationService = {}
local handlers: { [string]: (Player) -> boolean } = {}
local passCache: { [Player]: { [string]: boolean } } = {}
local callbacks: { (Player, string, boolean) -> () } = {}
local warned: { [number]: boolean } = {}

function MonetizationService.registerProduct(key: string, handler: (Player) -> boolean)
	local found = false
	for _, product in Products.Products do
		if product.key == key then
			found = true
			break
		end
	end
	assert(found, `Unknown product key {key}`)
	assert(handlers[key] == nil, `Product {key} already registered`)
	-- Handler runs synchronously inside DataService.transaction. Only mutate
	-- this player's profile through DataService.update; false/error rolls back.
	-- Disaster effects must use a persistent outbox before enabling real IDs.
	handlers[key] = handler
end
function MonetizationService.ownsPass(player: Player, key: string): boolean
	local id = 0
	for _, pass in Products.Gamepasses do
		if pass.key == key then
			id = pass.gamepassId
			break
		end
	end
	if id <= 0 then
		return false
	end
	local cached = passCache[player]
	if cached and cached[key] ~= nil then
		return cached[key]
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if not ok or player.Parent ~= Players then
		return false
	end
	cached = passCache[player] or {}
	-- A purchase callback may have completed while the ownership query yielded.
	cached[key] = cached[key] == true or owned == true
	passCache[player] = cached
	return cached[key]
end
function MonetizationService.onPassChanged(callback: (Player, string, boolean) -> ()): () -> ()
	table.insert(callbacks, callback)
	return function()
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end
local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.isLoaded(player) or not DataService.isPersistent() then
		return pending
	end
	local key: string? = nil
	for _, product in Products.Products do
		if product.productId > 0 and product.productId == receipt.ProductId then
			key = product.key
			break
		end
	end
	if not key then
		if not warned[receipt.ProductId] then
			warned[receipt.ProductId] = true
			warn(
				`[MonetizationService] Unknown product {receipt.ProductId}; receipt remains pending`
			)
		end
		return pending
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return pending
	end
	if ReceiptLedger.contains(profile.purchases, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local handler = handlers[key]
	if not handler then
		return pending
	end
	local saved = DataService.transaction(player, function(draft)
		return ReceiptLedger.apply(draft.purchases, receipt.PurchaseId, os.time(), function()
			return handler(player)
		end)
	end, true)
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else pending
end
function MonetizationService.init()
	DebugService.register(
		"passes",
		"Check configured gamepass ownership",
		"passes",
		function(player)
			local values = {}
			for _, pass in Products.Gamepasses do
				table.insert(values, `{pass.key}={MonetizationService.ownsPass(player, pass.key)}`)
			end
			return true, table.concat(values, ", ")
		end
	)
end
function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player, gamepassId, purchased)
			if not purchased or player.Parent ~= Players then
				return
			end
			for _, pass in Products.Gamepasses do
				if pass.gamepassId > 0 and pass.gamepassId == gamepassId then
					local cached = passCache[player] or {}
					local changed = cached[pass.key] ~= true
					cached[pass.key] = true
					passCache[player] = cached
					if changed then
						for _, callback in table.clone(callbacks) do
							task.spawn(callback, player, pass.key, true)
						end
					end
					break
				end
			end
		end
	)
	Players.PlayerRemoving:Connect(function(player)
		passCache[player] = nil
	end)
end
return MonetizationService
