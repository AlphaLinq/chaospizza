--!strict
-- Customer quirks (#139): some customers have a funny request. Meet it at
-- delivery and the tip is multiplied; the first time you meet it the customer
-- also gives an extra Customer Book star. Conditions are checked on the server
-- only (QuirkService); this table is pure data, read by Util/CustomerQuirks.

export type Kind = "unseen" | "still" | "airborne" | "lightning" | "fromZone" | "duringEvent"
export type QuirkDef = {
	kind: Kind,
	title: string, -- the customer's words, shown on the order card and figure
	request: string, -- what the courier has to do (Customer Book, hint)
	value: number?, -- studs / seconds, depending on kind
	zone: string?, -- fromZone: MapLayout street name
}

local function q(
	kind: Kind,
	title: string,
	request: string,
	value: number?,
	zone: string?
): QuirkDef
	return table.freeze({
		kind = kind,
		title = title,
		request = request,
		value = value,
		zone = zone,
	})
end

return table.freeze({
	tipMultiplier = 1.5,
	starBonus = 1, -- once per customer, the first time the quirk is met
	sampleSeconds = 0.2, -- courier position history (still / fromZone)
	historySeconds = 12,
	stillToleranceStuds = 1.5,

	quirks = table.freeze({
		SecretAgent = q(
			"unseen",
			"Nobody saw you. Right?",
			"Deliver with no other courier within 25 studs",
			25
		),
		StatueMan = q(
			"still",
			"Don't. Move.",
			"Stand perfectly still at the door for 2 seconds",
			2
		),
		GamerKid = q("airborne", "Jump! JUMP!", "Hand the pizza over mid-jump"),
		JoggingGrandpa = q("lightning", "Keep up, kiddo!", "Earn the Lightning style tag"),
		LostTourist = q(
			"fromZone",
			"Which way is the Plaza?",
			"Arrive within 10 seconds of leaving the Plaza",
			10,
			"Plaza"
		),
		TheMayor = q("duringEvent", "Make it ceremonial!", "Deliver while a disaster is on"),
	}) :: { [string]: QuirkDef },
})
