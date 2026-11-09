--!strict
-- Chaos finale (#186, docs/GAMEPLAY_LOOP.md G6). Every Tuning.Finale
-- .intervalSeconds the server ends a "session" with a MEGA CHAOS (two events
-- at once, the meter's MEGA path). The HUD warns noticeSeconds before
-- ("Finale in 3:00!") and counts down the last seconds; everyone who
-- delivers during the finale gets a bonus when it ends. If a MEGA is already
-- pending or running, the finale waits for it to finish.
--
-- Replication: CityState "FinaleAt" (server time of the next finale) and
-- "Finale" = true while the finale MEGA runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EventVote = require(ReplicatedStorage.Shared.Util.EventVote)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DailyService = require(script.Parent.DailyService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local FeatureTipService = require(script.Parent.FeatureTipService)
local LoopTitleService = require(script.Parent.LoopTitleService)
local OrderService = require(script.Parent.OrderService)

local FinaleService = {}

local cfg = Tuning.Finale
local nextAt = os.clock() + cfg.intervalSeconds
local requested = false -- the finale asked for the MEGA, not started yet
local running = false
local noticed = false
-- Deliveries during the finale, and when each courier reached their count.
local participants: { [Player]: { count: number, at: number } } = {}

local function cityState(): Instance
	return ReplicatedStorage:WaitForChild("CityState")
end

local function publish()
	cityState():SetAttribute(
		"FinaleAt",
		Workspace:GetServerTimeNow() + math.max(0, nextAt - os.clock())
	)
	cityState():SetAttribute("Finale", running or nil)
end

function FinaleService.secondsLeft(): number
	return math.max(0, nextAt - os.clock())
end

function FinaleService.isRunning(): boolean
	return running
end

-- No event vote while the finale is about to take the next slot.
function FinaleService.blocksVote(): boolean
	if running or requested then
		return true
	end
	local stage = EventVote.finaleStage(FinaleService.secondsLeft(), cfg :: any)
	return stage == "countdown" or stage == "due"
end

-- Moves the next finale to `seconds` from now (debug).
function FinaleService.schedule(seconds: number)
	nextAt = os.clock() + math.max(0, seconds)
	noticed = false
	publish()
end

local function step()
	if running or requested then
		return
	end
	local stage = EventVote.finaleStage(FinaleService.secondsLeft(), cfg :: any)
	if stage == "notice" and not noticed then
		noticed = true
		FeatureTipService.showAll("Finale")
		Net.event("Hint"):FireAllClients(
			`🎆 CHAOS FINALE in {EventVote.clock(FinaleService.secondsLeft())}! Stay for double disasters!`
		)
	elseif stage == "due" then
		if EventService.isMega() or EventService.isMegaPending() then
			nextAt = os.clock() + cfg.retrySeconds
			publish()
			return
		end
		if EventService.requestMega("finale") then
			requested = true
			table.clear(participants)
			Net.event("Hint"):FireAllClients("🎆 THE CHAOS FINALE BEGINS!")
		else
			nextAt = os.clock() + cfg.retrySeconds
			publish()
		end
	end
end

local function finish()
	running = false
	requested = false
	noticed = false
	nextAt = os.clock() + cfg.intervalSeconds
	-- The finale hero (#208): most deliveries, ties to the earlier one.
	local entries = {}
	for player, p in participants do
		if player.Parent then
			table.insert(entries, { id = player, count = p.count, at = p.at })
		end
	end
	local hero: Player? = EventVote.hero(entries)
	if hero then
		EconomyService.addTips(hero, cfg.heroTips, "finale_hero")
		AnalyticsService.custom(hero, "finale_hero")
		LoopTitleService.bump(hero, "loop.finaleHero") -- Finale Hero title (#227)
		hero:SetAttribute("FinaleHeroUntil", Workspace:GetServerTimeNow() + cfg.heroCrownSeconds)
		local count = participants[hero].count
		Net.event("Hint"):FireAllClients(
			`🏆 {hero.DisplayName} is the FINALE HERO with {count} {if count == 1
				then "delivery"
				else "deliveries"}!`
		)
		Net.event("Hint"):FireClient(hero, `🏆 Finale hero! +{cfg.heroTips} tips`)
	end
	for player in participants do
		if player.Parent then
			EconomyService.addTips(player, cfg.bonusTips, "finale")
			AnalyticsService.custom(player, "finale_bonus")
			DailyService.recordProgress(player, "finale", 1) -- weekly (#207)
			Net.event("Hint"):FireClient(player, `🎆 Finale survived! +{cfg.bonusTips} tips`)
		end
	end
	table.clear(participants)
	publish()
end

function FinaleService.init()
	DebugService.register(
		"finale",
		"Chaos finale: start now, or schedule it",
		"finale [now|in <seconds>]",
		function(_, args)
			local sub = args[1] or "now"
			if sub == "now" then
				FinaleService.schedule(0)
				return true, "finale due now"
			elseif sub == "in" then
				local seconds = tonumber(args[2]) or cfg.countdownSeconds
				FinaleService.schedule(seconds)
				return true, `finale in {seconds}s`
			end
			return false, "usage: finale [now|in <seconds>]"
		end
	)
end

function FinaleService.start()
	publish()
	EventService.onStarted(function(_, by)
		if by == "mega" and requested then
			requested = false
			running = true
			publish()
			-- #202: who stayed for the finale (value = players online).
			local online = #Players:GetPlayers()
			for _, player in Players:GetPlayers() do
				AnalyticsService.custom(player, "finale_start", online)
			end
		end
	end)
	EventService.onEnded(function(_, by)
		if by == "mega" and running then
			finish()
		end
	end)
	OrderService.onDelivered(function(player)
		if running then
			local p = participants[player] or { count = 0, at = 0 }
			p.count += 1
			p.at = os.clock()
			participants[player] = p
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			step()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end)
end

return FinaleService
