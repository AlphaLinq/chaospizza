--!strict
-- Pure: micro-chaos (#187) geometry. Picks the kind, a path along a street
-- (runaway cart, geese) or a spot on it (sprinkler, box pile), keeps them out
-- of avoid-rectangles, and samples a mover along its path. No Roblox APIs.

export type Rect = { x: number, z: number, sx: number, sz: number }
export type Point = { x: number, z: number }

local MicroChaos = {}

-- Weighted kind id from { [id] = { weight = n } }, ids sorted for determinism.
function MicroChaos.pickKind(kinds: { [string]: { [string]: number } }, rng: () -> number): string
	local ids = {}
	local total = 0
	for id, def in kinds do
		if (def.weight or 0) > 0 then
			table.insert(ids, id)
			total += def.weight
		end
	end
	table.sort(ids)
	local roll = rng() * total
	for _, id in ids do
		roll -= kinds[id].weight
		if roll < 0 then
			return id
		end
	end
	return ids[#ids]
end

local function inside(p: Point, r: Rect, margin: number): boolean
	return math.abs(p.x - r.x) <= r.sx / 2 + margin and math.abs(p.z - r.z) <= r.sz / 2 + margin
end

function MicroChaos.blocked(p: Point, avoid: { Rect }): boolean
	for _, r in avoid do
		if inside(p, r, 0) then
			return true
		end
	end
	return false
end

-- A random point on the street, `margin` from its edges, outside `avoid`.
-- Tries a few times; nil if the street has no free spot.
function MicroChaos.spot(street: Rect, margin: number, avoid: { Rect }, rng: () -> number): Point?
	for _ = 1, 12 do
		local p = {
			x = street.x + (rng() - 0.5) * math.max(0, street.sx - 2 * margin),
			z = street.z + (rng() - 0.5) * math.max(0, street.sz - 2 * margin),
		}
		if not MicroChaos.blocked(p, avoid) then
			return p
		end
	end
	return nil
end

-- A straight path of `length` along the street's long axis (either way),
-- clamped to the street, whose start, middle and end avoid `avoid`.
function MicroChaos.path(
	street: Rect,
	length: number,
	margin: number,
	avoid: { Rect },
	rng: () -> number
): (Point?, Point?)
	local alongX = street.sx >= street.sz
	local long = (if alongX then street.sx else street.sz) - 2 * margin
	local span = math.min(length, long)
	if span <= 0 then
		return nil, nil
	end
	for _ = 1, 12 do
		local startOffset = (rng() - 0.5) * (long - span) - span / 2
		local side = (rng() - 0.5)
			* math.max(0, (if alongX then street.sz else street.sx) - 2 * margin)
		local a, b
		if alongX then
			a = { x = street.x + startOffset, z = street.z + side }
			b = { x = a.x + span, z = a.z }
		else
			a = { x = street.x + side, z = street.z + startOffset }
			b = { x = a.x, z = a.z + span }
		end
		if rng() < 0.5 then
			a, b = b, a
		end
		local mid = { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2 }
		local q1 = { x = (a.x * 3 + b.x) / 4, z = (a.z * 3 + b.z) / 4 }
		local q3 = { x = (a.x + b.x * 3) / 4, z = (a.z + b.z * 3) / 4 }
		local clear = true
		for _, p in { a, q1, mid, q3, b } do
			if MicroChaos.blocked(p, avoid) then
				clear = false
				break
			end
		end
		if clear then
			return a, b
		end
	end
	return nil, nil
end

-- Where a mover is at `now` (server time), `behind` studs behind the head
-- (geese in a line). nil before the start or after the end.
function MicroChaos.moverAt(
	from: Point,
	to: Point,
	t0: number,
	speed: number,
	now: number,
	behind: number?
): Point?
	local dx, dz = to.x - from.x, to.z - from.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length <= 0 then
		return nil
	end
	local travelled = (now - t0) * speed - (behind or 0)
	if travelled < 0 or travelled > length then
		return nil
	end
	local f = travelled / length
	return { x = from.x + dx * f, z = from.z + dz * f }
end

-- Seconds a mover needs for the whole path (plus its tail).
function MicroChaos.duration(from: Point, to: Point, speed: number, tail: number?): number
	local dx, dz = to.x - from.x, to.z - from.z
	return (math.sqrt(dx * dx + dz * dz) + (tail or 0)) / speed
end

-- `count` box positions scattered around a spot (deterministic ring + jitter).
function MicroChaos.scatter(
	center: Point,
	count: number,
	spread: number,
	rng: () -> number
): { Point }
	local out = {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng() * 0.6
		local r = spread * (0.4 + 0.6 * rng())
		table.insert(out, { x = center.x + math.cos(a) * r, z = center.z + math.sin(a) * r })
	end
	return out
end

function MicroChaos.near(p: Point, q: Point, radius: number): boolean
	local dx, dz = p.x - q.x, p.z - q.z
	return dx * dx + dz * dz <= radius * radius
end

function MicroChaos.gap(minSeconds: number, maxSeconds: number, rng: () -> number): number
	return minSeconds + rng() * (maxSeconds - minSeconds)
end

return table.freeze(MicroChaos)
