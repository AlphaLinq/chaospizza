--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (config shapes, remote payloads, later the profile schema) live here.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type EventId = "HorseRace" | "Tornado" | "Flood" | "Blizzard" | "CheeseWheel" | "Blackout"

export type RarityDef = {
	id: RarityId,
	displayName: string,
	colorHex: string,
	order: number,
	-- Percent weights per draw table. Each table sums to 100 across rarities.
	weightNormal: number,
	weightEvent: number,
	weightMega: number,
	-- Multiplier for passive tips when seated as a regular. 0 = cannot be a regular.
	passiveMultiplier: number,
}

export type CustomerDef = {
	id: string,
	displayName: string,
	rarity: RarityId,
	-- nil = appears in normal times; otherwise only during this event.
	event: EventId?,
	-- Short funny line shown on delivery (English for now; localization later).
	line: string,
	-- Seasonal customers can be switched off after their season.
	seasonal: boolean?,
}

export type EventDef = {
	id: EventId,
	displayName: string,
	enabled: boolean,
	seasonal: boolean,
	-- Events this one may be combined with during MEGA CHAOS.
	megaCombos: { EventId },
	season: { fromMonth: number, fromDay: number, toMonth: number, toDay: number }?,
}

export type PizzeriaLevelDef = {
	level: number,
	displayName: string,
	cost: number,
	regularSlots: number,
	unlocks: { string },
}

export type MovementTierDef = {
	tier: number,
	displayName: string,
	speedBonus: number, -- fraction, e.g. 0.15 = +15%
	cost: number,
	requiredCourierLevel: number,
}

export type GamepassDef = {
	key: string,
	displayName: string,
	priceRobux: number,
	gamepassId: number, -- 0 until created on the Creator Hub
}

export type ProductDef = {
	key: string,
	displayName: string,
	priceRobux: number,
	productId: number, -- 0 until created on the Creator Hub
	changesOdds: boolean, -- if true, the shop must show odds (brief ch. 18.1)
}

export type DebugCommandInfo = {
	name: string,
	description: string,
	usage: string,
}

export type DebugInfo = {
	authorized: boolean,
	commands: { DebugCommandInfo },
}

return nil
