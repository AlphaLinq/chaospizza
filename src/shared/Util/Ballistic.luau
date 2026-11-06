--!strict
-- Pure ballistic helper (numbers only, testable outside Roblox): the launch
-- velocity that lands at `to` after `seconds` under `gravity` (no drag).

export type Point = { x: number, y: number, z: number }

local Ballistic = {}

function Ballistic.velocity(from: Point, to: Point, seconds: number, gravity: number): Point
	return {
		x = (to.x - from.x) / seconds,
		y = (to.y - from.y) / seconds + 0.5 * gravity * seconds,
		z = (to.z - from.z) / seconds,
	}
end

-- Position after `t` seconds of flight.
function Ballistic.at(from: Point, velocity: Point, t: number, gravity: number): Point
	return {
		x = from.x + velocity.x * t,
		y = from.y + velocity.y * t - 0.5 * gravity * t * t,
		z = from.z + velocity.z * t,
	}
end

-- Highest point above `from`.
function Ballistic.apex(velocity: Point, gravity: number): number
	return if velocity.y > 0 then velocity.y * velocity.y / (2 * gravity) else 0
end

return Ballistic
