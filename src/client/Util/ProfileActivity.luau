--!strict
-- Pure UI presentation, also exercised without the Roblox engine.
local Activity = {}
export type Facts = {
	best: any,
	gold: any,
	wins: any,
	buff: any,
	untilAt: any,
}
export type Row = { key: string, text: string }
local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function whole(value: any): boolean
	return finite(value) and value >= 0 and value % 1 == 0
end
function Activity.rows(
	facts: Facts,
	now: number,
	total: number,
	copy: any,
	formatTrial: (number) -> string
): { Row }
	local rows = {
		{
			key = "TrialBest",
			text = copy.trial .. "\n" .. (if whole(facts.best) and facts.best > 0
				then formatTrial(facts.best)
				else copy.noTrial),
		},
		{
			key = "GoldenFound",
			text = copy.gold .. "\n" .. (if whole(facts.gold) and facts.gold <= total
				then `{facts.gold} / {total}`
				else copy.loading),
		},
	}
	if whole(facts.wins) then
		table.insert(rows, { key = "RivalWins", text = copy.rival .. "\n" .. tostring(facts.wins) })
	end
	local wish = copy.noWish
	local name = if type(facts.buff) == "string" then copy.buffs[facts.buff] else nil
	if name and finite(now) and finite(facts.untilAt) and facts.untilAt > now then
		local seconds = math.ceil(facts.untilAt - now)
		wish = string.format("%s · %d:%02d %s", name, seconds // 60, seconds % 60, copy.remaining)
	end
	table.insert(rows, { key = "WishBuff", text = copy.wish .. "\n" .. wish })
	return rows
end
return Activity
