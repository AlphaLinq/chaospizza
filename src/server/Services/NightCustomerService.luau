--!strict
-- Night-only customers (#258): CustomerService adds them to the pool at
-- night (DayCycleService.isNight); this only tells the courier that the
-- order is a special one, so the night feels worth staying up for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local CustomerService = require(script.Parent.CustomerService)
local OrderService = require(script.Parent.OrderService)

local NightCustomerService = {}

function NightCustomerService.start()
	OrderService.onAssigned(function(player, order)
		local def = CustomerService.get(order.customerId)
		if def and def.night then
			Net.event("Hint")
				:FireClient(player, `🌙 A night-only customer! {def.displayName} is waiting.`)
		end
	end)
end

return NightCustomerService
