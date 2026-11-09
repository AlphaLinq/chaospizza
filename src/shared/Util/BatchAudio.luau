--!strict
local Logic = {}
local function positive(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end
function Logic.new(): any
	return {}
end
function Logic.hint(raw: any, cfg: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	for _, item in cfg.hints do
		if string.sub(raw, 1, #item.prefix) == item.prefix then
			return item.cue
		end
	end
	if
		string.sub(raw, 1, #"✨ ") == "✨ "
		and string.find(raw, " is carrying a GOLDEN PIZZA", 1, true)
	then
		return "GoldenJingle"
	end
	return nil
end
function Logic.rush(state: any, combo: any, emit: boolean): { string }
	local old = state.combo
	state.combo = if positive(combo) then combo else nil
	if not emit then
		return {}
	end
	if state.combo and not old then
		return { "RushStart" }
	end
	if old and not state.combo then
		return { "RushEnd" }
	end
	if old and state.combo and state.combo > old then
		return { "RushTick" }
	end
	if old and state.combo and state.combo < old then
		return { "RushStart" }
	end
	return {}
end
function Logic.errand(state: any, data: any, emit: boolean): { string }
	local key = if type(data) == "table"
			and type(data.name) == "string"
			and type(data.item) == "string"
		then data.name .. ":" .. data.item
		else nil
	local done = key ~= nil and data.done == true
	local old, wasDone = state.errand, state.done
	state.errand, state.done = key, done
	if not emit or not key then
		return {}
	end
	if key ~= old and not done then
		return { "ErrandRing" }
	end
	if key == old and done and not wasDone then
		return { "ErrandPickup" }
	end
	return {}
end
function Logic.hero(state: any, deadline: any, now: number, emit: boolean): { string }
	local previous = state.hero
	state.hero = if positive(deadline) then deadline else nil
	return if emit
			and state.hero
			and state.hero > now
			and state.hero ~= previous
		then { "HeroChime" }
		else {}
end
return Logic
