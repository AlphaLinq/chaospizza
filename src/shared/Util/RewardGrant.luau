--!strict
local RewardGrant = {}
function RewardGrant.apply(profile: any, reward: any, maxTips: number): number
	local credited = math.min(reward.tips or 0, math.max(0, maxTips - profile.tips))
	profile.tips += credited
	profile.xp += reward.xp or 0
	if reward.cosmetic then
		profile.cosmetics.owned[reward.cosmetic] = true
	end
	return credited
end
return RewardGrant
