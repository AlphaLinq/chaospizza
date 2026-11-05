--!strict
-- Config is injected so the same rules run in the engine and Luau CLI tests.
local Boosts = {}
export type ActiveBoost = { key: string, name: string, expiresAt: number }
local function finite(value: any): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
function Boosts.new(config: any)
	local definitions: { [string]: any } = {}
	for _, product in config.Products do
		if product.effect and product.effect.boostKey == product.key then
			definitions[product.key] = product
		end
	end
	local api = {}
	local function tipsFit(profile: any, effect: any): boolean
		return effect.tips == nil
			or finite(effect.tips)
				and finite(profile.tips)
				and profile.tips <= config.Limits.maxTips - effect.tips
	end
	local function validClock(boosts: { [string]: number }, now: number): boolean
		return finite(now)
			and (boosts.__clock == nil or (finite(boosts.__clock) and now >= boosts.__clock))
	end
	function api.find(key: string): (any, boolean)
		for _, pass in config.Gamepasses do
			if pass.key == key then
				return pass, true
			end
		end
		for _, product in config.Products do
			if product.key == key then
				return product, false
			end
		end
		return nil, false
	end
	function api.catalog(
		ownsPass: (string) -> boolean,
		available: (any) -> boolean,
		oddsFor: (any) -> any
	): ({ any }, { any })
		local passes, products = {}, {}
		for _, pass in config.Gamepasses do
			table.insert(passes, {
				key = pass.key,
				name = pass.displayName,
				price = pass.priceRobux,
				owned = ownsPass(pass.key),
				available = pass.gamepassId > 0,
			})
		end
		for _, product in config.Products do
			table.insert(products, {
				key = product.key,
				name = product.displayName,
				price = product.priceRobux,
				available = available(product),
				odds = oddsFor(product),
			})
		end
		return passes, products
	end
	function api.peekPending(profile: any, kind: string): any
		if profile then
			for _, effect in profile.pendingEffects do
				if effect.kind == kind then
					local result: any = table.clone(effect)
					local definition = api.find(effect.key)
					result.eventId = if definition and definition.effect
						then definition.effect.eventId
						else nil
					return result
				end
			end
		end
		return nil
	end
	function api.isActive(boosts: { [string]: number }, key: string, now: number): boolean
		local expires = boosts[key]
		return definitions[key] ~= nil
			and validClock(boosts, now)
			and finite(expires)
			and expires > now
			and expires - now <= config.Limits.maxDurationSeconds
	end
	function api.extend(
		boosts: { [string]: number },
		key: string,
		seconds: number,
		now: number
	): boolean
		if
			not definitions[key]
			or not validClock(boosts, now)
			or not finite(seconds)
			or seconds <= 0
		then
			return false
		end
		local old = if api.isActive(boosts, key, now) then boosts[key] else now
		boosts[key] = math.min(now + config.Limits.maxDurationSeconds, old + seconds)
		boosts.__clock = now
		return true
	end
	function api.active(boosts: { [string]: number }, now: number): { ActiveBoost }
		local result: { ActiveBoost } = {}
		for key, definition in definitions do
			if api.isActive(boosts, key, now) then
				table.insert(result, {
					key = key,
					name = definition.displayName,
					expiresAt = boosts[key],
				})
			end
		end
		table.sort(result, function(a: ActiveBoost, b: ActiveBoost)
			return a.key < b.key
		end)
		return result
	end
	function api.tipMultiplier(
		owned: { [string]: boolean },
		boosts: { [string]: number },
		now: number
	): number
		local multiplier = 1
		for _, pass in config.Gamepasses do
			if owned[pass.key] and pass.effect and pass.effect.tipMultiplier then
				multiplier *= pass.effect.tipMultiplier
			end
		end
		for key, product in definitions do
			if product.effect.tipMultiplier and api.isActive(boosts, key, now) then
				multiplier *= product.effect.tipMultiplier
			end
		end
		return math.min(config.Limits.maxTipMultiplier, multiplier)
	end
	function api.oddsModifiers(
		_owned: { [string]: boolean },
		boosts: { [string]: number },
		now: number
	): { rarePlusMultiplier: number, pizzeriaLevelBonus: number }
		local multiplier = 1
		for key, product in definitions do
			if product.effect.rarePlusMultiplier and api.isActive(boosts, key, now) then
				multiplier *= product.effect.rarePlusMultiplier
			end
		end
		return {
			rarePlusMultiplier = math.min(config.Limits.maxOddsMultiplier, multiplier),
			pizzeriaLevelBonus = 0,
		}
	end
	function api.canGrant(profile: any, definition: any, now: number): boolean
		if not profile or not definition.effect or not finite(now) then
			return false
		end
		local effect = definition.effect
		if not tipsFit(profile, effect) then
			return false
		end
		if effect.kind == "event" then
			return #profile.pendingEffects < config.Limits.maxPending
		end
		if definition.key == "StarterPack" then
			return not profile.cosmetics.owned[effect.cosmetic]
				and finite(profile.firstSeen)
				and now >= profile.firstSeen
				and now - profile.firstSeen
					<= definition.starterMaxDays * config.Limits.secondsPerDay
		end
		return true
	end
	function api.apply(profile: any, definition: any, receiptId: string, now: number): boolean
		local effect = definition.effect
		if not effect or not finite(now) or not tipsFit(profile, effect) then
			return false
		end
		if effect.kind == "event" then
			if #profile.pendingEffects >= config.Limits.maxPending then
				return false
			end
			table.insert(
				profile.pendingEffects,
				{ id = receiptId, kind = "event", key = definition.key, createdAt = now }
			)
		else
			-- The offer window gates prompts. An already paid receipt may arrive days later.
			if definition.key == "StarterPack" and profile.cosmetics.owned[effect.cosmetic] then
				return false
			end
			if
				effect.boostKey
				and not api.extend(profile.boosts, effect.boostKey, definition.durationSeconds, now)
			then
				return false
			end
			if effect.tips then
				profile.tips += effect.tips
			end
			if effect.cosmetic then
				profile.cosmetics.owned[effect.cosmetic] = true
			end
		end
		return true
	end
	function api.takePending(profile: any, kind: string, id: string?): { any }
		local consumed: { any } = {}
		for index = #profile.pendingEffects, 1, -1 do
			local effect = profile.pendingEffects[index]
			if effect.kind == kind and (id == nil or effect.id == id) then
				table.insert(consumed, 1, table.remove(profile.pendingEffects, index))
			end
		end
		return consumed
	end
	return api
end
return Boosts
