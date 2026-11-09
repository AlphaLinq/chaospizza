--!strict
-- Pure: the day/night clock (#217). Where in the day the city is at a given
-- server time, the Lighting.ClockTime for it, how bright it is, and where
-- the street lamps stand. No Roblox APIs.

export type Config = {
	periodSeconds: number,
	dawnShare: number,
	dayShare: number,
	duskShare: number,
	nightShare: number,
}
export type Phase = "dawn" | "day" | "dusk" | "night"

local DayCycle = {}

-- 0..1 through the day ("dawn" starts at 0).
function DayCycle.fraction(serverTime: number, offset: number, cfg: Config): number
	local p = cfg.periodSeconds
	return ((serverTime + offset) % p) / p
end

-- Phase, and 0..1 progress through that phase.
function DayCycle.phase(f: number, cfg: Config): (Phase, number)
	local a = cfg.dawnShare
	local b = a + cfg.dayShare
	local c = b + cfg.duskShare
	if f < a then
		return "dawn", f / a
	elseif f < b then
		return "day", (f - a) / cfg.dayShare
	elseif f < c then
		return "dusk", (f - b) / cfg.duskShare
	end
	return "night", (f - c) / math.max(1e-6, 1 - c)
end

-- Lighting.ClockTime: dawn 5→7, day 7→17.5, dusk 17.5→19.5, night 19.5→29 (5 am).
local SPANS = {
	dawn = { 5, 7 },
	day = { 7, 17.5 },
	dusk = { 17.5, 19.5 },
	night = { 19.5, 29 },
}
function DayCycle.clockTime(f: number, cfg: Config): number
	local phase, t = DayCycle.phase(f, cfg)
	local span = SPANS[phase]
	return (span[1] + (span[2] - span[1]) * t) % 24
end

-- 1 = full daylight, 0 = night.
function DayCycle.daylight(f: number, cfg: Config): number
	local phase, t = DayCycle.phase(f, cfg)
	if phase == "day" then
		return 1
	elseif phase == "night" then
		return 0
	elseif phase == "dawn" then
		return t
	end
	return 1 - t
end

-- Lamps glow from mid-dusk to mid-dawn.
function DayCycle.lampsOn(f: number, cfg: Config): boolean
	return DayCycle.daylight(f, cfg) < 0.5
end

-- The offset that puts the clock at the middle of `phase` now (debug).
function DayCycle.offsetFor(phase: Phase, serverTime: number, cfg: Config): number
	local a = cfg.dawnShare
	local b = a + cfg.dayShare
	local c = b + cfg.duskShare
	local mid = if phase == "dawn"
		then a / 2
		elseif phase == "day" then (a + b) / 2
		elseif phase == "dusk" then (b + c) / 2
		else (c + 1) / 2
	local p = cfg.periodSeconds
	return mid * p - (serverTime % p)
end

-- Lamp spots along both long edges of each street, every `spacing` studs,
-- `inset` studs in from the edge (decorative, no collision).
function DayCycle.lampSpots(
	streets: { { x: number, z: number, sx: number, sz: number } },
	spacing: number,
	inset: number
): { { x: number, z: number } }
	local out = {}
	for _, s in streets do
		local alongX = s.sx >= s.sz
		local long = if alongX then s.sx else s.sz
		local half = (if alongX then s.sz else s.sx) / 2 - inset
		local n = math.floor(long / spacing)
		for i = 0, n do
			local along = -long / 2 + (i + 0.5) * (long / (n + 1))
			for _, side in { -1, 1 } do
				if alongX then
					table.insert(out, { x = s.x + along, z = s.z + side * half })
				else
					table.insert(out, { x = s.x + side * half, z = s.z + along })
				end
			end
		end
	end
	return out
end

return table.freeze(DayCycle)
