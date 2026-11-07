--!strict
-- Pure: event challenge progress (#200). A small state per courier:
-- progress towards the goal, throttled hazard counting, and the one-time
-- completion. No Roblox APIs.

export type State = {
	event: string,
	goal: number,
	progress: number,
	done: boolean,
	lastHazard: number, -- clock of the last counted hazard mark
}

local EventChallenge = {}

function EventChallenge.new(event: string, goal: number): State
	return {
		event = event,
		goal = math.max(1, goal),
		progress = 0,
		done = false,
		lastHazard = -math.huge,
	}
end

-- Adds `amount`; returns true exactly once, when the goal is first reached.
function EventChallenge.add(state: State, amount: number): boolean
	if state.done or amount <= 0 or amount ~= amount then
		return false
	end
	state.progress = math.min(state.goal, state.progress + amount)
	if state.progress >= state.goal then
		state.done = true
		return true
	end
	return false
end

-- A hazard mark counts once per `cooldown` seconds (some are marked every
-- tick while they last). Returns true when this mark completed it.
function EventChallenge.hazard(state: State, now: number, cooldown: number): boolean
	if state.done or now - state.lastHazard < cooldown then
		return false
	end
	state.lastHazard = now
	return EventChallenge.add(state, 1)
end

-- Is (x, z) over any street rectangle? (rooftop check: high and NOT here)
function EventChallenge.overStreet(
	x: number,
	z: number,
	streets: { { x: number, z: number, sx: number, sz: number } }
): boolean
	for _, s in streets do
		if math.abs(x - s.x) <= s.sx / 2 and math.abs(z - s.z) <= s.sz / 2 then
			return true
		end
	end
	return false
end

-- HUD number: whole seconds/counts, never above the goal.
function EventChallenge.shown(state: State): number
	return math.min(state.goal, math.floor(state.progress))
end

return table.freeze(EventChallenge)
