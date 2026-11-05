--!strict
local FocusOrder = {}
function FocusOrder.sort(items: { any }): { any }
	local result = table.clone(items)
	table.sort(result, function(a: any, b: any)
		if a.y ~= b.y then
			return a.y < b.y
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.key < b.key
	end)
	return result
end
return FocusOrder
