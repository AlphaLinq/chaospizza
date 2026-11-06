--!strict
-- Pure bubble motion for the Bubble Storm (#161). A bubble rises from its
-- spawn point at `rise` studs/s up to `maxHeight`, drifting sideways; the
-- server catch test and the client animation use the same formula.

export type Bubble = {
	id: number,
	x: number,
	z: number,
	y0: number,
	t0: number, -- server time of spawn
	vx: number,
	vz: number,
	r: number,
}

local Bubbles = {}

function Bubbles.position(
	b: Bubble,
	now: number,
	rise: number,
	maxHeight: number
): (number, number, number)
	local t = math.max(0, now - b.t0)
	local y = math.min(b.y0 + rise * t, b.y0 + maxHeight)
	return b.x + b.vx * t, y, b.z + b.vz * t
end

function Bubbles.alive(b: Bubble, now: number, lifeSeconds: number): boolean
	return now >= b.t0 and now - b.t0 < lifeSeconds
end

return Bubbles
