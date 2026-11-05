--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local GraphicsSettingsService = {}
function GraphicsSettingsService.start()
	MonetizationService.registerAction("settings", function(player, action)
		local textSize = string.match(action, "^textsize%.(%a+)$")
		if textSize then
			if textSize ~= "normal" and textSize ~= "large" then
				return false, "Choose Normal or Large text."
			end
			local ok = DataService.update(player, function(profile)
				profile.settings.textSize = textSize
			end)
			if ok then
				player:SetAttribute("TextSize", textSize)
			end
			return ok, if ok then "Text size saved." else "Your profile is busy. Try again."
		end
		local quality = string.match(action, "^quality%.(%a+)$")
		if not quality or not Settings.isQuality(quality) then
			return false, "Choose Low, Medium or High."
		end
		local ok = DataService.update(player, function(profile)
			profile.settings.quality = quality
			profile.settings.effects = if quality == "low" then "low" else "normal"
		end)
		if ok then
			player:SetAttribute("EffectQuality", quality)
		end
		return ok, if ok then "Graphics setting saved." else "Your profile is busy. Try again."
	end)
	local function publishSettings(player: Player)
		local profile = DataService.getProfile(player)
		if profile then
			player:SetAttribute("TextSize", profile.settings.textSize)
			player:SetAttribute("EffectQuality", profile.settings.quality)
			player:SetAttribute("QualityLoaded", true)
		end
	end
	DataService.onLoaded(publishSettings)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			publishSettings(player)
		end
	end
end
return GraphicsSettingsService
