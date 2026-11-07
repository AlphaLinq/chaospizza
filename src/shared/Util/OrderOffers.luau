--!strict
-- Pure: the order choice board (#185). Which addresses make the "near",
-- "far" and "daredevil" offers, the rough tip estimate shown on a card, and
-- the best-of-N rarity roll for far customers. No Roblox APIs.

export type Address = { id: string, x: number, z: number }
export type Zone = { x: number, z: number, sx: number, sz: number }
export type Config = {
	nearShare: number,
	farShare: number,
	farTipMultiplier: number,
	daredevilMultiplier: number,
	daredevilZoneMargin: number,
}

local OrderOffers = {}

local function flatDistance(a: Address, from: { x: number, z: number }): number
	local dx, dz = a.x - from.x, a.z - from.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Addresses sorted by distance from the counter (nearest first, ties by id
-- so the result is deterministic).
function OrderOffers.byDistance(
	addresses: { Address },
	counter: { x: number, z: number }
): { Address }
	local list = table.clone(addresses)
	table.sort(list, function(a: Address, b: Address): boolean
		local da, db = flatDistance(a, counter), flatDistance(b, counter)
		if math.abs(da - db) > 1e-6 then
			return da < db
		end
		return a.id < b.id
	end)
	return list
end

local function pickFrom(list: { Address }, avoid: { [string]: boolean }, rng: () -> number): string?
	local options = {}
	for _, a in list do
		if not avoid[a.id] then
			table.insert(options, a.id)
		end
	end
	if #options == 0 then
		return if #list > 0 then list[1].id else nil
	end
	return options[math.clamp(math.floor(rng() * #options) + 1, 1, #options)]
end

-- A random address from the nearest `share` of the list (at least one).
function OrderOffers.pickNear(
	sorted: { Address },
	share: number,
	avoid: { [string]: boolean },
	rng: () -> number
): string?
	local n = math.max(1, math.floor(#sorted * share + 0.5))
	return pickFrom(table.move(sorted, 1, n, 1, {}), avoid, rng)
end

-- A random address from the farthest `share` of the list (at least one).
function OrderOffers.pickFar(
	sorted: { Address },
	share: number,
	avoid: { [string]: boolean },
	rng: () -> number
): string?
	local n = math.max(1, math.floor(#sorted * share + 0.5))
	return pickFrom(table.move(sorted, #sorted - n + 1, #sorted, 1, {}), avoid, rng)
end

-- Addresses whose door is inside (or within `margin` of) a hazard zone.
function OrderOffers.inZone(addresses: { Address }, zone: Zone, margin: number): { Address }
	local list = {}
	for _, a in addresses do
		if
			math.abs(a.x - zone.x) <= zone.sx / 2 + margin
			and math.abs(a.z - zone.z) <= zone.sz / 2 + margin
		then
			table.insert(list, a)
		end
	end
	return list
end

-- The card's rough tip: base tip with the event bonus (capped like a real
-- delivery, no style), times the offer and order-kind multipliers.
function OrderOffers.estimate(
	baseTip: number,
	eventBonus: number,
	maxBonus: number,
	multiplier: number
): number
	local bonus = math.min(maxBonus, math.max(0, eventBonus))
	return math.floor(baseTip * (1 + bonus) * multiplier + 0.5)
end

-- Best of `rolls` rarity rolls (by rank), for far customers.
function OrderOffers.bestRarity(roll: () -> string, rank: (string) -> number, rolls: number): string
	local best = roll()
	for _ = 2, math.max(1, rolls) do
		local r = roll()
		if rank(r) > rank(best) then
			best = r
		end
	end
	return best
end

-- Validated choice: an integer index within the offers, else nil.
function OrderOffers.validIndex(raw: unknown, count: number): number?
	if typeof(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return nil
	end
	local index = raw :: number
	return if index >= 1 and index <= count then index else nil
end

return table.freeze(OrderOffers)
