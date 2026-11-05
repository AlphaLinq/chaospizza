--!strict
export type State = { day: number, lastClaim: number }
export type Reward = { tips: number, xp: number, cosmetic: string? }
type Config = { secondsPerDay: number, daily: { Reward } }
local DailyLogin = {}
local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
function DailyLogin.claim(part: State, nowUnix: number, config: Config): (Reward?, State)
	local state = { day = part.day, lastClaim = part.lastClaim }
	if
		not finite(nowUnix)
		or nowUnix < 0
		or not finite(state.day)
		or state.day < 0
		or state.day % 1 ~= 0
		or state.day > #config.daily
		or not finite(state.lastClaim)
		or state.lastClaim < 0
	then
		return nil, state
	end
	if
		state.day > 0
		and (
			nowUnix < state.lastClaim
			or math.floor(nowUnix / config.secondsPerDay)
				== math.floor(state.lastClaim / config.secondsPerDay)
		)
	then
		return nil, state
	end
	local day = state.day % #config.daily + 1
	local reward = table.clone(config.daily[day])
	return reward, { day = day, lastClaim = math.floor(nowUnix) }
end
function DailyLogin.new(config: Config)
	assert(
		config.secondsPerDay > 0 and #config.daily == 7,
		"daily calendar must contain seven days"
	)
	return {
		claim = function(part: State, nowUnix: number)
			return DailyLogin.claim(part, nowUnix, config)
		end,
	}
end
return DailyLogin
