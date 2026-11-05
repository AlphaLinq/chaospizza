--!strict
-- "Order a Disaster!" / "MEGA CHAOS Now!" (brief ch. 16), event side.
-- MonetizationService (Codex, C14) grants the receipt and stores a pending
-- effect { kind = "event", key = "OrderDisaster" | "MegaChaosNow", eventId? }.
-- This service consumes those effects when the city can take them, queues the
-- event for everyone, gives the buyer their perk, and handles "Thanks, Dani!".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

local CustomerService = require(script.Parent.CustomerService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)
local MonetizationService = require(script.Parent.MonetizationService)

local POLL_SECONDS = 2
local ACK_RETRIES = 10
local ACK_RETRY_SECONDS = 0.5

local DisasterOrderService = {}

-- Thanks given during the current ordered event: [thanker] = true
local thanked: { [Player]: boolean } = {}
local thankCount = 0

-- Queue an ordered disaster for `buyer`. With an `effectId` (a paid receipt)
-- the pending effect is only acknowledged when the event really starts.
function DisasterOrderService.order(
	buyer: Player,
	eventId: string,
	effectId: string?
): (boolean, string)
	local wasQueued = effectId ~= nil and EventService.isOrderQueued(effectId)
	local ok, message = EventService.orderEvent(eventId, buyer, effectId)
	if ok and not wasQueued then
		Net.event("Hint")
			:FireAllClients(`🍕 {buyer.DisplayName} ordered a disaster! It's {message}.`)
	end
	return ok, message
end

function DisasterOrderService.megaNow(buyer: Player, effectId: string?): (boolean, string)
	if effectId and EventService.isOrderQueued(effectId) then
		return true, "MEGA CHAOS incoming"
	end
	if not EventService.requestMega("purchase", buyer, effectId) then
		return false, "MEGA CHAOS is already on its way!"
	end
	Net.event("Hint"):FireAllClients(`💥 {buyer.DisplayName} started MEGA CHAOS for everyone!`)
	return true, "MEGA CHAOS incoming"
end

local function api(): any
	local m = MonetizationService :: any
	if typeof(m.peekPending) ~= "function" or typeof(m.consumePending) ~= "function" then
		return nil
	end
	return m
end

-- The order is live: acknowledge the receipt's pending effect (retrying while
-- the profile is busy) and give the buyer their perk.
local function acknowledge(info: { userId: number, effectId: string? }?)
	if not info then
		return
	end
	local buyer = Players:GetPlayerByUserId(info.userId)
	if not buyer then
		return
	end
	CustomerService.grantRarePlus(buyer)
	local m = api()
	if not info.effectId or not m then
		return
	end
	for _ = 1, ACK_RETRIES do
		if m.consumePending(buyer, "event", info.effectId) then
			return
		end
		task.wait(ACK_RETRY_SECONDS)
	end
	-- Still pending: the world effect may replay later, but nothing paid is lost.
	warn(`[DisasterOrderService] could not acknowledge effect {info.effectId} for {info.userId}`)
end

-- Pending effects from receipts. Nothing is consumed here: the effect is queued
-- (idempotently, by its id) and acknowledged only when the event starts.
local function pump(player: Player)
	local m = api()
	if not m then
		return
	end
	local effect = m.peekPending(player, "event")
	if typeof(effect) ~= "table" or typeof(effect.id) ~= "string" then
		return
	end
	if EventService.isOrderQueued(effect.id) then
		return
	end
	if effect.key == "MegaChaosNow" then
		if EventService.isMega() or EventService.isMegaPending() then
			return
		end
		DisasterOrderService.megaNow(player, effect.id)
	elseif effect.key == "OrderDisaster" then
		local eventId = if typeof(effect.eventId) == "string" then effect.eventId else nil
		if not eventId or not EventService.canOrder(eventId) then
			return
		end
		DisasterOrderService.order(player, eventId, effect.id)
	end
end

function DisasterOrderService.init()
	DebugService.register(
		"orderevent",
		"Simulate a paid 'Order a Disaster!' (no Robux)",
		"orderevent <HorseRace|Tornado|Flood|Blizzard|mega>",
		function(player, args)
			local id = args[1]
			if id == "mega" then
				return DisasterOrderService.megaNow(player)
			end
			if not id then
				return false, "usage: orderevent <eventId|mega>"
			end
			return DisasterOrderService.order(player, id)
		end
	)
end

function DisasterOrderService.start()
	Net.onServerEvent("ThankBuyer", { ratePerSecond = 1, burst = 2 }, function(player)
		local buyer = EventService.getOrderedBy()
		if not buyer or buyer.userId == player.UserId or thanked[player] then
			return
		end
		thanked[player] = true
		thankCount += 1
		local buyerPlayer = Players:GetPlayerByUserId(buyer.userId)
		if buyerPlayer then
			local name = Validate.string(player.DisplayName, 40) or "A courier"
			Net.event("Hint")
				:FireClient(buyerPlayer, `❤️ {name} says thanks! ({thankCount} so far)`)
		end
	end)
	EventService.onStarted(function(_, by)
		if by == "order" then
			acknowledge(EventService.getOrderedBy())
		elseif by == "mega" then
			acknowledge(EventService.getMegaBuyer())
		end
	end)
	EventService.onEnded(function()
		table.clear(thanked)
		thankCount = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		thanked[player] = nil
		-- Unstarted paid orders stay pending in the profile for the next server.
		EventService.cancelOrdersBy(player.UserId)
	end)

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok: boolean, err: any = pcall(pump :: any, player)
				if not ok then
					warn(`[DisasterOrderService] pump failed: {err}`)
				end
			end
		end
	end)
end

return DisasterOrderService
