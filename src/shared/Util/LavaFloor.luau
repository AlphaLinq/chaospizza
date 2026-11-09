--!strict
-- Pure logic for The Floor Is Lava (#244). The street slabs are cut into a
-- tile grid (the same list on server and clients, built from MapLayout), so
-- only tile indices replicate. Tiles near doors, the counter, the spawn and
-- the safe spots never turn to lava: every address stays reachable.
-- No Roblox APIs; randomness is injected.

local LavaFloor = {}

export type Tile = { x: number, z: number, sx: number, sz: number }
export type Rect = { x: number, z: number, sx: number, sz: number }
export type Point = { x: number, z: number }
export type Wave = { tiles: { number }, startsAt: number, lavaAt: number, endsAt: number }
export type Config = {
	tileSize: number,
	safeRadius: number,
	waveShare: number,
	telegraphSeconds: number,
	lavaSeconds: number,
}

local function inside(r: Rect, x: number, z: number, margin: number): boolean
	return math.abs(x - r.x) <= r.sx / 2 + margin and math.abs(z - r.z) <= r.sz / 2 + margin
end

-- Distance from a point to a rectangle (0 inside).
local function rectDistance(r: Rect, p: Point): number
	local dx = math.max(math.abs(p.x - r.x) - r.sx / 2, 0)
	local dz = math.max(math.abs(p.z - r.z) - r.sz / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Tiles over the street rectangles: each slab is split evenly into cells of
-- about `tileSize`; a cell that overlaps an earlier slab is skipped (no
-- overlapping tiles: junction edges just stay safe), and so is any cell
-- within `safeRadius` of a point in `keepClear`.
function LavaFloor.tiles(streets: { Rect }, keepClear: { Point }, cfg: Config): { Tile }
	local out: { Tile } = {}
	for i, s in streets do
		local nx = math.max(1, math.floor(s.sx / cfg.tileSize + 0.5))
		local nz = math.max(1, math.floor(s.sz / cfg.tileSize + 0.5))
		local w, d = s.sx / nx, s.sz / nz
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				local cx = s.x - s.sx / 2 + w * (ix + 0.5)
				local cz = s.z - s.sz / 2 + d * (iz + 0.5)
				local skip = false
				for j = 1, i - 1 do
					local o = streets[j]
					if
						math.abs(cx - o.x) < (w + o.sx) / 2 - 1
						and math.abs(cz - o.z) < (d + o.sz) / 2 - 1
					then
						skip = true
						break
					end
				end
				local tile = { x = cx, z = cz, sx = w, sz = d }
				if not skip then
					for _, p in keepClear do
						if rectDistance(tile, p) < cfg.safeRadius then
							skip = true
							break
						end
					end
				end
				if not skip then
					table.insert(out, tile)
				end
			end
		end
	end
	return out
end

-- The points that must stay walkable, from a MapLayout-shaped table: every
-- address door (via the injected `doorPoint`), the counter, the spawn and
-- the safe spots. Server and clients call this with the same data.
function LavaFloor.keepClear(layout: any, doorPoint: (building: any) -> Point): { Point }
	local out: { Point } = {}
	for _, b in layout.buildings do
		if b.address then
			local d = doorPoint(b)
			table.insert(out, { x = d.x, z = d.z })
		end
	end
	table.insert(out, { x = layout.counter.x, z = layout.counter.z })
	table.insert(out, { x = layout.spawn.x, z = layout.spawn.z })
	for _, p in layout.safeSpots do
		table.insert(out, { x = p.x, z = p.z })
	end
	return out
end

-- A wave: `waveShare` of the tiles (at least 1), unique, sorted.
function LavaFloor.pickWave(
	count: number,
	cfg: Config,
	random: (number, number) -> number
): { number }
	if count <= 0 then
		return {}
	end
	local want = math.clamp(math.floor(count * cfg.waveShare + 0.5), 1, count)
	local pool = table.create(count, 0)
	for i = 1, count do
		pool[i] = i
	end
	local picked = {}
	for k = 1, want do
		local j = random(k, count)
		pool[k], pool[j] = pool[j], pool[k]
		table.insert(picked, pool[k])
	end
	table.sort(picked)
	return picked
end

function LavaFloor.schedule(tiles: { number }, now: number, cfg: Config): Wave
	local lavaAt = now + cfg.telegraphSeconds
	return { tiles = tiles, startsAt = now, lavaAt = lavaAt, endsAt = lavaAt + cfg.lavaSeconds }
end

export type Phase = "telegraph" | "lava" | "cool"

function LavaFloor.phase(wave: Wave?, now: number): Phase
	if not wave or now >= wave.endsAt then
		return "cool"
	end
	return if now < wave.lavaAt then "telegraph" else "lava"
end

-- The wave tile under (x, z), or nil.
function LavaFloor.tileAt(all: { Tile }, wave: { number }, x: number, z: number): number?
	for _, i in wave do
		local t = all[i]
		if t and inside(t, x, z, 0) then
			return i
		end
	end
	return nil
end

-- Unit direction from (x, z) out over the tile's nearest edge.
function LavaFloor.pushOut(t: Tile, x: number, z: number): Point
	local toX = t.sx / 2 - math.abs(x - t.x)
	local toZ = t.sz / 2 - math.abs(z - t.z)
	if toX <= toZ then
		return { x = if x >= t.x then 1 else -1, z = 0 }
	end
	return { x = 0, z = if z >= t.z then 1 else -1 }
end

return LavaFloor
