--!strict
local Decorations = {}
function Decorations.new(config: any)
	local byId, slots = {}, {}
	for _, slot in config.slots do
		slots[slot.id] = slot
	end
	for _, item in config.items do
		assert(not byId[item.id] and slots[item.slot], "invalid decoration")
		assert(item.price >= 0 and item.price % 1 == 0, "invalid decoration price")
		byId[item.id] = item
	end
	local api = {}
	function api.get(id: string): any
		return byId[id]
	end
	function api.owns(profile: any, id: string): boolean
		local item = byId[id]
		return item ~= nil and (item.price == 0 or profile.cosmetics.owned[id] == true)
	end
	function api.action(raw: any): (string?, string?, string?)
		if type(raw) ~= "string" then
			return nil, nil, nil
		end
		local id = string.match(raw, "^buy%.([%w_]+)$")
		if id and byId[id] then
			return "buy", nil, id
		end
		local slot, selected = string.match(raw, "^place%.([%w_]+)%.([%w_]+)$")
		if slots[slot] and byId[selected] and byId[selected].slot == slot then
			return "place", slot, selected
		end
		slot = string.match(raw, "^clear%.([%w_]+)$")
		if slots[slot] then
			return "clear", slot, nil
		end
		return nil, nil, nil
	end
	function api.apply(profile: any, raw: any): (boolean, string)
		local mode, slot, id = api.action(raw)
		if not mode then
			return false, "missing"
		end
		if mode == "buy" then
			if api.owns(profile, id :: string) then
				return false, "already"
			end
			local item = byId[id]
			if
				type(profile.tips) ~= "number"
				or profile.tips ~= profile.tips
				or math.abs(profile.tips) == math.huge
				or profile.tips < item.price
			then
				return false, "low"
			end
			profile.tips -= item.price
			profile.cosmetics.owned[id] = true
		elseif mode == "place" then
			if not api.owns(profile, id :: string) then
				return false, "unowned"
			end
			profile.cosmetics.owned[id] = true
			profile.cosmetics.equipped[config.ledgerPrefix .. slot] = id
		else
			profile.cosmetics.equipped[config.ledgerPrefix .. slot] = nil
		end
		return true, "saved"
	end
	function api.selected(profile: any, slot: string): string?
		local id = profile.cosmetics.equipped[config.ledgerPrefix .. slot]
		return if slots[slot]
				and byId[id]
				and byId[id].slot == slot
				and api.owns(profile, id)
			then id
			else nil
	end
	function api.snapshot(profile: any, ready: boolean): any
		local result = { ready = ready, slots = {}, owned = {}, tips = profile.tips }
		for _, slot in config.slots do
			result.slots[slot.id] = api.selected(profile, slot.id)
		end
		for _, item in config.items do
			result.owned[item.id] = api.owns(profile, item.id)
		end
		return result
	end
	return api
end
return Decorations
