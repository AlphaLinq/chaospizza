--!strict
export type Config = {
	targetSeconds: number,
	deliverySeconds: number,
	minPlayers: number,
	maxPlayers: number,
	eventMultiplier: number,
}
export type State = { value: number, players: number, updatedAt: number, config: Config }
local ChaosMeterLogic = {}
local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
function ChaosMeterLogic.new(config: Config, playerCount: number?, now: number?): State
	assert(
		config.targetSeconds > 0
			and config.deliverySeconds > 0
			and config.minPlayers > 0
			and config.maxPlayers >= config.minPlayers
			and config.eventMultiplier > 0,
		"invalid chaos configuration"
	)
	local players = if playerCount and finite(playerCount)
		then math.max(0, math.floor(playerCount))
		else config.minPlayers
	return {
		value = 0,
		players = players,
		updatedAt = if now and finite(now) then now else 0,
		config = table.clone(config),
	}
end
-- All clock values come from the caller. No passive filling: only deliveries count.
function ChaosMeterLogic.addDelivery(state: State, duringEvent: boolean, now: number?): number
	if now and (not finite(now) or now < state.updatedAt) then
		return state.value
	end
	local population = math.clamp(state.players, state.config.minPlayers, state.config.maxPlayers)
	local gain = state.config.deliverySeconds / (state.config.targetSeconds * population)
	state.value =
		math.min(1, state.value + gain * (if duringEvent then state.config.eventMultiplier else 1))
	if now then
		state.updatedAt = now
	end
	return state.value
end
function ChaosMeterLogic.isFull(state: State): boolean
	return state.value >= 1 - 1e-9
end
function ChaosMeterLogic.reset(state: State, now: number?)
	state.value = 0
	if now and finite(now) then
		state.updatedAt = math.max(state.updatedAt, now)
	end
end
function ChaosMeterLogic.setPlayers(state: State, count: number)
	if finite(count) then
		state.players = math.max(0, math.floor(count))
	end
end
return ChaosMeterLogic
