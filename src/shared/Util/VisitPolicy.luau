--!strict
local VisitPolicy = {}
function VisitPolicy.check(
	phase: string,
	now: number,
	nextAt: number,
	alive: boolean,
	carrying: boolean
): (boolean, string)
	if phase ~= "calm" then
		return false, "Visits reopen when the streets settle."
	end
	if not alive then
		return false, "Wait until your courier respawns."
	end
	if carrying then
		return false, "Finish carrying the giant pizza before visiting."
	end
	if now ~= now or now >= math.huge or now < nextAt then
		return false, "Your next visit is on cooldown."
	end
	return true, "Ready to visit."
end
return VisitPolicy
