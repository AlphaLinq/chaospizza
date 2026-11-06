--!strict
local Comfort = {}
function Comfort.new(config: any)
	local api = {}
	function api.read(profile: any): { [string]: boolean }
		local result = {}
		for _, item in config.items do
			result[item.attribute] = profile.claims[item.claim] ~= nil
		end
		return result
	end
	function api.action(raw: string): (string?, boolean?)
		local key, mode = string.match(raw, "^(%a+)%.(%a+)$")
		if mode ~= "on" and mode ~= "off" then
			return nil, nil
		end
		for _, item in config.items do
			if item.key == key then
				return key, mode == "on"
			end
		end
		return nil, nil
	end
	function api.apply(profile: any, key: string, enabled: unknown, now: number): boolean
		if type(enabled) ~= "boolean" or now ~= now or now < 0 or now >= math.huge then
			return false
		end
		for _, item in config.items do
			if item.key == key then
				profile.claims[item.claim] = if enabled then math.floor(now) else nil
				return true
			end
		end
		return false
	end
	return api
end
return Comfort
