--!strict
-- Customers and the Customer Book (brief ch. 9).
--   * pickForOrder: rolls a rarity (CustomerOdds, server only), then a customer
--     for the current situation (normal / event); the client never influences it
--   * recordServed: saves served count and stars in the profile's customerBook
--   * GetCustomerBook: the book snapshot for the UI (unknown customers hidden)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local CustomerOdds = require(ReplicatedStorage.Shared.Util.CustomerOdds)
local CustomerQuirks = require(ReplicatedStorage.Shared.Util.CustomerQuirks)
local OrderOffers = require(ReplicatedStorage.Shared.Util.OrderOffers)
local QuirkConfig = require(ReplicatedStorage.Shared.Config.CustomerQuirks)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)

export type ServeResult = {
	isNew: boolean,
	served: number,
	stars: number,
	rarity: string,
	quirkFirst: boolean, -- the quirk was met for the first time (extra star)
}

local CustomerService = {}

local byId: { [string]: any } = {}
local eventName: { [string]: string } = {}
local rng = Random.new()
local Quirks = CustomerQuirks.new(QuirkConfig :: any)

-- Extra odds modifiers per player (boosts, pizzeria level) — set by other services.
local modifierProviders: { (player: Player) -> CustomerOdds.Modifiers? } = {}

local function rand(): number
	return rng:NextNumber()
end

local function modifiersFor(player: Player): CustomerOdds.Modifiers
	local rarePlus, levelBonus = 1, 0
	for _, provider in modifierProviders do
		local m = provider(player)
		if m then
			rarePlus *= m.rarePlusMultiplier or 1
			levelBonus += m.pizzeriaLevelBonus or 0
		end
	end
	return { rarePlusMultiplier = rarePlus, pizzeriaLevelBonus = levelBonus }
end

function CustomerService.addModifierProvider(provider: (player: Player) -> CustomerOdds.Modifiers?)
	table.insert(modifierProviders, provider)
end

function CustomerService.get(id: string): any
	return byId[id]
end

function CustomerService.currentMode(): CustomerOdds.OddsTable
	-- Explicit literal returns (an if-expression widens to `string`).
	if EventService.isMega() then
		return "mega"
	elseif EventService.isHazardActive() then
		return "event"
	end
	return "normal"
end

-- Odds the UI must show for odds-changing products (brief ch. 9.2 / 18.1).
function CustomerService.describeOdds(
	player: Player,
	extra: CustomerOdds.Modifiers?
): { [string]: number }
	local m = modifiersFor(player)
	if extra then
		m.rarePlusMultiplier = (m.rarePlusMultiplier or 1) * (extra.rarePlusMultiplier or 1)
		m.pizzeriaLevelBonus = (m.pizzeriaLevelBonus or 0) + (extra.pizzeriaLevelBonus or 0)
	end
	return CustomerOdds.describe(CustomerService.currentMode(), Rarities :: any, m)
end

-- One-shot perk (ordered disaster buyer): the next order is Rare+.
local rarePlusNext: { [Player]: boolean } = {}
function CustomerService.grantRarePlus(player: Player)
	rarePlusNext[player] = true
end

local function rollRarePlus(): string
	local weights = Tuning.OrderedEvents.buyerRarityWeights :: any
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rand() * total
	for _, rarity in { "Rare", "Epic", "Legendary" } do
		local w = weights[rarity] or 0
		if roll < w then
			return rarity
		end
		roll -= w
	end
	return "Rare"
end

local rarityRank: { [string]: number } = {}
for _, r in Rarities do
	rarityRank[r.id] = r.order
end

