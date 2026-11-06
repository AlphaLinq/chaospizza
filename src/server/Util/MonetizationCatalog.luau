--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local CustomerOdds = require(ReplicatedStorage.Shared.Util.CustomerOdds)
local Boosts = require(ReplicatedStorage.Shared.Util.Boosts).new(Products)
local Disasters = require(ReplicatedStorage.Shared.Util.DisasterProducts).new(
	require(ReplicatedStorage.Shared.Config.Events),
	require(ReplicatedStorage.Shared.Util.Season).isActive
)
local DataService = require(script.Parent.Parent.Services.DataService)
local Catalog = {}
function Catalog.build(
	player: Player,
	handlers: any,
	ownsPass: (Player, string) -> boolean,
	blockedReason: (Player) -> string?,
	joined: any
): any
	local CustomerService = require(script.Parent.Parent.Services.CustomerService)
	local profile, now = DataService.getProfile(player), os.time()
	local today = os.date("!*t", now)
	local EventService = require(script.Parent.Parent.Services.EventService)
	local passes, products = Boosts.catalog(function(key)
		return ownsPass(player, key)
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
	end, function(product)
		return Disasters.visible(product, today.month, today.day)
	end)
	for _, item in products do
		local definition = Boosts.find(item.key)
		item.isChaos = Disasters.isDisaster(definition) or item.key == "MegaChaosNow"
		if item.isChaos then
			local allowed, reason =
				Disasters.check(definition, today.month, today.day, EventService.canOrder)
			item.disabledReason = if not allowed then reason else nil
			item.available = item.available and allowed
		end
	end
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
return Catalog
