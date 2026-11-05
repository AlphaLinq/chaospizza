--!strict
local Cosmetics = {}
function Cosmetics.new(config: any)
	local byId: { [string]: any } = {}
	for _, item in config.items do
		assert(
			not byId[item.id] and table.find(config.slots, item.slot),
			"invalid cosmetic definition"
		)
		assert(
			item.price == nil or item.price >= 0 and item.price % 1 == 0,
			"invalid cosmetic price"
		)
		byId[item.id] = item
	end
	local api = {}
	function api.get(id: string): any
		return byId[id]
	end
	function api.owns(profile: any, id: string): boolean
		local item = byId[id]
		return item ~= nil and (item.free or profile.cosmetics.owned[id] == true)
	end
	function api.effective(profile: any, slot: string): any
		local id = profile.cosmetics.equipped[slot]
		if id and byId[id] and byId[id].slot == slot and api.owns(profile, id) then
			return byId[id]
		end
		return byId[config.defaults[slot]]
	end
	function api.buy(profile: any, id: string): boolean
		local item = byId[id]
		if not item or item.price == nil or api.owns(profile, id) or profile.tips < item.price then
			return false
		end
		profile.tips -= item.price
		profile.cosmetics.owned[id] = true
		return true
	end
	function api.equip(profile: any, id: string): boolean
		local item = byId[id]
		if not item or not api.owns(profile, id) then
			return false
		end
		profile.cosmetics.owned[id] = true
		profile.cosmetics.equipped[item.slot] = id
		return true
	end
	function api.catalog(profile: any): { any }
		local result: { any } = {}
		for _, item in config.items do
			local active = api.effective(profile, item.slot)
			table.insert(result, {
				id = item.id,
				name = item.name,
				slot = item.slot,
				color = item.color,
				accent = item.accent,
				price = item.price,
				unlockHint = config.unlockHints[item.id],
				owned = api.owns(profile, item.id),
				equipped = active ~= nil and active.id == item.id,
			})
		end
		return result
	end
	return api
end
return Cosmetics
