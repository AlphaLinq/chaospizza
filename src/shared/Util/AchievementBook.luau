--!strict
local AchievementBook = {}
function AchievementBook.snapshot(profile: any, definitions: { any }, customers: { any }): { any }
	local discovered = 0
	for _, customer in customers do
		local entry = profile.customerBook[customer.id]
		if entry and entry.served > 0 then
			discovered += 1
		end
	end
	local rows = {}
	for _, definition in definitions do
		local earned = profile.claims["achievement." .. definition.key] ~= nil
		local target = definition.deliveries or definition.book or definition.pizzeria or 1
		local current = if definition.deliveries
			then profile.deliveries
			elseif definition.book then discovered
			elseif definition.pizzeria then profile.pizzeriaLevel
			else if earned then 1 else 0
		table.insert(rows, {
			key = definition.key,
			current = if earned then target else math.min(current, target),
			target = target,
			earned = earned,
			awarded = definition.badgeId > 0
				and profile.claims["badge." .. definition.badgeId] ~= nil,
		})
	end
	return rows
end
return AchievementBook
