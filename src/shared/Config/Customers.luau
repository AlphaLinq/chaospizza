--!strict
-- Starter customer pool: 24 customers (brief ch. 9.3). Shape: Types.CustomerDef.
-- Models/animations are added in the content ticket; ids must stay stable
-- because they are saved in player profiles.

local function c(id: string, displayName: string, rarity: string, event: string?, line: string)
	return table.freeze({
		id = id,
		displayName = displayName,
		rarity = rarity,
		event = event,
		line = line,
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
})
