--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local Calendar = require(ReplicatedStorage.Shared.Util.DailyLogin).new(Config)
local Weekly = require(ReplicatedStorage.Shared.Util.WeeklyChallenges).new(Config)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local MonetizationService = require(script.Parent.MonetizationService)
local DailyService = {}
local loading: { [Player]: boolean } = {}
local function publish(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	player:SetAttribute(
		"DailyState",
		HttpService:JSONEncode({
			daily = profile.dailyLogin,
			weekly = Weekly.refresh(profile.weekly, os.time()),
			choices = Weekly.choices(),
		})
	)
	EconomyService.refresh(player)
end
local function mutate(player: Player, fn: (any) -> boolean, persist: boolean): boolean
	for _ = 1, Persistence.retries do
		if not DataService.isLoaded(player) or player.Parent ~= Players then
			return false
		end
		local evaluated = false
		if
			DataService.transaction(player, function(profile)
				evaluated = true
				return fn(profile)
			end, persist)
		then
			publish(player)
			return true
		end
		if evaluated then
			return false
		end
		task.wait(Persistence.retryBaseSeconds)
	end
	return false
end
local function grant(profile: any, gift: any): any
	local awarded = table.clone(gift)
	awarded.tips = math.min(gift.tips, math.max(0, Config.maxTips - profile.tips))
	profile.tips += awarded.tips
	profile.xp += gift.xp
	if gift.cosmetic then
		profile.cosmetics.owned[gift.cosmetic] = true
	end
	return awarded
end
function DailyService.claimLogin(player: Player): boolean
	local reward: any = nil
	local now = os.time()
	local ok = mutate(player, function(profile)
		local gift, state = Calendar.claim(profile.dailyLogin, now)
		profile.dailyLogin = state
		profile.weekly = Weekly.refresh(profile.weekly, now)
		if profile.firstSeen == 0 then
			profile.firstSeen = now
		end
		if gift then
			reward = grant(profile, gift)
		end
		return true
	end, true)
	if ok and reward then
		player:SetAttribute(
			"DailyReward",
			HttpService:JSONEncode({
				day = (DataService.getProfile(player) :: any).dailyLogin.day,
				tips = reward.tips,
				xp = reward.xp,
				claimedAt = now,
				cosmetic = reward.cosmetic,
			})
		)
		if reward.tips > 0 then
			AnalyticsService.economy(player, "Source", reward.tips, "daily", "daily")
		end
	end
	return ok
end
function DailyService.recordProgress(player: Player, event: string, amount: number): boolean
	if event ~= "delivery" and event ~= "eventDelivery" and event ~= "newCustomer" then
		return false
	end
	if not Validate.integer(amount, 0, Config.maxProgressAmount) then
		return false
	end
	return mutate(player, function(profile)
		profile.weekly = Weekly.record(profile.weekly, event, amount, os.time())
		return true
	end, false)
end
function DailyService.select(player: Player, id: string): boolean
	return mutate(player, function(profile)
		local selected, state = Weekly.select(profile.weekly, id, os.time())
		profile.weekly = state
		return selected
	end, true)
end
function DailyService.claimWeekly(player: Player, id: string): boolean
	local reward: any = nil
	local ok = mutate(player, function(profile)
		local gift, state = Weekly.claim(profile.weekly, id, os.time())
		if not gift then
			return false
		end
		profile.weekly = state
		reward = grant(profile, gift)
		return true
	end, true)
	if ok and reward.tips > 0 then
		AnalyticsService.economy(player, "Source", reward.tips, id, "weekly")
	end
	return ok
end
local function onLoaded(player: Player)
	if loading[player] then
		return
	end
	loading[player] = true
	while
		player.Parent == Players
		and DataService.isLoaded(player)
		and not DailyService.claimLogin(player)
	do
		task.wait(Persistence.retryBaseSeconds)
	end
	loading[player] = nil
end
function DailyService.init()
	DebugService.register(
		"daily",
		"Claim calendar or simulate weekly progress",
		"daily [progress <event> <amount>]",
		function(player, args)
			if args[1] == "progress" then
				local amount = tonumber(args[3])
				local ok = amount ~= nil
					and DailyService.recordProgress(player, args[2] or "", amount)
				return ok,
					if ok then "weekly progress recorded" else "invalid progress event/amount"
			end
			local ok = DailyService.claimLogin(player)
			local profile = DataService.getProfile(player)
			return ok,
				if profile
					then HttpService:JSONEncode({
						daily = profile.dailyLogin,
						weekly = profile.weekly,
					})
					else "profile unavailable"
		end
	)
end
function DailyService.start()
	MonetizationService.registerAction("daily", function(player, action)
		local mode, id = string.match(action, "^(%a+)%.([%w_]+)$")
		local ok = if mode == "select" and id
			then DailyService.select(player, id)
			elseif mode == "claim" and id then DailyService.claimWeekly(player, id)
			else false
		return ok,
			if ok
				then "Weekly calendar updated."
				else "This challenge can't be selected or claimed right now."
	end)
	DataService.onLoaded(onLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			task.spawn(onLoaded, player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		loading[player] = nil
	end)
end
return DailyService
