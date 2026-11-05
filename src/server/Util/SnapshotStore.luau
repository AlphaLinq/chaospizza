--!strict
-- Atomic create-if-absent records. Only DataService supplies storage access.
local SnapshotStore = {}
local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end
function SnapshotStore.new(
	storeFor: (string) -> any,
	persistent: () -> boolean,
	retry: (() -> any) -> (boolean, any)
)
	local memory: { [string]: any } = {}
	return function(name: string, key: string, initial: any): any
		if not persistent() then
			local id = name .. ":" .. key
			if memory[id] == nil and initial ~= nil then
				memory[id] = copy(initial)
			end
			return copy(memory[id])
		end
		local ok, result = retry(function()
			local store = storeFor(name)
			if initial == nil then
				return store:GetAsync(key)
			end
			return store:UpdateAsync(key, function(existing)
				return existing or copy(initial)
			end)
		end)
		return if ok then copy(result) else nil
	end
end
SnapshotStore.copy = copy
return SnapshotStore
