--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Collector = require(ReplicatedStorage.Shared.Runtime.PerfCollector)
local DebugService = require(script.Parent.DebugService)
local PerfService = {}
local connections: { RBXScriptConnection } = {}
local tracked: { [Instance]: RBXScriptConnection } = {}
local trackedCount, transforms, attributes, sequence = 0, 0, 0, 0
local coverageLimited = false
local network: any = {}
local alive = false
function PerfService.snapshot(): any
	local report = Collector.snapshot()
	report.players = #Players:GetPlayers()
	report.transformTrafficModel = table.clone(network)
	report.transformTrafficModel.trackedParts = trackedCount
	report.transformTrafficModel.coverageLimited = coverageLimited
	return report
end
function PerfService.request(player: Player, seconds: number): (boolean, string)
	if
		seconds ~= seconds
		or seconds < 0
		or seconds > Config.maxCaptureSeconds
		or seconds % 1 ~= 0
	then
		return false, "Choose an integer capture duration from 0 to 60."
	end
	sequence += 1
	player:SetAttribute(
		"PerfRequest",
		HttpService:JSONEncode({ sequence = sequence, seconds = seconds })
	)
	local json = HttpService:JSONEncode(PerfService.snapshot())
	player:SetAttribute("PerfServerReport", json)
	print("[Perf server] " .. json)
	return true,
		if seconds > 0
			then `Client capture started: {seconds}s. See PerfClientReport and Output.`
			else json
end
function PerfService.init()
	DebugService.register(
		"perf",
		"Server budget and local frame capture",
		"perf [client [1-60 seconds]]",
		function(player, args)
			local seconds = if args[1] == "client"
				then tonumber(args[2] or tostring(Config.defaultCaptureSeconds))
				else 0
			if
				args[1] and args[1] ~= "client"
				or not seconds
				or seconds < 0
				or seconds > Config.maxCaptureSeconds
				or seconds % 1 ~= 0
				or args[1] == "client" and seconds == 0
			then
				return false, "usage: perf [client [1-60 seconds]]"
			end
			return PerfService.request(player, seconds)
		end
	)
end
function PerfService.start()
	alive = true
	local function watch(instance: Instance)
		if
			not instance:IsA("BasePart")
			or tracked[instance]
			or not Collector.eventRoot(instance)
		then
			return
		end
		if trackedCount >= Config.maxTrackedParts then
			coverageLimited = true
			return
		end
		trackedCount += 1
		tracked[instance] = instance:GetPropertyChangedSignal("CFrame"):Connect(function()
			transforms += 1
		end)
	end
	for _, instance in Workspace:GetDescendants() do
		watch(instance)
	end
	table.insert(connections, Workspace.DescendantAdded:Connect(watch))
	table.insert(
		connections,
		Workspace.DescendantRemoving:Connect(function(instance)
			local connection = tracked[instance]
			if connection then
				connection:Disconnect()
				tracked[instance] = nil
				trackedCount -= 1
			end
		end)
	)
	local state = ReplicatedStorage:WaitForChild("CityState")
	table.insert(
		connections,
		state.AttributeChanged:Connect(function()
			attributes += 1
		end)
	)
	task.spawn(function()
		local last = os.clock()
		while alive do
			task.wait(Config.networkWindowSeconds)
			if not alive then
				break
			end
			local now = os.clock()
			local bytes = transforms * Config.bytesPerTransformEstimate
				+ attributes * Config.bytesPerAttributeEstimate
			network = {
				windowSeconds = now - last,
				transformsPerSecond = transforms / (now - last),
				attributesPerSecond = attributes / (now - last),
				estimatedKiBPerSecondAllPlayers = bytes
					/ (now - last)
					* #Players:GetPlayers()
					/ 1024,
				measuredBandwidth = false,
			}
			transforms, attributes, last = 0, 0, now
		end
	end)
	task.spawn(function()
		local warned: { [string]: boolean } = {}
		local signature = ""
		while alive do
			task.wait(Config.scanIntervalSeconds)
			if not alive then
				break
			end
			local current = tostring(state:GetAttribute("EventId"))
				.. ":"
				.. tostring(state:GetAttribute("PhaseEndsAt"))
			if signature ~= current then
				table.clear(warned)
				signature = current
			end
			for _, warning in PerfService.snapshot().warnings do
				local key = string.match(warning, "^(.-)=") or warning
				if not warned[key] then
					warned[key] = true
					warn("[Perf budget] " .. warning)
				end
			end
		end
	end)
end
function PerfService.destroy()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, connection in tracked do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(tracked)
	trackedCount = 0
end
return PerfService
