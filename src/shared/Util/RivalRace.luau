--!strict
-- Pure rules for the Speedy Sal rival race (#148): who gets a race and how
-- long Sal needs. No Roblox APIs; the roll is injected.

export type Config = {
	minLevel: number,
	chance: number,
	cooldownSeconds: number,
	revSeconds: number,
	paceFactor: number,
	minFlightSeconds: number,
}

local RivalRace = {}

-- Seconds from race start until Sal reaches the door.
function RivalRace.eta(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	walkSpeed: number,
	cfg: Config
): number
	local street = math.abs(toX - fromX) + math.abs(toZ - fromZ)
	local flight = math.max(cfg.minFlightSeconds, street / math.max(1, walkSpeed) * cfg.paceFactor)
	return cfg.revSeconds + flight
end

-- Only plain single-stop orders, from minLevel, not too often.
function RivalRace.eligible(
	level: number,
	kind: string?,
	secondsSinceLastRace: number,
	cfg: Config,
	roll: () -> number
): boolean
	if level < cfg.minLevel then
		return false
	end
	if kind ~= nil and kind ~= "normal" and kind ~= "fragile" then
		return false
	end
	if secondsSinceLastRace < cfg.cooldownSeconds then
		return false
	end
	return roll() < cfg.chance
end

return RivalRace
