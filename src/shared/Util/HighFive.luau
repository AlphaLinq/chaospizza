--!strict
-- Pure high-five matching (#246). A request is "I raised my hand at (x, z)
-- at time t". Two requests from different couriers, close in space and time,
-- make a high five; the same pair pays only once per pair cooldown.

local HighFive = {}

export type Request = { t: number, x: number, z: number }
export type Config = { radius: number, windowSeconds: number, pairCooldownSeconds: number }

function HighFive.pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

-- The nearest other courier with a fresh request in range, or nil.
function HighFive.match(
	requests: { [number]: Request },
	me: number,
	x: number,
	z: number,
	now: number,
	cfg: Config
): number?
	local best, bestD = nil, math.huge
	for id, r in requests do
		if id == me or now - r.t > cfg.windowSeconds then
			continue
		end
		local d = math.sqrt((r.x - x) ^ 2 + (r.z - z) ^ 2)
		if d <= cfg.radius and (d < bestD or (d == bestD and best and id < best)) then
			best, bestD = id, d
		end
	end
	return best
end

-- Whether this pair may be paid now (and records it if so).
function HighFive.claimPair(
	paid: { [string]: number },
	a: number,
	b: number,
	now: number,
	cfg: Config
): boolean
	local key = HighFive.pairKey(a, b)
	local last = paid[key]
	if last and now - last < cfg.pairCooldownSeconds then
		return false
	end
	paid[key] = now
	return true
end

function HighFive.prune(requests: { [number]: Request }, now: number, cfg: Config)
	for id, r in requests do
		if now - r.t > cfg.windowSeconds then
			requests[id] = nil
		end
	end
end

return HighFive
