--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Badges = require(ReplicatedStorage.Shared.Config.Badges)
local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Logic = require(ReplicatedStorage.Shared.Util.AchievementBook)
local Data = require(script.Parent.DataService)
local Debug = require(script.Parent.DebugService)
local Service = {}
function Service.snapshot(player: Player): any
	local profile = Data.getProfile(player)
	return if profile then Logic.snapshot(profile, Badges.items, Customers) else nil
end
function Service.refresh(player: Player)
	local rows = Service.snapshot(player)
	if rows then
		player:SetAttribute("AchievementBook", HttpService:JSONEncode(rows))
	end
end
function Service.init()
	Debug.register(
		"achievements",
		"Read your saved milestones and progress",
		"achievements",
		function(player)
			local rows = Service.snapshot(player)
			return rows ~= nil,
				if rows then HttpService:JSONEncode(rows) else "Your profile is still loading."
		end
	)
end
function Service.start()
	Data.onLoaded(Service.refresh)
	Data.onUpdated(Service.refresh)
	for _, player in Players:GetPlayers() do
		Service.refresh(player)
	end
end
return Service
