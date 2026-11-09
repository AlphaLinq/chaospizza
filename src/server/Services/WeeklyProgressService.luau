--!strict
-- Feeds authentic server-side delivery facts into the weekly challenges
-- (Codex: DailyService.recordProgress). One delivery = one call per event kind;
-- the client never reports progress.

local DailyService = require(script.Parent.DailyService)
local OrderService = require(script.Parent.OrderService)

local WeeklyProgressService = {}

function WeeklyProgressService.start()
	OrderService.onDelivered(function(player, _order, _tips, _deliveries, info)
		DailyService.recordProgress(player, "delivery", 1)
		if info.duringEvent then
			DailyService.recordProgress(player, "eventDelivery", 1)
		end
		if info.isNew then
			DailyService.recordProgress(player, "newCustomer", 1)
		end
		if info.daredevil then
			DailyService.recordProgress(player, "daredevil", 1) -- #207
		end
	end)
end

return WeeklyProgressService
