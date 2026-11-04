--!strict
-- Pure order rules: which address and customer an order goes to, and the tip.
-- Randomness is injected (rng returns a float in [0, 1)) so tests are deterministic.

export type Rng = () -> number

export type AddressInfo = {
	id: string,
	starter: boolean,
}

export type CustomerInfo = {
	id: string,
	event: string?,
}

local OrderLogic = {}

local function pick<T>(list: { T }, rng: Rng): T
	assert(#list > 0, "cannot pick from an empty list")
	local index = math.floor(rng() * #list) + 1
	return list[math.clamp(index, 1, #list)]
end

-- New players get starter addresses (close to the counter) for their first orders.
-- Never repeats the previous address when another one is available.
function OrderLogic.pickAddress(
	addresses: { AddressInfo },
	deliveriesSoFar: number,
	starterDeliveries: number,
	lastAddressId: string?,
	rng: Rng
): string
	local useStarter = deliveriesSoFar < starterDeliveries
	local candidates: { AddressInfo } = {}
	for _, address in addresses do
		if (not useStarter or address.starter) and address.id ~= lastAddressId then
			table.insert(candidates, address)
		end
	end
	if #candidates == 0 then
		-- Only one valid address (e.g. a single starter): allow a repeat.
		for _, address in addresses do
			if not useStarter or address.starter then
				table.insert(candidates, address)
			end
		end
	end
	if #candidates == 0 then
		candidates = addresses
	end
	return pick(candidates, rng).id
end

-- Placeholder until CustomerService (M4): any normal-time customer, or one
-- for the active event when there is one.
function OrderLogic.pickCustomer(
	customers: { CustomerInfo },
	activeEvent: string?,
	rng: Rng
): string
	local candidates: { CustomerInfo } = {}
	for _, customer in customers do
		if customer.event == activeEvent then
			table.insert(candidates, customer)
		end
	end
	if #candidates == 0 then
		for _, customer in customers do
			if customer.event == nil then
				table.insert(candidates, customer)
			end
		end
	end
	return pick(candidates, rng).id
end

-- Tip = base * (1 + bonus), bonus capped. Always a whole, non-negative number.
function OrderLogic.tip(base: number, bonusFraction: number, maxBonus: number): number
	local bonus = math.clamp(bonusFraction, 0, maxBonus)
	return math.max(0, math.floor(base * (1 + bonus) + 0.5))
end

return OrderLogic
