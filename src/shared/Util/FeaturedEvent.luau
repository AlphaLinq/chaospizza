--!strict
-- Pure: "Disaster of the week" (#224). Every server agrees which event is
-- featured from the week number alone (weeks start on Monday, UTC), it comes
-- up more often in the random pick, and its challenge pays more.

local FeaturedEvent = {}

-- Monday-based week number (Unix day 0 was a Thursday).
function FeaturedEvent.week(now: number): number
	return math.floor((now / 86400 + 3) / 7)
end

-- The featured id for `week` among `ids` (sorted first, so order-proof).
function FeaturedEvent.pick(ids: { string }, week: number): string?
	if #ids == 0 then
		return nil
	end
	local sorted = table.clone(ids)
	table.sort(sorted)
	return sorted[week % #sorted + 1]
end

-- A random candidate where `featured` counts `weight` times. `roll` is 0..1.
function FeaturedEvent.weightedPick(
	candidates: { string },
	featured: string?,
	weight: number,
	roll: number
): string?
	if #candidates == 0 then
		return nil
	end
	local total = 0
	for _, id in candidates do
		total += if id == featured then weight else 1
	end
	local x = math.clamp(roll, 0, 0.999999) * total
	for _, id in candidates do
		x -= if id == featured then weight else 1
		if x < 0 then
			return id
		end
	end
	return candidates[#candidates]
end

return table.freeze(FeaturedEvent)
