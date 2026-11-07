--!strict
-- Presentation state only. No rewards, votes or gameplay decisions.
local Logic = {}
local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Logic.new(): any
	return { initialized = false, running = false, noticed = false }
end
function Logic.finale(
	s: any,
	now: number,
	at: any,
	running: boolean,
	notice: number,
	cfg: any
): { string }
	local cues = {}
	if not finite(now) or not finite(at) then
		return cues
	end
	if s.initialized and running and not s.running then
		table.insert(cues, "FinaleStart")
	end
	if not running then
		if s.at and math.abs(at - s.at) > cfg.deadlineEpsilonSeconds then
			s.noticed, s.tick = false, nil
		end
		local left = at - now
		local tick = math.ceil(left)
		if left > 0 and tick <= cfg.finalTicks then
			if not s.tick or tick < s.tick then
				table.insert(cues, "FinaleTick")
			end
			s.noticed, s.tick = true, math.min(s.tick or tick, tick)
		elseif left > 0 and left <= notice and not s.noticed then
			s.noticed = true
			table.insert(cues, "FinaleNotice")
		end
	end
	s.initialized, s.running, s.at = true, running, at
	return cues
end
function Logic.micro(s: any, data: any, now: number, near: boolean, cfg: any): { string }
	local cues = {}
	if
		type(data) ~= "table"
		or not finite(now)
		or not finite(data.t0)
		or not finite(data.endsAt)
		or now < data.t0
		or now >= data.endsAt
	then
		s.micro = nil
		return cues
	end
	local key = tostring(data.id) .. ":" .. tostring(data.t0)
	if s.micro ~= key then
		s.micro, s.honkAt, s.warned = key, nil, false
		-- A late join during the spray must not replay its launch.
		s.sprayed = data.kind == "Sprinkler" and finite(data.warn) and now >= data.t0 + data.warn
	end
	if data.kind == "Geese" and near and (not s.honkAt or now >= s.honkAt) then
		s.honkAt = now + cfg.gooseIntervalSeconds
		table.insert(cues, "GeeseHonk")
	elseif data.kind == "Sprinkler" and finite(data.warn) then
		if now < data.t0 + data.warn then
			if near and not s.warned then
				table.insert(cues, "GeyserWarning")
				s.warned = true
			end
		elseif not s.sprayed then
			s.sprayed = true
			if near then
				table.insert(cues, "GeyserLaunch")
			end
		end
	end
	return cues
end
function Logic.hint(raw: any, cfg: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	for _, hint in cfg.hints do
		if string.sub(raw, 1, #hint.prefix) == hint.prefix then
			return hint.cue
		end
	end
	return nil
end
return Logic
