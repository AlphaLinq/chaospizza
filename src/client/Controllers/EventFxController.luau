--!strict
-- Client-side event visuals that used to be animated on the server every frame
-- (#57, mobile network budget):
--   * the tornado funnel + orbiting debris, drawn around the replicated
--     CityState.TornadoPos (10 Hz) and smoothed locally
--   * bobbing flood platforms (tag "FloodPlatform"); the server keeps them still
-- Visual only: launches, rescues and hits stay on the server.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventFxController = {}

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
	end)
end

return EventFxController
