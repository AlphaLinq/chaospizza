--!strict
-- Pure hourly city goal (#133). One goal per server per hour window: every
-- delivery counts; once the goal is reached, everyone with enough own
-- deliveries in that window is rewarded exactly once (also if they reach the
-- minimum after the goal was completed).

export type Config = {
	windowSeconds: number,
	perPlayer: number,
	minTarget: number,
	maxTarget: number,
	roundTo: number,
	minContribution: number,
}
export type State = {
	window: number,
	target: number,
	progress: number,
	peakPlayers: number,
	completed: boolean,
	contributions: { [number]: number }, -- userId → deliveries this window
	rewarded: { [number]: boolean },
}

local CityGoal = {}

function CityGoal.window(now: number, cfg: Config): number
	return math.floor(now / cfg.windowSeconds)
end

function CityGoal.target(players: number, cfg: Config): number
	local raw = math.max(1, players) * cfg.perPlayer
	local rounded = math.ceil(raw / cfg.roundTo) * cfg.roundTo
	return math.clamp(rounded, cfg.minTarget, cfg.maxTarget)
end

function CityGoal.new(window: number, players: number, cfg: Config): State
	return {
		window = window,
		target = CityGoal.target(players, cfg),
		progress = 0,
		peakPlayers = math.max(1, players),
		completed = false,
		contributions = {},
		rewarded = {},
	}
end

-- More players joined: the goal may grow (never shrinks, never once completed).
function CityGoal.observePlayers(state: State, players: number, cfg: Config)
	if players > state.peakPlayers and not state.completed then
		state.peakPlayers = players
		state.target = math.max(state.target, CityGoal.target(players, cfg))
	end
end

-- Records one delivery. Returns true if this delivery completed the goal.
function CityGoal.record(state: State, userId: number): boolean
	state.contributions[userId] = (state.contributions[userId] or 0) + 1
	state.progress += 1
	if not state.completed and state.progress >= state.target then
		state.completed = true
		return true
	end
	return false
end

-- User ids that should get the reward now (and marks them as rewarded).
function CityGoal.claimable(state: State, cfg: Config): { number }
	local list: { number } = {}
	if not state.completed then
		return list
	end
	for userId, count in state.contributions do
		if count >= cfg.minContribution and not state.rewarded[userId] then
			state.rewarded[userId] = true
			table.insert(list, userId)
		end
	end
	table.sort(list)
	return list
end

return CityGoal
