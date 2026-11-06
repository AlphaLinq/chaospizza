--!strict
-- Golden pepperoni collectibles (#132). 30 hidden spots (balconies via their
-- ladders, the overpass, street ends). Each UTC day every courier gets
-- `perDay` active spots, unfound ones first; collecting all 30 is the goal.
-- Positions: coin centre; server pickup radius is `pickupRadius`.

export type Spot = { id: string, x: number, y: number, z: number, hint: string }

return table.freeze({
	perDay = 10,
	pickupRadius = 5,
	tipsPerFind = 25,
	repeatTips = 10, -- an already found spot reactivated after all are found
	completeTips = 500,
	daySeconds = 86400, -- UTC day
	spots = table.freeze({
		{ id = "GP01", x = -176, y = 15.4, z = -129, hint = "On the balcony of 1 Crust Road" },
		{ id = "GP02", x = -56, y = 15.4, z = -129, hint = "On the balcony of 3 Crust Road" },
		{ id = "GP03", x = 64, y = 15.4, z = -129, hint = "On the balcony of 5 Crust Road" },
		{ id = "GP04", x = 184, y = 15.4, z = -129, hint = "On the balcony of 7 Crust Road" },
		{ id = "GP05", x = -96, y = 15.4, z = -86, hint = "On the balcony of 2 Crust Road" },
		{ id = "GP06", x = 114, y = 15.4, z = -86, hint = "On the balcony of 4 Crust Road" },
		{ id = "GP07", x = 124, y = 15.4, z = -12, hint = "On the balcony of 10 Basil Street" },
		{ id = "GP08", x = 204, y = 15.4, z = 12, hint = "On the balcony of 13 Basil Street" },
		{ id = "GP09", x = -81, y = 15.4, z = -12, hint = "On the balcony of 2 Olive Way" },
		{ id = "GP10", x = -156, y = 15.4, z = -35, hint = "On the balcony of 1 Fountain Square" },
		{ id = "GP11", x = -156, y = 15.4, z = 35, hint = "On the balcony of 3 Fountain Square" },
		{ id = "GP12", x = -136, y = 15.4, z = 165, hint = "On the balcony of 8 Harbor Lane" },
		{ id = "GP13", x = -16, y = 15.4, z = 165, hint = "On the balcony of 10 Harbor Lane" },
		{ id = "GP14", x = 124, y = 15.4, z = 165, hint = "On the balcony of 12 Harbor Lane" },
		{ id = "GP15", x = 0, y = 17, z = -95, hint = "On the overpass, north end" },
		{ id = "GP16", x = 0, y = 17, z = -110, hint = "In the middle of the overpass" },
		{ id = "GP17", x = 0, y = 17, z = -125, hint = "On the overpass, south end" },
		{ id = "GP18", x = 0, y = 3, z = -110, hint = "In the shade under the overpass" },
		{ id = "GP19", x = -152, y = 4.9, z = -8, hint = "On the rim of the fountain basin" },
		{ id = "GP20", x = -255, y = 3, z = -110, hint = "At the far west end of Main Street" },
		{ id = "GP21", x = 255, y = 3, z = -110, hint = "At the far east end of Main Street" },
		{ id = "GP22", x = -215, y = 3, z = 150, hint = "Where Harbor Lane ends in the west" },
		{ id = "GP23", x = 215, y = 3, z = 150, hint = "Where Harbor Lane ends in the east" },
		{ id = "GP24", x = 250, y = 3, z = -90, hint = "North end of the east connector" },
		{ id = "GP25", x = 250, y = 3, z = 128, hint = "South end of the east connector" },
		{ id = "GP26", x = -210, y = 3, z = -90, hint = "North end of the west connector" },
		{ id = "GP27", x = -210, y = 3, z = 128, hint = "South end of the west connector" },
		{ id = "GP28", x = 255, y = 3, z = 0, hint = "At the very end of Basil Street" },
		{ id = "GP29", x = 0, y = 3, z = 115, hint = "Bottom of South Avenue" },
		{ id = "GP30", x = -192, y = 3, z = 0, hint = "West edge of Fountain Square" },
	}) :: { Spot },
})
