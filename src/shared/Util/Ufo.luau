--!strict
-- Pure UFO motion and beam timing (#183), shared by the server (abductions)
-- and the client (drawing). A UFO loops its closed route; its beam cycles
-- warn → on → rest, offset per UFO.

-- RoutePath is passed in (no script requires: this stays testable).
type Point = { x: number, z: number }
type Path = {
	length: (route: { Point }) -> number,
	sample: (route: { Point }, distance: number) -> (number, number, number, number, boolean),
}

export type Saucer = { id: number, route: number, t0: number, offset: number }
export type Config = {
	speed: number,
	beamCycleSeconds: number,
	beamWarnSeconds: number,
	beamOnSeconds: number,
}
export type BeamState = "rest" | "warn" | "on"

local Ufo = {}

function Ufo.position(
	path: Path,
	route: { Point },
	s: Saucer,
	now: number,
	cfg: Config
): (number, number)
	local length = path.length(route)
	local d = (cfg.speed * (now - s.t0) + s.offset * length) % length
	local x, z = path.sample(route, d)
	return x, z
end

function Ufo.beam(s: Saucer, now: number, cfg: Config): BeamState
	local cycle = (now - s.t0 + s.offset * cfg.beamCycleSeconds) % cfg.beamCycleSeconds
	if cycle < cfg.beamWarnSeconds then
		return "warn"
	elseif cycle < cfg.beamWarnSeconds + cfg.beamOnSeconds then
		return "on"
	end
	return "rest"
end

return Ufo
