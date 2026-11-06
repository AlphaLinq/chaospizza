--!strict
-- An unpublished-Studio QA runner. Gameplay state is reached through public
-- APIs; the original perf command and this runner use the same capture API.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Events = require(script.Parent.EventService)
local Moni = require(script.Parent.MonetizationService)
local Perf = require(script.Parent.PerfService)
local Debug = require(script.Parent.DebugService)
local Service = {}
local busy: { [Player]: boolean } = {}
function Service.run(player: Player, quality: string, event: string): (boolean, string)
	if not RunService:IsStudio() or game.GameId ~= 0 then
		return false, "Use an unpublished Studio fixture."
	end
	if quality ~= "low" and quality ~= "high" then
		return false, "Choose low or high."
	end
	if
		event ~= "CheeseWheel"
		and event ~= "Blackout"
		and event ~= "BubbleStorm"
		and event ~= "mega"
	then
		return false, "Choose a benchmark event or mega."
	end
	if busy[player] or Events.getPhase() ~= "calm" or Events.isMegaPending() then
		return false, "Start from a fresh calm playtest."
	end
	local ok, reason = Moni.requestPurchase(player, `settings:quality.{quality}`)
	if not ok then
		return false, reason
	end
	local queued = if event == "mega"
		then Events.requestMega("debug")
		else Events.requestSoon(event, 0)
	if not queued then
		return false, "The event could not be scheduled."
	end
	busy[player] = true
	local function publish(stage: string)
		player:SetAttribute(
			"PerfScenario",
			HttpService:JSONEncode({ stage = stage, quality = quality, event = event })
		)
	end
	publish("waiting")
	task.spawn(function()
		local deadline = os.clock() + Config.scenarioTimeoutSeconds
		while
			player.Parent == Players
			and Events.getPhase() ~= "active"
			and os.clock() < deadline
		do
			task.wait(Config.scenarioPollSeconds)
		end
		if player.Parent ~= Players then
			busy[player] = nil
			return
		end
		if
			Events.getPhase() ~= "active"
			or (event == "mega" and not Events.isMega())
			or (event ~= "mega" and Events.getActiveEvent() ~= event)
		then
			publish("wrong_event")
			busy[player] = nil
			return
		end
		task.wait(Config.scenarioWarmupSeconds)
		local captured = Perf.request(player, Config.defaultCaptureSeconds)
		publish(if captured then "capture_requested" else "failed")
		task.wait(Config.defaultCaptureSeconds)
		busy[player] = nil
	end)
	return true, "Scenario queued; inspect PerfScenario and PerfClientReport."
end
function Service.init()
	Debug.register(
		"perfcase",
		"Run one unpublished Studio benchmark",
		"perfcase <low|high> <CheeseWheel|Blackout|BubbleStorm|mega>",
		function(player, args)
			return Service.run(player, args[1] or "", args[2] or "")
		end
	)
end
function Service.start()
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end
return Service
