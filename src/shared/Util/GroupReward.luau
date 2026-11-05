--!strict
local GroupReward = {}
function GroupReward.apply(profile: any, config: any, member: boolean, now: number): boolean
	if config.groupId <= 0 or not member or now ~= now or now < 0 or now >= math.huge then
		return false
	end
	local key = `group.{config.groupId}`
	if profile.claims[key] ~= nil then
		return false
	end
	profile.cosmetics.owned[config.groupCosmetic] = true
	profile.claims[key] = math.floor(now)
	return true
end
return GroupReward
