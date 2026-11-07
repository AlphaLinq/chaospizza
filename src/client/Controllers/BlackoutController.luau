--!strict
-- Blackout visuals (#131), all local:
--   * Lighting tweens to night and back (saved values are restored exactly)
--   * building windows glow (some flicker), scaled by the EffectQuality setting
--   * the courier's target door gets a light and a tall beacon beam
--   * every pizza box carries a small PointLight
--   * neon waves ripple across the city from CityState "BlackoutWave"
-- The server never touches Lighting for this event.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MapGeometry = require(ReplicatedStorage.Shared.Util.MapGeometry)
local ComfortFlags = require(ReplicatedStorage.Shared.Util.ComfortFlags)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local BlackoutController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)

local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local WINDOW_COLORS = { "#FFD27A", "#FFE9B0", "#FFB45C", "#BFE3FF" }
local WAVE_COLORS = { "#FF4FD8", "#3FE0FF", "#B47CFF" }
local WAVE_SECONDS = 4
local WAVE_RADIUS = 320
local BOX_LIGHT = "BlackoutLight"

type Saved = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ExposureCompensation: number,
}

local dark = false
local saved: Saved? = nil
local folder: Folder? = nil
local flicker: { BasePart } = {}
local beacon: Model? = nil
local connections: { RBXScriptConnection } = {}
local lastWave: string? = nil

local function quality(): number
	return settings.particleScale(player:GetAttribute("EffectQuality"))
end

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: string): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromHex(color)
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function buildWindows(root: Folder)
	local rng = Random.new(42)
	-- Low quality still lights one window per building: the city stays readable.
	local perBuilding = math.clamp(math.floor(1 + 3 * quality()), 1, 4)
	local groundY = MapLayout.streetY + 0.2
	for _, b in MapLayout.buildings do
		local f = MapGeometry.facing(b.door)
		local halfDepth = if f.x ~= 0 then b.sx / 2 else b.sz / 2
		local width = if f.x ~= 0 then b.sz else b.sx
		local facade =
			Vector3.new(b.x + f.x * (halfDepth + 0.05), groundY, b.z + f.z * (halfDepth + 0.05))
		local look = CFrame.lookAt(facade, facade + Vector3.new(f.x, 0, f.z))
		for i = 1, perBuilding do
			local u = (i / (perBuilding + 1) - 0.5) * width * 0.8
			local y = math.max(MapGeometry.DOOR_HEIGHT + 5, b.h * (0.55 + rng:NextNumber() * 0.3))
			if y < b.h - 1 then
				local w = neon(
					root,
					Vector3.new(3, 3.4, 0.2),
					look * CFrame.new(u, y, 0),
					WINDOW_COLORS[rng:NextInteger(1, #WINDOW_COLORS)]
				)
				w.Name = "Window"
				if rng:NextNumber() < 0.25 then
					table.insert(flicker, w)
				end
			end
		end
	end
end

local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function updateBeacon()
	clearBeacon()
	local root = folder
	if not dark or not root then
		return
	end
	local target = player:GetAttribute("OrderTarget") or player:GetAttribute("GiantTarget")
	if typeof(target) ~= "Vector3" then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Beacon"
	local base = target - Vector3.new(0, 2.5, 0)
	local pad = neon(
		model,
		Vector3.new(0.3, 7, 7),
		CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		"#FFD23F"
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.Transparency = 0.4
	local beam = neon(
		model,
		Vector3.new(80, 1.2, 1.2),
		CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		"#FFE27A"
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 0.55
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#FFD23F")
	light.Range = 26
	light.Brightness = 3
	light.Parent = pad
	model.Parent = root
	beacon = model
end

local function lightBoxes()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local box = character and character:FindFirstChild("PizzaBox", true)
		if box and box:IsA("BasePart") and not box:FindFirstChild(BOX_LIGHT) then
			local light = Instance.new("PointLight")
			light.Name = BOX_LIGHT
			light.Color = Color3.fromHex("#FFC46B")
			light.Range = 14
			light.Brightness = 2
			light.Parent = box
		end
	end
end

local function unlightBoxes()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			for _, d in character:GetDescendants() do
				if d.Name == BOX_LIGHT then
					d:Destroy()
				end
			end
		end
	end
end

local function wave(raw: unknown)
	local root = folder
	if not dark or not root or typeof(raw) ~= "string" or raw == lastWave then
		return
	end
	lastWave = raw
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(data) ~= "table" then
		return
	end
	local d = data :: any
	if typeof(d.x) ~= "number" or typeof(d.z) ~= "number" then
		return
	end
	local ring = neon(
		root,
		Vector3.new(0.3, 4, 4),
		CFrame.new(d.x, MapLayout.streetY + 0.5, d.z) * CFrame.Angles(0, 0, math.rad(90)),
		WAVE_COLORS[math.random(1, #WAVE_COLORS)]
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	local tween = TweenService:Create(ring, TweenInfo.new(WAVE_SECONDS, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.3, WAVE_RADIUS * 2, WAVE_RADIUS * 2),
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
	tween:Play()
end

local function enter(state: Instance)
	if dark then
		return
	end
	dark = true
	saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	-- Low quality keeps a brighter ambient so streets stay readable.
	local low = quality() < 0.5
	TweenService:Create(Lighting, FADE, {
		ClockTime = 0.5,
		Brightness = if low then 1 else 0.6,
		Ambient = Color3.fromHex(if low then "#4A5078" else "#2C3150"),
		OutdoorAmbient = Color3.fromHex(if low then "#555C88" else "#363C62"),
		ExposureCompensation = if low then 0 else -0.25,
	}):Play()

	local root = Instance.new("Folder")
	root.Name = "LocalBlackout"
	root.Parent = Workspace
	folder = root
	buildWindows(root)
	updateBeacon()
	lightBoxes()

	local elapsed, boxCheck = 0, 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			boxCheck += dt
			if elapsed >= 0.15 then
				elapsed = 0
				-- Comfort (#177): flickering windows hold steady with reduced flashes.
				local steady = ComfortFlags.reduced(player:GetAttribute("ReduceFlashes"))
				for _, w in flicker do
					w.Transparency = if not steady and math.random() < 0.3 then 0.85 else 0
				end
			end
			if boxCheck >= 1 then
				boxCheck = 0
				lightBoxes() -- couriers who picked up a box since
			end
		end)
	)
	for _, name in { "OrderTarget", "GiantTarget" } do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(updateBeacon))
	end
	wave(state:GetAttribute("BlackoutWave"))
end

local function leave()
	if not dark then
		return
	end
	dark = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(flicker)
	clearBeacon()
	unlightBoxes()
	if folder then
		folder:Destroy()
		folder = nil
	end
	lastWave = nil
	local restore = saved
	saved = nil
	if restore then
		TweenService:Create(Lighting, FADE, restore :: any):Play()
	end
end

function BlackoutController.start()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local function refresh()
		if state:GetAttribute("Blackout") == true then
			enter(state)
		else
			leave()
		end
	end
	state:GetAttributeChangedSignal("Blackout"):Connect(refresh)
	state:GetAttributeChangedSignal("BlackoutWave"):Connect(function()
		wave(state:GetAttribute("BlackoutWave"))
	end)
	refresh()
end

return BlackoutController
