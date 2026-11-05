--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.WeeklyRewards)
local Ranking = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Logic = require(ReplicatedStorage.Shared.Util.WeeklyAwards)
local DataService = require(script.Parent.DataService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local DebugService = require(script.Parent.DebugService)
local WeeklyRewardService = {}
local busy: { [Player]: boolean } = {}
local function week(now: number): number
	return math.floor((math.floor(now / Config.secondsPerDay) + Config.mondayOffsetDays) / 7)
end
function WeeklyRewardService.finalize(target: number): any
	local boundary = ((target + 1) * 7 - Config.mondayOffsetDays) * Config.secondsPerDay
	if target < Config.firstWeek or os.time() < boundary + Config.finalizeDelaySeconds then
		return nil
	end
	local existing = DataService.snapshot(Config.snapshotStore, tostring(target), nil)
	if existing then
		return existing
	end
	local rows = DataService.readRanking(Ranking.weeklyStorePrefix .. tostring(target), Config.top)
	if not rows then
		return nil
	end
	return DataService.snapshot(
		Config.snapshotStore,
		tostring(target),
		Logic.snapshot(target, rows, os.time(), Config.top)
	)
end
function WeeklyRewardService.process(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	local profile = DataService.getProfile(player)
	if profile and profile.firstSeen > 0 then
		local from = math.max(
			Config.firstWeek,
			week(profile.firstSeen),
			(profile.claims["weekly.cursor"] or Config.firstWeek - 1) + 1
		)
		for target = from, math.min(week(os.time()) - 1, from + Config.maxWeeksPerPass - 1) do
			if player.Parent ~= Players then
				break
			end
			local snapshot = WeeklyRewardService.finalize(target)
			if not snapshot then
				break
			end
			local ok = Transaction.run(player, function(draft)
				Logic.claim(draft, player.UserId, snapshot, Config, os.time())
				draft.claims["weekly.cursor"] = target
				return true, "Weekly standings checked."
			end, "weekly_rank")
			if not ok then
				break
			end
		end
	end
	busy[player] = nil
end
function WeeklyRewardService.init()
	DebugService.register(
		"weeklyreward",
		"Finalize eligible weeks and claim your real standing",
		"weeklyreward",
		function(player)
			WeeklyRewardService.process(player)
			return true, "Eligible finalized standings checked."
		end
	)
end
function WeeklyRewardService.start()
	DataService.onLoaded(WeeklyRewardService.process)
	for _, player in Players:GetPlayers() do
		task.spawn(WeeklyRewardService.process, player)
	end
	task.spawn(function()
		while true do
			task.wait(Config.refreshSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(WeeklyRewardService.process, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end
return WeeklyRewardService
