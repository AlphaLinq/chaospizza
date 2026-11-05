--!strict
local Codes = {}
function Codes.new(
	config: any,
	levelFromXp: (number) -> number,
	grant: (any, any, number) -> number
)
	local api = {}
	function api.normalize(raw: any): string?
		if type(raw) ~= "string" or #raw > config.maxLength + 2 then
			return nil
		end
		local value = string.upper(string.match(raw, "^%s*(.-)%s*$") or "")
		return if #value > 0
				and #value <= config.maxLength
				and string.match(value, "^[%w_%-]+$")
			then value
			else nil
	end
	function api.redeem(profile: any, raw: any, now: number): (boolean, string)
		local code = api.normalize(raw)
		local reward = code and config.codes[code]
		if not code or not reward then
			return false, "That code wasn't found. Check the spelling."
		end
		if
			now ~= now
			or now < 0
			or now >= math.huge
			or (reward.expiresAt > 0 and now >= reward.expiresAt)
		then
			return false, "That code has expired. Look out for the next one!"
		end
		if reward.startsAt and now < reward.startsAt then
			return false, "That code isn't active yet."
		end
		if levelFromXp(profile.xp) < reward.minimumLevel then
			return false, `Reach courier level {reward.minimumLevel} to use this code.`
		end
		local key = `code.{code}`
		if profile.claims[key] ~= nil then
			return false, "You already redeemed that code."
		end
		local tips = grant(profile, reward, config.maxTips)
		profile.claims[key] = math.floor(now)
		return true, `Code redeemed! +{tips} tips{if reward.cosmetic then " · New look!" else ""}`
	end
	return api
end
return Codes
