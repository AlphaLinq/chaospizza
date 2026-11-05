--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Perf)
local Metrics = require(ReplicatedStorage.Shared.Util.PerfMetrics)
local Collector = require(ReplicatedStorage.Shared.Runtime.PerfCollector)
local PerfController = {}
local connections: { RBXScriptConnection } = {}
local alive = false
local token = 0
function PerfController.start()
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local rolling = Metrics.frames(Config.rollingFrameSamples, Config.targetFps)
	local capture: any = nil
	local context: any = {}
	local key = ""
	local function refreshContext()
		context = Collector.context()
		context.quality = player:GetAttribute("EffectQuality")
		key = table.concat({
			tostring(context.id),
			tostring(context.combo),
			tostring(context.phase),
			tostring(context.quality),
		}, ":")
	end
	local state = ReplicatedStorage:WaitForChild("CityState")
	table.insert(connections, state.AttributeChanged:Connect(refreshContext))
	table.insert(
		connections,
		player:GetAttributeChangedSignal("EffectQuality"):Connect(refreshContext)
	)
	refreshContext()
	local function report(frames: any, segments: any?, wallSeconds: number?)
		local summary = frames.report()
		local segmentReports = {}
		if segments then
			for name, segment in segments do
				segmentReports[name] =
					{ context = segment.context, frames = segment.frames.report() }
			end
		end
		local snapshot = Collector.snapshot()
		if not alive then
			return
		end
		snapshot.frames = summary
		snapshot.segments = segmentReports
		snapshot.captureWallSeconds = wallSeconds
		snapshot.frameBudget = {
			targetFps = Config.targetFps,
			p95WithinBudget = summary.p95FrameMs ~= nil
				and summary.p95FrameMs <= 1000 / Config.targetFps,
		}
		snapshot.touchEnabled = UserInputService.TouchEnabled
		snapshot.quality = player:GetAttribute("EffectQuality")
		local camera = Workspace.CurrentCamera
		if camera then
			snapshot.viewport = { x = camera.ViewportSize.X, y = camera.ViewportSize.Y }
		end
		local json = HttpService:JSONEncode(snapshot)
		pg:SetAttribute("PerfClientReport", json)
		pg:SetAttribute("PerfCapture", "done")
		print("[Perf client] " .. json)
	end
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			rolling.add(dt)
			if capture then
				capture.frames.add(dt)
				local segment = capture.segments[key]
				if not segment and capture.segmentCount < Config.maxSegments then
					segment = {
						frames = Metrics.frames(Config.captureFrameSamples, Config.targetFps),
						context = table.clone(context),
					}
					capture.segments[key] = segment
					capture.segmentCount += 1
				end
				if segment then
					segment.frames.add(dt)
				end
			end
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal("PerfRequest"):Connect(function()
			local raw = player:GetAttribute("PerfRequest")
			if type(raw) ~= "string" then
				return
			end
			local ok, request = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if not ok or type(request) ~= "table" or type(request.seconds) ~= "number" then
				return
			end
			local seconds = request.seconds
			if seconds ~= seconds or seconds < 0 or seconds > Config.maxCaptureSeconds then
				return
			end
			if seconds == 0 then
				task.spawn(function()
					report(rolling, nil, nil)
				end)
				return
			end
			token += 1
			local current = token
			local started = os.clock()
			local pending = {
				frames = Metrics.frames(Config.captureFrameSamples, Config.targetFps),
				segments = {},
				segmentCount = 0,
			}
			capture = pending
			pg:SetAttribute("PerfCapture", "running")
			task.delay(seconds, function()
				if alive and token == current then
					capture = nil
					report(pending.frames, pending.segments, os.clock() - started)
				end
			end)
		end)
	)
end
function PerfController.destroy()
	alive = false
	token += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end
return PerfController
