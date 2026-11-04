--!strict
-- Pure geometry helpers for the map layout (numbers in, numbers out).
-- Used by MapService (to build) and by tests (to check the layout).

export type Point = { x: number, y: number, z: number }

export type Building = {
	x: number,
	z: number,
	sx: number,
	sz: number,
	h: number,
	door: string,
}

local MapGeometry = {}

local FACING: { [string]: { x: number, z: number } } = {
	N = { x = 0, z = -1 },
	S = { x = 0, z = 1 },
	E = { x = 1, z = 0 },
	W = { x = -1, z = 0 },
}

MapGeometry.DOOR_HEIGHT = 8
MapGeometry.BALCONY_HEIGHT = 12
MapGeometry.BALCONY_DEPTH = 6

function MapGeometry.facing(door: string): { x: number, z: number }
	local f = FACING[door]
	assert(f, `unknown door side '{door}'`)
	return f
end

-- Point on the ground just outside the door (where the player stands to deliver).
function MapGeometry.doorPoint(b: Building, groundY: number): Point
	local f = MapGeometry.facing(b.door)
	local halfDepth = if f.x ~= 0 then b.sx / 2 else b.sz / 2
	return {
		x = b.x + f.x * (halfDepth + 3),
		y = groundY + 3,
		z = b.z + f.z * (halfDepth + 3),
	}
end

-- Centre of the balcony above the door: the flood-time delivery point.
function MapGeometry.highPoint(b: Building, groundY: number): Point
	local f = MapGeometry.facing(b.door)
	local halfDepth = if f.x ~= 0 then b.sx / 2 else b.sz / 2
	local out = halfDepth + MapGeometry.BALCONY_DEPTH / 2
	return {
		x = b.x + f.x * out,
		y = groundY + MapGeometry.BALCONY_HEIGHT + 3,
		z = b.z + f.z * out,
	}
end

function MapGeometry.distance2D(a: { x: number, z: number }, b: { x: number, z: number }): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Axis-aligned footprint overlap check (with an optional gap).
function MapGeometry.overlaps(a: Building, b: Building, gap: number?): boolean
	local g = gap or 0
	return math.abs(a.x - b.x) * 2 < (a.sx + b.sx + g * 2)
		and math.abs(a.z - b.z) * 2 < (a.sz + b.sz + g * 2)
end

return MapGeometry
