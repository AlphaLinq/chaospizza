--!strict
-- Pure: the server-wide delivery combo (#219). Deliveries within
-- `windowSeconds` of each other chain; once at least `minCouriers` different
-- couriers are in the chain it is a City Rush and every further delivery
-- grows the combo. When the chain breaks, everyone in it gets combo × tips.
-- No Roblox APIs; couriers are keys (UserIds).

export type Config = {
	windowSeconds: number,
	minCouriers: number,
	perComboTips: number,
	maxCombo: number,
}
export type State = {
	combo: number,
	lastAt: number,
	couriers: { [any]: boolean },
	courierCount: number,
	active: boolean,
}

local CityRush = {}

function CityRush.new(): State
	return { combo = 0, lastAt = -math.huge, couriers = {}, courierCount = 0, active = false }
end

-- Has the chain run out at `now`?
function CityRush.expired(state: State, now: number, cfg: Config): boolean
	return state.combo > 0 and now - state.lastAt > cfg.windowSeconds
end

-- Records a delivery. Returns "start" when the rush just began, "grow" when an
-- active rush grew, or nil. Call `finish` first if the chain had expired.
function CityRush.deliver(state: State, courier: any, now: number, cfg: Config): string?
	state.combo = math.min(cfg.maxCombo, state.combo + 1)
	state.lastAt = now
	if not state.couriers[courier] then
		state.couriers[courier] = true
		state.courierCount += 1
	end
	if not state.active and state.courierCount >= cfg.minCouriers then
		state.active = true
		return "start"
	end
	return if state.active then "grow" else nil
end

-- Ends the chain. Returns tips per courier (empty if it never became a rush)
-- and a fresh state.
function CityRush.finish(state: State, cfg: Config): ({ [any]: number }, State)
	local pay = {}
	if state.active then
		for courier in state.couriers do
			pay[courier] = state.combo * cfg.perComboTips
		end
	end
	return pay, CityRush.new()
end

return table.freeze(CityRush)
