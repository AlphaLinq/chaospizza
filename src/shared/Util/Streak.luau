--!strict
-- Pure: delivery streak (consecutive deliveries without an accident).
export type Config = { step: number, max: number, timeoutSeconds: number }
export type State = { count: number, lastAt: number }

local Streak = {}

function Streak.new(): State
	return { count = 0, lastAt = -math.huge }
end

-- Multiplier for a streak of `count` deliveries (1st delivery = x1).
function Streak.multiplier(count: number, config: Config): number
	if count <= 1 then
		return 1
	end
	return math.min(config.max, 1 + (count - 1) * config.step)
end

-- Records a delivery at `now`; returns (newCount, multiplier for this delivery).
function Streak.deliver(state: State, now: number, config: Config): (number, number)
	if now - state.lastAt > config.timeoutSeconds then
		state.count = 0
	end
	state.count += 1
	state.lastAt = now
	return state.count, Streak.multiplier(state.count, config)
end

function Streak.reset(state: State)
	state.count = 0
end

return table.freeze(Streak)
