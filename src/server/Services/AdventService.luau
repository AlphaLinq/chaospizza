--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Advent)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Logic = require(ReplicatedStorage.Shared.Util.Advent).new(
	Config,
	require(ReplicatedStorage.Shared.Util.Boosts).new(Products),
	Products.Limits.maxTips
)
local Data = require(script.Parent.DataService)
local Debug = require(script.Parent.DebugService)
local Moni = require(script.Parent.MonetizationService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local limiter = require(ReplicatedStorage.Shared.Util.RateLimiter).new(Config.rate, Config.burst)
local Service = {}
local testClocks: { [Player]: number } = {}
local function now(player: Player): number
	return testClocks[player] or os.time()
end
function Service.refresh(player: Player)
	local profile = Data.getProfile(player)
	if profile then
		local state = Logic.snapshot(profile, now(player))
		state.preview = testClocks[player] ~= nil
		local encoded = HttpService:JSONEncode(state)
		if player:GetAttribute("AdventState") ~= encoded then
			player:SetAttribute("AdventState", encoded)
		end
	end
end
function Service.claim(player: Player, day: any): (boolean, string)
	if not limiter:allow(player) then
		return false, "Please wait a moment before opening another advent window."
	end
	local ok, reason = Transaction.run(player, function(profile)
		local accepted = Logic.claim(profile, day, now(player))
		return accepted,
			if accepted then "Advent reward saved." else "That advent window cannot be claimed now."
	end, "advent")
	Service.refresh(player)
	return ok, reason
end
function Service.init()
	Debug.register(
		"advent",
		"Read or claim the UTC advent calendar",
		"advent [claim <1-24>|test <0-26>|reset]",
		function(player, args)
			if args[1] == "claim" then
				return Service.claim(player, tonumber(args[2]))
			elseif args[1] == "test" then
				local day = tonumber(args[2])
				-- Never move the reward clock in a published experience or a live server.
				if
					not RunService:IsStudio()
					or game.GameId ~= 0
					or not day
					or day % 1 ~= 0
					or day < 0
					or day > 26
				then
					return false,
						"Test dates are only available in an unpublished Studio place (0–26)."
				end
				testClocks[player] = Config.startsAt + (day - 1) * Config.secondsPerDay
			elseif args[1] == "reset" then
				testClocks[player] = nil
			end
			Service.refresh(player)
			return true, tostring(player:GetAttribute("AdventState"))
		end
	)
end
function Service.start()
	Moni.registerAction("advent", function(player, action)
		local day = string.match(action, "^claim%.(%d%d?)$")
		return Service.claim(player, if day then tonumber(day) else nil)
	end)
	Data.onLoaded(Service.refresh)
	Data.onUpdated(Service.refresh)
	for _, player in Players:GetPlayers() do
		Service.refresh(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		testClocks[player] = nil
		limiter:remove(player)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.refreshSeconds)
			for _, player in Players:GetPlayers() do
				Service.refresh(player)
			end
		end
	end)
end
return Service
