--!strict
-- Validation predicates for remote arguments. Every remote argument is hostile
-- until it passes one of these. Each function returns the typed value, or nil
-- when the value is invalid, so handlers can early-return:
--
--     local name = Validate.string(arg, 32)
--     if not name then return end
--
-- Pure module: no Roblox APIs, unit-tested in tests/.

local Validate = {}

function Validate.string(value: unknown, maxLength: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value == 0 or #value > maxLength then
		return nil
	end
	return value
end

-- Like string(), but also allows the empty string.
function Validate.optionalString(value: unknown, maxLength: number): string?
	if value == nil then
		return ""
	end
	if typeof(value) ~= "string" or #value > maxLength then
		return nil
	end
	return value
end

-- Finite number (rejects NaN, +inf, -inf) inside [min, max].
function Validate.number(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" then
		return nil
	end
	if value ~= value then -- NaN
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

function Validate.integer(value: unknown, min: number, max: number): number?
	local n = Validate.number(value, min, max)
	if n == nil or n ~= math.floor(n) then
		return nil
	end
	return n
end

function Validate.boolean(value: unknown): boolean?
	if typeof(value) ~= "boolean" then
		return nil
	end
	return value
end

-- Value must be one of the keys of `allowed` (a set-like table).
function Validate.oneOf(value: unknown, allowed: { [string]: any }): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if allowed[value] == nil then
		return nil
	end
	return value
end

return table.freeze(Validate)
