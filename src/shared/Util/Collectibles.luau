--!strict
-- Pure golden pepperoni logic (#132). State lives in the profile
-- (`collectibles = { day, found, active }`). Each UTC day a courier gets
-- `perDay` active spots, unfound ones first; collecting an active spot removes
-- it from today's list. Randomness is injected (`pick(n) -> 1..n`).

export type State = { day: number, found: { [string]: boolean }, active: { string } }
export type Result = "new" | "repeat"

local Collectibles = {}

function Collectibles.dayOf(now: number, daySeconds: number): number
	return math.floor(now / daySeconds)
end

local function shuffle(list: { string }, pick: (number) -> number)
	for i = #list, 2, -1 do
		local j = pick(i)
		list[i], list[j] = list[j], list[i]
	end
end

-- New day → new active list. Returns true when the list was rolled.
function Collectibles.roll(
	state: State,
	day: number,
	ids: { string },
	perDay: number,
	pick: (number) -> number
): boolean
	if state.day == day then
		return false
	end
	state.day = day
	local unfound, seen = {}, {}
	for _, id in ids do
		if state.found[id] then
			table.insert(seen, id)
		else
			table.insert(unfound, id)
		end
	end
	shuffle(unfound, pick)
	shuffle(seen, pick)
	local active = {}
	for _, list in { unfound, seen } do
		for _, id in list do
			if #active >= perDay then
				break
			end
			table.insert(active, id)
		end
	end
	state.active = active
	return true
end

-- Collects an active spot. nil when the id is not active today.
function Collectibles.collect(state: State, id: string): Result?
	local index = table.find(state.active, id)
	if not index then
		return nil
	end
	table.remove(state.active, index)
	if state.found[id] then
		return "repeat"
	end
	state.found[id] = true
	return "new"
end

function Collectibles.foundCount(state: State, ids: { string }): number
	local n = 0
	for _, id in ids do
		if state.found[id] then
			n += 1
		end
	end
	return n
end

return Collectibles
