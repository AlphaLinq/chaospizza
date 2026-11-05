--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Policy = require(ReplicatedStorage.Shared.Util.VisualBudget)
local Collector = require(ReplicatedStorage.Shared.Runtime.PerfCollector)
local ParticleBudgetController = {}
local records: { [ParticleEmitter]: any } = {}
local connections: { RBXScriptConnection } = {}
local alive, queued = false, false
local nextKey = 0
local lastReport = ""
local function scoped(instance: Instance): boolean
	if Collector.eventRoot(instance) then
		return true
	end
	local root = instance
	while root.Parent and root.Parent ~= Workspace do
		root = root.Parent
	end
	return root.Parent == Workspace and root.Name == "PizzaMap"
end
function ParticleBudgetController.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local function apply()
		queued = false
		if not alive then
			return
		end
		local quality = player:GetAttribute("EffectQuality")
		local budget = Config.visualProfiles[if type(quality) == "string" then quality else "low"]
			or Config.visualProfiles.low
		local requests = {}
		for emitter, record in records do
			if emitter.Parent then
				table.insert(requests, {
					key = record.key,
					rate = record.desired,
					lifetime = emitter.Lifetime.Max,
					enabled = emitter.Enabled,
				})
			end
		end
		local rates = Policy.allocate(requests, budget, Config.allocationHeadroom)
		local total, live = 0, 0
		for emitter, record in records do
			if emitter.Parent then
				local rate = if emitter.Enabled then rates[record.key] or 0 else record.desired
				record.applied = rate
				if math.abs(emitter.Rate - rate) > Config.rateEpsilon then
					emitter.Rate = rate
				end
				record.applied = emitter.Rate
				if emitter.Enabled then
					total += emitter.Rate
					live += emitter.Rate * emitter.Lifetime.Max
				end
			end
		end
		local json = HttpService:JSONEncode({
			quality = quality,
			particlesPerSecond = total,
			estimatedAliveParticles = live,
			trackedEmitters = #requests,
		})
		if json ~= lastReport then
			lastReport = json
			pg:SetAttribute("ParticleBudget", json)
		end
	end
	local function queue()
		if not queued and alive then
			queued = true
			task.defer(apply)
		end
	end
	local function track(instance: Instance)
		if
			not alive
			or not instance:IsA("ParticleEmitter")
			or not instance:IsDescendantOf(Workspace)
			or not scoped(instance)
			or records[instance]
		then
			return
		end
		nextKey += 1
		local record: any =
			{ key = nextKey, desired = instance.Rate, applied = instance.Rate, connections = {} }
		records[instance] = record
		table.insert(
			record.connections,
			instance:GetPropertyChangedSignal("Rate"):Connect(function()
				if math.abs(instance.Rate - record.applied) <= Config.rateEpsilon then
					return
				end
				record.desired = instance.Rate
				queue()
			end)
		)
		for _, property in { "Enabled", "Lifetime" } do
			table.insert(
				record.connections,
				instance:GetPropertyChangedSignal(property):Connect(queue)
			)
		end
		queue()
	end
	local function added(instance: Instance)
		if instance:IsA("ParticleEmitter") then
			-- Let the existing event-quality controller capture its unmodified base.
			task.delay(Config.budgetInitialDelaySeconds, function()
				track(instance)
			end)
		end
	end
	for _, instance in Workspace:GetDescendants() do
		added(instance)
	end
	table.insert(connections, Workspace.DescendantAdded:Connect(added))
	table.insert(
		connections,
		Workspace.DescendantRemoving:Connect(function(instance)
			if instance:IsA("ParticleEmitter") and records[instance] then
				for _, c in records[instance].connections do
					c:Disconnect()
				end
				records[instance] = nil
				queue()
			end
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("EffectQuality"):Connect(queue))
end
function ParticleBudgetController.destroy()
	alive = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for emitter, record in records do
		for _, c in record.connections do
			c:Disconnect()
		end
		if emitter.Parent then
			emitter.Rate = record.desired
		end
	end
	table.clear(records)
end
return ParticleBudgetController
