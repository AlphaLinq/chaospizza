--!strict
local SoundPolicy = {}
function SoundPolicy.percent(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value > 100 or value % 1 ~= 0 then
		return nil
	end
	return value
end
function SoundPolicy.action(action: string): (string?, number?)
	local channel, raw = string.match(action, "^(%a+)%.(%d+)$")
	if channel ~= "music" and channel ~= "sfx" then
		return nil, nil
	end
	return channel, SoundPolicy.percent(tonumber(raw))
end
function SoundPolicy.volume(value: unknown): number
	-- Stay silent until the server publishes the persisted preference, including
	-- late joins during MEGA. A missing value must not briefly unmute the game.
	return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 0
end
function SoundPolicy.step(value: number, direction: number, steps: { number }): number
	if direction < 0 then
		for i = #steps, 1, -1 do
			if steps[i] < value then
				return steps[i]
			end
		end
		return steps[1]
	end
	for _, step in steps do
		if step > value then
			return step
		end
	end
	return steps[#steps]
end
function SoundPolicy.note(music: any, now: number): (number, number)
	local beat = math.floor(now / (60 / music.bpm / music.subdivisions))
	return beat, music.notes[beat % #music.notes + 1]
end
return SoundPolicy
