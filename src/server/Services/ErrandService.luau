--!strict
-- Errands (#218, docs/GAMEPLAY_LOOP.md G1). Now and then, a few seconds after
-- you pick up a normal order, the customer calls: "Grab some hot sauce from
-- the Hot Sauce Hut!" A shop near your route lights up; touch it before you
-- deliver and the tip is ×1.4 ("Errand"). Skipping it costs nothing. The
-- server picks the shop (Util/Errand), checks the touch by distance, and
-- pays through OrderService.addTipModifier.
--
-- Replication: player attribute "Errand" = JSON { name, item, icon, x, z,
-- done }.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Errand = require(ReplicatedStorage.Shared.Util.Errand)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local ErrandService = {}

type State = { orderId: string, shop: Errand.Shop, done: boolean }

local cfg = Tuning.Errand
local errands: { [Player]: State } = {}

local function publish(player: Player)
	local e = errands[player]
	player:SetAttribute(
		"Errand",
		if e
			then HttpService:JSONEncode({
				name = e.shop.name,
				item = e.shop.item,
				icon = e.shop.icon,
				x = e.shop.x,
				z = e.shop.z,
				done = e.done,
			})
			else nil
	)
end

local function clear(player: Player)
	if errands[player] then
		errands[player] = nil
		publish(player)
	end
end

-- Calls the customer's errand in now. Returns ok + message (debug too).
function ErrandService.call(player: Player): (boolean, string)
	local order = OrderService.getOrder(player)
	local root = CharacterService.getRootPart(player)
	if not order or not root then
		return false, "no order"
	end
	local address = MapService.getAddress(order.addressId)
	if not address then
		return false, "no address"
	end
	local door = OrderService.deliveryPoint(address)
	local shop = Errand.pick(
		MapLayout.errandShops :: any,
		{ x = root.Position.X, z = root.Position.Z },
		{ x = door.X, z = door.Z },
		cfg :: any
	)
	if not shop then
		return false, "no shop near the route"
	end
	errands[player] = { orderId = order.id, shop = shop, done = false }
	publish(player)
	AnalyticsService.custom(player, "errand_offered")
	Net.event("Hint"):FireClient(
		player,
		`📞 The customer calls: "Grab {shop.item} from the {shop.name}!" {shop.icon}`
	)
	return true, `errand: {shop.name}`
end

local function eligible(player: Player, order: OrderService.Order): boolean
	return (order.kind == nil or order.kind == "normal")
		and order.daredevil == nil
		and EconomyService.getDeliveries(player) >= cfg.minDeliveries
end

function ErrandService.init()
	DebugService.register(
		"errand",
		"Errand: the customer calls now, or tick it off",
		"errand [call|grab]",
		function(player, args)
			if args[1] == "grab" then
				local e = errands[player]
				if not e then
					return false, "no errand"
				end
				CharacterService.teleport(
					player,
					Vector3.new(e.shop.x, MapLayout.streetY + 3, e.shop.z)
				)
				return true, `moved to the {e.shop.name}`
			end
			return ErrandService.call(player)
		end
	)
end

function ErrandService.start()
	OrderService.onAssigned(function(player, order)
		clear(player)
		if not eligible(player, order) or math.random() >= cfg.chance then
			return
		end
		local wait = cfg.delayMinSeconds
			+ math.random() * (cfg.delayMaxSeconds - cfg.delayMinSeconds)
		task.delay(wait, function()
			local current = OrderService.getOrder(player)
			if player.Parent and current and current.id == order.id and not errands[player] then
				ErrandService.call(player)
			end
		end)
	end)
	OrderService.addTipModifier(function(player, order)
		local e = errands[player]
		if e and e.done and e.orderId == order.id then
			AnalyticsService.custom(player, "errand_done")
			return cfg.tipMultiplier, "Errand"
		end
		return 1, nil
	end)
	OrderService.onDelivered(function(player)
		clear(player)
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, e in errands do
				local order = OrderService.getOrder(player)
				if not order or order.id ~= e.orderId then
					clear(player) -- cancelled or replaced
					continue
				end
				if e.done then
					continue
				end
				local root = CharacterService.getRootPart(player)
				if
					root
					and Errand.reached(
						{ x = root.Position.X, z = root.Position.Z },
						e.shop,
						cfg.pickupRadius
					)
				then
					e.done = true
					publish(player)
					Net.event("Hint")
						:FireClient(player, `{e.shop.icon} Got {e.shop.item}! Now deliver it.`)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		errands[player] = nil
	end)
end

return ErrandService
