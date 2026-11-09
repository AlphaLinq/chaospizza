--!strict
-- Pure: which shop an errand sends you to (#218). The one that adds the
-- least walking on the way from `from` to the door, but not one right next
-- to you or to the door, and not a huge detour. No Roblox APIs.

export type Shop = { name: string, item: string, icon: string, x: number, z: number }
export type Point = { x: number, z: number }
export type Config = { maxDetourStuds: number, minGapStuds: number }

local Errand = {}

local function dist(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Extra studs walked via `shop` compared to going straight.
function Errand.detour(from: Point, shop: Point, to: Point): number
	return dist(from, shop) + dist(shop, to) - dist(from, to)
end

-- The best shop, or nil when none fits. Ties: the earlier one in the list.
function Errand.pick(shops: { Shop }, from: Point, to: Point, cfg: Config): Shop?
	local best: Shop? = nil
	local bestDetour = math.huge
	for _, shop in shops do
		local extra = Errand.detour(from, shop, to)
		if
			dist(from, shop) >= cfg.minGapStuds
			and dist(shop, to) >= cfg.minGapStuds
			and extra <= cfg.maxDetourStuds
			and extra < bestDetour
		then
			best, bestDetour = shop, extra
		end
	end
	return best
end

function Errand.reached(p: Point, shop: Point, radius: number): boolean
	return dist(p, shop) <= radius
end

return table.freeze(Errand)
