--!strict
-- Pure time-trial rules (#163): checkpoint hits, impossible legs, scores and
-- the weekly key. Positions are plain numbers so tests run outside Roblox.

export type Point = { x: number, y: number, z: number }
export type Config = {
	checkpointRadius: number,
	checkpointHeight: number,
	legSpeedSlack: number,
	maxScoreMs: number,
}

local Trial = {}

function Trial.hits(p: Point, checkpoint: Point, cfg: Config): boolean
	local dx, dz = p.x - checkpoint.x, p.z - checkpoint.z
	return dx * dx + dz * dz <= cfg.checkpointRadius * cfg.checkpointRadius
		and math.abs(p.y - checkpoint.y) <= cfg.checkpointHeight
end

-- True when a leg of `distance` studs took less time than the fastest
-- courier could possibly need.
function Trial.impossibleLeg(
	distance: number,
	seconds: number,
	fastestSpeed: number,
	cfg: Config
): boolean
	return seconds < distance / (fastestSpeed * cfg.legSpeedSlack)
end

function Trial.score(ms: number, cfg: Config): number
	return math.max(0, cfg.maxScoreMs - math.floor(ms))
end

function Trial.msFromScore(score: number, cfg: Config): number
	return cfg.maxScoreMs - score
end

function Trial.week(now: number): number
	return math.floor(now / (7 * 86400))
end

function Trial.format(ms: number): string
	local total = math.max(0, math.floor(ms))
	local minutes = total // 60000
	local seconds = (total % 60000) / 1000
	return string.format("%d:%05.2f", minutes, seconds)
end

return Trial
