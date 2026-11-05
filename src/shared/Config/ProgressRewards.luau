--!strict
-- Initial economy tuning for brief 9.4 and 17. No paid advantage is granted.
return table.freeze({
	maxTips = 1e12,
	levelTipsBase = 25,
	levelTipsGrowth = 10,
	book = table.freeze({
		table.freeze({ count = 5, tips = 150, cosmetic = "ExtraCheeseBox" }),
		table.freeze({ count = 10, tips = 300, cosmetic = "ExtraCheeseBag" }),
		table.freeze({ count = 15, tips = 600, cosmetic = "ExtraCheeseUniform" }),
		table.freeze({ count = 20, tips = 1000, cosmetic = "ExtraCheeseDecor" }),
		table.freeze({
			count = 24,
			tips = 2000,
			cosmetic = "HospitalityLegend",
			title = "Hospitality Legend",
		}),
	}),
})
