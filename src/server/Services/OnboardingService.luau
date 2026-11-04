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

local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
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
	setStep(player, if EconomyService.getDeliveries(player) >= 2 then "done" else "pickup")
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
		end
	end)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return OnboardingService
