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

local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local OrderService = require(script.Parent.OrderService)

local FinaleService = {}

local cfg = Tuning.Finale
local nextAt = os.clock() + cfg.intervalSeconds
local requested = false -- the finale asked for the MEGA, not started yet
local running = false
local noticed = false
local participants: { [Player]: boolean } = {}

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
	for player in participants do
		if player.Parent then
			EconomyService.addTips(player, cfg.bonusTips, "finale")
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
		end
	end)
	EventService.onEnded(function(_, by)
		if by == "mega" and running then
			finish()
		end
	end)
	OrderService.onDelivered(function(player)
		if running then
			participants[player] = true
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
