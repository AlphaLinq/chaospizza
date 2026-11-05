--!strict
local PerfMetrics = {}
function PerfMetrics.empty(): any
	return {
		instances = 0,
		parts = 0,
		unanchoredParts = 0,
		emitters = 0,
		enabledEmitters = 0,
		particlesPerSecond = 0,
		estimatedAliveParticles = 0,
		playingSounds = 0,
	}
end
function PerfMetrics.add(metrics: any, facts: any)
	metrics.instances += 1
	if facts.part then
		metrics.parts += 1
		if not facts.anchored then
			metrics.unanchoredParts += 1
		end
	end
	if facts.emitter then
		metrics.emitters += 1
		if facts.enabled then
			metrics.enabledEmitters += 1
			local rate = math.max(0, facts.rate or 0)
			metrics.particlesPerSecond += rate
			metrics.estimatedAliveParticles += rate * math.max(0, facts.lifetime or 0)
		end
	end
	if facts.playing then
		metrics.playingSounds += 1
	end
end
function PerfMetrics.overBudget(metrics: any, budget: any): { string }
	local exceeded = {}
	for key, limit in budget do
		if type(metrics[key]) == "number" and metrics[key] > limit then
			table.insert(exceeded, string.format("%s=%.1f > %.1f", key, metrics[key], limit))
		end
	end
	table.sort(exceeded)
	return exceeded
end
function PerfMetrics.frames(capacity: number, targetFps: number)
	local samples: { number } = {}
	local focusSamples: { number } = {}
	local index, observed = 1, 0
	local api = {}
	function api.add(dt: number, focused: boolean?)
		if dt ~= dt or dt <= 0 or dt == math.huge then
			return
		end
		samples[index] = dt
		focusSamples[index] = if focused == nil then 2 else if focused then 0 else 1
		index = index % capacity + 1
		observed += 1
	end
	function api.report(): any
		if #samples == 0 then
			return { frames = 0, observedFrames = observed }
		end
		local sorted = table.clone(samples)
		table.sort(sorted)
		local seconds, slow, background, unknown = 0, 0, 0, 0
		for sampleIndex, dt in samples do
			seconds += dt
			if focusSamples[sampleIndex] == 1 then
				background += 1
			elseif focusSamples[sampleIndex] == 2 then
				unknown += 1
			end
			if dt > 1 / targetFps then
				slow += 1
			end
		end
		local p95 = sorted[math.ceil(#sorted * 0.95)]
		return {
			backgroundFrames = background,
			unknownFocusFrames = unknown,
			frames = #samples,
			observedFrames = observed,
			truncated = observed > capacity,
			seconds = seconds,
			averageFps = #samples / seconds,
			averageFrameMs = seconds / #samples * 1000,
			p95FrameMs = p95 * 1000,
			worstFrameMs = sorted[#sorted] * 1000,
			framesOver33ms = slow,
		}
	end
	return api
end
return PerfMetrics
