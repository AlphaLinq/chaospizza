--!strict
-- Pure wishing-well rules (#162): weighted outcome roll and the odds shown to
-- players. `r` is a number in [0, 1).

export type Outcome = { id: string, name: string, weight: number, text: string }

local Wish = {}

function Wish.totalWeight(outcomes: { Outcome }): number
	local total = 0
	for _, o in outcomes do
		total += o.weight
	end
	return total
end

function Wish.roll(outcomes: { Outcome }, r: number): Outcome
	local target = r * Wish.totalWeight(outcomes)
	local acc = 0
	for _, o in outcomes do
		acc += o.weight
		if target < acc then
			return o
		end
	end
	return outcomes[#outcomes]
end

-- Percentages for the UI, rounded, in config order.
function Wish.odds(outcomes: { Outcome }): { { name: string, percent: number, text: string } }
	local total = Wish.totalWeight(outcomes)
	local list = {}
	for _, o in outcomes do
		table.insert(
			list,
			{ name = o.name, percent = math.floor(o.weight / total * 100 + 0.5), text = o.text }
		)
	end
	return list
end

function Wish.dayOf(now: number, daySeconds: number): number
	return math.floor(now / daySeconds)
end

return Wish
