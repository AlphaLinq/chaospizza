--!strict
-- Pure party-tower wobble (#170). Each sample takes the courier's velocity
-- change since the last one and returns the new tilt; at `dropAt` the top
-- box falls. Velocities are plain numbers so tests run outside Roblox.

export type Config = {
	accelThreshold: number,
	accelGain: number,
	jumpKick: number,
	jumpSpeed: number,
	settlePerSecond: number,
	dropAt: number,
	afterDrop: number,
}
export type Sample = { vx: number, vy: number, vz: number }

local Tower = {}

-- Returns (new tilt, dropped a box?)
function Tower.step(
	tilt: number,
	before: Sample,
	after: Sample,
	dt: number,
	cfg: Config
): (number, boolean)
	if dt <= 0 then
		return tilt, false
	end
	local ax = (after.vx - before.vx) / dt
	local az = (after.vz - before.vz) / dt
	local accel = math.sqrt(ax * ax + az * az)
	local next = math.max(0, tilt - cfg.settlePerSecond * dt)
	if accel > cfg.accelThreshold then
		next += (accel - cfg.accelThreshold) * cfg.accelGain * dt
	end
	if after.vy >= cfg.jumpSpeed and before.vy < cfg.jumpSpeed then
		next += cfg.jumpKick
	end
	if next >= cfg.dropAt then
		return cfg.afterDrop, true
	end
	return next, false
end

return Tower
