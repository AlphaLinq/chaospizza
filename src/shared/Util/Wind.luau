--!strict
-- Pure wind-gust logic for the Gale Force event (#230). No Roblox APIs:
-- vectors are plain {x, z} tables and randomness is injected, so
-- tests/run.luau can check it.
--
-- A gust is announced `telegraphSeconds` ahead (HUD arrow + countdown),
-- blows for `gustSeconds`, then the air is calm until the next one.

local Wind = {}

export type Dir = { name: string, x: number, z: number }
export type Gust = {
	name: string,
	x: number,
	z: number,
	startsAt: number,
	endsAt: number,
}
export type Config = {
	telegraphSeconds: number,
	gustSeconds: number,
	calmMinSeconds: number,
	calmMaxSeconds: number,
	groundAccel: number,
	airAccel: number,
	maxWindSpeed: number,
	rideFeet: number,
	rideSpeed: number,
}

local D = math.sqrt(0.5)

-- "name" is where the wind blows FROM (a west wind pushes you east).
Wind.directions = table.freeze({
	table.freeze({ name = "north", x = 0, z = 1 }),
	table.freeze({ name = "north-east", x = -D, z = D }),
	table.freeze({ name = "east", x = -1, z = 0 }),
	table.freeze({ name = "south-east", x = -D, z = -D }),
	table.freeze({ name = "south", x = 0, z = -1 }),
	table.freeze({ name = "south-west", x = D, z = -D }),
	table.freeze({ name = "west", x = 1, z = 0 }),
	table.freeze({ name = "north-west", x = D, z = D }),
}) :: { Dir }

-- Picks a direction index, never the same one twice in a row.
function Wind.pickIndex(random: (number, number) -> number, last: number?): number
	local n = #Wind.directions
	if not last or last < 1 or last > n then
		return random(1, n)
	end
	local step = random(1, n - 1)
	return (last - 1 + step) % n + 1
end

-- The next gust: announced at `now`, blowing after the telegraph.
function Wind.schedule(now: number, index: number, cfg: Config): Gust
	local d = Wind.directions[index]
	local startsAt = now + cfg.telegraphSeconds
	return {
		name = d.name,
		x = d.x,
		z = d.z,
		startsAt = startsAt,
		endsAt = startsAt + cfg.gustSeconds,
	}
end

-- Calm seconds after a gust, rolled with `random01()` in [0, 1).
function Wind.calmSeconds(random01: () -> number, cfg: Config): number
	return cfg.calmMinSeconds + random01() * (cfg.calmMaxSeconds - cfg.calmMinSeconds)
end

export type Phase = "telegraph" | "blowing" | "calm"

function Wind.phase(gust: Gust?, now: number): Phase
	if not gust then
		return "calm"
	end
	if now < gust.startsAt then
		return "telegraph"
	elseif now < gust.endsAt then
		return "blowing"
	end
	return "calm"
end

-- Horizontal velocity to add this frame. Grounded couriers barely slide
-- (the humanoid brakes them); in the air the wind carries you, but the
-- speed it gives along its direction is capped at maxWindSpeed, so it never
-- stacks into a launch (and the anti-teleport travel check stays happy).
function Wind.push(
	gust: Gust,
	vx: number,
	vz: number,
	grounded: boolean,
	dt: number,
	cfg: Config
): (number, number)
	local along = vx * gust.x + vz * gust.z
	local room = cfg.maxWindSpeed - along
	if room <= 0 or dt <= 0 then
		return 0, 0
	end
	local accel = if grounded then cfg.groundAccel else cfg.airAccel
	local add = math.min(accel * dt, room)
	return gust.x * add, gust.z * add
end

-- Riding a gust: high enough in the air and moving with the wind.
function Wind.riding(gust: Gust, vx: number, vz: number, feet: number, cfg: Config): boolean
	return feet >= cfg.rideFeet and vx * gust.x + vz * gust.z >= cfg.rideSpeed
end

-- Screen rotation (degrees, 0 = up) of an arrow showing where the wind
-- pushes, for a camera looking along (lookX, lookZ).
function Wind.arrowRotation(gust: Gust, lookX: number, lookZ: number): number
	local camYaw = math.atan2(lookX, -lookZ)
	local windYaw = math.atan2(gust.x, -gust.z)
	local deg = math.deg(windYaw - camYaw)
	deg = (deg + 180) % 360 - 180
	return math.floor(deg * 10 + 0.5) / 10
end

return Wind
