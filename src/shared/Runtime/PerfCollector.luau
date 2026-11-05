--!strict
-- Engine adapter; the counter/budget/frame math lives in the pure PerfMetrics.
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Metrics = require(ReplicatedStorage.Shared.Util.PerfMetrics)
local PerfCollector = {}
function PerfCollector.eventRoot(instance: Instance): string?
	local root = instance
	while root.Parent and root.Parent ~= Workspace do
		root = root.Parent
	end
	if root.Parent ~= Workspace then
		return nil
	end
	return string.match(root.Name, "^Event_(.+)$") or Config.localEventRoots[root.Name]
end
function PerfCollector.context(): any
	local state = ReplicatedStorage:FindFirstChild("CityState")
	return {
		id = state and state:GetAttribute("EventId"),
		combo = state and state:GetAttribute("ComboId"),
		phase = state and state:GetAttribute("EventPhase"),
		mega = state and state:GetAttribute("Mega") == true,
	}
end
function PerfCollector.snapshot(): any
	local started = os.clock()
	local total = Metrics.empty()
	local events: { [string]: any } = {}
	for index, instance in Workspace:GetDescendants() do
		local facts: any = {}
		if instance:IsA("BasePart") then
			facts.part, facts.anchored = true, instance.Anchored
		elseif instance:IsA("ParticleEmitter") then
			facts.emitter, facts.enabled, facts.rate, facts.lifetime =
				true, instance.Enabled, instance.Rate, instance.Lifetime.Max
		elseif instance:IsA("Sound") then
			facts.playing = instance.IsPlaying
		end
		Metrics.add(total, facts)
		local event = PerfCollector.eventRoot(instance)
		if event then
			if not events[event] then
				events[event] = Metrics.empty()
			end
			Metrics.add(events[event], facts)
		end
		if index % Config.scanYieldEvery == 0 then
			task.wait()
		end
	end
	-- Music/UI sounds are outside Workspace, so include their playing voices too.
	for _, instance in SoundService:GetDescendants() do
		if instance:IsA("Sound") and instance.IsPlaying then
			total.playingSounds += 1
		end
	end
	local stats, unavailable = {}, {}
	for _, key in Config.statNames do
		local ok, value = pcall(function()
			return (Stats :: any)[key]
		end)
		if ok and type(value) == "number" and value == value then
			stats[key] = value
		else
			table.insert(unavailable, key)
		end
	end
	local ok, memory = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if ok then
		stats.memoryMb = memory
	else
		table.insert(unavailable, "memoryMb")
	end
	local warnings = Metrics.overBudget(total, Config.workspaceBudget)
	for event, metrics in events do
		for _, warning in Metrics.overBudget(metrics, Config.eventBudget) do
			table.insert(warnings, event .. ": " .. warning)
		end
	end
	return {
		side = if RunService:IsServer() then "server" else "client",
		unix = os.time(),
		studio = RunService:IsStudio(),
		placeVersion = game.PlaceVersion,
		context = PerfCollector.context(),
		workspace = total,
		events = events,
		stats = stats,
		unavailableStats = unavailable,
		streamingEnabled = Workspace.StreamingEnabled,
		warnings = warnings,
		scanMs = (os.clock() - started) * 1000,
	}
end
return PerfCollector
