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

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Net = require(ReplicatedStorage.Shared.Net)
local OrderLogic = require(ReplicatedStorage.Shared.Util.OrderLogic)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local MapService = require(script.Parent.MapService)

export type Order = {
	id: string,
	addressId: string,
	customerId: string,
	createdAt: number,
}

local DISTANCE_TOLERANCE = 4 -- studs of latency slack on top of the radius

local OrderService = {}

local orders: { [Player]: Order } = {}
local lastAddress: { [Player]: string } = {}
local customerById: { [string]: any } = {}
local customerInfos: { OrderLogic.CustomerInfo } = {}

-- Hooks for later systems (events, style, onboarding): called after a delivery.
local deliveredCallbacks: { (player: Player, order: Order, tips: number, deliveries: number) -> () } =
	{}

local function rng(): number
	return math.random()
end

local function customerName(id: string): string
	local c = customerById[id]
	return if c then c.displayName else id
end

local function publish(player: Player)
	local order = orders[player]
	if order then
		local address = MapService.getAddress(order.addressId)
		-- OrderId is the "changed" signal clients listen to: set it LAST.
		player:SetAttribute("OrderAddressId", order.addressId)
		player:SetAttribute("OrderLabel", if address then address.label else order.addressId)
		player:SetAttribute("OrderCustomer", customerName(order.customerId))
		player:SetAttribute("OrderTarget", if address then address.doorPosition else nil)
		player:SetAttribute("OrderId", order.id)
	else
		-- ...and clear it FIRST.
		player:SetAttribute("OrderId", nil)
		player:SetAttribute("OrderAddressId", nil)
		player:SetAttribute("OrderLabel", nil)
		player:SetAttribute("OrderCustomer", nil)
		player:SetAttribute("OrderTarget", nil)
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

function OrderService.onDelivered(callback: (
	player: Player,
	order: Order,
	tips: number,
	deliveries: number
) -> ())
	table.insert(deliveredCallbacks, callback)
end

-- Creates an order for the player if they do not have one. Returns the order.
function OrderService.assignOrder(player: Player): Order?
	if orders[player] then
		return orders[player]
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
	local order: Order = {
		id = HttpService:GenerateGUID(false),
		addressId = addressId,
		customerId = OrderLogic.pickCustomer(customerInfos, EventService.getActiveEvent(), rng),
		createdAt = os.clock(),
	}
	orders[player] = order
	lastAddress[player] = addressId
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
		local flat = Vector3.new(1, 0, 1)
		local distance = ((root.Position - address.doorPosition) * flat).Magnitude
		local verticalOk = math.abs(root.Position.Y - address.doorPosition.Y) < 10
		if distance > Tuning.Orders.deliveryRadiusStuds + DISTANCE_TOLERANCE or not verticalOk then
			return false, "too far from the door"
		end
	end

	-- Anti-teleport farming: the client owns its character physics, so also
	-- require a plausible travel time from the counter to the door.
	if not skipDistanceCheck then
		local counter = MapService.getCounterPart().Position
		local flatDistance = ((address.doorPosition - counter) * Vector3.new(1, 0, 1)).Magnitude
		local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
		local minSeconds = flatDistance / fastest * Tuning.Orders.minTravelTimeFactor
		if os.clock() - order.createdAt < minSeconds then
			return false, "too fast"
		end
	end

	-- Clear first: a repeated request can never pay twice.
	orders[player] = nil
	removeBox(player)
	publish(player)

	local bonus = if EventService.isHazardActive() then Tuning.Events.tipBonusDuringEvent else 0
	local tips = OrderLogic.tip(Tuning.Orders.baseTip, bonus, Tuning.Style.maxTotalBonus)
	EconomyService.addTips(player, tips, "delivery")
	EconomyService.addXp(player, Tuning.Orders.baseXp)
	local deliveries = EconomyService.recordDelivery(player)

	local customer = customerById[order.customerId]
	Net.event("DeliveryResult"):FireClient(player, {
		tips = tips,
		customer = customerName(order.customerId),
		line = if customer then customer.line else "",
		deliveries = deliveries,
		eventBonus = bonus > 0,
	})

	for _, callback in deliveredCallbacks do
		task.spawn(callback, player, order, tips, deliveries)
	end
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
		table.insert(customerInfos, { id = c.id, event = c.event })
	end

	DebugService.register(
		"order",
		"Show or force your current order",
		"order [new|cancel]",
		function(player, args)
			if args[1] == "new" then
				OrderService.cancelOrder(player)
				local order = OrderService.assignOrder(player)
				return order ~= nil, if order then `new order to {order.addressId}` else "failed"
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
