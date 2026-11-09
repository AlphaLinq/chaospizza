--!strict
-- Day/night visuals (#217). Every client runs the same clock from server
-- time (Util/DayCycle + CityState "DayOffset"), so nothing streams: the sky
-- turns, the light dims, neon street lamps glow at night (a real PointLight
-- only on high effect quality), and a small ☀️ / 🌆 / 🌙 sits on the HUD.
-- Paused while a Blackout runs (it owns Lighting then) and briefly after it,
-- so the two never fight over ClockTime.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DayCycle = require(ReplicatedStorage.Shared.Util.DayCycle)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DayCycleController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local cfg = Tuning.DayCycle
local GROUND_Y = MapLayout.streetY
local RESUME_AFTER_BLACKOUT = 3
local NIGHT_AMBIENT = Color3.fromRGB(70, 80, 120)
local DAY_AMBIENT = Color3.fromRGB(140, 140, 140)
local ICONS = { dawn = "🌅", day = "☀️", dusk = "🌆", night = "🌙" }

local folder: Folder
local bulbs: { BasePart } = {}
local lights: { PointLight } = {}
local icon: TextLabel
local lampsLit: boolean? = nil
local blackoutEnded = -math.huge

local function buildLamps()
	-- The plaza and the fountain square are open squares: no lamps there.
	local streets = {}
	for _, s in MapLayout.streets do
		if s.name ~= "Plaza" and s.name ~= "Fountain" then
			table.insert(streets, s)
		end
	end
	for _, spot in DayCycle.lampSpots(streets :: any, cfg.lampSpacing, 1.2) do
		local post = Instance.new("Part")
		post.Name = "LampPost"
		post.Anchored = true
		post.CanCollide = false
		post.CanQuery = false
		post.CanTouch = false
		post.CastShadow = false
		post.Size = Vector3.new(0.5, 9, 0.5)
		post.Color = Color3.fromHex("#2B2633")
		post.Material = Enum.Material.Metal
		post.CFrame = CFrame.new(spot.x, GROUND_Y + 4.5, spot.z)
		post.Parent = folder
		local bulb = Instance.new("Part")
		bulb.Name = "Bulb"
		bulb.Anchored = true
		bulb.CanCollide = false
		bulb.CanQuery = false
		bulb.CanTouch = false
		bulb.CastShadow = false
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.new(1.4, 1.4, 1.4)
		bulb.Color = Color3.fromHex("#FFE8A3")
		bulb.Material = Enum.Material.SmoothPlastic
		bulb.CFrame = CFrame.new(spot.x, GROUND_Y + 9.3, spot.z)
		bulb.Parent = folder
		local light = Instance.new("PointLight")
		light.Range = cfg.lampLightRange
		light.Brightness = 1.4
		light.Color = Color3.fromHex("#FFD9A0")
		light.Enabled = false
		light.Parent = bulb
		table.insert(bulbs, bulb)
		table.insert(lights, light)
	end
end

local function setLamps(on: boolean)
	-- Real lights cost on phones: only on high effect quality.
	local realLights = on and settings.particleScale(player:GetAttribute("EffectQuality")) >= 1
	for i, bulb in bulbs do
		bulb.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lights[i].Enabled = realLights and i % 2 == 0 -- every other lamp: half the cost
	end
	lampsLit = on
end

local function step()
	local state = ReplicatedStorage:FindFirstChild("CityState")
	local offset = state and state:GetAttribute("DayOffset")
	local f = DayCycle.fraction(
		Workspace:GetServerTimeNow(),
		if typeof(offset) == "number" then offset else 0,
		cfg :: any
	)
	local phase = DayCycle.phase(f, cfg :: any)
	icon.Text = ICONS[phase] or ""
	local on = DayCycle.lampsOn(f, cfg :: any)
	if on ~= lampsLit then
		setLamps(on)
	end
	if state and state:GetAttribute("Blackout") == true then
		blackoutEnded = os.clock()
		return -- the blackout owns Lighting
	end
	if os.clock() - blackoutEnded < RESUME_AFTER_BLACKOUT then
		return -- let the blackout's restore tween finish
	end
	local daylight = DayCycle.daylight(f, cfg :: any)
	Lighting.ClockTime = DayCycle.clockTime(f, cfg :: any)
	Lighting.Brightness = cfg.nightBrightness + (cfg.dayBrightness - cfg.nightBrightness) * daylight
	Lighting.OutdoorAmbient = NIGHT_AMBIENT:Lerp(DAY_AMBIENT, daylight)
end

function DayCycleController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalStreetLamps"
	folder.Parent = Workspace
	buildLamps()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DayCycle"
	gui.ResetOnSpawn = false
	icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(1, 0)
	icon.Position = UDim2.new(1, -250, 0, 14) -- left of the tips counter
	icon.Size = UDim2.fromOffset(32, 32)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.Font = Enum.Font.FredokaOne
	icon.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("EffectQuality"):Connect(function()
		if lampsLit ~= nil then
			setLamps(lampsLit)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			step()
		end
	end)
	step()
end

return DayCycleController
