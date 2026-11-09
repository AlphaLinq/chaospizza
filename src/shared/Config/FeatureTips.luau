--!strict
-- First-time tips for the new loop (#211): shown once per courier, the first
-- time they meet the feature. Text is player-facing English; HU in Strings.

export type Tip = { icon: string, title: string, text: string }

return table.freeze({
	OfferBoard = table.freeze({
		icon = "🍕",
		title = "Pick your order!",
		text = "🏃 Quick hop = safe. 🗺️ Long haul = more tips, rarer customers. 😈 Daredevil = ×2 in the danger zone!",
	}),
	Vote = table.freeze({
		icon = "🗳️",
		title = "The city votes!",
		text = "Choose the next disaster on the right. Change your mind any time before it starts.",
	}),
	Challenge = table.freeze({
		icon = "🎯",
		title = "Event challenge",
		text = "Every disaster has a little task under the banner. Pull it off for bonus tips!",
	}),
	Finale = table.freeze({
		icon = "🎆",
		title = "Chaos finale soon",
		text = "Two disasters at once! Deliver during the finale for a bonus — the best courier becomes the hero.",
	}),
	MicroChaos = table.freeze({
		icon = "🛒",
		title = "Street surprise!",
		text = "Little chaos pops up between disasters. Bumps never break your streak — boxes give free tips.",
	}),
}) :: { [string]: Tip }
