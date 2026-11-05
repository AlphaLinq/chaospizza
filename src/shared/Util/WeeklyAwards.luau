--!strict
local WeeklyAwards = {}
function WeeklyAwards.snapshot(week: number, rows: { any }, now: number, limit: number): any
	local winners = {}
	for _, row in rows do
		local id = tonumber(row.key)
		if id and id > 0 and row.value > 0 and #winners < limit then
			table.insert(winners, id)
		end
	end
	return { week = week, winners = winners, finalizedAt = now }
end
function WeeklyAwards.claim(
	profile: any,
	userId: number,
	snapshot: any,
	config: any,
	now: number
): boolean
	local key = `weekly.reward.{snapshot.week}`
	if profile.claims[key] ~= nil or not table.find(snapshot.winners, userId) then
		return false
	end
	profile.claims[key] = now
	profile.claims["weekly.titleWeek"] =
		math.max(profile.claims["weekly.titleWeek"] or 0, snapshot.week)
	profile.cosmetics.owned[config.cosmetic] = true
	profile.cosmetics.owned[config.title] = true
	profile.cosmetics.equipped.title = config.title
	return true
end
return WeeklyAwards
