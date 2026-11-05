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

local DisasterOrderService = {}

-- Thanks given during the current ordered event: [thanker] = true
local thanked: { [Player]: boolean } = {}
local thankCount = 0

-- Queue an ordered disaster for `buyer` (after the purchase is recorded).
function DisasterOrderService.order(buyer: Player, eventId: string): (boolean, string)
	local ok, message = EventService.orderEvent(eventId, buyer)
	if ok then
		CustomerService.grantRarePlus(buyer)
		Net.event("Hint")
			:FireAllClients(`🍕 {buyer.DisplayName} ordered a disaster! It's {message}.`)
	end
	return ok, message
end

function DisasterOrderService.megaNow(buyer: Player): (boolean, string)
	if not EventService.requestMega("purchase") then
		return false, "MEGA CHAOS is already on its way!"
	end
	CustomerService.grantRarePlus(buyer)
	Net.event("Hint"):FireAllClients(`💥 {buyer.DisplayName} started MEGA CHAOS for everyone!`)
	return true, "MEGA CHAOS incoming"
end

-- Pending effects from receipts. Feature-detected until C14 lands, so this
-- service never breaks the bootstrap. An effect is only consumed when it can
-- be applied right now; otherwise it stays pending (never lost after payment).
local function pump(player: Player)
	local api = MonetizationService :: any
	if typeof(api.peekPending) ~= "function" or typeof(api.consumePending) ~= "function" then
		return
	end
	local effect = api.peekPending(player, "event")
	if typeof(effect) ~= "table" then
		return
	end
	if effect.key == "MegaChaosNow" then
		if EventService.isMega() or EventService.isMegaPending() then
			return
		end
		if api.consumePending(player, "event", effect.id) then
			DisasterOrderService.megaNow(player)
		end
	elseif effect.key == "OrderDisaster" then
		local eventId = if typeof(effect.eventId) == "string" then effect.eventId else nil
		if not eventId or not EventService.canOrder(eventId) then
			return
		end
		if api.consumePending(player, "event", effect.id) then
			DisasterOrderService.order(player, eventId)
		end
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
	EventService.onEnded(function()
		table.clear(thanked)
		thankCount = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		thanked[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(pump, player)
				if not ok then
					warn(`[DisasterOrderService] pump failed: {err}`)
				end
			end
		end
	end)
end

return DisasterOrderService
