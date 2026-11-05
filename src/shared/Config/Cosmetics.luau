--!strict
local function item(
	id: string,
	name: string,
	slot: string,
	color: string,
	accent: string,
	price: number?,
	free: boolean?
)
	return table.freeze({
		id = id,
		name = name,
		slot = slot,
		color = color,
		accent = accent,
		price = price,
		free = free == true,
	})
end
return table.freeze({
	requestTimeoutSeconds = 8,
	unlockHints = table.freeze({
		CommunityBag = "Join the Roblox community",
		WeekOneJar = "Claim your seventh daily reward",
		StarterPizzaBox = "Included in the Starter Pack",
		HospitalityLegend = "Serve 24 different customers",
	}),
	defaults = table.freeze({
		box = "ClassicBox",
		bag = "ClassicBag",
		uniform = "ClassicUniform",
		movement = "ClassicMovement",
		decor = "ClassicDecor",
		jar = "ClassicJar",
	}),
	slots = table.freeze({ "box", "bag", "uniform", "movement", "decor", "jar", "title" }),
	items = table.freeze({
		item("CommunityBag", "Community Courier · Bag", "bag", "#68C8A4", "#FFF3D6", nil),
		item("ClassicBox", "Classic Courier · Box", "box", "#D9A66B", "#C0392B", nil, true),
		item("ClassicBag", "Classic Courier · Bag", "bag", "#D6452F", "#FFF3D6", nil, true),
		item(
			"ClassicUniform",
			"Classic Courier · Apron",
			"uniform",
			"#FFF3D6",
			"#D6452F",
			nil,
			true
		),
		item(
			"ClassicMovement",
			"Classic Courier · Shoes",
			"movement",
			"#D6452F",
			"#FFF3D6",
			nil,
			true
		),
		item("ClassicDecor", "Classic Courier · Sign", "decor", "#D6452F", "#FFF3D6", nil, true),
		item("ClassicJar", "Classic Courier · Jar", "jar", "#D6452F", "#FFF3D6", nil, true),
		item("ExtraCheeseBox", "Extra Cheese · Box", "box", "#FFD24A", "#D6452F", 750),
		item("ExtraCheeseBag", "Extra Cheese · Bag", "bag", "#FFD24A", "#FFF3D6", 1000),
		item("ExtraCheeseUniform", "Extra Cheese · Apron", "uniform", "#FFD24A", "#D6452F", 1250),
		item(
			"ExtraCheeseMovement",
			"Extra Cheese · Shoes",
			"movement",
			"#FFD24A",
			"#D6452F",
			1500
		),
		item("ExtraCheeseDecor", "Extra Cheese · Sign", "decor", "#FFD24A", "#D6452F", 2000),
		item("ExtraCheeseJar", "Extra Cheese · Jar", "jar", "#FFD24A", "#D6452F", 1500),
		item("WeekOneJar", "Seven-Day Special · Jar", "jar", "#68C8A4", "#FFF3D6", nil),
		item("StarterPizzaBox", "Starter Special · Box", "box", "#8062BD", "#FFD24A", nil),
		item("HospitalityLegend", "Hospitality Legend", "title", "#FFD24A", "#FFF3D6", nil),
	}),
})
