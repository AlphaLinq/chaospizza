--!strict
-- Pure pizza-toss rules (#236): can this order be tossed from here, and the
-- box's arc. Positions are plain {x, y, z} tables (no Roblox APIs).

local Toss = {}

export type Config = {
	maxStuds: number,
	maxHeightDiff: number,
	arcHeight: number,
	blockedKinds: { string },
}
export type V3 = { x: number, y: number, z: number }

-- ok, or false + a player-facing reason. `minStuds` is the normal delivery
-- radius: closer than that you just deliver (the toss button hides).
function Toss.check(
	kind: string?,
	flatDistance: number,
	heightDiff: number,
	minStuds: number,
	cfg: Config,
	tolerance: number?
): (boolean, string)
	if kind and table.find(cfg.blockedKinds, kind) then
		return false, "Cakes don't fly! Carry this one to the door."
	end
	if flatDistance > cfg.maxStuds + (tolerance or 0) then
		return false, "Too far to toss: get closer!"
	end
	if math.abs(heightDiff) > cfg.maxHeightDiff then
		return false, "Can't toss from up here!"
	end
	if flatDistance < minStuds - (tolerance or 0) then
		return true, "close" -- fine, it's basically a hand-over
	end
	return true, "toss"
end

-- Whether the toss button should show (client): in range, not too close.
function Toss.inRange(
	kind: string?,
	flatDistance: number,
	heightDiff: number,
	minStuds: number,
	cfg: Config
): boolean
	local ok = Toss.check(kind, flatDistance, heightDiff, minStuds, cfg)
	return ok and flatDistance >= minStuds and flatDistance <= cfg.maxStuds
end

-- Point on the arc at t in [0, 1]: a straight line plus a parabola bump.
function Toss.arc(from: V3, to: V3, t: number, arcHeight: number): V3
	local k = math.clamp(t, 0, 1)
	return {
		x = from.x + (to.x - from.x) * k,
		y = from.y + (to.y - from.y) * k + 4 * arcHeight * k * (1 - k),
		z = from.z + (to.z - from.z) * k,
	}
end

return Toss
