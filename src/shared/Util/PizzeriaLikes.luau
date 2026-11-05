--!strict
local PizzeriaLikes = {}
local function valid(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function userId(value: any): boolean
	return valid(value) and value > 0 and value <= 9007199254740991 and value % 1 == 0
end
function PizzeriaLikes.new(config: any)
	local api = {}
	local function day(now: number): number
		return math.floor(now / config.secondsPerDay)
	end
	function api.count(state: any, now: number): number
		if not valid(now) or now < 0 or state.day ~= day(now) then
			return 0
		end
		local count = 0
		for _, liked in state.from do
			if liked == true then
				count += 1
			end
		end
		return count
	end
	function api.canLike(
		state: any,
		from: number,
		owner: number,
		now: number,
		sessionSeconds: number
	): (boolean, string)
		if not userId(from) or not userId(owner) or from == owner then
			return false, "Visit another courier's pizzeria to leave a like."
		end
		if not valid(now) or now < 0 or day(now) < state.day then
			return false, "Likes will reopen when the server clock catches up."
		end
		if not valid(sessionSeconds) or sessionSeconds < config.minimumSessionSeconds then
			return false,
				`Explore the city for {math.ceil(config.minimumSessionSeconds / 60)} minutes before leaving likes.`
		end
		if state.day == day(now) and state.from[tostring(from)] then
			return false, "You already liked this pizzeria today."
		end
		if api.count(state, now) >= config.maxDailyLikes then
			return false, "This pizzeria's like jar is full for today!"
		end
		return true, "Ready to leave a like."
	end
	function api.apply(
		profile: any,
		from: number,
		owner: number,
		now: number,
		sessionSeconds: number
	): (boolean, string)
		local accepted, reason = api.canLike(profile.likes, from, owner, now, sessionSeconds)
		if not accepted then
			return false, reason
		end
		if profile.likes.day ~= day(now) then
			profile.likes = { day = day(now), from = {} }
		end
		profile.likes.from[tostring(from)] = true
		return true, "Like delivered! Thanks for stopping by."
	end
	function api.leaders(counts: { [number]: number }): { [number]: boolean }
		local maximum = 0
		for _, count in counts do
			if valid(count) then
				maximum = math.max(maximum, count)
			end
		end
		local leaders: { [number]: boolean } = {}
		if maximum > 0 then
			for id, count in counts do
				if count == maximum then
					leaders[id] = true
				end
			end
		end
		return leaders
	end
	return api
end
return PizzeriaLikes
