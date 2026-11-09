--!strict
-- City Rush (#219): when two or more couriers deliver within
-- Tuning.CityRush.windowSeconds of each other the whole server is "on a
-- rush" — every delivery grows the combo, and when the chain breaks everyone
-- who took part gets combo × perComboTips. Logic in Util/CityRush.
--
-- Replication: CityState "CityRush" = JSON { combo, endsAt, couriers }
-- (server time) while a rush is on.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CityRush = require(ReplicatedStorage.Shared.Util.CityRush)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local OrderService = require(script.Parent.OrderService)

local CityRushService = {}

local cfg = Tuning.CityRush
local state = CityRush.new()

local function publish()
	local cs = ReplicatedStorage:FindFirstChild("CityState")
	if not cs then
		return
	end
	if not state.active then
		cs:SetAttribute("CityRush", nil)
		return
	end
	cs:SetAttribute(
		"CityRush",
		HttpService:JSONEncode({
			combo = state.combo,
			endsAt = Workspace:GetServerTimeNow()
				+ math.max(0, state.lastAt + cfg.windowSeconds - os.clock()),
			couriers = state.courierCount,
		})
	)
end

local function finish()
	local wasActive, combo = state.active, state.combo
	local pay
	pay, state = CityRush.finish(state, cfg :: any)
	for userId, tips in pay do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			EconomyService.addTips(player, tips, "city_rush")
			AnalyticsService.custom(player, "city_rush_done", combo)
			Net.event("Hint"):FireClient(player, `🔥 City Rush ×{combo} over! +{tips} tips`)
		end
	end
	if wasActive then
		publish()
	end
end

function CityRushService.record(player: Player)
	local now = os.clock()
	if CityRush.expired(state, now, cfg :: any) then
		finish()
	end
	local result = CityRush.deliver(state, player.UserId, now, cfg :: any)
	if result == "start" then
		Net.event("Hint"):FireAllClients(`🔥 CITY RUSH! Keep the deliveries coming!`)
	end
	if state.active then
		publish()
	end
end

function CityRushService.init()
	DebugService.register(
		"rush",
		"City Rush: add a fake second courier's delivery, or end the rush now",
		"rush [bot|end]",
		function(player, args)
			if args[1] == "end" then
				finish()
				return true, "rush ended"
			end
			-- A pretend courier (negative id) so one tester can start a rush.
			local now = os.clock()
			if CityRush.expired(state, now, cfg :: any) then
				finish()
			end
			CityRush.deliver(state, -1, now, cfg :: any)
			CityRushService.record(player)
			return true,
				`combo ×{state.combo}, couriers {state.courierCount}, active {state.active}`
		end
	)
end

function CityRushService.start()
	OrderService.onDelivered(function(player)
		CityRushService.record(player)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if CityRush.expired(state, os.clock(), cfg :: any) then
				finish()
			end
		end
	end)
end

return CityRushService
