--!strict
-- Order choice board (#185, docs/GAMEPLAY_LOOP.md G1/G2). Picking up at the
-- counter offers three orders instead of one:
--   near    — a close address: quick and safe;
--   far     — a far address: long-haul tip bonus and a best-of-two rarity
--             roll for the customer;
--   special — an order type (rush / double / fragile / party) or, before
--             those unlock, a customer with a quirk. While an event with a
--             hazard zone runs it becomes **Daredevil**: an address inside the
--             zone, ×2 tips if delivered while the event still runs.
-- The offers are fixed until chosen (no rerolling for rares); after
-- Tuning.Offers.choiceSeconds the first one is taken. New couriers in
-- onboarding still get their order straight away.
--
-- Replication: player attribute "OrderOffers" = JSON { expires, offers }
-- (server time). The client sends only the index ("ChooseOffer").

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CustomerQuirks = require(ReplicatedStorage.Shared.Util.CustomerQuirks)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local HazardZones = require(ReplicatedStorage.Shared.Util.HazardZones)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local OrderKinds = require(ReplicatedStorage.Shared.Util.OrderKinds)
local OrderOffers = require(ReplicatedStorage.Shared.Util.OrderOffers)
local QuirkConfig = require(ReplicatedStorage.Shared.Config.CustomerQuirks)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local CustomerService = require(script.Parent.CustomerService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local FeatureTipService = require(script.Parent.FeatureTipService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)
local StoryService = require(script.Parent.StoryService)

local OfferService = {}

type Slot = "near" | "far" | "special" | "daredevil" | "story"
type Offer = {
	slot: Slot,
	spec: OrderService.Spec,
	card: { [string]: any },
	story: StoryService.Pick?, -- a story chapter (#254)
}
type Pending = { offers: { Offer }, expires: number } -- expires: os.clock()

local cfg = Tuning.Offers
local Quirks = CustomerQuirks.new(QuirkConfig :: any)
local pending: { [Player]: Pending } = {}
local eventNames: { [string]: string } = {}
for _, e in Events do
	eventNames[e.id] = e.displayName
end

local function rng(): number
	return math.random()
end

-- Adaptive Daredevil (#242): did the courier take the Daredevil card, on the
-- last boards that showed one (server-wide, newest last)?
local daredHistory: { boolean } = {}

local function daredevilMultiplier(): number
	local picks = 0
	for _, took in daredHistory do
		if took then
			picks += 1
		end
	end
	return OrderOffers.daredevilMultiplier(
		picks,
		#daredHistory,
		cfg.daredevilMultiplier,
		cfg.daredevilAdaptive
	)
end

local function publishMultiplier()
	local state = ReplicatedStorage:FindFirstChild("CityState")
	if state then
		state:SetAttribute("DaredevilMultiplier", daredevilMultiplier())
	end
end

local function recordDared(took: boolean)
	table.insert(daredHistory, took)
	while #daredHistory > cfg.daredevilAdaptive.window do
		table.remove(daredHistory, 1)
	end
	publishMultiplier()
end

local function publish(player: Player, p: Pending?)
	if not p then
		player:SetAttribute("OrderOffers", nil)
		return
	end
	local cards = {}
	for _, offer in p.offers do
		table.insert(cards, offer.card)
	end
	player:SetAttribute(
		"OrderOffers",
		HttpService:JSONEncode({
			expires = Workspace:GetServerTimeNow() + (p.expires - os.clock()),
			offers = cards,
		})
	)
end

local function addressList(): { OrderOffers.Address }
	local list = {}
	for _, a in MapService.getAddresses() do
		table.insert(list, { id = a.id, x = a.doorPosition.X, z = a.doorPosition.Z })
	end
	return list
end

-- Live danger points from CityState: a Vector3 or a JSON list of { x, z }.
local function statePoints(def: { [string]: any }): { { x: number, z: number } }
	local state = ReplicatedStorage:FindFirstChild("CityState")
	if not state then
		return {}
	end
	if def.stateVector then
		local v = state:GetAttribute(def.stateVector)
		return if typeof(v) == "Vector3" then { { x = v.X, z = v.Z } } else {}
	end
	local raw = state:GetAttribute(def.stateJson)
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	local points = {}
	if ok and typeof(list) == "table" then
		for _, item in list :: { any } do
			if
				typeof(item) == "table"
				and typeof(item.x) == "number"
				and typeof(item.z) == "number"
			then
				table.insert(points, { x = item.x, z = item.z })
			end
		end
	end
	return points
end

-- The event a Daredevil offer can dare right now, with the addresses in its
-- danger area: a fixed zone (HazardZones), its routes, or live positions.
local function daredevilTarget(
	addresses: { OrderOffers.Address }
): (string?, { OrderOffers.Address })
	for _, id in EventService.getActiveEvents() do
		local inside: { OrderOffers.Address } = {}
		local zoneName = HazardZones.EVENT_ZONE[id]
		local zone = zoneName and (MapLayout.zones :: any)[zoneName]
		local def = cfg.daredevil[id]
		if zone then
			inside = OrderOffers.inZone(addresses, zone, cfg.daredevilZoneMargin)
		elseif def and def.routes then
			inside = OrderOffers.nearRoutes(addresses, (MapLayout :: any)[def.routes], def.radius)
		elseif def then
			inside = OrderOffers.nearPoints(addresses, statePoints(def), def.radius)
		end
		if #inside > 0 then
			return id, inside
		end
	end
	return nil, {}
end

local function card(
	slot: Slot,
	title: string,
	spec: OrderService.Spec,
	estimate: number,
	extra: string?
): { [string]: any }
	local address = spec.addressId and MapService.getAddress(spec.addressId)
	local customer = spec.customerId and CustomerService.get(spec.customerId)
	local quirk = spec.customerId and Quirks.describe(spec.customerId)
	return {
		slot = slot,
		title = title,
		address = if address then address.label else spec.addressId,
		customer = if customer then customer.displayName else spec.customerId,
		rarity = if customer then customer.rarity else "Common",
		kind = spec.kind or "normal",
		quirk = if quirk then quirk.title else nil,
		tip = estimate,
		-- Meeting a quirk request multiplies the tip: show the range.
		tipMax = if quirk
			then math.floor(estimate * (QuirkConfig :: any).tipMultiplier + 0.5)
			else nil,
		extra = extra,
	}
end

local function build(player: Player): { Offer }
	local addresses = addressList()
	local counter = MapService.getCounterPart().Position
	local sorted = OrderOffers.byDistance(addresses, { x = counter.X, z = counter.Z })
	local avoid: { [string]: boolean } = {}
	local last = OrderService.getLastAddress(player)
	if last then
		avoid[last] = true
	end
	local base = Tuning.Orders.baseTip
	local maxBonus = Tuning.Style.maxTotalBonus
	local eventBonus = EventService.eventTipBonus()
	local offers: { Offer } = {}

	-- Roll the far customer first: a pending "next customer is rare+" buff
	-- (wishing well) then lands on the long-haul card, where it belongs.
	local farCustomer = CustomerService.pickForOrder(player, cfg.farRarityRolls)

	local nearId = OrderOffers.pickNear(sorted, cfg.nearShare, avoid, rng)
	if nearId then
		avoid[nearId] = true
		local spec: OrderService.Spec = {
			addressId = nearId,
			customerId = CustomerService.pickForOrder(player),
			kind = "normal",
		}
		table.insert(offers, {
			slot = "near",
			spec = spec,
			card = card(
				"near",
				"Quick hop",
				spec,
				OrderOffers.estimate(base, eventBonus, maxBonus, 1)
			),
		})
	end

	local farId = OrderOffers.pickFar(sorted, cfg.farShare, avoid, rng)
	if farId then
		avoid[farId] = true
		local spec: OrderService.Spec = {
			addressId = farId,
			customerId = farCustomer,
			kind = "normal",
			multiplier = cfg.farTipMultiplier,
			label = "Long haul",
		}
		table.insert(offers, {
			slot = "far",
			spec = spec,
			card = card(
				"far",
				"Long haul",
				spec,
				OrderOffers.estimate(base, eventBonus, maxBonus, cfg.farTipMultiplier),
				"Better rare odds"
			),
		})
	end

	local dared, zoneAddresses = daredevilTarget(addresses)
	-- Only addresses not already on the other cards (a small danger area may
	-- hold just the near one); none left = a normal special card instead.
	local fresh = {}
	for _, a in zoneAddresses do
		if not avoid[a.id] then
			table.insert(fresh, a)
		end
	end
	if dared and #fresh > 0 then
		local inside = OrderOffers.byDistance(fresh, { x = counter.X, z = counter.Z })
		local id = OrderOffers.pickFar(inside, 1, avoid, rng)
		local multiplier = daredevilMultiplier()
		local spec: OrderService.Spec = {
			addressId = id,
			customerId = CustomerService.pickForOrder(player),
			kind = "normal",
			daredevil = dared,
			daredevilMultiplier = multiplier,
		}
		table.insert(offers, {
			slot = "daredevil",
			spec = spec,
			card = card(
				"daredevil",
				"DAREDEVIL",
				spec,
				OrderOffers.estimate(base, eventBonus, maxBonus, multiplier),
				`×{OrderOffers.formatMultiplier(multiplier)} inside the {eventNames[dared] or dared}!`
			),
		})
		return offers
	end

	-- Story chapter (#254): sometimes, in the calm, instead of the special.
	local storySpec, storyLine, storyPick = StoryService.offer(player)
	if storySpec and storyPick and not avoid[storySpec.addressId or ""] then
		table.insert(offers, {
			slot = "story",
			spec = storySpec,
			story = storyPick,
			card = card(
				"story",
				"STORY",
				storySpec,
				OrderOffers.estimate(base, eventBonus, maxBonus, Tuning.Stories.tipMultiplier),
				storyLine
			),
		})
		return offers
	end

	-- Special: an order type when unlocked, else a quirky customer.
	local level = tonumber(player:GetAttribute("PizzeriaLevel")) or 1
	local kinds = Tuning.OrderKinds :: any
	local available = OrderKinds.available(
		level,
		EconomyService.getDeliveries(player),
		Tuning.Orders.starterDeliveries,
		kinds
	)
	local special: OrderKinds.Kind = "normal"
	if #available > 1 then
		local noNormal = table.clone(kinds)
		noNormal.normalWeight = 0
		special = OrderKinds.pick(
			level,
			EconomyService.getDeliveries(player),
			Tuning.Orders.starterDeliveries,
			noNormal,
			rng
		)
	end
	local customerId = CustomerService.pickForOrder(player)
	if special == "normal" then
		-- Only everyday quirky customers: the board must not hand out rares.
		local quirky = {}
		for _, id in Quirks.ids() do
			local def = CustomerService.get(id)
			if def and (def.rarity == "Common" or def.rarity == "Uncommon") then
				table.insert(quirky, id)
			end
		end
		if #quirky > 0 then
			customerId = quirky[math.random(1, #quirky)]
		end
	end
	local spec: OrderService.Spec = {
		addressId = OrderOffers.pickFar(sorted, 1, avoid, rng),
		customerId = customerId,
		kind = special,
	}
	local def = if special ~= "normal" then (kinds :: any)[special] else nil
	local kindBonus = if def then def.bonus or 0 else 0
	local kindMultiplier = if def then def.tipMultiplier or 1 else 1
	table.insert(offers, {
		slot = "special",
		spec = spec,
		card = card(
			"special",
			if special == "normal" then "Special request" else "Special order",
			spec,
			OrderOffers.estimate(base, eventBonus + kindBonus, maxBonus, kindMultiplier),
			if special == "normal" then "Meet the request: bigger tip" else nil
		),
	})
	return offers
end

-- Takes offer `index` (or the first one when nil). Returns ok + message.
function OfferService.choose(
	player: Player,
	index: number?,
	skipDistance: boolean?,
	auto: boolean?
): (boolean, string)
	local p = pending[player]
	if not p then
		return false, "no offers"
	end
	local i = index or 1
	local offer = p.offers[i]
	if not offer then
		return false, "no such offer"
	end
	if not skipDistance then
		local root = CharacterService.getRootPart(player)
		local counter = MapService.getCounterPart().Position
		if
			not root
			or (root.Position - counter).Magnitude
				> Tuning.Orders.pickupRadiusStuds + cfg.chooseSlackStuds
		then
			return false, "come back to the counter to choose"
		end
	end
	pending[player] = nil
	publish(player, nil)
	for _, o in p.offers do
		if o.slot == "daredevil" then
			recordDared(offer.slot == "daredevil")
			break
		end
	end
	if OrderService.getOrder(player) then
		return false, "you already have an order"
	end
	local order = OrderService.assignOrder(player, offer.spec)
	if not order then
		return false, "could not create the order"
	end
	if offer.story then
		StoryService.begin(player, order.id, offer.story)
	end
	-- #202: which card couriers pick (auto = the timer took the first one).
	AnalyticsService.custom(player, if auto then "offer_auto" else `offer_pick_{offer.slot}`)
	local shown = offer.card
	Net.event("Hint"):FireClient(
		player,
		if offer.slot == "daredevil"
			then `😈 Daredevil! Deliver to {shown.customer} before the event ends for ×{OrderOffers.formatMultiplier(
				offer.spec.daredevilMultiplier or cfg.daredevilMultiplier
			)} tips!`
			else `Deliver to {shown.customer}!`
	)
	return true, `took the {offer.slot} offer to {order.addressId}`
end

-- Shows the choice board. Returns false when this pickup should stay the
-- classic instant order (onboarding, map without enough addresses).
function OfferService.present(player: Player, force: boolean?): boolean
	if not force and EconomyService.getDeliveries(player) < Tuning.Orders.starterDeliveries then
		return false
	end
	local existing = pending[player]
	if existing then
		publish(player, existing) -- same offers again: no rerolling
		return true
	end
	local offers = build(player)
	if #offers < 2 then
		return false
	end
	local p: Pending = { offers = offers, expires = os.clock() + cfg.choiceSeconds }
	pending[player] = p
	publish(player, p)
	FeatureTipService.show(player, "OfferBoard")
	return true
end

function OfferService.init()
	DebugService.register(
		"offers",
		"Order choice board: show offers, take one",
		"offers [show|take <1-3>|rate|clear]",
		function(player, args)
			local sub = args[1] or "show"
			if sub == "show" then
				OrderService.cancelOrder(player)
				pending[player] = nil
				if not OfferService.present(player, true) then
					return false, "no offers (not enough addresses?)"
				end
				local p = pending[player] :: Pending
				local slots = {}
				for i, offer in p.offers do
					table.insert(slots, `{i}={offer.slot}:{offer.spec.addressId}`)
				end
				return true, table.concat(slots, " ")
			elseif sub == "take" then
				return OfferService.choose(player, tonumber(args[2]), true)
			elseif sub == "rate" then
				local picks = 0
				for _, took in daredHistory do
					picks += if took then 1 else 0
				end
				return true,
					`daredevil {picks}/{#daredHistory} picked → ×{daredevilMultiplier()}`
			elseif sub == "clear" then
				pending[player] = nil
				publish(player, nil)
				return true, "cleared"
			end
			return false, "usage: offers [show|take <1-3>|rate|clear]"
		end
	)
end

function OfferService.start()
	publishMultiplier()
	OrderService.setPickupHandler(function(player)
		return OfferService.present(player)
	end)
	Net.onServerEvent("ChooseOffer", { ratePerSecond = 2, burst = 3 }, function(player, raw)
		local p = pending[player]
		if not p then
			return
		end
		local index = OrderOffers.validIndex(raw, #p.offers)
		if not index then
			return
		end
		local ok, message = OfferService.choose(player, index)
		if not ok then
			Net.event("Hint"):FireClient(player, `🍕 {message}`)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for player, p in pending do
				if now >= p.expires then
					OfferService.choose(player, 1, true, true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return OfferService
