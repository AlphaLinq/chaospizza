--!strict
-- Event challenges (#200): one optional personal mini-task per event, shown
-- under the event banner. Kinds:
--   hazard       — StyleService hazard marks of `hazard` (counted at most once
--                  per Tuning.Challenges.hazardCooldownSeconds)
--   custom       — the event module reports progress for `key`
--   deliver      — any delivery during the event
--   deliverZone  — a delivery whose door is in MapLayout.zones[`zone`]
--   near         — seconds within `radius` of the CityState Vector3 `state`
--   rooftop      — `minFeet` above the street, not over a street (a roof)

export type Challenge = {
	kind: "hazard" | "custom" | "deliver" | "deliverZone" | "near" | "rooftop",
	goal: number,
	text: string,
	tips: number?,
	hazard: string?,
	key: string?,
	zone: string?,
	state: string?,
	radius: number?,
	minFeet: number?,
}

local function c(def: Challenge): Challenge
	return table.freeze(def)
end

return table.freeze({
	HorseRace = c({ kind = "hazard", hazard = "horse", goal = 3, text = "Dodge 3 horses up close" }),
	Tornado = c({
		kind = "near",
		state = "TornadoPos",
		radius = 35,
		goal = 10,
		text = "Stay near the tornado for 10 s",
	}),
	Flood = c({
		kind = "deliverZone",
		zone = "LowerTown",
		goal = 1,
		text = "Deliver to flooded Lower Town",
	}),
	Blizzard = c({ kind = "deliver", goal = 1, text = "Deliver through the blizzard" }),
	CheeseWheel = c({
		kind = "hazard",
		hazard = "cheese",
		goal = 2,
		text = "Jump over 2 cheese wheels",
	}),
	Blackout = c({ kind = "deliver", goal = 1, text = "Deliver an order in the dark" }),
	BubbleStorm = c({ kind = "hazard", hazard = "bubble", goal = 1, text = "Ride a bubble" }),
	LowGravity = c({ kind = "rooftop", minFeet = 12, goal = 1, text = "Moon-jump onto a rooftop" }),
	MeteorShower = c({ kind = "custom", key = "stardust", goal = 3, text = "Grab 3 stardust" }),
	PizzaRain = c({ kind = "custom", key = "pizza", goal = 5, text = "Catch 5 pizzas" }),
	UfoAbduction = c({
		kind = "hazard",
		hazard = "ufo",
		goal = 1,
		text = "Get abducted (on purpose!)",
	}),
	GiantCat = c({
		kind = "custom",
		key = "bowl",
		goal = 3,
		text = "Toss 3 slices into the cat bowl",
	}),
	WindGust = c({
		kind = "hazard",
		hazard = "gust",
		goal = 3,
		text = "Ride 3 gusts through the air",
	}),
	FloorIsLava = c({
		kind = "hazard",
		hazard = "lava",
		goal = 3,
		text = "Hop over lava 3 times",
	}),
}) :: { [string]: Challenge }
