--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Smoke)
local Schema = require(ReplicatedStorage.Shared.Util.ProfileSchema)
local Badges = require(ReplicatedStorage.Shared.Config.Badges)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local OrderService = require(script.Parent.OrderService)
local EventService = require(script.Parent.EventService)
local CharacterService = require(script.Parent.CharacterService)
local MonetizationService = require(script.Parent.MonetizationService)
local DailyService = require(script.Parent.DailyService)
local DebugService = require(script.Parent.DebugService)
local ChaosMeterService = require(script.Parent.ChaosMeterService)
local SmokeService = {}
local running = false
function SmokeService.run(player: Player): (boolean, string)
	if
		not RunService:IsStudio()
		or not DebugService.isAuthorized(player)
		or DataService.isPersistent()
	then
		return false, "Smoke requires Studio, debug access and memory-only profiles."
	end
	if
		running
		or #Players:GetPlayers() ~= 1
		or EventService.getPhase() ~= "calm"
		or player:GetAttribute("OrderId")
		or player:GetAttribute("GiantOrderId")
		or ChaosMeterService.getValue() ~= 0
	then
		return false, "Start a fresh solo playtest with calm streets and no active order."
	end
	for _, badge in Badges.items do
		if badge.badgeId > 0 then
			return false, "Disable real badge IDs for the smoke test."
		end
	end
	local profile = DataService.getProfile(player)
	local root = CharacterService.getRootPart(player)
	if not profile or not root then
		return false, "Wait for the profile and character."
	end
	running = true
	local baseline = Schema.migrate(profile)
	local onboarding = player:GetAttribute("OnboardingStep")
	player:SetAttribute("OnboardingStep", "done")
	local ranks = DataService.mockRankings(nil)
	local position = root.Position
	local started = os.clock()
	local rows: { any } = {}
	local function step(name: string, fn: () -> boolean)
		local ok, result = pcall(fn)
		local passed = ok and result == true
		table.insert(
			rows,
			{ name = name, passed = passed, detail = if ok then "" else tostring(result) }
		)
		player:SetAttribute("SmokeReport", HttpService:JSONEncode({ running = true, steps = rows }))
		print(`[Smoke] {if passed then "PASS" else "FAIL"} {name}`)
	end
	step("order pickup", function()
		return OrderService.assignOrder(player) ~= nil
	end)
	step("delivery reward", function()
		local before = player:GetAttribute("Deliveries")
		local ok = OrderService.completeOrder(player, true)
		task.wait(Config.settleSeconds)
		return ok and player:GetAttribute("Deliveries") == (before :: number) + 1
	end)
	step("shop preview", function()
		local snapshot = MonetizationService.getShop(player)
		return type(snapshot.gamepasses) == "table" and type(snapshot.products) == "table"
	end)
	step("daily idempotency", function()
		if not DailyService.claimLogin(player) then
			return false
		end
		local first = DataService.getProfile(player)
		if not first then
			return false
		end
		local balance = first.tips
		return DailyService.claimLogin(player)
			and (DataService.getProfile(player) :: any).tips == balance
	end)
	step("event lifecycle", function()
		if not EventService.requestMega("smoke") then
			return false
		end
		local sawActive = false
		while os.clock() - started < Config.maxSeconds do
			local phase = EventService.getPhase()
			if phase == "active" then
				sawActive = true
			end
			if sawActive and phase == "calm" then
				return true
			end
			task.wait(Config.pollSeconds)
		end
		return false
	end)
	OrderService.cancelOrder(player)
	step("restore profile", function()
		local ok = DataService.transaction(player, function(draft)
			for key in draft do
				(draft :: any)[key] = nil
			end
			for key, value in baseline do
				(draft :: any)[key] = value
			end
			return true
		end, true)
		if ok then
			EconomyService.refresh(player)
			player:SetAttribute("OnboardingStep", onboarding)
			local known = 0
			for _, entry in baseline.customerBook do
				if entry.served > 0 then
					known += 1
				end
			end
			player:SetAttribute("BookDiscovered", known)
			Net.event("CustomerBookUpdated"):FireClient(player, { id = "", isNew = false })
		end
		return ok
	end)
	step("restore rankings and position", function()
		CharacterService.teleport(player, position)
		return DataService.mockRankings(ranks) ~= nil
			and EventService.getPhase() == "calm"
			and ChaosMeterService.getValue() == 0
	end)
	local passed = true
	for _, row in rows do
		if not row.passed then
			passed = false
		end
	end
	running = false
	local report = HttpService:JSONEncode({
		running = false,
		passed = passed,
		seconds = math.floor(os.clock() - started),
		steps = rows,
	})
	player:SetAttribute("SmokeReport", report)
	return passed, report
end
function SmokeService.init()
	if RunService:IsStudio() then
		DebugService.register(
			"smoke",
			"Run the solo Studio smoke test and restore mock progress",
			"smoke [status]",
			function(player, args)
				if args[1] == "status" then
					return true, tostring(player:GetAttribute("SmokeReport"))
				end
				return SmokeService.run(player)
			end
		)
	end
end
return SmokeService
