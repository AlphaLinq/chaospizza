--!strict
local Referrals = {}
function Referrals.new(config: any, grant: (any, any, number) -> number)
	local api = {}
	function api.key(friend: number, now: number): string
		return `friend.{math.floor(now / config.secondsPerDay)}.{friend}`
	end
	function api.apply(
		profile: any,
		selfId: number,
		friend: number,
		now: number,
		facts: any
	): boolean
		if
			now ~= now
			or now < (profile.claims["friend.clock"] or 0)
			or now >= math.huge
			or friend <= 0
			or friend % 1 ~= 0
			or selfId == friend
		then
			return false
		end
		if
			not facts.friends
			or facts.secondsA < config.minimumSessionSeconds
			or facts.secondsB < config.minimumSessionSeconds
			or facts.ageA < config.minimumAccountDays
			or facts.ageB < config.minimumAccountDays
		then
			return false
		end
		local key = api.key(friend, now)
		if profile.claims[key] ~= nil then
			return false
		end
		local prefix = `friend.{math.floor(now / config.secondsPerDay)}.`
		local count = 0
		for claimed in profile.claims do
			if string.sub(claimed, 1, #prefix) == prefix then
				count += 1
			end
		end
		if count >= config.maxFriendRewardsPerDay then
			return false
		end
		grant(profile, { tips = config.friendTips }, config.maxTips)
		profile.claims[key], profile.claims["friend.clock"] = math.floor(now), math.floor(now)
		return true
	end
	return api
end
return Referrals
