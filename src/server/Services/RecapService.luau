--!strict
-- Shift report (#234). The chaos finale is the session's peak; this gives
-- it a close: a few seconds after each finale pays out, every courier who
-- delivered this round gets a recap card (Net "Recap"): deliveries, tips,
-- rarest customer, best streak, daredevils, events lived through and event
-- challenges done, under a headline (Util/Recap). Then a new round starts.
-- Couriers who join mid-round count from when they joined. Challenges come
-- from the "ChallengesDone" attribute delta, so nothing else needs a hook.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Recap = require(ReplicatedStorage.Shared.Util.Recap)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)
local FinaleService = require(script.Parent.FinaleService)
local OrderService = require(script.Parent.OrderService)

local RecapService = {}

type Round = { stats: Recap.Stats, challengesAtStart: number }

local cfg = Tuning.Recap
local rounds: { [Player]: Round } = {}
local lastReport: { [Player]: Recap.Report } = {} -- #248: the previous round
local customerById: { [string]: any } = {}
for _, c in Customers do
	customerById[c.id] = c
end
local rarityOrder: { [string]: number } = {}
local legendaryOrder = math.huge
for _, r in Rarities do
	rarityOrder[r.id] = r.order
	if r.id == "Legendary" then
		legendaryOrder = r.order
	end
end

local function challengesDone(player: Player): number
	local v = player:GetAttribute("ChallengesDone")
	return if typeof(v) == "number" then v else 0
end

local function newRound(player: Player)
	rounds[player] = { stats = Recap.new(), challengesAtStart = challengesDone(player) }
end

local function roundOf(player: Player): Round
	local round = rounds[player]
	if not round then
		newRound(player)
		round = rounds[player]
	end
	return round :: Round
end

-- Sends the card (if there is something to report) and starts a new round.
function RecapService.send(player: Player, hero: boolean): boolean
	local round = roundOf(player)
	local challenges = challengesDone(player) - round.challengesAtStart
	local report = Recap.report(round.stats, hero, challenges, legendaryOrder)
	newRound(player)
	if not report then
		return false
	end
	local payload = table.clone(report) :: any
	payload.nextFinaleIn = math.max(0, math.floor(FinaleService.secondsLeft()))
	payload.compare = Recap.compare(report, lastReport[player])
	lastReport[player] = report
	Net.event("Recap"):FireClient(player, payload)
	AnalyticsService.custom(player, "recap_shown", report.deliveries)
	return true
end

function RecapService.init()
	DebugService.register(
		"recap",
		"Shift report: show this round's card now",
		"recap",
		function(player)
			local round = roundOf(player)
			local deliveries = round.stats.deliveries
			local hero = (tonumber(player:GetAttribute("FinaleHeroUntil")) or 0)
				> Workspace:GetServerTimeNow()
			if RecapService.send(player, hero) then
				return true, `recap sent ({deliveries} deliveries); new round started`
			end
			return false, "nothing to report yet: deliver an order first"
		end
	)
end

function RecapService.start()
	for _, player in Players:GetPlayers() do
		newRound(player)
	end
	Players.PlayerAdded:Connect(newRound)
	Players.PlayerRemoving:Connect(function(player)
		rounds[player] = nil
		lastReport[player] = nil
	end)
	OrderService.onDelivered(function(player, order, tips, _, info)
		local customer = customerById[order.customerId]
		local rarity = customer and customer.rarity
		local streak = tonumber(player:GetAttribute("Streak")) or 0
		Recap.addDelivery(
			roundOf(player).stats,
			tips,
			streak,
			info.daredevil == true,
			if rarity then rarityOrder[rarity] else nil,
			rarity,
			customer and customer.displayName
		)
	end)
	EventService.onEnded(function()
		for _, player in Players:GetPlayers() do
			roundOf(player).stats.events += 1
		end
	end)
	FinaleService.onFinished(function(hero)
		task.wait(cfg.delaySeconds)
		for _, player in Players:GetPlayers() do
			RecapService.send(player, player == hero)
		end
	end)
end

return RecapService
