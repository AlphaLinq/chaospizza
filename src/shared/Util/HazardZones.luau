--!strict
-- Pure: is a ground position inside a live event hazard? Used to keep
-- (re)spawning couriers out of danger during events (AGENTS 4.6).

export type Zone = { x: number, z: number, sx: number, sz: number }
export type Hazards = {
	events: { string }, -- active event ids (MEGA: two)
	tornadoX: number?,
	tornadoZ: number?,
	tornadoRadius: number?,
}
export type Zones = { [string]: Zone }

local HazardZones = {}

-- Which map zone each event makes dangerous (MapLayout.zones keys).
HazardZones.EVENT_ZONE = table.freeze({
	HorseRace = "MainStreet",
	Flood = "LowerTown",
	GiantCat = "Fountain", -- swipes around the square (#184)
})

local function inZone(x: number, z: number, zone: Zone, margin: number): boolean
	return math.abs(x - zone.x) <= zone.sx / 2 + margin
		and math.abs(z - zone.z) <= zone.sz / 2 + margin
end

function HazardZones.isUnsafe(
	x: number,
	z: number,
	hazards: Hazards,
	zones: Zones,
	margin: number
): boolean
	for _, id in hazards.events do
		local zoneName = HazardZones.EVENT_ZONE[id]
		local zone = zoneName and zones[zoneName]
		if zone and inZone(x, z, zone, margin) then
			return true
		end
		if id == "Tornado" and hazards.tornadoX and hazards.tornadoZ then
			local r = (hazards.tornadoRadius or 0) + margin
			local dx, dz = x - hazards.tornadoX, z - (hazards.tornadoZ :: number)
			if dx * dx + dz * dz <= r * r then
				return true
			end
		end
	end
	return false
end

-- First safe candidate {x, z}, or nil if every candidate is in danger.
function HazardZones.pickSafe(
	candidates: { { x: number, z: number } },
	hazards: Hazards,
	zones: Zones,
	margin: number
): { x: number, z: number }?
	for _, c in candidates do
		if not HazardZones.isUnsafe(c.x, c.z, hazards, zones, margin) then
			return c
		end
	end
	return nil
end

return table.freeze(HazardZones)
