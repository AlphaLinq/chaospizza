--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local Persistence = require(ReplicatedStorage.Shared.Config.Progression).persistence
local Calendar = require(ReplicatedStorage.Shared.Config.DailyRewards)
local SessionService = {}
local recorded: { [Player]: boolean } = {}
local running: { [Player]: boolean } = {}
function SessionService.record(player: Player): boolean
	if recorded[player] then
		return true
	end
	if running[player] then
		return false
	end
	running[player] = true
	while player.Parent == Players and DataService.isLoaded(player) do
		local count = 0
		local ok = DataService.transaction(player, function(profile)
			profile.sessions.count += 1
			profile.sessions.lastDay =
				math.max(profile.sessions.lastDay, math.floor(os.time() / Calendar.secondsPerDay))
			count = profile.sessions.count
			return true
		end, true)
		if ok then
			recorded[player] = true
			running[player] = nil
			player:SetAttribute("SessionCount", count)
			if count == 2 then
				AnalyticsService.funnel(player, "second_session")
			end
			return true
		end
		-- Another loaded callback or autosave may hold the profile briefly.
		task.wait(Persistence.retryBaseSeconds)
	end
	running[player] = nil
	return false
end
function SessionService.init()
	DebugService.register("sessions", "Show persisted session count", "sessions", function(player)
		local profile = DataService.getProfile(player)
		if not profile then
			return false, "profile not loaded"
		end
		return true,
			`count={profile.sessions.count} lastDay={profile.sessions.lastDay} recorded={recorded[player] == true}`
	end)
end
function SessionService.start()
	DataService.onLoaded(function(player)
		SessionService.record(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		recorded[player] = nil
		running[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			task.spawn(SessionService.record, player)
		end
	end
end
return SessionService
