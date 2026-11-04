--!strict
local RobloxAnalytics = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local AnalyticsService = {}
-- Onboarding funnels span sessions, so second_session belongs to the same funnel.
local STEPS = table.freeze({
	"join",
	"first_order_pickup",
	"first_delivery",
	"first_customer_new",
	"first_event_seen",
	"first_upgrade",
	"second_session",
})
local seen: { [Player]: { [string]: boolean } } = {}
local warned: { [string]: boolean } = {}
local function send(player: Player, name: string, fn: () -> ()): boolean
	if RunService:IsStudio() then
		print(`[AnalyticsService] {player.UserId} {name}`)
	end
	local ok, err = pcall(function()
		fn()
		return nil
	end)
	if not ok and not warned[name] then
		warned[name] = true
		warn(`[AnalyticsService] {name} unavailable: {err}`)
	end
	return ok
end
function AnalyticsService.funnel(player: Player, step: string): boolean
	local index = table.find(STEPS, step)
	if not index then
		return false
	end
	local completed = seen[player] or {}
	if completed[step] then
		return true
	end
	local ok = send(player, `funnel:{step}`, function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, index, step)
	end)
	if ok then
		completed[step] = true
		seen[player] = completed
	end
	return ok
end
-- Call AFTER committing the currency mutation, so endingBalance is authoritative.
function AnalyticsService.economy(
	player: Player,
	flow: string,
	amount: number,
	item: string,
	reason: string
): boolean
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	local direction = if flow == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		elseif flow == "Sink" then Enum.AnalyticsEconomyFlowType.Sink
		else nil
	if not direction then
		return false
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	return send(player, "economy", function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			direction,
			"Tips",
			amount,
			profile.tips,
			reason,
			item
		)
	end)
end
function AnalyticsService.custom(player: Player, name: string, value: number?): boolean
	local amount = if value == nil then 1 else value
	if #name == 0 or amount ~= amount or math.abs(amount) == math.huge then
		return false
	end
	return send(player, `custom:{name}`, function()
		RobloxAnalytics:LogCustomEvent(player, name, amount)
	end)
end
function AnalyticsService.init()
	DebugService.register(
		"analytics",
		"Send a QA custom analytics event",
		"analytics",
		function(player)
			local ok = AnalyticsService.custom(player, "qa_analytics", 1)
			return ok, if ok then "analytics call accepted" else "analytics unavailable; see output"
		end
	)
end
function AnalyticsService.start()
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
	end)
end
return AnalyticsService
