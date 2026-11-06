--!strict
-- Pure: order types (brief 8.1). Which kinds a player can get, a weighted
-- pick, and the reward effect of a finished order. No Roblox APIs.

export type Kind = "normal" | "double" | "rush" | "fragile" | "party"
export type KindDef = { minLevel: number, weight: number, bonus: number?, tipMultiplier: number? }
export type Config = {
	normalWeight: number,
	double: KindDef,
	rush: KindDef & { timeFactor: number },
	fragile: KindDef,
	party: KindDef & { boxes: number },
}
export type Facts = { onTime: boolean?, intact: boolean?, boxes: number? }

local OrderKinds = {}

local ORDER: { Kind } = { "double", "rush", "fragile", "party" }

-- Kinds unlocked at this pizzeria level (never during onboarding).
function OrderKinds.available(
	level: number,
	deliveries: number,
	starterDeliveries: number,
	config: Config
): { Kind }
	local list: { Kind } = { "normal" }
	if deliveries < starterDeliveries then
		return list
	end
	for _, kind in ORDER do
		local def = (config :: any)[kind] :: KindDef
		if level >= def.minLevel and def.weight > 0 then
			table.insert(list, kind)
		end
	end
	return list
end

function OrderKinds.pick(
	level: number,
	deliveries: number,
	starterDeliveries: number,
	config: Config,
	rng: () -> number
): Kind
	local options = OrderKinds.available(level, deliveries, starterDeliveries, config)
	local total = 0
	local weights: { number } = {}
	for i, kind in options do
		local w = if kind == "normal"
			then config.normalWeight
			else ((config :: any)[kind] :: KindDef).weight
		weights[i] = math.max(0, w)
		total += weights[i]
	end
	if total <= 0 then
		return "normal"
	end
	local roll = math.clamp(rng(), 0, 0.999999) * total
	for i, kind in options do
		if roll < weights[i] then
			return kind
		end
		roll -= weights[i]
	end
	return options[#options]
end

-- Extra tip effect of a finished order: (bonus fraction added before the cap,
-- tip multiplier after the cap, display labels).
function OrderKinds.reward(kind: Kind, facts: Facts, config: Config): (number, number, { string })
	if kind == "double" then
		return 0, config.double.tipMultiplier or 1, { "Double order" }
	elseif kind == "rush" then
		if facts.onTime then
			return config.rush.bonus or 0, 1, { "On time" }
		end
		return 0, 1, { "Late rush" }
	elseif kind == "fragile" then
		if facts.intact then
			return config.fragile.bonus or 0, 1, { "Cake intact" }
		end
		return 0, 1, { "Squished cake" }
	elseif kind == "party" then
		-- Party tower (#170): pays per box still on the stack.
		local total = config.party.boxes
		local left = math.clamp(facts.boxes or total, 0, total)
		local multiplier = (config.party.tipMultiplier or 1) * left / total
		if left == total then
			return 0, multiplier, { "Tower of Power" }
		end
		return 0, multiplier, { `Party {left}/{total}` }
	end
	return 0, 1, {}
end

return table.freeze(OrderKinds)
