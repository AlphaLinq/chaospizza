--!strict
local DisasterProducts = {}
function DisasterProducts.new(events: any, isInSeason: any)
	local byId = {}
	for _, event in events do
		byId[event.id] = event
	end
	local api = {}
	function api.isDisaster(product: any): boolean
		return product.effect ~= nil
			and product.effect.kind == "event"
			and product.effect.eventId ~= nil
	end
	function api.visible(product: any, month: number, day: number): boolean
		if product.legacy then
			return false
		end
		if not api.isDisaster(product) then
			return true
		end
		local event = byId[product.effect.eventId]
		return event ~= nil
			and event.enabled
			and (not event.seasonal or isInSeason(event.season, month, day))
	end
	function api.check(
		product: any,
		month: number,
		day: number,
		canOrder: (string) -> (boolean, string)
	): (boolean, string)
		if not api.visible(product, month, day) then
			return false, "That disaster isn't available right now."
		end
		if api.isDisaster(product) then
			return canOrder(product.effect.eventId)
		end
		if product.key == "MegaChaosNow" then
			for _, event in events do
				if
					event.enabled and (not event.seasonal or isInSeason(event.season, month, day))
				then
					return canOrder(event.id)
				end
			end
			return false, "That disaster isn't available right now."
		end
		return true, ""
	end
	return api
end
return DisasterProducts
