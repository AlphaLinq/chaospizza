--!strict
-- Orders: pick up at the Pizza HQ counter, carry the box, deliver at the address.
-- Server-authoritative (AGENTS.md 4.1):
--   * one active order per player, created and stored only here
--   * the client only sends the intent "DeliverOrder"; the server checks the
--     order, the address and the distance
--   * completing an order is idempotent: the order is cleared before rewards
--
-- Replication: the owner's current order is mirrored on player attributes
-- (OrderId, OrderAddressId, OrderLabel, OrderCustomer, OrderTarget) so late
-- joiners and streaming clients always have the full state.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Net = require(ReplicatedStorage.Shared.Net)
local OrderKinds = require(ReplicatedStorage.Shared.Util.OrderKinds)
local OrderLogic = require(ReplicatedStorage.Shared.Util.OrderLogic)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CustomerService = require(script.Parent.CustomerService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local MapService = require(script.Parent.MapService)
local StyleService = require(script.Parent.StyleService)
local KnockbackService = require(script.Parent.KnockbackService)
local MonetizationService = require(script.Parent.MonetizationService)

export type Order = {
	id: string,
	addressId: string,
	customerId: string,
	createdAt: number,
	-- Order type (brief 8.1); optional fields only exist for their kind.
	kind: OrderKinds.Kind?,
	nextAddressId: string?, -- double: second stop
	nextCustomerId: string?,
	legFrom: Vector3?, -- where the current leg started (travel-time check)
	deadline: number?, -- rush: os.clock() target
	broken: boolean?, -- fragile: squished by a knockback
}

local DISTANCE_TOLERANCE = 4 -- studs of latency slack on top of the radius

local OrderService = {}

local orders: { [Player]: Order } = {}
local lastAddress: { [Player]: string } = {}
local customerById: { [string]: any } = {}
local forcedKind: { [Player]: OrderKinds.Kind } = {} -- debug only

-- Hooks for later systems (events, style, onboarding): called after a delivery.
-- Extra facts about a delivery for listeners (weekly challenges, analytics).
export type DeliveryInfo = { isNew: boolean, duringEvent: boolean, giant: boolean }

type DeliveredCallback = (
	player: Player,
	order: Order,
	tips: number,
	deliveries: number,
	info: DeliveryInfo
) -> ()
local deliveredCallbacks: { DeliveredCallback } = {}

local function rng(): number
	return math.random()
end

local function customerName(id: string): string
	local c = customerById[id]
	return if c then c.displayName else id
end

-- Flood (brief 1.0 ch. 12): customers in the flooded zone wait on their
-- balcony (ladder next to the door) while the flood is coming / active.
local FLOOD_ZONE = MapLayout.zones.LowerTown
local function isFlooded(position: Vector3): boolean
	if not table.find(EventService.getActiveEvents(), "Flood") then
		return false
	end
	return math.abs(position.X - FLOOD_ZONE.x) <= FLOOD_ZONE.sx / 2
		and math.abs(position.Z - FLOOD_ZONE.z) <= FLOOD_ZONE.sz / 2
end

-- Where the customer currently waits (the door, or the balcony during a flood).
function OrderService.deliveryPoint(address: MapService.Address): Vector3
	return if isFlooded(address.doorPosition) then address.highPosition else address.doorPosition
end

local function publish(player: Player)
	local order = orders[player]
	if order then
		local address = MapService.getAddress(order.addressId)
		-- OrderId is the "changed" signal clients listen to: set it LAST.
		player:SetAttribute("OrderAddressId", order.addressId)
		player:SetAttribute("OrderLabel", if address then address.label else order.addressId)
		player:SetAttribute("OrderCustomer", customerName(order.customerId))
		local def = customerById[order.customerId]
		player:SetAttribute("OrderRarity", if def then def.rarity else "Common")
		player:SetAttribute(
			"OrderTarget",
			if address then OrderService.deliveryPoint(address) else nil
		)
		player:SetAttribute("OrderKind", order.kind or "normal")
		player:SetAttribute("OrderStops", if order.nextAddressId then 2 else nil)
		player:SetAttribute(
			"OrderDeadline",
			if order.deadline
				then Workspace:GetServerTimeNow() + (order.deadline - os.clock())
				else nil
		)
		player:SetAttribute("OrderBroken", order.broken or nil)
		player:SetAttribute("OrderId", order.id)
	else
		-- ...and clear it FIRST.
		player:SetAttribute("OrderId", nil)
		player:SetAttribute("OrderAddressId", nil)
		player:SetAttribute("OrderLabel", nil)
		player:SetAttribute("OrderCustomer", nil)
		player:SetAttribute("OrderRarity", nil)
		player:SetAttribute("OrderTarget", nil)
		player:SetAttribute("OrderKind", nil)
		player:SetAttribute("OrderStops", nil)
		player:SetAttribute("OrderDeadline", nil)
		player:SetAttribute("OrderBroken", nil)
	end
end

local function removeBox(player: Player)
	local character = player.Character
	local box = character and character:FindFirstChild("PizzaBox")
	if box then
		box:Destroy()
	end
end

local function attachBox(player: Player)
	removeBox(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local box = Instance.new("Part")
	box.Name = "PizzaBox"
	box.Size = Vector3.new(2.6, 0.5, 2.6)
	box.Color = Color3.fromHex("#D9A66B")
	box.Material = Enum.Material.Cardboard
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Massless = true
	box.CFrame = root.CFrame * CFrame.new(0, 0.4, -1.7)
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(1.6, 0.05, 1.6)
	lid.Color = Color3.fromHex("#C0392B")
	lid.CanCollide = false
	lid.CanQuery = false
	lid.CanTouch = false
	lid.Massless = true
	lid.CFrame = box.CFrame * CFrame.new(0, 0.27, 0)
	local lidWeld = Instance.new("WeldConstraint")
	lidWeld.Part0 = box
	lidWeld.Part1 = lid
	lidWeld.Parent = lid
	lid.Parent = box
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = box
	weld.Parent = box
	box.Parent = character
end

function OrderService.getOrder(player: Player): Order?
	return orders[player]
end

-- Other delivery kinds (giant co-op order) report through the same hooks so
-- chaos meter, regulars and onboarding treat them like a normal delivery.
function OrderService.notifyDelivered(
	player: Player,
	order: Order,
	tips: number,
	deliveries: number,
	info: DeliveryInfo?
)
	local facts: DeliveryInfo = info or { isNew = false, duringEvent = false, giant = false }
	for _, callback in deliveredCallbacks do
		task.spawn(callback, player, order, tips, deliveries, facts)
	end
end

-- A guard returns a player-facing reason to refuse a normal pickup, or nil.
local pickupGuards: { (player: Player) -> string? } = {}
function OrderService.addPickupGuard(guard: (player: Player) -> string?)
	table.insert(pickupGuards, guard)
end

function OrderService.onDelivered(callback: DeliveredCallback)
	table.insert(deliveredCallbacks, callback)
end

-- Creates an order for the player if they do not have one. Returns the order.
function OrderService.assignOrder(player: Player): Order?
	if orders[player] then
		return orders[player]
	end
	if not EconomyService.isReady(player) then
		return nil -- profile still loading
	end
	local addressInfos = {}
	for _, address in MapService.getAddresses() do
		table.insert(addressInfos, { id = address.id, starter = address.starter })
	end
	if #addressInfos == 0 then
		warn("[OrderService] no addresses on the map")
		return nil
	end
	local addressId = OrderLogic.pickAddress(
		addressInfos,
		EconomyService.getDeliveries(player),
		Tuning.Orders.starterDeliveries,
		lastAddress[player],
		rng
	)
	local deliveriesSoFar = EconomyService.getDeliveries(player)
	local level = tonumber(player:GetAttribute("PizzeriaLevel")) or 1
	local kinds = Tuning.OrderKinds :: any
	local kind = forcedKind[player]
		or OrderKinds.pick(level, deliveriesSoFar, Tuning.Orders.starterDeliveries, kinds, rng)
	forcedKind[player] = nil
	local order: Order = {
		id = HttpService:GenerateGUID(false),
		addressId = addressId,
		customerId = CustomerService.pickForOrder(player),
		createdAt = os.clock(),
		kind = kind,
	}
	if kind == "double" then
		order.nextAddressId =
			OrderLogic.pickAddress(addressInfos, deliveriesSoFar, 0, addressId, rng)
		order.nextCustomerId = CustomerService.pickForOrder(player)
		if order.nextAddressId == addressId then
			order.kind = "normal"
			order.nextAddressId = nil
			order.nextCustomerId = nil
		end
	elseif kind == "rush" then
		local address = MapService.getAddress(addressId)
		local counter = MapService.getCounterPart().Position
		local distance = if address
			then ((address.doorPosition - counter) * Vector3.new(1, 0, 1)).Magnitude
			else 100
		order.deadline = os.clock()
			+ distance / Tuning.Movement.baseWalkSpeed * Tuning.OrderKinds.rush.timeFactor
	end
	orders[player] = order
	lastAddress[player] = addressId
	if EconomyService.getDeliveries(player) == 0 then
		AnalyticsService.funnel(player, "first_order_pickup")
	end
	attachBox(player)
	publish(player)
	return order
end

-- Completes the active order. `skipDistanceCheck` is only for debug commands.
function OrderService.completeOrder(player: Player, skipDistanceCheck: boolean?): (boolean, string)
	local order = orders[player]
	if not order then
		return false, "no active order"
	end
	local address = MapService.getAddress(order.addressId)
	if not address then
		return false, "unknown address"
	end
	if not skipDistanceCheck then
		local root = CharacterService.getRootPart(player)
		if not root then
			return false, "no character"
		end
		-- The door always counts; during a flood the balcony counts too, so the
		-- moment the point moves never makes a delivery fail.
		local function near(point: Vector3): boolean
			local distance = ((root.Position - point) * Vector3.new(1, 0, 1)).Magnitude
			return distance <= Tuning.Orders.deliveryRadiusStuds + DISTANCE_TOLERANCE
				and math.abs(root.Position.Y - point.Y) < 10
		end
		if not near(address.doorPosition) and not near(OrderService.deliveryPoint(address)) then
			return false, "too far from the door"
		end
	end

	-- Anti-teleport farming: the client owns its character physics, so also
	-- require a plausible travel time from the counter to the door.
	local counter = order.legFrom or MapService.getCounterPart().Position
	local flatDistance = ((address.doorPosition - counter) * Vector3.new(1, 0, 1)).Magnitude
	if not skipDistanceCheck then
		local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
		local minSeconds = flatDistance / fastest * Tuning.Orders.minTravelTimeFactor
		if os.clock() - order.createdAt < minSeconds then
			return false, "too fast"
		end
	end

	-- Double order: the first stop only advances the order (pay at the end).
	if order.nextAddressId and order.nextCustomerId then
		local firstCustomer = order.customerId
		order.addressId = order.nextAddressId
		order.customerId = order.nextCustomerId
		order.nextAddressId = nil
		order.nextCustomerId = nil
		order.legFrom = address.doorPosition
		order.createdAt = os.clock()
		CustomerService.recordServed(player, firstCustomer)
		publish(player)
		local nextAddress = MapService.getAddress(order.addressId)
		Net.event("Hint"):FireClient(
			player,
			`📦 1/2 delivered! Next: {customerName(order.customerId)} at {if nextAddress
				then nextAddress.label
				else order.addressId}`
		)
		return true, `first stop {address.id} done`
	end

	-- Clear first: a repeated request can never pay twice.
	orders[player] = nil
	removeBox(player)
	publish(player)

	-- Style tags (server facts only) stack with the event bonus under one cap;
	-- MEGA CHAOS multiplies the result (brief ch. 14–15).
	local eventBonus = if EventService.isOrderedActive()
		then Tuning.OrderedEvents.tipBonusForEveryone
		elseif EventService.isHazardActive() then Tuning.Events.tipBonusDuringEvent
		else 0
	local style = StyleService.evaluate(player, order.createdAt, flatDistance)
	local kind: OrderKinds.Kind = order.kind or "normal"
	local kindBonus, kindMultiplier, kindLabels = OrderKinds.reward(kind, {
		onTime = order.deadline ~= nil and os.clock() <= order.deadline,
		intact = not order.broken,
	}, Tuning.OrderKinds :: any)
	local bonus = eventBonus + style.bonus + kindBonus
	local tips = OrderLogic.tip(Tuning.Orders.baseTip, bonus, Tuning.Style.maxTotalBonus)
	if kindMultiplier ~= 1 then
		tips = math.floor(tips * kindMultiplier + 0.5)
	end
	local labels = table.clone(style.names)
	for _, label in kindLabels do
		table.insert(labels, label)
	end
	-- Paid multipliers (DoubleTips pass, TipBoost): server-side, capped by MonetizationService.
	local boost = MonetizationService.getTipMultiplier(player)
	if boost > 1 then
		tips = math.floor(tips * boost + 0.5)
	end
	local mega = EventService.isMega()
	if mega then
		tips *= Tuning.ChaosMeter.megaTipMultiplier
	end
	EconomyService.addTips(player, tips, "delivery")
	EconomyService.addXp(player, Tuning.Orders.baseXp)
	local deliveries = EconomyService.recordDelivery(player)
	if deliveries == 1 then
		AnalyticsService.funnel(player, "first_delivery")
	end
	local served = CustomerService.recordServed(player, order.customerId)

	local customer = customerById[order.customerId]
	Net.event("DeliveryResult"):FireClient(player, {
		tips = tips,
		customer = customerName(order.customerId),
		line = if customer then customer.line else "",
		deliveries = deliveries,
		eventBonus = eventBonus > 0,
		style = labels,
		kind = kind,
		mega = mega,
		boost = boost,
		isNew = if served then served.isNew else false,
		rarity = if served then served.rarity else "Common",
		stars = if served then served.stars else 0,
	})

	OrderService.notifyDelivered(player, order, tips, deliveries, {
		isNew = if served then served.isNew else false,
		duringEvent = eventBonus > 0,
		giant = false,
	})
	return true, `delivered to {address.id} for {tips} tips`
end

function OrderService.cancelOrder(player: Player)
	orders[player] = nil
	removeBox(player)
	publish(player)
end

local function setupCounterPrompt()
	local counter = MapService.getCounterPart()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up order"
	prompt.ObjectText = "Pizza HQ"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Tuning.Orders.pickupRadiusStuds
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player)
		if orders[player] then
			Net.event("Hint"):FireClient(player, "You already have a pizza to deliver!")
			return
		end
		if not EconomyService.isReady(player) then
			Net.event("Hint"):FireClient(player, "Loading your courier profile…")
			return
		end
		for _, guard in pickupGuards do
			local reason = guard(player)
			if reason then
				Net.event("Hint"):FireClient(player, reason)
				return
			end
		end
		-- The engine checks activation distance; re-check on the server anyway.
		local root = CharacterService.getRootPart(player)
		if
			not root
			or (root.Position - counter.Position).Magnitude
				> Tuning.Orders.pickupRadiusStuds + DISTANCE_TOLERANCE
		then
			return
		end
		local order = OrderService.assignOrder(player)
		if order then
			Net.event("Hint"):FireClient(player, `Deliver to {customerName(order.customerId)}!`)
		end
	end)
