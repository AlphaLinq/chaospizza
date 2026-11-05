--!strict
-- Client-side event visuals that used to be animated on the server every frame
-- (#57, mobile network budget):
--   * the tornado funnel + orbiting debris, drawn around the replicated
--     CityState.TornadoPos (10 Hz) and smoothed locally
--   * bobbing flood platforms (tag "FloodPlatform"); the server keeps them still
-- Visual only: launches, rescues and hits stay on the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local EventFxController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local SHAKE_SECONDS = 0.45
local SHAKE_STUDS = 0.6
local SPLASH_PARTICLES = 24
local FLOOD_ZONE = MapLayout.zones.LowerTown

local function qualityScale(): number
	return settings.particleScale(player:GetAttribute("EffectQuality"))
end

local FUNNEL_LAYERS = 9
local DEBRIS = 10
local SMOOTHING = 8 -- higher = snappier follow of the 10 Hz position
local BOB_HEIGHT = 0.25
local BOB_SPEED = 1.6

type Piece = { part: BasePart, height: number, phase: number, orbit: number?, base: Vector3? }

local funnel: Model? = nil
local pieces: { Piece } = {}
local shown = Vector3.zero
local spin = 0

local function newPart(parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function buildFunnel(at: Vector3)
	local model = Instance.new("Model")
	model.Name = "LocalTornado"
	for i = 1, FUNNEL_LAYERS do
		local t = (i - 1) / (FUNNEL_LAYERS - 1)
		local ring = newPart(model)
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.SmoothPlastic
		ring.Color = Color3.fromHex("#8D96A3"):Lerp(Color3.fromHex("#D8DDE4"), t)
		ring.Transparency = 0.25 + t * 0.35
		local radius = 3 + t * 16
		ring.Size = Vector3.new(5, radius * 2, radius * 2)
		table.insert(pieces, { part = ring, height = 2 + i * 5, phase = i * 0.7 })
	end
	for i = 1, DEBRIS do
		local d = newPart(model)
		d.Size = Vector3.new(1.2 + (i % 3), 0.4, 1 + (i % 2))
		d.Color = Color3.fromHex(if i % 2 == 0 then "#B5835A" else "#E8E2D6")
		d.Material = Enum.Material.Wood
		table.insert(pieces, {
			part = d,
			height = 4 + (i * 3.7) % 30,
			phase = i * 1.3,
			orbit = 6 + (i * 2.3) % 12,
		})
	end
	model.Parent = Workspace
	funnel = model
	shown = at
end

local function clearFunnel()
	if funnel then
		funnel:Destroy()
	end
	funnel = nil
	table.clear(pieces)
end

local function stepFunnel(state: Instance, dt: number)
	local target = state:GetAttribute("TornadoPos")
	if typeof(target) ~= "Vector3" then
		if funnel then
			clearFunnel()
		end
		return
	end
	if not funnel then
		buildFunnel(target)
	end
	shown = shown:Lerp(target, math.clamp(dt * SMOOTHING, 0, 1))
	spin += dt
	for _, piece in pieces do
		if piece.orbit then
			local a = spin * 2.2 + piece.phase
			piece.part.CFrame = CFrame.new(
				shown
					+ Vector3.new(
						math.cos(a) * piece.orbit,
						piece.height,
						math.sin(a) * piece.orbit
					)
			) * CFrame.Angles(a, a * 0.5, 0)
		else
			local wobble = Vector3.new(
				math.sin(spin * 1.3 + piece.phase) * 1.5,
				0,
				math.cos(spin + piece.phase) * 1.5
			)
			piece.part.CFrame = CFrame.new(shown + Vector3.new(0, piece.height, 0) + wobble)
				* CFrame.Angles(0, spin * 3 + piece.phase, math.rad(90))
		end
	end
end

-- Flood platforms: remember each platform's server position, bob locally.
local platformBase: { [BasePart]: Vector3 } = {}
local bobTime = 0

local function stepPlatforms(dt: number)
	bobTime += dt
	local i = 0
	for part, base in platformBase do
		i += 1
		if part.Parent then
			part.CFrame =
				CFrame.new(base + Vector3.new(0, math.sin(bobTime * BOB_SPEED + i) * BOB_HEIGHT, 0))
		else
			platformBase[part] = nil
		end
	end
end

-- Knockback feedback (#19): a short camera shake and a "💫" above the head —
-- the visual equivalent of the hit sound, so muted players still notice.
local shakeToken = 0
local function knockFeedback(duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid then
		return
	end
	shakeToken += 1
	local token = shakeToken
	local strength = SHAKE_STUDS * math.max(0.35, qualityScale())
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < SHAKE_SECONDS and token == shakeToken do
			local fade = 1 - (os.clock() - t0) / SHAKE_SECONDS
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * 2 * strength * fade,
				(math.random() - 0.5) * 2 * strength * fade,
				0
			)
			task.wait()
		end
		if token == shakeToken then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
	if head and head:IsA("BasePart") then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(60, 40)
		billboard.StudsOffset = Vector3.new(0, 2.2, 0)
		billboard.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "💫"
		label.Parent = billboard
		billboard.Parent = head
		TweenService
			:Create(label, TweenInfo.new(duration), { TextTransparency = 1, Rotation = 180 })
			:Play()
		task.delay(duration, function()
			billboard:Destroy()
		end)
	end
end

-- Flood splash when the local courier drops into the water.
local wasInWater = false
local function stepSplash(state: Instance)
	local level = state:GetAttribute("FloodLevel")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(level) ~= "number" or not root or not root:IsA("BasePart") then
		wasInWater = false
		return
	end
	local p = root.Position
	local inZone = math.abs(p.X - FLOOD_ZONE.x) < FLOOD_ZONE.sx / 2
		and math.abs(p.Z - FLOOD_ZONE.z) < FLOOD_ZONE.sz / 2
	local inWater = inZone and p.Y < level + 1
	if inWater and not wasInWater then
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(p.X, level, p.Z)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromHex("#BFE6FF"))
		emitter.Size = NumberSequence.new(0.6, 0.1)
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(12, 20)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.Rate = 0
		emitter.Parent = anchor
		anchor.Parent = Workspace
		emitter:Emit(math.max(4, math.floor(SPLASH_PARTICLES * qualityScale())))
		task.delay(1.2, function()
			anchor:Destroy()
		end)
	end
	wasInWater = inWater
end

function EventFxController.start()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end

	local function track(instance: Instance)
		if instance:IsA("BasePart") then
			platformBase[instance] = instance.Position
		end
	end
	for _, part in CollectionService:GetTagged("FloodPlatform") do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal("FloodPlatform"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("FloodPlatform"):Connect(function(instance)
		if instance:IsA("BasePart") then
			platformBase[instance] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepFunnel(state, dt)
		stepPlatforms(dt)
		stepSplash(state)
	end)

	Net.event("Knockback").OnClientEvent:Connect(function(_impulse: unknown, duration: unknown)
		knockFeedback(if typeof(duration) == "number" then math.clamp(duration, 0.3, 3) else 1)
	end)
end

return EventFxController
