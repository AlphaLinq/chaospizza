--!strict
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Config.Products)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Progression).shop
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)
local CustomerOdds = require(ReplicatedStorage.Shared.Util.CustomerOdds)
local ReceiptLedger = require(ReplicatedStorage.Shared.Util.ReceiptLedger)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local Boosts = require(ReplicatedStorage.Shared.Util.Boosts).new(Products)
local MonetizationService = {}
local actions: { [string]: (Player, string) -> (boolean, string) } = {}
local productDefinitions: { [string]: any } = {}
local purchasing: { [Player]: { id: string, now: number } } = {}
local handlers: { [string]: (Player) -> boolean } = {}
local passCache: { [Player]: { [string]: boolean } } = {}
local callbacks: { (Player, string, boolean) -> () } = {}
local warned: { [number]: boolean } = {}
local joined: { [Player]: number } = {}
local prompting: { [Player]: boolean } = {}
local function blockedReason(player: Player): string?
	local profile = DataService.getProfile(player)
	if not profile then
		return "Your profile is still loading."
	end
	if player:GetAttribute("OnboardingStep") ~= "done" then
		return "Finish your first deliveries to unlock the shop."
	end
	if
		profile.sessions.count <= 1
		and os.clock() - (joined[player] or os.clock())
			< Tuning.Onboarding.noShopPromptsFirstSeconds
	then
		return "The shop opens after your first 3 minutes. Keep delivering!"
	end
	local city = ReplicatedStorage:FindFirstChild("CityState")
	if not city then
		return "The city is still loading."
	end
	local phase = city:GetAttribute("EventPhase")
	if phase == "warning" or phase == "buildUp" or phase == "active" then
		return "Chaos in progress! Shop when the streets settle."
	end
	return nil
end
function MonetizationService.getShop(player: Player): any
	local CustomerService = require(script.Parent.CustomerService)
	local profile, now = DataService.getProfile(player), os.time()
	local passes, products = Boosts.catalog(function(key)
		return MonetizationService.ownsPass(player, key)
	end, function(product)
		return product.productId > 0
			and handlers[product.key] ~= nil
			and DataService.isPersistent()
			and Boosts.canGrant(profile, product, now)
	end, function(product)
		if not product.changesOdds then
			return nil
		end
		if product.key == "MegaChaosNow" then
			return CustomerOdds.describe("mega", Rarities :: any, {})
		end
		local active = profile
			and product.effect
			and product.effect.boostKey
			and Boosts.isActive(profile.boosts, product.effect.boostKey, now)
		local multiplier = if active
			then 1
			else (if product.effect then product.effect.rarePlusMultiplier or 1 else 1)
		return CustomerService.describeOdds(player, { rarePlusMultiplier = multiplier })
	end)
	return {
		gamepasses = passes,
		products = products,
		blockedReason = blockedReason(player),
		secondsUntilAllowed = math.max(
			0,
			Tuning.Onboarding.noShopPromptsFirstSeconds
				- (os.clock() - (joined[player] or os.clock()))
		),
	}
end
function MonetizationService.requestPurchase(player: Player, rawKey: unknown): (boolean, string)
	local key = Validate.string(rawKey, ShopConfig.maxKeyLength)
	if not key then
		return false, "Choose a valid shop item."
	end
	local namespace, argument = string.match(key, "^(%a+)[:](.+)$")
	if namespace and argument and actions[namespace] then
		return actions[namespace](player, argument)
	end
	local definition, isPass = Boosts.find(key)
	if not definition then
		return false, "This item isn't in the shop."
	end
	local id = if isPass then definition.gamepassId else definition.productId
	if id <= 0 then
		return false, "This item isn't available yet."
	end
	if prompting[player] then
		return false, "Finish your current purchase first."
	end
	prompting[player] = true
	local ok, result, message = pcall(function(): (boolean, string)
		if isPass and MonetizationService.ownsPass(player, key) then
			return false, "You already own this pass."
		end
		-- Ownership queries may yield: recheck every gate just before prompting.
		local reason = blockedReason(player)
		if reason then
			return false, reason
		end
		if not isPass and (not handlers[key] or not DataService.isPersistent()) then
			return false, "This item isn't ready yet."
		end
		if
			not isPass
			and not Boosts.canGrant(DataService.getProfile(player), definition, os.time())
		then
			return false, "This offer cannot be granted right now."
		end
		if player.Parent ~= Players then
			return false, "You have left the server."
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
		return true, "Confirm or cancel in the Roblox purchase window."
	end)
	if not ok or not result then
		prompting[player] = nil
	end
	return if ok then result else false,
		if ok then message else "Roblox couldn't open the purchase window. Try again."
end

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
	local resolved: { [string]: boolean } = passCache[player] or {}
	-- A purchase callback may have completed while the ownership query yielded.
	resolved[key] = resolved[key] == true or owned == true
	passCache[player] = resolved
	return resolved[key]
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
			purchasing[player] = { id = receipt.PurchaseId, now = os.time() }
			local result = handler(player)
			purchasing[player] = nil
			return result
		end)
	end, true)
	purchasing[player] = nil
	if saved then
		require(script.Parent.EconomyService).refresh(player)
	end
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else pending
end
function MonetizationService.registerAction(
	namespace: string,
	handler: (Player, string) -> (boolean, string)
)
	assert(actions[namespace] == nil, "action namespace already registered")
	actions[namespace] = handler
