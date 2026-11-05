--!strict
local Settings = {}
function Settings.new(config: any)
	local api = {}
	function api.textScale(playerOrPreference: any): number
		local value = if type(playerOrPreference) == "string"
			then playerOrPreference
			else if playerOrPreference ~= nil
				then playerOrPreference:GetAttribute("TextSize")
				else nil
		return config.textScales[value or "normal"] or config.textScales.normal
	end
	function api.isQuality(value: unknown): boolean
		return type(value) == "string" and config.presets[value] ~= nil
	end
	function api.default(touchEnabled: boolean, width: number): string
		return if touchEnabled
				and width > 0
				and width <= config.mobileMaxWidth
			then "low"
			else "high"
	end
	function api.particleScale(quality: unknown): number
		return if api.isQuality(quality)
			then config.presets[quality :: string].particleScale
			else config.presets.low.particleScale
	end
	return api
end
return Settings
