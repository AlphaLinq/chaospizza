--!strict
-- MEGA combo name lookup (#270): order-independent.

local ComboName = {}

function ComboName.key(a: string, b: string): string
	return if a < b then `{a}+{b}` else `{b}+{a}`
end

function ComboName.get(names: { [string]: string }, a: string, b: string): string?
	return names[ComboName.key(a, b)]
end

return ComboName
