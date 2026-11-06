--!strict
-- Starter customer pool: 24 customers (brief ch. 9.3). Shape: Types.CustomerDef.
-- Models/animations are added in the content ticket; ids must stay stable
-- because they are saved in player profiles.

local function c(
	id: string,
	displayName: string,
	rarity: string,
	event: string?,
	line: string,
	seasonal: boolean?
)
	return table.freeze({
		id = id,
		displayName = displayName,
		rarity = rarity,
		event = event,
		line = line,
		seasonal = seasonal,
	})
end

return table.freeze({
	-- Normal times (12)
	c(
		"SleepyStudent",
		"Sleepy Student",
		"Common",
		nil,
		"Is it breakfast or dinner? Doesn't matter. Pizza."
	),
	c("JoggingGrandpa", "Jogging Grandpa", "Common", nil, "Just in time for my 40th lap!"),
	c(
		"SelfieInfluencer",
		"Selfie Influencer",
		"Common",
		nil,
		"Wait, hold it closer to my face. For the fans."
	),
	c("LostTourist", "Lost Tourist", "Common", nil, "Is this the Eiffel Tower? No? Thanks anyway!"),
	c("GardenerAuntie", "Gardener Auntie", "Common", nil, "Basil on top? I grew that basil."),
	c("GamerKid", "Gamer Kid", "Uncommon", nil, "Pause! PAUSE! Okay, pizza's here."),
	c("MailDog", "Mail Dog", "Uncommon", nil, "Woof. (He tips in tennis balls.)"),
	c("StatueMan", "Statue Man", "Uncommon", nil, "...  ...  (He blinked. He definitely blinked.)"),
	c("SecretAgent", "Secret Agent", "Rare", nil, "You never saw me. Extra cheese, though."),
	c("Magician", "The Magician", "Rare", nil, "Is this your pizza? It IS your pizza!"),
	c("EscalatorBot", "Escalator Repair Bot", "Epic", nil, "BEEP. SLICE ACQUIRED. GOING UP."),
	c("TheMayor", "The Mayor", "Epic", nil, "Officially the best delivery in town. I'd know."),

	-- Tornado (4)
	c(
		"StormChaserGranny",
		"Storm Chaser Granny",
		"Rare",
		"Tornado",
		"Did you see that funnel? Gorgeous!"
	),
	c(
		"WeathervaneKnight",
		"Weathervane Knight",
		"Rare",
		"Tornado",
		"I point wherever the wind says. Today: pizza."
	),
	c("FlyingCow", "Flying Cow", "Epic", "Tornado", "Moo-ving at 80 mph. Thanks for catching up."),
	c(
		"TornadoKid",
		"Tornado Kid",
		"Legendary",
		"Tornado",
		"I'm not IN the tornado. I AM the tornado."
	),

	-- Flood (4)
	c(
		"RubberDuckCaptain",
		"Rubber Duck Captain",
		"Uncommon",
		"Flood",
		"Ahoy! Permission to board with pepperoni."
	),
	c(
		"BalconyMermaid",
		"Balcony Mermaid",
		"Rare",
		"Flood",
		"Finally, someone who delivers to the 2nd floor."
	),
	c("ScubaWaiter", "Scuba Waiter", "Epic", "Flood", "Table for one, underwater section, please."),
	c(
		"TheShark",
		"The Shark Himself",
		"Legendary",
		"Flood",
		"I was chasing you for the pizza. Obviously."
	),

	-- Horse race (4)
	c("Jockey", "Jockey", "Uncommon", "HorseRace", "Quick, one slice before the next lap!"),
	c(
		"RaceAnnouncer",
		"Race Announcer",
		"Rare",
		"HorseRace",
		"AND THE PIZZA CROSSES THE LINE FIRST!"
	),
	c(
		"PonyPaparazzi",
		"Pony Paparazzi",
		"Epic",
		"HorseRace",
		"Smile for the camera! Neigh, wider!"
	),
	c(
		"GoldenHorseshoe",
		"Golden Horseshoe Horse",
		"Legendary",
		"HorseRace",
		"I don't run for medals. I run for pizza."
	),

	-- Runaway cheese wheel (4, #140)
	c(
		"CheeseRoller",
		"Cheese Roller",
		"Uncommon",
		"CheeseWheel",
		"I've chased cheese down fourteen hills. Pizza is easier."
	),
	c(
		"MouseFamily",
		"Mouse Family",
		"Rare",
		"CheeseWheel",
		"We followed that wheel for a week. A pizza will do."
	),
	c(
		"Fromager",
		"The Fromager",
		"Epic",
		"CheeseWheel",
		"Aged twenty-four months, rolled three miles. Exquisite."
	),
	c(
		"TheBigCheese",
		"The Big Cheese",
		"Legendary",
		"CheeseWheel",
		"Yes, I'm the boss. Yes, it's my wheel. Extra cheese, obviously."
	),

	-- Blackout (4, #131): only order while the city is dark.
	c(
		"FlashlightKid",
		"Flashlight Kid",
		"Uncommon",
		"Blackout",
		"Is this a power cut or a sleepover? Both!"
	),
	c("NightOwl", "Night Owl", "Rare", "Blackout", "Hoo ordered a pizza? Me. Hoo."),
	c(
		"CandleGhost",
		"Candle Ghost",
		"Epic",
		"Blackout",
		"Boo! ...Sorry, reflex. Thanks for the pizza."
	),
	c(
		"LighthouseKeeper",
		"Lighthouse Keeper",
		"Legendary",
		"Blackout",
		"I keep the light on for ships. And for pizza."
	),

	-- Bubble Storm (4, #161)
	c(
		"SoapChemist",
		"Soap Chemist",
		"Uncommon",
		"BubbleStorm",
		"In my defence, the label said 'mild'."
	),
	c(
		"BubbleBaby",
		"Bubble Baby",
		"Rare",
		"BubbleStorm",
		"Bwub! Bwub bwub. (Translation: extra cheese.)"
	),
	c(
		"FloatingFrank",
		"Floating Frank",
		"Epic",
		"BubbleStorm",
		"Been up here since lunch. Toss it up, will you?"
	),
	c(
		"TheBubbleQueen",
		"The Bubble Queen",
		"Legendary",
		"BubbleStorm",
		"My kingdom is round, shiny and pops easily. Like this pizza box."
	),

	-- Moon Walk (4, #180)
	c(
		"AstronautAnn",
		"Astronaut Ann",
		"Uncommon",
		"LowGravity",
		"One small step for me, one large pizza for mankind."
	),
	c(
		"MoonRabbit",
		"Moon Rabbit",
		"Rare",
		"LowGravity",
		"I usually eat mochi up there. Pizza is a nice change."
	),
	c(
		"SpaceGranny",
		"Space Granny",
		"Epic",
		"LowGravity",
		"In my day we floated uphill both ways."
	),
	c(
		"ManInTheMoon",
		"The Man in the Moon",
		"Legendary",
		"LowGravity",
		"I've watched you all from up here. Extra cheese, please."
	),

	-- Meteor Shower (4, #181)
	c(
		"StargazerStan",
		"Stargazer Stan",
		"Uncommon",
		"MeteorShower",
		"I wished on a shooting star. It wished back. With fire."
	),
	c(
		"RockCollector",
		"Space Rock Collector",
		"Rare",
		"MeteorShower",
		"Is that crater still warm? Asking for my collection."
	),
	c(
		"CometKid",
		"Comet Kid",
		"Epic",
		"MeteorShower",
		"I'm basically a comet. Fast, shiny, hungry."
	),
	c(
		"AstronomerRoyal",
		"The Astronomer Royal",
		"Legendary",
		"MeteorShower",
		"I predicted this shower to the second. Pizza, sadly, I did not."
	),

	-- Pizza Rain (4, #182)
	c(
		"OpenMouthOscar",
		"Open-Mouth Oscar",
		"Uncommon",
		"PizzaRain",
		"I've been standing here with my mouth open for an hour. Delivery is fine too."
	),
	c(
		"WeatherWitch",
		"Weather Witch",
		"Rare",
		"PizzaRain",
		"I ordered sunshine. Got pizza. Not complaining."
	),
	c("RainDancer", "Rain Dancer", "Epic", "PizzaRain", "One more dance and it rains calzones!"),
	c(
		"ChefInTheClouds",
		"Chef in the Clouds",
		"Legendary",
		"PizzaRain",
		"Sorry about the mess. My oven is up there somewhere."
	),

	-- UFO Abduction (4, #183)
	c(
		"LittleGlorp",
		"Little Glorp",
		"Uncommon",
		"UfoAbduction",
		"Glorp! (Translation: is this the famous Earth disc?)"
	),
	c(
		"ProbePete",
		"Probe Pete",
		"Rare",
		"UfoAbduction",
		"I'm only here for research. The research is pizza."
	),
	c(
		"MothershipMom",
		"Mothership Mom",
		"Epic",
		"UfoAbduction",
		"I came 40 light years because the kids wanted 'the cheesy one'."
	),
	c(
		"GalacticOverlord",
		"The Galactic Overlord",
		"Legendary",
		"UfoAbduction",
		"Your planet is spared. Your pizza is not."
	),

	-- Christmas season (Blizzard event, M9). Limited: only during the season.
	c(
		"SnowmanSam",
		"Snowman Sam",
		"Uncommon",
		"Blizzard",
		"Hot pizza? Bold choice. I respect it.",
		true
	),
	c(
		"GingerbreadKid",
		"Gingerbread Kid",
		"Rare",
		"Blizzard",
		"Run, run, as fast as you can… with extra cheese!",
		true
	),
	c(
		"ElfCourier",
		"Elf Courier",
		"Rare",
		"Blizzard",
		"Finally, a delivery I didn't have to make myself.",
		true
	),
	c(
		"ReindeerRudi",
		"Reindeer Rudi",
		"Epic",
		"Blizzard",
		"My nose is red from the cold, not the hot sauce.",
		true
	),
	c(
		"SantaHimself",
		"Santa Himself",
		"Legendary",
		"Blizzard",
		"Ho ho ho! You're on the nice list. Five stars.",
		true
	),
})
