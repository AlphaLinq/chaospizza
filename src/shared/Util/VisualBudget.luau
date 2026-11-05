--!strict
local VisualBudget = {}
function VisualBudget.visible(
	distance: number,
	wasVisible: boolean,
	near: number,
	hysteresis: number
): boolean
	return distance <= near + (if wasVisible then hysteresis else 0)
end
function VisualBudget.allocate(requests: { any }, budget: any, headroom: number): any
	local rate, alive = 0, 0
	for _, request in requests do
		if request.enabled then
			rate += math.max(0, request.rate)
			alive += math.max(0, request.rate) * math.max(0, request.lifetime)
		end
	end
	local scale = 1
	if rate > budget.particlesPerSecond then
		scale = math.min(scale, budget.particlesPerSecond / rate)
	end
	if alive > budget.estimatedAliveParticles then
		scale = math.min(scale, budget.estimatedAliveParticles / alive)
	end
	if scale < 1 then
		scale *= headroom
	end
	local result = {}
	for _, request in requests do
		result[request.key] = if request.enabled then math.max(0, request.rate) * scale else 0
	end
	return result
end
return VisualBudget
