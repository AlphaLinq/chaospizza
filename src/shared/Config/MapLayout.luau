--!strict
-- Greybox layout of the first district, "Pepperoni Quarter" (brief ch. 6).
-- Pure data, built at server start by MapService. Coordinates are studs:
-- x = east, z = south, ground top at y = 0 (the default Baseplate top).
--
-- Zones used by events (later milestones):
--   MainStreet  — horse race track (M2)
--   Fountain    — tornado route (M3)
--   LowerTown   — flood zone (M3)
--
-- Address ids are saved in player data later: keep them stable.

export type AddressDef = { id: string, label: string, starter: boolean? }

export type BuildingDef = {
	x: number,
	z: number,
	sx: number,
	sz: number,
	h: number,
	color: string,
	door: string,
	address: AddressDef?,
}

local STREET_Y = 0.2 -- street slabs are 0.4 thick, top at 0.4

return table.freeze({
	streetY = STREET_Y,

	-- Flat walkable slabs { name, x, z, sizeX, sizeZ, color }
	streets = table.freeze({
		{ name = "Plaza", x = 0, z = 0, sx = 90, sz = 90, color = "#E8DCC4" },
		{ name = "MainStreet", x = 0, z = -110, sx = 520, sz = 36, color = "#5B5B63" },
		{ name = "NorthAvenue", x = 0, z = -68, sx = 24, sz = 48, color = "#6E6E76" },
		{ name = "WestStreet", x = -85, z = 0, sx = 80, sz = 24, color = "#6E6E76" },
		{ name = "Fountain", x = -160, z = 0, sx = 70, sz = 70, color = "#D9CFB8" },
		{ name = "EastStreet", x = 152, z = 0, sx = 214, sz = 24, color = "#6E6E76" },
		{ name = "SouthAvenue", x = 0, z = 82, sx = 24, sz = 74, color = "#6E6E76" },
		{ name = "HarborLane", x = 0, z = 150, sx = 440, sz = 30, color = "#5B5B63" },
		{ name = "WestConnector", x = -210, z = 20, sx = 20, sz = 230, color = "#6E6E76" },
		{ name = "EastConnector", x = 250, z = 20, sx = 20, sz = 230, color = "#6E6E76" },
	}),

	-- Event zones { x, z, sizeX, sizeZ } (flat rectangles on the ground)
	zones = table.freeze({
		MainStreet = { x = 0, z = -110, sx = 520, sz = 36 },
		Fountain = { x = -160, z = 0, sx = 70, sz = 70 },
		LowerTown = { x = 0, z = 150, sx = 460, sz = 90 },
	}),

	-- Buildings. door = side the door faces ("N","S","E","W").
	-- address: optional delivery address on that door. starter = used for a new
	-- player's first orders (close to the counter).
	buildings = table.freeze({
		-- North row, doors face the main street
		{
			x = -180,
			z = -150,
			sx = 50,
			sz = 36,
			h = 26,
			color = "#C96F53",
			door = "S",
			address = { id = "A01", label = "1 Crust Road" },
		},
		{
			x = -60,
			z = -150,
			sx = 50,
			sz = 36,
			h = 30,
			color = "#7FA7C9",
			door = "S",
			address = { id = "A02", label = "3 Crust Road" },
		},
		{
			x = 60,
			z = -150,
			sx = 50,
			sz = 36,
			h = 24,
			color = "#E3B448",
			door = "S",
			address = { id = "A03", label = "5 Crust Road" },
		},
		{
			x = 180,
			z = -150,
			sx = 50,
			sz = 36,
			h = 28,
			color = "#8CBF88",
			door = "S",
			address = { id = "A04", label = "7 Crust Road" },
		},
		-- Between main street and plaza, doors face the main street
		{
			x = -100,
			z = -68,
			sx = 40,
			sz = 30,
			h = 22,
			color = "#B98BC9",
			door = "N",
			address = { id = "A05", label = "2 Crust Road" },
		},
		{
			x = 110,
			z = -68,
			sx = 60,
			sz = 30,
			h = 24,
			color = "#D98C8C",
			door = "N",
			address = { id = "A06", label = "4 Crust Road", starter = true },
		},
		{ x = -40, z = -68, sx = 32, sz = 30, h = 18, color = "#A8A8A8", door = "N" },
		{ x = 40, z = -68, sx = 32, sz = 30, h = 18, color = "#A8A8A8", door = "N" },
		-- East street
		{
			x = 120,
			z = -30,
			sx = 50,
			sz = 30,
			h = 20,
			color = "#6FB7B7",
			door = "S",
			address = { id = "A07", label = "10 Basil Street", starter = true },
		},
		{
			x = 200,
			z = 32,
			sx = 50,
			sz = 34,
			h = 22,
			color = "#E59A5C",
			door = "N",
			address = { id = "A08", label = "13 Basil Street" },
		},
		-- West street / fountain square
		{
			x = -85,
			z = -30,
			sx = 44,
			sz = 30,
			h = 20,
			color = "#9DB86A",
			door = "S",
			address = { id = "A09", label = "2 Olive Way", starter = true },
		},
		{
			x = -160,
			z = -58,
			sx = 60,
			sz = 40,
			h = 28,
			color = "#C9A26B",
			door = "S",
			address = { id = "A10", label = "1 Fountain Square" },
		},
		{ x = -250, z = -60, sx = 30, sz = 40, h = 20, color = "#A8A8A8", door = "E" },
		{
			x = -160,
			z = 58,
			sx = 60,
			sz = 40,
			h = 24,
			color = "#7F8FC9",
			door = "N",
			address = { id = "A11", label = "3 Fountain Square" },
		},
		-- Lower town (flood zone), doors face harbor lane
		{
			x = -140,
			z = 190,
			sx = 60,
			sz = 44,
			h = 20,
			color = "#5FA3B8",
			door = "N",
			address = { id = "A12", label = "8 Harbor Lane" },
		},
		{
			x = -20,
			z = 190,
			sx = 60,
			sz = 44,
			h = 22,
			color = "#D4C26A",
			door = "N",
			address = { id = "A13", label = "10 Harbor Lane" },
		},
		{
			x = 120,
			z = 190,
			sx = 60,
			sz = 44,
			h = 18,
			color = "#C97FA0",
			door = "N",
			address = { id = "A14", label = "12 Harbor Lane" },
		},
		{ x = -110, z = 112, sx = 70, sz = 30, h = 16, color = "#A8A8A8", door = "S" },
		{ x = 110, z = 112, sx = 70, sz = 30, h = 16, color = "#A8A8A8", door = "S" },
	} :: { BuildingDef }),

	-- Pizza HQ counter (order pickup) and player spawn on the plaza
	counter = { x = 0, z = -22 },
	spawn = { x = 0, z = 26 },
	-- Giant city chaos meter on the plaza (brief ch. 15)
	chaosMeter = { x = 22, z = 2 },
	-- Where giant co-op orders appear (brief ch. 13)
	giantOrder = { x = 0, z = 6 },
	-- Hourly city goal board (#133), mirrors the chaos meter
	cityGoalBoard = { x = -22, z = 2 },

	-- 12 pizzeria plots around the plaza edge (used from M5)
	plots = table.freeze({
		{ x = -36, z = -36 },
		{ x = -12, z = -38 },
		{ x = 12, z = -38 },
		{ x = 36, z = -36 },
		{ x = 38, z = -12 },
		{ x = 38, z = 12 },
		{ x = 36, z = 36 },
		{ x = 12, z = 38 },
		{ x = -12, z = 38 },
		{ x = -36, z = 36 },
		{ x = -38, z = 12 },
		{ x = -38, z = -12 },
	}),

	-- Tornado routes (waypoints on open streets; the funnel loops along one)
	tornadoRoutes = table.freeze({
		{
			{ x = -210, z = -100 },
			{ x = -210, z = 0 },
			{ x = -160, z = 0 },
			{ x = -95, z = 0 },
			{ x = -55, z = 0 },
		},
		{
			{ x = -60, z = 0 },
			{ x = -160, z = 0 },
			{ x = -160, z = 28 },
			{ x = -203, z = 28 },
			{ x = -210, z = 60 },
			{ x = -210, z = 140 },
			{ x = -120, z = 150 },
		},
		{ { x = -200, z = 150 }, { x = -60, z = 150 }, { x = 60, z = 150 }, { x = 200, z = 150 } },
	}),

	-- Runaway cheese wheel routes (#140): open streets only, clear of the
	-- plaza spawn and the safe spots; a run may go either way.
	cheeseRoutes = table.freeze({
		{ { x = -255, z = -110 }, { x = 255, z = -110 } },
		{ { x = 250, z = -95 }, { x = 250, z = 130 } },
		{ { x = -210, z = -95 }, { x = -210, z = 0 }, { x = -50, z = 0 } },
		{ { x = 215, z = 150 }, { x = -215, z = 150 } },
	}),

	-- Pizza cannons (#147): stand in, get shot across town. y = muzzle height;
	-- landing points are open street spots (checked in tests).
	cannons = table.freeze({
		{ name = "Harbor Express", x = 8, z = 62, to = { x = 150, z = 150 } },
		{ name = "Crust Road Shot", x = 220, z = -8, to = { x = -180, z = -110 } },
		{ name = "Fountain Flinger", x = -178, z = -24, to = { x = 180, z = 0 } },
		{ name = "Homeward Bun", x = -150, z = 158, to = { x = -10, z = 18 } },
	}),

	-- Overpass across the main street (safe crossing during the horse race)
	overpass = { x = 0, zNorth = -134, zSouth = -86, deckY = 14, width = 12, rampLength = 34 },

	-- Safe respawn points (used by unstuck / event knockback recovery)
	safeSpots = table.freeze({
		{ x = 0, z = 30 },
		{ x = -160, z = 20 },
		{ x = 150, z = 0 },
		{ x = 0, z = 95 },
		{ x = -200, z = -130 },
		{ x = 200, z = -130 },
	}),

	bounds = { minX = -280, maxX = 280, minZ = -190, maxZ = 230, wallHeight = 60 },
})
