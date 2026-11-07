--!strict
-- Client-side event visuals that used to be animated on the server every frame
-- (#57, mobile network budget):
--   * the tornado funnel + orbiting debris, drawn around the replicated
--     CityState.TornadoPos (10 Hz) and smoothed locally
--   * bobbing flood platforms (tag "FloodPlatform"); the server keeps them still
-- Visual only: launches, rescues and hits stay on the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ComfortFlags = require(ReplicatedStorage.Shared.Util.ComfortFlags)
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

type Piece = { part: BasePart, height: number, phase: number, orbit: number? }

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
		local piece: Piece = { part = ring, height = 2 + i * 5, phase = i * 0.7, orbit = nil }
		table.insert(pieces, piece)
	end
	for i = 1, DEBRIS do
		local d = newPart(model)
		d.Size = Vector3.new(1.2 + (i % 3), 0.4, 1 + (i % 2))
		d.Color = Color3.fromHex(if i % 2 == 0 then "#B5835A" else "#E8E2D6")
		d.Material = Enum.Material.Wood
		local piece: Piece = {
			part = d,
			height = 4 + (i * 3.7) % 30,
			phase = i * 1.3,
			orbit = 6 + (i * 2.3) % 12,
		}
		table.insert(pieces, piece)
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
local function reduceMotion(): boolean
	return ComfortFlags.reduced(player:GetAttribute("ReduceMotion"))
end
local function reduceFlashes(): boolean
	return ComfortFlags.reduced(player:GetAttribute("ReduceFlashes"))
end

-- Comfort (#177): stop a running shake and reset the camera right away.
local function stopShake()
	shakeToken += 1
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
end

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
		while os.clock() - t0 < SHAKE_SECONDS and token == shakeToken and not reduceMotion() do
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
	if reduceMotion() then
		humanoid.CameraOffset = Vector3.zero
	end
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

-- MEGA CHAOS light show (#115, brief ch. 15): a cycling colour pulse, sparks
-- from the plaza chaos meter and sweeping neon beams. Local only; beams are
-- skipped on Low quality.
local MEGA_COLORS =
	{ Color3.fromHex("#FF3FA4"), Color3.fromHex("#3FE0FF"), Color3.fromHex("#FFD24A") }
local MEGA_BEAMS = 4
local megaParts: { BasePart } = {}
local megaPulse: ColorCorrectionEffect? = nil
local megaSparks: ParticleEmitter? = nil
local megaTime = 0

local function megaOn()
	if megaPulse then
		return
	end
	local pulse = Instance.new("ColorCorrectionEffect")
	pulse.Name = "MegaPulse"
	pulse.Parent = Lighting
	megaPulse = pulse

	local meter = Workspace:FindFirstChild("ChaosMeter", true)
	local cap = meter and meter:FindFirstChild("Cap")
	if cap and cap:IsA("BasePart") then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(MEGA_COLORS[1], MEGA_COLORS[2])
		sparks.Size = NumberSequence.new(0.8, 0)
		sparks.Lifetime = NumberRange.new(0.6, 1.2)
		sparks.Speed = NumberRange.new(10, 18)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Rate = 40 * qualityScale()
		sparks.Parent = cap
		megaSparks = sparks
	end

	if qualityScale() > 0.3 then
		local plaza = MapLayout.chaosMeter
		for i = 1, MEGA_BEAMS do
			local beam = Instance.new("Part")
			beam.Name = "MegaBeam"
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanQuery = false
			beam.CanTouch = false
			beam.CastShadow = false
			beam.Material = Enum.Material.Neon
			beam.Color = MEGA_COLORS[(i - 1) % #MEGA_COLORS + 1]
			beam.Transparency = 0.55
			beam.Size = Vector3.new(1.2, 70, 1.2)
			beam:SetAttribute("Index", i)
			beam:SetAttribute("Cx", plaza.x)
			beam:SetAttribute("Cz", plaza.z)
			beam.Parent = Workspace
			table.insert(megaParts, beam)
		end
	end
end

local function megaOff()
	if megaPulse then
		megaPulse:Destroy()
		megaPulse = nil
	end
	if megaSparks then
		megaSparks:Destroy()
		megaSparks = nil
	end
	for _, p in megaParts do
		p:Destroy()
	end
	table.clear(megaParts)
end

local function stepMega(state: Instance, dt: number)
	if state:GetAttribute("Mega") ~= true then
		if megaPulse then
			megaOff()
		end
		return
	end
	megaOn()
	megaTime += dt
	local pulse = megaPulse
	if pulse then
		local k = (megaTime * 0.8) % #MEGA_COLORS
		local a = MEGA_COLORS[math.floor(k) + 1]
		local b = MEGA_COLORS[(math.floor(k) + 1) % #MEGA_COLORS + 1]
		local tint = a:Lerp(b, k % 1)
		if reduceFlashes() then
			-- Comfort (#177): a steady MEGA tint, no colour cycling or pulsing.
			pulse.TintColor = Color3.new(1, 1, 1):Lerp(MEGA_COLORS[1], 0.2)
			pulse.Brightness = 0
		else
			pulse.TintColor = Color3.new(1, 1, 1):Lerp(tint, 0.35)
			pulse.Brightness = 0.05 + math.sin(megaTime * 6) * 0.04
		end
		pulse.Saturation = 0.25
	end
	for _, beam in megaParts do
		local i = beam:GetAttribute("Index") :: number
		local angle = megaTime * 1.4 + i * (math.pi * 2 / MEGA_BEAMS)
		local cx, cz = beam:GetAttribute("Cx") :: number, beam:GetAttribute("Cz") :: number
		beam.CFrame = CFrame.new(cx + math.cos(angle) * 30, 30, cz + math.sin(angle) * 30)
			* CFrame.Angles(math.sin(angle) * 0.5, 0, math.cos(angle) * 0.5)
	end
end

function EventFxController.start()
	player:GetAttributeChangedSignal("ReduceMotion"):Connect(function()
		if reduceMotion() then
			stopShake()
		end
	end)
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
		stepMega(state, dt)
	end)

	Net.event("Knockback").OnClientEvent:Connect(function(_impulse: unknown, duration: unknown)
		knockFeedback(if typeof(duration) == "number" then math.clamp(duration, 0.3, 3) else 1)
	end)
end

return EventFxController
