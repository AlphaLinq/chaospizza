--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Community)
local Logic = require(ReplicatedStorage.Shared.Util.GroupReward)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local GroupRewardService = {}
local checking: { [Player]: boolean } = {}
function GroupRewardService.claim(player: Player): boolean
	if Config.groupId == 0 or checking[player] then
		return false
	end
	local profile = DataService.getProfile(player)
	if not profile or profile.claims[`group.{Config.groupId}`] then
		return false
	end
	checking[player] = true
	local ok, member = pcall(function()
		return player:IsInGroupAsync(Config.groupId)
	end)
	local awarded = false
	if ok and member and player.Parent == Players then
		awarded = Transaction.run(player, function(draft)
			return Logic.apply(draft, Config, true, os.time()), "Community look unlocked!"
		end, "group_reward")
	end
	checking[player] = nil
	return awarded
end
function GroupRewardService.init()
	DebugService.register(
		"groupreward",
		"Check real Roblox community membership",
		"groupreward",
		function(player)
			return GroupRewardService.claim(player),
				if Config.groupId == 0
					then "Group rewards are disabled (groupId=0)."
					else "Community reward checked."
		end
	)
end
function GroupRewardService.start()
	if Config.groupId == 0 then
		return
	end
	DataService.onLoaded(GroupRewardService.claim)
	for _, player in Players:GetPlayers() do
		task.spawn(GroupRewardService.claim, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		checking[player] = nil
	end)
end
return GroupRewardService
