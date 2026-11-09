--!strict
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type OddsTable = "normal" | "event" | "mega"
export type Modifiers = { rarePlusMultiplier: number?, pizzeriaLevelBonus: number? }
type Rarity = {
	id: string,
	order: number,
	weightNormal: number,
	weightEvent: number,
	weightMega: number,
}
type Customer = { id: string, rarity: string, event: string?, night: boolean? }
local CustomerOdds = {}
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local function finite(value: number?, fallback: number): number
	return if value
			and value == value
			and math.abs(value) < math.huge
		then math.max(0, value)
		else fallback
end
-- Bonus is additive to the Rare+ weight multiplier (0.1 means +10%).
-- Zero-weight content stays impossible, even when a paid modifier is active.
function CustomerOdds.describe(
	mode: OddsTable,
	rarities: { Rarity },
	modifiers: Modifiers?
): { [string]: number }
	local mods: Modifiers = modifiers or {}
	local boost = finite(mods.rarePlusMultiplier, 1) + finite(mods.pizzeriaLevelBonus, 0)
	local weights: { [string]: number } = {}
	local total = 0
	for _, rarity in rarities do
		local weight = if mode == "normal"
			then rarity.weightNormal
			elseif mode == "event" then rarity.weightEvent
			else rarity.weightMega
		weight = finite(weight, 0) * (if rarity.order >= 3 then boost else 1)
		weights[rarity.id] = weight
		total += weight
	end
	assert(total > 0 and total < math.huge, "rarity weights must have a finite positive sum")
	for key, value in weights do
		weights[key] = value / total * 100
	end
	return weights
end
local function sample(rng: () -> number): number
	local value = rng()
	assert(value == value and value >= 0 and value <= 1, "rng must return [0, 1]")
	return value
end
function CustomerOdds.rollRarity(
	mode: OddsTable,
	rarities: { Rarity },
	modifiers: Modifiers?,
	rng: () -> number
): RarityId
	local odds = CustomerOdds.describe(mode, rarities, modifiers)
	local target = sample(rng) * 100
	local cumulative = 0
	local last = "Common"
	for _, rarity in rarities do
		local weight = odds[rarity.id]
		if weight > 0 then
			last = rarity.id
			cumulative += weight
			if target < cumulative then
				return rarity.id :: RarityId
			end
		end
	end
	return last :: RarityId
end
function CustomerOdds.pickCustomer(
	customers: { Customer },
	rarity: string,
	eventId: string?,
	rng: () -> number,
	night: boolean? -- night-only customers join the pool (#258)
): string?
	local index = table.find(ORDER, rarity)
	if not index then
		return nil
	end
	for rank = index, 1, -1 do
		local pool: { string } = {}
		for _, customer in customers do
			if
				customer.rarity == ORDER[rank]
				and (customer.event == nil or customer.event == eventId)
				and (not customer.night or night == true)
			then
				table.insert(pool, customer.id)
			end
		end
		if #pool > 0 then
			return pool[math.min(#pool, math.floor(sample(rng) * #pool) + 1)]
		end
	end
	return nil
end
return CustomerOdds
