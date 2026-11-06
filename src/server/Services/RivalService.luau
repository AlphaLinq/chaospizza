--!strict
-- Speedy Sal, the rival courier (#148). Now and then (Tuning.Rival) Sal from
-- the pizzeria across town takes the same order and races you there on his
-- rocket scooter. Deliver before he lands and the customer doubles your tips;
-- if he gets there first you just get a cheeky line. No penalty, no contact:
-- Sal flies over the rooftops and never touches anyone.
--
-- Replication: player attribute "RivalRace" = JSON { id, from, to, t0, arrive,
-- outcome? } (server time). Only the racing player's client draws Sal and
-- the countdown (RivalController).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local RivalRace = require(ReplicatedStorage.Shared.Util.RivalRace)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local RivalService = {}

type Race = {
	id: number,
	orderId: string,
	deadline: number, -- os.clock()
	data: { [string]: any },
	done: boolean,
}

local cfg = Tuning.Rival
local races: { [Player]: Race } = {}
local lastRace: { [Player]: number } = {}
local nextId = 0

local LOSE_LINES = {
	'Sal: "Too slow, pizza turtle!"',
	'Sal: "Cheese melts faster than you run!"',
	'Sal: "Better luck next slice!"',
}

local function publish(player: Player, race: Race?)
	player:SetAttribute("RivalRace", if race then HttpService:JSONEncode(race.data) else nil)
end

local function finish(player: Player, race: Race, outcome: "won" | "lost" | "cancelled")
	if race.done then
		return
	end
	race.done = true
	race.data.outcome = outcome
	publish(player, race)
	-- Keep the outcome visible briefly so the client can play Sal's reaction.
	task.delay(4, function()
		if races[player] == race then
			races[player] = nil
			publish(player, nil)
		end
	end)
end

function RivalService.startRace(player: Player, order: OrderService.Order): boolean
	local address = MapService.getAddress(order.addressId)
	local root = CharacterService.getRootPart(player)
	if not address or not root then
		return false
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local walk = if humanoid then humanoid.WalkSpeed else Tuning.Movement.baseWalkSpeed
	local door = OrderService.deliveryPoint(address)
	local eta = RivalRace.eta(root.Position.X, root.Position.Z, door.X, door.Z, walk, cfg :: any)
	local now = Workspace:GetServerTimeNow()
	local start = MapLayout.rivalStart
	nextId += 1
	local race: Race = {
		id = nextId,
		orderId = order.id,
		deadline = os.clock() + eta,
		done = false,
		data = {
			id = nextId,
			from = { start.x, start.y, start.z },
			to = { door.X, door.Y, door.Z },
			t0 = now + cfg.revSeconds,
			arrive = now + eta,
			cruise = cfg.cruiseHeight,
		},
	}
	races[player] = race
	lastRace[player] = os.clock()
	publish(player, race)
	Net.event("Hint")
		:FireClient(player, `🛵 Speedy Sal wants this order too! Beat him to {address.label}!`)
	return true
end

function RivalService.getRace(player: Player): { [string]: any }?
	local race = races[player]
	return if race then race.data else nil
end

function RivalService.init()
	DebugService.register(
		"sal",
		"Speedy Sal rival race: start on your order, win or lose now",
		"sal [spawn|win|lose]",
		function(player, args)
			local sub = args[1] or "spawn"
			if sub == "spawn" then
				local order = OrderService.getOrder(player) or OrderService.assignOrder(player)
				if not order then
					return false, "no order"
				end
				local current = races[player]
				if current then
					races[player] = nil
					publish(player, nil)
				end
				local ok = RivalService.startRace(player, order)
				local race = races[player]
				return ok,
					if race
						then `Sal races you, arrives in {math.floor(
							race.data.arrive - Workspace:GetServerTimeNow()
						)}s`
						else "could not start"
			end
			local race = races[player]
			if not race or race.done then
				return false, "no race running"
			end
			if sub == "win" then
				return OrderService.completeOrder(player, true)
			elseif sub == "lose" then
				race.deadline = 0
				return true, "Sal will land now"
			end
			return false, "usage: sal [spawn|win|lose]"
		end
	)
end

function RivalService.start()
	OrderService.onAssigned(function(player, order)
		if races[player] then
			return
		end
		local level = tonumber(player:GetAttribute("CourierLevel")) or 1
		local since = os.clock() - (lastRace[player] or -math.huge)
		if RivalRace.eligible(level, order.kind, since, cfg :: any, math.random) then
			RivalService.startRace(player, order)
		end
	end)
	OrderService.onDelivered(function(player, order, tips)
		local race = races[player]
		if not race or race.done or race.orderId ~= order.id then
			return
		end
		if os.clock() <= race.deadline then
			local bonus = math.floor(tips * (cfg.winTipMultiplier - 1) + 0.5)
			if bonus > 0 then
				EconomyService.addTips(player, bonus, "rival_win")
			end
			Net.event("Hint"):FireClient(
				player,
				`🏁 You beat Speedy Sal! The customer doubled your tips (+{bonus}).`
			)
			finish(player, race, "won")
		else
			finish(player, race, "lost")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, race in races do
				if race.done then
					continue
				end
				local order = OrderService.getOrder(player)
				if not order or order.id ~= race.orderId then
					finish(player, race, "cancelled")
				elseif os.clock() > race.deadline then
					Net.event("Hint"):FireClient(
						player,
						`🛵 Sal got there first! {LOSE_LINES[math.random(1, #LOSE_LINES)]}`
					)
					finish(player, race, "lost")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		races[player] = nil
		lastRace[player] = nil
	end)
end

return RivalService
