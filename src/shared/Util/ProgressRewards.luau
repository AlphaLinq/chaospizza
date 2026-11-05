--!strict
export type Plan = {
	tips: number,
	discovered: number,
	milestones: { number },
	cosmetics: { string },
	levelFrom: number,
	levelTo: number,
	changed: boolean,
}
local ProgressRewards = {}
function ProgressRewards.new(config: any, customers: { any }, levelFromXp: (number) -> number)
	local known: { [string]: boolean } = {}
	for _, customer in customers do
		known[customer.id] = true
	end
	local api = {}
	function api.plan(profile: any): Plan
		local discovered = 0
		for id, entry in profile.customerBook do
			if known[id] and entry.served > 0 then
				discovered += 1
			end
		end
		local tips = 0
		local milestones: { number }, cosmetics: { string } = {}, {}
		for _, milestone in config.book do
			if
				discovered >= milestone.count
				and not profile.progressRewards.book[tostring(milestone.count)]
			then
				table.insert(milestones, milestone.count)
				tips += milestone.tips
				if milestone.cosmetic then
					table.insert(cosmetics, milestone.cosmetic)
				end
			end
		end
		local from = profile.progressRewards.level
		local target = math.max(from, levelFromXp(profile.xp))
		local count = target - from
		-- Arithmetic series avoids a loop when a migration restores a large XP value.
		tips += count * config.levelTipsBase + config.levelTipsGrowth * count * (from + target - 3) / 2
		return {
			tips = math.min(tips, math.max(0, config.maxTips - profile.tips)),
			discovered = discovered,
			milestones = milestones,
			cosmetics = cosmetics,
			levelFrom = from,
			levelTo = target,
			changed = #milestones > 0 or count > 0,
		}
	end
	function api.claim(profile: any): Plan
		local plan = api.plan(profile)
		if not plan.changed then
			return plan
		end
		profile.tips += plan.tips
		profile.progressRewards.level = plan.levelTo
		for _, milestone in plan.milestones do
			profile.progressRewards.book[tostring(milestone)] = true
		end
		for _, id in plan.cosmetics do
			profile.cosmetics.owned[id] = true
		end
		return plan
	end
	function api.title(profile: any): string?
		local title: string? = nil
		for _, milestone in config.book do
			if milestone.title and profile.progressRewards.book[tostring(milestone.count)] then
				title = milestone.title
			end
		end
		return title
	end
	return api
end
return ProgressRewards