-- `rarityRolls` > 1 keeps the best of that many rarity rolls (far offers on
-- the order choice board, #185); the shown odds stay the single-roll odds.
function CustomerService.pickForOrder(player: Player, rarityRolls: number?): string
	local mode = CustomerService.currentMode()
	-- During MEGA CHAOS either running event may bring its customers.
	local active = EventService.getActiveEvents()
	local activeEvent = if #active > 0
		then active[math.min(#active, math.floor(rand() * #active) + 1)]
		else nil
	local modifiers = modifiersFor(player)
	local rarity = OrderOffers.bestRarity(function()
		return CustomerOdds.rollRarity(mode, Rarities :: any, modifiers, rand)
	end, function(id)
		return rarityRank[id] or 0
	end, rarityRolls or 1)
	if rarePlusNext[player] then
		rarePlusNext[player] = nil
		local order = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
		if (order :: any)[rarity] < 3 then
			rarity = rollRarePlus()
		end
	end
	local id = CustomerOdds.pickCustomer(Customers :: any, rarity, activeEvent, rand)
	if id then
		return id
	end
	-- Should not happen with the shipped config; fall back to any normal customer.
	for _, c in Customers do
		if c.event == nil then
			return c.id
		end
	end
	return Customers[1].id
end

-- Stars: one per repeat serve, plus a one-time bonus for meeting the
-- customer's quirk (#139), capped at the configured maximum.
local function starsFor(entry: { served: number, quirk: boolean? }): number
	local bonus = if entry.quirk then QuirkConfig.starBonus else 0
	return math.min(ProgressionConfig.maxStars, entry.served - 1 + bonus)
end

function CustomerService.recordServed(
	player: Player,
	customerId: string,
	quirkMet: boolean?
): ServeResult?
	local def = byId[customerId]
	if not def then
		return nil
	end
	local result: ServeResult? = nil
	local discovered = 0
	local ok = DataService.update(player, function(profile)
		local entry = profile.customerBook[customerId]
		local isNew = entry == nil
		if not entry then
			entry = { served = 0, stars = 0 }
			profile.customerBook[customerId] = entry
		end
		entry.served += 1
		local quirkFirst = quirkMet == true and not entry.quirk
		if quirkFirst then
			entry.quirk = true
		end
		entry.stars = starsFor(entry)
		result = {
			isNew = isNew,
			served = entry.served,
			stars = entry.stars,
			rarity = def.rarity,
			quirkFirst = quirkFirst,
		}
		for _ in profile.customerBook do
			discovered += 1
		end
	end)
	if not ok or not result then
		return nil
	end
	local r = result :: ServeResult
	Net.event("CustomerBookUpdated"):FireClient(player, { id = customerId, isNew = r.isNew })
	if r.isNew then
		if discovered == 1 then
			AnalyticsService.funnel(player, "first_customer_new")
		end
		AnalyticsService.custom(player, `customer_new_{r.rarity}`)
	end
	player:SetAttribute("BookDiscovered", discovered)
	return r
end

local function hintFor(def: any): string
	if def.event then
		return `Appears during: {eventName[def.event] or def.event}`
	end
	return `A {string.lower(def.rarity)} customer in normal times`
end

function CustomerService.getBook(player: Player): { [string]: any }?
	local profile = DataService.getProfile(player)
	if not profile then
		return nil
	end
	local list = {}
	local discovered = 0
	for _, def in Customers do
		local entry = profile.customerBook[def.id]
		local known = entry ~= nil
		if known then
			discovered += 1
		end
		table.insert(list, {
			id = def.id,
			name = if known then def.displayName else "???",
			rarity = def.rarity,
			event = def.event,
			served = if entry then entry.served else 0,
			stars = if entry then entry.stars else 0,
			known = known,
			hint = hintFor(def),
			line = if known then def.line else nil,
			-- #139: the request is shown once the customer is known.
			quirk = if known then Quirks.describe(def.id) else nil,
			quirkDone = entry ~= nil and entry.quirk == true,
		})
	end
	return { total = #Customers, discovered = discovered, customers = list }
end

function CustomerService.init()
	for _, c in Customers do
		byId[c.id] = c
	end
	for _, e in Events do
		eventName[e.id] = e.displayName
	end

	DebugService.register("book", "Customer Book progress", "book", function(player)
		local book = CustomerService.getBook(player)
		if not book then
			return false, "profile not loaded"
		end
		return true, `{book.discovered}/{book.total} customers discovered`
	end)
	DebugService.register(
		"serve",
		"Mark a customer as served",
		"serve <CustomerId>",
		function(player, args)
			local id = args[1]
			if not id or not byId[id] then
				return false, "usage: serve <CustomerId> (e.g. TheShark)"
			end
			local r = CustomerService.recordServed(player, id)
			if not r then
				return false, "profile not loaded"
			end
			return true,
				`{id}: served {r.served}, stars {r.stars}{if r.isNew then " (NEW)" else ""}`
		end
	)
	DebugService.register("odds", "Show current customer odds", "odds", function(player)
		local odds = CustomerService.describeOdds(player)
		local parts = {}
		for _, r in Rarities do
			table.insert(parts, `{r.id}={string.format("%.1f", odds[r.id] or 0)}%`)
		end
		return true, `{CustomerService.currentMode()}: {table.concat(parts, " ")}`
	end)
end

function CustomerService.start()
	Players.PlayerRemoving:Connect(function(player)
		rarePlusNext[player] = nil
	end)
	Net.onServerInvoke("GetCustomerBook", { ratePerSecond = 1, burst = 3 }, function(player)
		return CustomerService.getBook(player)
	end)
	DataService.onLoaded(function(player, profile)
		local n = 0
		for _ in profile.customerBook do
			n += 1
		end
		player:SetAttribute("BookDiscovered", n)
	end)
end

return CustomerService
