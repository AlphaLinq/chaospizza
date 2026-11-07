--!strict
-- Pure: how effect code reads the comfort settings (#137 / #177). The server
-- sets Player attributes "ReduceMotion" / "ReduceFlashes"; until the profile
-- has loaded they may be missing, and missing counts as reduced, so a
-- sensitive player never sees a flash before their setting arrives.

local ComfortFlags = {}

function ComfortFlags.reduced(value: unknown): boolean
	return value ~= false
end

return table.freeze(ComfortFlags)
