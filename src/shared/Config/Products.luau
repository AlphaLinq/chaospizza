--!strict
-- Robux products (brief ch. 18). Starting price hypotheses — tune with data.
-- IDs stay 0 until the items are created on the Creator Hub (M8). Code must
-- treat id 0 as "not available yet". The server always looks prices/ids up
-- here, never from the client.

return table.freeze({
	Gamepasses = table.freeze({
		table.freeze({
			key = "DoubleTips",
			displayName = "Double Tips",
			priceRobux = 299,
			gamepassId = 0,
		}),
		table.freeze({
			key = "VipCourier",
			displayName = "VIP Courier",
			priceRobux = 199,
			gamepassId = 0,
		}),
		table.freeze({
			key = "ExtraRegularSlots",
			displayName = "+4 Regular Seats",
			priceRobux = 249,
			gamepassId = 0,
		}),
		table.freeze({
			key = "LongShift",
			displayName = "Long Shift (8h offline tips)",
			priceRobux = 149,
			gamepassId = 0,
		}),
		table.freeze({
			key = "EarlyEScooter",
			displayName = "E-Scooter Early Access",
			priceRobux = 199,
			gamepassId = 0,
		}),
		table.freeze({
			key = "AutoCollect",
			displayName = "Auto-Collect Tips",
			priceRobux = 99,
			gamepassId = 0,
		}),
	}),
	Products = table.freeze({
		table.freeze({
			key = "OrderDisaster",
			displayName = "Order a Disaster!",
			priceRobux = 49,
			productId = 0,
			changesOdds = false,
		}),
		table.freeze({
			key = "MegaChaosNow",
			displayName = "MEGA CHAOS Now!",
			priceRobux = 199,
			productId = 0,
			changesOdds = true,
		}),
		table.freeze({
			key = "PizzaScentCloud",
			displayName = "Pizza Scent Cloud (10 min)",
			priceRobux = 39,
			productId = 0,
			changesOdds = true,
		}),
		table.freeze({
			key = "TipBoost",
			displayName = "Tip Boost x2 (15 min)",
			priceRobux = 29,
			productId = 0,
			changesOdds = false,
		}),
		table.freeze({
			key = "TipsSmall",
			displayName = "Small Tip Jar",
			priceRobux = 25,
			productId = 0,
			changesOdds = false,
		}),
		table.freeze({
			key = "TipsMedium",
			displayName = "Medium Tip Jar",
			priceRobux = 99,
			productId = 0,
			changesOdds = false,
		}),
		table.freeze({
			key = "TipsLarge",
			displayName = "Huge Tip Jar",
			priceRobux = 399,
			productId = 0,
			changesOdds = false,
		}),
		table.freeze({
			key = "StarterPack",
			displayName = "Starter Pack",
			priceRobux = 99,
			productId = 0,
			changesOdds = false,
		}),
	}),
})
