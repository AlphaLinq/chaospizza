--!strict
-- Pure quirk logic (#139): describe a customer's request and check the server
-- facts of a delivery against it. No Roblox APIs; construct with the config:
--   local Quirks = CustomerQuirks.new(require(Shared.Config.CustomerQuirks))
--   Quirks.describe("StatueMan") --> { title, request, tipMultiplier, ... } | nil

export type Kind = "unseen" | "still" | "airborne" | "lightning" | "fromZone" | "duringEvent"
export type QuirkDef = {
	kind: Kind,
	title: string,
	request: string,
	value: number?,
	zone: string?,
}
export type Config = {
	tipMultiplier: number,
	starBonus: number,
	quirks: { [string]: QuirkDef },
}
export type Facts = {
	nearestOtherCourier: number?, -- studs; nil = nobody in the server
	stillSeconds: number, -- how long the courier has not moved
	tags: { string }, -- style tag ids of this delivery
	secondsSinceZone: number?, -- since last seen in the quirk's zone; nil = not recently
	duringEvent: boolean,
}
export type Description = {
	id: string,
	kind: Kind,
	title: string,
	request: string,
	tipMultiplier: number,
	starBonus: number,
}
export type Quirks = {
	describe: (id: string) -> Description?,
	check: (id: string, facts: Facts) -> boolean,
	ids: () -> { string },
}

local CustomerQuirks = {}

local function hasTag(tags: { string }, id: string): boolean
	return table.find(tags, id) ~= nil
end

function CustomerQuirks.new(config: Config): Quirks
	local function describe(id: string): Description?
		local def = config.quirks[id]
		if not def then
			return nil
		end
		return {
			id = id,
			kind = def.kind,
			title = def.title,
			request = def.request,
			tipMultiplier = config.tipMultiplier,
			starBonus = config.starBonus,
		}
	end

	local function check(id: string, facts: Facts): boolean
		local def = config.quirks[id]
		if not def then
			return false
		end
		local value = def.value or 0
		if def.kind == "unseen" then
			return facts.nearestOtherCourier == nil or facts.nearestOtherCourier > value
		elseif def.kind == "still" then
			return facts.stillSeconds >= value
		elseif def.kind == "airborne" then
			return hasTag(facts.tags, "AirDelivery")
		elseif def.kind == "lightning" then
			return hasTag(facts.tags, "Lightning")
		elseif def.kind == "fromZone" then
			return facts.secondsSinceZone ~= nil and facts.secondsSinceZone <= value
		elseif def.kind == "duringEvent" then
			return facts.duringEvent
		end
		return false
	end

	local function ids(): { string }
		local list = {}
		for id in config.quirks do
			table.insert(list, id)
		end
		table.sort(list)
		return list
	end

	return { describe = describe, check = check, ids = ids }
end

return CustomerQuirks
