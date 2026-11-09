--!strict
-- Pure convoy logic (#232): couriers who deliver close together in time and
-- space both get a small flat bonus. The log keeps recent deliveries; each
-- entry can pay out to at most `maxCredits` later partners, so a crowd at
-- one door can't farm a single delivery.

local Convoy = {}

export type Entry = { userId: number, name: string, x: number, z: number, t: number, credits: number }
export type Config = {
	windowSeconds: number,
	radius: number,
	maxCredits: number,
	maxPartners: number,
}

function Convoy.prune(log: { Entry }, now: number, cfg: Config)
	for i = #log, 1, -1 do
		if now - log[i].t > cfg.windowSeconds then
			table.remove(log, i)
		end
	end
end

-- Partners for a delivery by `userId` at (x, z): other couriers' recent
-- deliveries within the radius, nearest first, one entry per courier, at most
-- maxPartners. Marks the used entries (credits) — call once per delivery.
function Convoy.match(
	log: { Entry },
	userId: number,
	x: number,
	z: number,
	now: number,
	cfg: Config
): { Entry }
	local best: { [number]: { entry: Entry, d: number } } = {}
	for _, e in log do
		if e.userId == userId or now - e.t > cfg.windowSeconds or e.credits >= cfg.maxCredits then
			continue
		end
		local d = math.sqrt((e.x - x) ^ 2 + (e.z - z) ^ 2)
		if d > cfg.radius then
			continue
		end
		local seen = best[e.userId]
		if not seen or d < seen.d or (d == seen.d and e.t > seen.entry.t) then
			best[e.userId] = { entry = e, d = d }
		end
	end
	local list = {}
	for _, v in best do
		table.insert(list, v)
	end
	table.sort(list, function(a, b)
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.entry.userId < b.entry.userId
	end)
	local out = {}
	for i = 1, math.min(#list, cfg.maxPartners) do
		local e = list[i].entry
		e.credits += 1
		table.insert(out, e)
	end
	return out
end

function Convoy.record(
	log: { Entry },
	userId: number,
	name: string,
	x: number,
	z: number,
	now: number
)
	table.insert(log, { userId = userId, name = name, x = x, z = z, t = now, credits = 0 })
end

return Convoy
