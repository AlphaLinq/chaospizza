--!strict
-- Pure: the event vote and the chaos finale clock (#186). Which events are
-- on the ballot, when the ballot opens, the tally and the winner, and which
-- finale stage the server is in. No Roblox APIs; randomness injected.

export type VoteConfig = {
	options: number,
	openAtCalmFraction: number, -- open once this share of the calm has passed
	minOpenSeconds: number, -- never open with less calm left than this
}

export type FinaleConfig = {
	intervalSeconds: number,
	noticeSeconds: number,
	countdownSeconds: number,
}

export type FinaleStage = "none" | "notice" | "countdown" | "due"

local EventVote = {}

-- `count` distinct ids from `candidates` (fewer if there are fewer).
function EventVote.pickOptions(candidates: { string }, count: number, rng: () -> number): { string }
	local pool = table.clone(candidates)
	local out = {}
	while #out < count and #pool > 0 do
		local i = math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)
		table.insert(out, table.remove(pool, i) :: string)
	end
	return out
end

-- Should the ballot be open now? `total` and `left` are the calm's length and
-- what is left of it, in seconds.
function EventVote.shouldOpen(total: number, left: number, cfg: VoteConfig): boolean
	if left < cfg.minOpenSeconds then
		return false
	end
	return total - left >= total * cfg.openAtCalmFraction
end

-- Votes: voter key -> option index. Returns counts per option.
function EventVote.tally(votes: { [any]: number }, optionCount: number): { number }
	local counts = table.create(optionCount, 0)
	for _, index in votes do
		if index >= 1 and index <= optionCount and index % 1 == 0 then
			counts[index] += 1
		end
	end
	return counts
end

-- The winning option index (ties broken at random), or nil with no votes.
function EventVote.winner(counts: { number }, rng: () -> number): number?
	local best, top = 0, {}
	for i, n in counts do
		if n > best then
			best, top = n, { i }
		elseif n == best and n > 0 then
			table.insert(top, i)
		end
	end
	if best == 0 then
		return nil
	end
	return top[math.clamp(math.floor(rng() * #top) + 1, 1, #top)]
end

-- The finale stage `secondsLeft` before the next finale.
function EventVote.finaleStage(secondsLeft: number, cfg: FinaleConfig): FinaleStage
	if secondsLeft <= 0 then
		return "due"
	elseif secondsLeft <= cfg.countdownSeconds then
		return "countdown"
	elseif secondsLeft <= cfg.noticeSeconds then
		return "notice"
	end
	return "none"
end

-- "3:05" style clock for the HUD.
function EventVote.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return table.freeze(EventVote)
