--!strict
-- Customers and the Customer Book (brief ch. 9).
--   * pickForOrder: rolls a rarity (CustomerOdds, server only), then a customer
--     for the current situation (normal / event); the client never influences it
--   * recordServed: saves served count and stars in the profile's customerBook
--   * GetCustomerBook: the book snapshot for the UI (unknown customers hidden)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local CustomerOdds = require(ReplicatedStorage.Shared.Util.CustomerOdds)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)

export type ServeResult = {
	isNew: boolean,
	served: number,
	stars: number,
	rarity: string,
}

local CustomerService = {}

local byId: { [string]: any } = {}
local eventName: { [string]: string } = {}
local rng = Random.new()

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
	if EventService.isMega() then
		return "mega"
	end
	return if EventService.isHazardActive() then "event" else "normal"
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

function CustomerService.pickForOrder(player: Player): string
	local mode = CustomerService.currentMode()
	local activeEvent = EventService.getActiveEvent()
	local rarity = CustomerOdds.rollRarity(mode, Rarities :: any, modifiersFor(player), rand)
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

function CustomerService.recordServed(player: Player, customerId: string): ServeResult?
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
		-- First serve = 0 stars, then one star per repeat serve (max from config).
		entry.stars = math.min(ProgressionConfig.maxStars, entry.served - 1)
		result = { isNew = isNew, served = entry.served, stars = entry.stars, rarity = def.rarity }
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
