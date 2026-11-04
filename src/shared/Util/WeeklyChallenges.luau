--!strict
export type Entry = { progress: number, claimed: boolean }
export type State = { week: number, lastUpdate: number, selected: { [string]: Entry } }
type Challenge = { id: string, name: string, event: string, target: number, tips: number, xp: number }
type Config = {
	secondsPerDay: number,
	daysPerWeek: number,
	mondayOffsetDays: number,
	weekly: { selectionLimit: number, challenges: { Challenge } },
}
local WeeklyChallenges = {}
local function validTime(now: number): boolean
	return now == now and now >= 0 and now < math.huge
end
function WeeklyChallenges.new(config: Config)
	local definitions: { [string]: Challenge } = {}
	for _, challenge in config.weekly.challenges do
		assert(not definitions[challenge.id] and challenge.target > 0, "invalid weekly definition")
		definitions[challenge.id] = challenge
	end
	local api = {}
	function api.weekFromTime(now: number): number
		return math.floor(
			(math.floor(now / config.secondsPerDay) + config.mondayOffsetDays) / config.daysPerWeek
		)
	end
	function api.start(now: number): State
		assert(validTime(now), "invalid weekly clock")
		return { week = api.weekFromTime(now), lastUpdate = math.floor(now), selected = {} }
	end
	local function advance(part: State, now: number): (State, boolean)
		local selected: { [string]: Entry } = {}
		for id, entry in part.selected do
			selected[id] = table.clone(entry)
		end
		local state = { week = part.week, lastUpdate = part.lastUpdate, selected = selected }
		if not validTime(now) or now < part.lastUpdate or api.weekFromTime(now) < part.week then
			return state, false
		end
		if api.weekFromTime(now) > part.week then
			return api.start(now), true
		end
		state.lastUpdate = math.floor(now)
		return state, true
	end
	function api.choices(): { Challenge }
		local result: { Challenge } = {}
		for _, challenge in config.weekly.challenges do
			table.insert(result, table.clone(challenge))
		end
		return result
	end
	function api.select(part: State, id: string, now: number): (boolean, State)
		local state, ok = advance(part, now)
		if not ok or not definitions[id] or state.selected[id] then
			return false, state
		end
		local count = 0
		for _ in state.selected do
			count += 1
		end
		if count >= config.weekly.selectionLimit then
			return false, state
		end
		state.selected[id] = { progress = 0, claimed = false }
		return true, state
	end
	function api.record(part: State, event: string, amount: number, now: number): State
		local state, ok = advance(part, now)
		if not ok or not validTime(amount) or amount % 1 ~= 0 then
			return state
		end
		for id, entry in state.selected do
			local definition = definitions[id]
			if definition and not entry.claimed and definition.event == event then
				entry.progress = math.min(definition.target, entry.progress + amount)
			end
		end
		return state
	end
	function api.claim(part: State, id: string, now: number): ({ tips: number, xp: number }?, State)
		local state, ok = advance(part, now)
		local definition, entry = definitions[id], state.selected[id]
		if
			not ok
			or not definition
			or not entry
			or entry.claimed
			or entry.progress < definition.target
		then
			return nil, state
		end
		entry.claimed = true
		return { tips = definition.tips, xp = definition.xp }, state
	end
	function api.refresh(part: State, now: number): State
		local state = advance(part, now)
		return state
	end
	return api
end
return WeeklyChallenges
