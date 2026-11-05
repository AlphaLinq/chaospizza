--!strict
local Achievements = {}
function Achievements.met(profile: any, definition: any, customers: { any }): boolean
	if profile.claims[`achievement.{definition.key}`] ~= nil then
		return true
	end
	if definition.deliveries and profile.deliveries >= definition.deliveries then
		return true
	end
	if definition.pizzeria and profile.pizzeriaLevel >= definition.pizzeria then
		return true
	end
	if definition.book then
		local count = 0
		for _, customer in customers do
			local entry = profile.customerBook[customer.id]
			if entry and entry.served > 0 then
				count += 1
			end
		end
		return count >= definition.book
	end
	return false
end
return Achievements
