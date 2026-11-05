--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Sounds)
local Policy = require(ReplicatedStorage.Shared.Util.SoundPolicy)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local DebugService = require(script.Parent.DebugService)
local AudioSettingsService = {}
local previewSequence = 0
function AudioSettingsService.setVolume(
	player: Player,
	channel: string,
	percent: unknown
): (boolean, string)
	local value = Policy.percent(percent)
	if (channel ~= "music" and channel ~= "sfx") or value == nil then
		return false, "Choose a volume from 0 to 100."
	end
	local ok = DataService.update(player, function(profile)
		profile.settings[channel] = value / 100
	end)
	return ok, if ok then "Volume saved." else "Your profile is busy. Try again."
end
local function publish(player: Player)
	local profile = DataService.getProfile(player)
	if profile then
		player:SetAttribute("MusicVolume", profile.settings.music)
		player:SetAttribute("SfxVolume", profile.settings.sfx)
	end
end
function AudioSettingsService.init()
	DebugService.register(
		"audio",
		"Save music or SFX volume",
		"audio <music|sfx> <0-100>",
		function(player, args)
			return AudioSettingsService.setVolume(player, args[1] or "", tonumber(args[2]))
		end
	)
	DebugService.register(
		"sound",
		"Preview a configured sound and its visual cue",
		"sound <cue>",
		function(player, args)
			local key = args[1] or "Delivery"
			if not Config.clips[key] then
				return false, "Unknown sound cue."
			end
			previewSequence += 1
			player:SetAttribute(
				"AudioPreview",
				HttpService:JSONEncode({ cue = key, sequence = previewSequence })
			)
			return true, `Sound preview: {key}`
		end
	)
end
function AudioSettingsService.start()
	MonetizationService.registerAction("audio", function(player, action)
		local channel, percent = Policy.action(action)
		return AudioSettingsService.setVolume(player, channel or "", percent)
	end)
	DataService.onLoaded(publish)
	DataService.onUpdated(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end
return AudioSettingsService
