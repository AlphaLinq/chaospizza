--!strict
local Passport = {}
export type Registry = { ids: { string }, known: { [string]: boolean } }
local function positiveInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value > 0
		and value < math.huge
		and value % 1 == 0
end
function Passport.registry(buildings: { any }, config: any): Registry
	local ids: { string } = {}
	local known: { [string]: boolean } = {}
	for _, building in buildings do
		local address = type(building) == "table" and building.address
		local id = if type(address) == "table" then address.id else nil
		if
			type(id) == "string"
			and #id > 0
			and #id <= config.maxIdBytes
			and string.match(id, "^[%w_-]+$")
			and not known[id]
		then
			known[id] = true
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	assert(#ids <= config.maxAddresses, "Route passport capacity is smaller than the map")
	return { ids = ids, known = known }
end
function Passport.stamp(profile: any, registry: Registry, id: any, now: any, config: any): boolean
	if type(id) ~= "string" or not registry.known[id] or not positiveInteger(now) then
		return false
	end
	local key = config.claimPrefix .. id
	if positiveInteger(profile.claims[key]) then
		return false
	end
	profile.claims[key] = now
	return true
end
function Passport.summary(profile: any, registry: Registry, config: any): (number, number, string?)
	local count = 0
	local nextId: string? = nil
	for _, id in registry.ids do
		if positiveInteger(profile.claims[config.claimPrefix .. id]) then
			count += 1
		elseif not nextId then
			nextId = id
		end
	end
	return count, #registry.ids, nextId
end
return Passport