end

function OrderService.init()
	for _, c in Customers do
		customerById[c.id] = c
	end

	DebugService.register(
		"order",
		"Show or force your current order",
		"order [new [normal|double|rush|fragile]|cancel]",
		function(player, args)
			if args[1] == "new" then
				OrderService.cancelOrder(player)
				local kind = args[2]
				if kind == "normal" or kind == "double" or kind == "rush" or kind == "fragile" then
					forcedKind[player] = kind
				end
				local order = OrderService.assignOrder(player)
				return order ~= nil,
					if order
						then `new {order.kind or "normal"} order to {order.addressId}`
						else "failed"
			elseif args[1] == "cancel" then
				OrderService.cancelOrder(player)
				return true, "order cancelled"
			end
			local order = orders[player]
			if not order then
				return true, "no active order"
			end
			return true,
				`order {order.id:sub(1, 8)} → {order.addressId} for {customerName(
					order.customerId
				)}`
		end
	)
	DebugService.register(
		"deliver",
		"Complete your order without walking",
		"deliver",
		function(player)
			return OrderService.completeOrder(player, true)
		end
	)
end

function OrderService.start()
	setupCounterPrompt()

	-- Fragile cake: a knockback squishes it (the order still counts).
	KnockbackService.onHit(function(player)
		local order = orders[player]
		if order and order.kind == "fragile" and not order.broken then
			order.broken = true
			publish(player)
			Net.event("Hint")
				:FireClient(player, "🎂 Oh no, the cake got squished! Deliver it anyway.")
		end
	end)

	-- Move active order targets when a flood starts / ends (phase changes are
	-- replicated on CityState; react to them instead of the start callback,
	-- which fires before the warning phase is set).
	local wasFlooded: { [Player]: boolean } = {}
	local function refreshTargets()
		for player, order in orders do
			local address = MapService.getAddress(order.addressId)
			local flooded = address ~= nil and isFlooded(address.doorPosition)
			if flooded and not wasFlooded[player] then
				Net.event("Hint"):FireClient(
					player,
					`🌊 Flood! {customerName(order.customerId)} is waiting on the balcony — take the ladder!`
				)
			end
			wasFlooded[player] = flooded or nil
			publish(player)
		end
	end
	local cityState = ReplicatedStorage:WaitForChild("CityState")
	cityState:GetAttributeChangedSignal("EventPhase"):Connect(refreshTargets)
	Players.PlayerRemoving:Connect(function(player)
		wasFlooded[player] = nil
	end)

	Net.onServerEvent("DeliverOrder", { ratePerSecond = 2, burst = 4 }, function(player, rawOrderId)
		if typeof(rawOrderId) ~= "string" or #rawOrderId > 64 then
			return
		end
		local order = orders[player]
		if not order or order.id ~= rawOrderId then
			return -- stale or forged request
		end
		local ok, reason = OrderService.completeOrder(player, false)
		if not ok then
			Net.event("Hint"):FireClient(
				player,
				if reason == "too far from the door" then "Get closer to the door!" else reason
			)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if orders[player] then
				task.spawn(function()
					local character = player.Character
					if
						character
						and character:WaitForChild("HumanoidRootPart", 5)
						and orders[player]
					then
						attachBox(player)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		orders[player] = nil
		lastAddress[player] = nil
	end)
end

return OrderService
