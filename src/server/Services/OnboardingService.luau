--!strict
-- First-session guidance (brief ch. 5). Drives a simple step machine mirrored
-- on the player attribute "OnboardingStep" so the HUD can show the right hint
-- even if it loads late:
--   pickup  → pick up your first order
--   deliver → follow the arrow and deliver
--   again   → grab a second order
--   done    → normal play (M2 adds the guaranteed first event here)
-- No shop prompts are allowed while the step is not "done" (AGENTS.md 4.7).

local Players = game:GetService("Players")

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local OrderService = require(script.Parent.OrderService)

local OnboardingService = {}

-- Callbacks run when a player finishes onboarding (e.g. EventService in M2).
local finishedCallbacks: { (player: Player) -> () } = {}

local function setStep(player: Player, step: string)
	if player:GetAttribute("OnboardingStep") ~= step then
		player:SetAttribute("OnboardingStep", step)
	end
end

function OnboardingService.isDone(player: Player): boolean
	return player:GetAttribute("OnboardingStep") == "done"
end

function OnboardingService.onFinished(callback: (player: Player) -> ())
	table.insert(finishedCallbacks, callback)
end

local function onPlayer(player: Player)
	-- The real step is decided once the profile is loaded (returning players).
	if not player:GetAttribute("OnboardingStep") then
		setStep(player, "loading")
	end
	player:GetAttributeChangedSignal("OrderId"):Connect(function()
		local step = player:GetAttribute("OnboardingStep")
		if player:GetAttribute("OrderId") ~= nil and (step == "pickup" or step == "again") then
			setStep(player, "deliver")
		end
	end)
end

function OnboardingService.init()
	DebugService.register(
		"onboarding",
		"Restart or skip onboarding",
		"onboarding <reset|skip>",
		function(player, args)
			if args[1] == "reset" then
				setStep(player, "pickup")
				return true, "onboarding reset"
			elseif args[1] == "skip" then
				setStep(player, "done")
				return true, "onboarding skipped"
			end
			return true, `step={player:GetAttribute("OnboardingStep")}`
		end
	)
end

function OnboardingService.start()
	OrderService.onDelivered(function(player, _order, _tips, deliveries)
		if OnboardingService.isDone(player) then
			return
		end
		if deliveries >= 2 then
			setStep(player, "done")
			for _, callback in finishedCallbacks do
				task.spawn(callback, player)
			end
		else
			setStep(player, "again")
			-- Brief ch. 5: the first event should happen during the second order.
			EventService.requestSoon("HorseRace", 8)
		end
	end)

	DataService.onLoaded(function(player, profile)
		AnalyticsService.funnel(player, "join")
		setStep(player, if profile.deliveries >= 2 then "done" else "pickup")
	end)
	EventService.onStarted(function()
		for _, player in Players:GetPlayers() do
			AnalyticsService.funnel(player, "first_event_seen")
		end
	end)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	-- Profiles that finished loading before this service started.
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) and player:GetAttribute("OnboardingStep") == "loading" then
			setStep(player, if EconomyService.getDeliveries(player) >= 2 then "done" else "pickup")
		end
	end
end

return OnboardingService
