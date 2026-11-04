--!strict
-- Token-bucket rate limiter, keyed by anything (usually a Player).
-- Pure module: the clock is injectable so tests can control time.
--
--     local limiter = RateLimiter.new(5, 10) -- 5 requests/sec, bursts of 10
--     if not limiter:allow(player) then return end
--     Players.PlayerRemoving:Connect(function(p) limiter:remove(p) end)

export type Clock = () -> number

type Bucket = {
	tokens: number,
	last: number,
}

export type RateLimiter = {
	allow: (self: RateLimiter, key: any) -> boolean,
	remove: (self: RateLimiter, key: any) -> (),
	ratePerSecond: number,
	burst: number,
	_clock: Clock,
	_buckets: { [any]: Bucket },
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond: number, burst: number, clock: Clock?): RateLimiter
	assert(ratePerSecond > 0, "ratePerSecond must be > 0")
	assert(burst >= 1, "burst must be >= 1")
	local self = {
		ratePerSecond = ratePerSecond,
		burst = burst,
		_clock = clock or os.clock,
		_buckets = {},
	}
	return (setmetatable(self, RateLimiter) :: any) :: RateLimiter
end

function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self.burst, last = now }
		self._buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.ratePerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.remove(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
