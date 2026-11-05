--!strict
-- Robux products (brief ch. 18). Starting price hypotheses — tune with data.
-- IDs stay 0 until the items are created on the Creator Hub (M8). Code must
-- treat id 0 as "not available yet". The server always looks prices/ids up
-- here, never from the client.

export type Effect = {
	tipMultiplier: number?,
	rarePlusMultiplier: number?,
	kind: string?,
	eventId: string?,
	boostKey: string?,
	tips: number?,
	cosmetic: string?,
}
export type Pass = {
	key: string,
	displayName: string,
	priceRobux: number,
	gamepassId: number,
	effect: Effect?,
}
export type Product = {
	key: string,
	displayName: string,
	priceRobux: number,
	productId: number,
	changesOdds: boolean,
	effect: Effect?,
	durationSeconds: number?,
	starterMaxDays: number?,
}
local function pass(value: Pass): Pass
	return table.freeze(value)
end
local function product(value: Product): Product
	return table.freeze(value)
end

return table.freeze({
	Limits = table.freeze({
		secondsPerDay = 86400,
		maxTipMultiplier = 4,
		maxOddsMultiplier = 2,
		maxDurationSeconds = 7 * 86400,
		maxPending = 20,
		maxTips = 1e12,
	}),
	Gamepasses = table.freeze({
		pass({
			key = "DoubleTips",
			effect = table.freeze({ tipMultiplier = 2 }),
			displayName = "Double Tips",
			priceRobux = 299,
			gamepassId = 0,
		}),
		pass({
			key = "VipCourier",
			displayName = "VIP Courier",
			priceRobux = 199,
			gamepassId = 0,
		}),
		pass({
			key = "ExtraRegularSlots",
			displayName = "+4 Regular Seats",
			priceRobux = 249,
			gamepassId = 0,
		}),
		pass({
			key = "LongShift",
			displayName = "Long Shift (8h offline tips)",
			priceRobux = 149,
			gamepassId = 0,
		}),
		pass({
			key = "EarlyEScooter",
			displayName = "E-Scooter Early Access",
			priceRobux = 199,
			gamepassId = 0,
		}),
		pass({
			key = "AutoCollect",
			displayName = "Auto-Collect Tips",
			priceRobux = 99,
			gamepassId = 0,
		}),
	}),
	Products = table.freeze({
		product({
			key = "OrderDisaster",
			effect = table.freeze({ kind = "event", eventId = "Tornado" }),
			displayName = "Order a Disaster!",
			priceRobux = 49,
			productId = 0,
			changesOdds = false,
		}),
		product({
			key = "MegaChaosNow",
			effect = table.freeze({ kind = "event" }),
			displayName = "MEGA CHAOS Now!",
			priceRobux = 199,
			productId = 0,
			changesOdds = true,
		}),
		product({
			key = "PizzaScentCloud",
			durationSeconds = 600,
			effect = table.freeze({ boostKey = "PizzaScentCloud", rarePlusMultiplier = 2 }),
			displayName = "Pizza Scent Cloud (10 min)",
			priceRobux = 39,
			productId = 0,
			changesOdds = true,
		}),
		product({
			key = "TipBoost",
			durationSeconds = 900,
			effect = table.freeze({ boostKey = "TipBoost", tipMultiplier = 2 }),
			displayName = "Tip Boost x2 (15 min)",
			priceRobux = 29,
			productId = 0,
			changesOdds = false,
		}),
		product({
			key = "TipsSmall",
			effect = table.freeze({ tips = 250 }),
			displayName = "Small Tip Jar",
			priceRobux = 25,
			productId = 0,
			changesOdds = false,
		}),
		product({
			key = "TipsMedium",
			effect = table.freeze({ tips = 1200 }),
			displayName = "Medium Tip Jar",
			priceRobux = 99,
			productId = 0,
			changesOdds = false,
		}),
		product({
			key = "TipsLarge",
			effect = table.freeze({ tips = 5000 }),
			displayName = "Huge Tip Jar",
			priceRobux = 399,
			productId = 0,
			changesOdds = false,
		}),
		product({
			key = "StarterPack",
			durationSeconds = 1800,
			effect = table.freeze({
				boostKey = "TipBoost",
				tips = 500,
				cosmetic = "StarterPizzaBox",
			}),
			starterMaxDays = 3,
			displayName = "Starter Pack",
			priceRobux = 99,
			productId = 0,
			changesOdds = false,
		}),
	}),
})
