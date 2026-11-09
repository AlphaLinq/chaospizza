--!strict
-- "What's new" panel (#268): shown once per `version` to returning couriers.
-- Bump `version` with every big update and rewrite the lines. English here,
-- HU in Strings.

export type Line = { icon: string, text: string }

return table.freeze({
	version = "2026-11-wave3",
	title = "What's new in Pizza Chaos!",
	minDeliveries = 5, -- brand-new couriers get the onboarding instead
	delaySeconds = 20, -- after the profile loads (let the daily reward go first)
	lines = table.freeze({
		table.freeze({
			icon = "🌋",
			text = "New disaster: The Floor Is Lava! Hop the glowing tiles.",
		}),
		table.freeze({
			icon = "💨",
			text = "New disaster: Gale Force! Hide from the gusts or ride them.",
		}),
		table.freeze({
			icon = "🍕",
			text = "Toss the pizza from the street: tap Toss (F) near the door.",
		}),
		table.freeze({
			icon = "📖",
			text = "Story orders: little stories in 3 chapters on the order board.",
		}),
		table.freeze({ icon = "🌙", text = "Night-only customers. Stay up late!" }),
		table.freeze({
			icon = "🚚",
			text = "Deliver together for a Convoy bonus, and high-five (H) friends.",
		}),
		table.freeze({ icon = "🧾", text = "A shift report after every chaos finale." }),
	}) :: { Line },
})