end
function MonetizationService.hasPass(player: Player, key: string): boolean
	return MonetizationService.ownsPass(player, key)
end
function MonetizationService.getTipMultiplier(player: Player): number
	local profile = DataService.getProfile(player)
	return if profile
		then Boosts.tipMultiplier(
			{ DoubleTips = MonetizationService.ownsPass(player, "DoubleTips") },
			profile.boosts,
			os.time()
		)
		else 1
end
function MonetizationService.getOddsModifiers(player: Player): {
	rarePlusMultiplier: number,
	pizzeriaLevelBonus: number,
}
	local profile = DataService.getProfile(player)
	return Boosts.oddsModifiers({}, if profile then profile.boosts else {}, os.time())
end
function MonetizationService.peekPending(player: Player, kind: string): any
	return Boosts.peekPending(DataService.getProfile(player), kind)
end
-- Nil means no confirmed consumption; callers must not treat an empty array as success.
function MonetizationService.consumePending(player: Player, kind: string, id: string?): { any }?
	local consumed: { any } = {}
	local ok = DataService.transaction(player, function(profile)
		consumed = Boosts.takePending(profile, kind, id)
		return #consumed > 0
	end, true)
	return if ok then consumed else nil
end
function MonetizationService.grantConfigured(
	player: Player,
	key: string,
	id: string,
	now: number
): boolean
	local definition = productDefinitions[key]
	if not definition then
		return false
	end
	local accepted = false
	local ok = DataService.update(player, function(profile)
		accepted = Boosts.apply(profile, definition, id, now)
	end)
	return ok and accepted
end

function MonetizationService.init()
	DebugService.register(
		"product",
		"Grant a configured product for QA (no Robux)",
		"product <key>",
		function(player, args)
			local ok = MonetizationService.grantConfigured(
				player,
				args[1] or "",
				"debug-" .. HttpService:GenerateGUID(false),
				os.time()
			)
			if ok then
				require(script.Parent.EconomyService).refresh(player)
			end
			return ok,
				if ok
					then "product effect granted for QA"
					else "product unavailable or cannot be granted"
		end
	)
	for _, definition in Products.Products do
		productDefinitions[definition.key] = definition
		MonetizationService.registerProduct(definition.key, function(player)
			local context = purchasing[player]
			return if context
				then MonetizationService.grantConfigured(
					player,
					definition.key,
					context.id,
					context.now
				)
				else false
		end)
	end
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
	MonetizationService.registerAction("settings", function(player, action)
		local textSize = string.match(action, "^textsize%.(%a+)$")
		if textSize then
			if textSize ~= "normal" and textSize ~= "large" then
				return false, "Choose Normal or Large text."
			end
			local ok = DataService.update(player, function(profile)
				profile.settings.textSize = textSize
			end)
			if ok then
				player:SetAttribute("TextSize", textSize)
			end
			return ok, if ok then "Text size saved." else "Your profile is busy. Try again."
		end
		local quality = string.match(action, "^quality%.(%a+)$")
		if not quality or not Settings.isQuality(quality) then
			return false, "Choose Low, Medium or High."
		end
		local ok = DataService.update(player, function(profile)
			profile.settings.quality = quality
			profile.settings.effects = if quality == "low" then "low" else "normal"
		end)
		if ok then
			player:SetAttribute("EffectQuality", quality)
		end
		return ok, if ok then "Graphics setting saved." else "Your profile is busy. Try again."
	end)
	local function publishSettings(player: Player)
		local profile = DataService.getProfile(player)
		if profile then
			player:SetAttribute("TextSize", profile.settings.textSize)
			player:SetAttribute("EffectQuality", profile.settings.quality)
			player:SetAttribute("QualityLoaded", true)
		end
	end
	DataService.onLoaded(publishSettings)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			publishSettings(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		joined[player] = os.clock()
	end)
	for _, player in Players:GetPlayers() do
		joined[player] = os.clock()
	end
	Net.onServerInvoke(
		"GetShop",
		{ ratePerSecond = ShopConfig.snapshotRate, burst = ShopConfig.snapshotBurst },
		function(player)
			return MonetizationService.getShop(player)
		end
	)
	Net.onServerEvent(
		"RequestPurchase",
		{ ratePerSecond = ShopConfig.requestRate, burst = ShopConfig.requestBurst },
		function(player, rawKey)
			local accepted, reason = MonetizationService.requestPurchase(player, rawKey)
			Net.event("PurchaseResult")
				:FireClient(
					player,
					accepted,
					reason,
					if type(rawKey) == "string" then rawKey else ""
				)
		end
	)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			prompting[player] = nil
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player, gamepassId, purchased)
			prompting[player] = nil
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
		joined[player] = nil
		prompting[player] = nil
	end)
end
return MonetizationService
