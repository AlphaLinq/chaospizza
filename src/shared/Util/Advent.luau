--!strict
-- Epoch arithmetic makes UTC boundaries independent of the client timezone.
local Advent = {}
function Advent.new(config: any, boosts: any, maxTips: number)
	local api = {}
	local function validDay(day: any): boolean
		return type(day) == "number"
			and day == math.floor(day)
			and day >= 1
			and day <= #config.rewards
	end
	local function clock(now: number): boolean
		return now == now and now >= 0 and now < math.huge
	end
	local function key(day: number): string
		return `advent.{config.season}.{day}`
	end
	function api.state(profile: any, day: any, now: number): string
		if not validDay(day) then
			return "invalid"
		end
		if profile.claims[key(day)] ~= nil then
			return "claimed"
		end
		if not clock(now) then
			return "locked"
		end
		local opens = config.startsAt + (day - 1) * config.secondsPerDay
		if now < opens then
			return "locked"
		elseif now >= opens + (1 + config.catchUpDays) * config.secondsPerDay then
			return "missed"
		end
		return if now < opens + config.secondsPerDay then "claimable" else "catchup"
	end
	function api.snapshot(profile: any, now: number): any
		local rows = {}
		for day in config.rewards do
			table.insert(rows, { day = day, state = api.state(profile, day, now) })
		end
		return {
			season = config.season,
			active = clock(now)
				and now >= config.startsAt
				and now
					< config.startsAt + (#config.rewards + config.catchUpDays) * config.secondsPerDay,
			rows = rows,
		}
	end
	function api.claim(profile: any, day: any, now: number): (boolean, string)
		local state = api.state(profile, day, now)
		if state ~= "claimable" and state ~= "catchup" then
			return false, state
		end
		local gift = config.rewards[day]
		local duplicate = gift.cosmetic and profile.cosmetics.owned[gift.cosmetic]
		local tips = (gift.tips or 0) + (if duplicate then config.duplicateLookTips else 0)
		-- Refuse a full wallet rather than consume its calendar window for no reward.
		if profile.tips > maxTips - tips then
			return false, "wallet_full"
		end
		if gift.boost and not boosts.extend(profile.boosts, gift.boost, gift.seconds, now) then
			return false, "boost_unavailable"
		end
		profile.tips += tips
		if gift.cosmetic then
			profile.cosmetics.owned[gift.cosmetic] = true
		end
		profile.claims[key(day)] = math.floor(now)
		return true, "claimed"
	end
	return api
end
return Advent
