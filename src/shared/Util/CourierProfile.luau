--!strict
local CourierProfile = {}
function CourierProfile.new(customers: { any }, rarities: { any }, levelFromXp: (number) -> number)
	local ranks: { [string]: number } = {}
	for _, rarity in rarities do
		ranks[rarity.id] = rarity.order
	end
	return function(profile: any, likes: number, title: string?): any
		local count, best = 0, 0
		local rarest, rarity = "No customers yet", "None"
		for _, customer in customers do
			local entry = profile.customerBook[customer.id]
			if entry and entry.served > 0 then
				count += 1
				local rank = ranks[customer.rarity] or 0
				if rank > best then
					best, rarest, rarity = rank, customer.displayName, customer.rarity
				end
			end
		end
		return {
			deliveries = profile.deliveries,
			level = levelFromXp(profile.xp),
			rarest = rarest,
			rarity = rarity,
			discovered = count,
			total = #customers,
			pizzeriaLevel = profile.pizzeriaLevel,
			likes = likes,
			title = title or "Courier",
		}
	end
end
return CourierProfile
