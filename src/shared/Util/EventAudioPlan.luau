--!strict
local EventAudioPlan = {}
function EventAudioPlan.get(config: any, state: any): any
	local event = config.events[state.id or ""]
	local result: any = { ambience = {}, phase = state.phase }
	if not event then
		return result
	end
	if state.phase == "warning" then
		result.warning = if state.mega then "MegaWarning" else event.warning
		result.warningToken = tostring(state.endsAt) .. ":" .. state.id
	elseif state.phase == "buildUp" or state.phase == "active" then
		table.insert(result.ambience, event.ambience)
		local combo = config.events[state.combo or ""]
		if state.mega then
			result.music = "Mega"
			if combo and combo.ambience ~= event.ambience then
				table.insert(result.ambience, combo.ambience)
			end
		end
	end
	return result
end
return EventAudioPlan
