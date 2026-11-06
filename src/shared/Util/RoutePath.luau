--!strict
-- Pure polyline helpers for things that travel along a route of {x, z}
-- waypoints (cheese wheel, #140). The server hit test and the client
-- animation use the same formula, so only the route and start time replicate.

export type Point = { x: number, z: number }

local RoutePath = {}

function RoutePath.length(route: { Point }): number
	local total = 0
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return total
end

-- Position and unit heading at `distance` along the route. `done` is true
-- once the end is reached (the position then stays at the last point).
function RoutePath.sample(
	route: { Point },
	distance: number
): (number, number, number, number, boolean)
	local travelled = 0
	local hx, hz = 1, 0
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local segment = math.sqrt(dx * dx + dz * dz)
		if segment > 0 then
			hx, hz = dx / segment, dz / segment
			if travelled + segment >= distance then
				local t = math.max(0, distance - travelled) / segment
				return a.x + dx * t, a.z + dz * t, hx, hz, false
			end
			travelled += segment
		end
	end
	local last = route[#route]
	return last.x, last.z, hx, hz, true
end

-- A copy of the route, optionally reversed.
function RoutePath.oriented(route: { Point }, reversed: boolean): { Point }
	local out: { Point } = {}
	for i = 1, #route do
		local p = if reversed then route[#route + 1 - i] else route[i]
		table.insert(out, { x = p.x, z = p.z })
	end
	return out
end

return RoutePath
