--!strict
-- Seasonal date windows (pure). A window may wrap the new year
-- (e.g. Dec 1 → Jan 6). Dates are compared as (month, day) in UTC.

export type Window = { fromMonth: number, fromDay: number, toMonth: number, toDay: number }

local Season = {}

local function key(month: number, day: number): number
	return month * 100 + day
end

function Season.isActive(window: Window?, month: number, day: number): boolean
	if window == nil then
		return true
	end
	local now = key(month, day)
	local from = key(window.fromMonth, window.fromDay)
	local to = key(window.toMonth, window.toDay)
	if from <= to then
		return now >= from and now <= to
	end
	-- wraps the new year
	return now >= from or now <= to
end

return table.freeze(Season)
