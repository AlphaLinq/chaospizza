--!strict
-- Shows the shared city event state (ReplicatedStorage.CityState): announcer
-- banner, phase countdown, a warning ping and sky tint. Visual only.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local Net = require(ReplicatedStorage.Shared.Net)

local EventController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local SNOW_RATE = 220

-- Particle multiplier from the player's EffectQuality (Codex: SettingsController).
-- Before the profile loads, fall back to the device default.
local function particleScale(): number
	local quality = player:GetAttribute("EffectQuality")
	if not settings.isQuality(quality) then
		local camera = Workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 0
		quality = settings.default(UserInputService.TouchEnabled, width)
	end
	return settings.particleScale(quality)
end

-- Event props are built by the server; emitter rates are scaled locally
-- (a client-side property change only affects this device).
local baseRates: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
local function scaleEmitter(emitter: ParticleEmitter)
	if baseRates[emitter] == nil then
		baseRates[emitter] = emitter.Rate
	end
	emitter.Rate = baseRates[emitter] * particleScale()
end
local function watchEventFolder(folder: Instance)
	if not folder.Name:match("^Event_") then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			scaleEmitter(d)
		end
	end
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("ParticleEmitter") then
			task.defer(scaleEmitter, d)
		end
	end)
end

local EVENT_TINT: { [string]: Color3 } = {
	HorseRace = Color3.fromRGB(255, 236, 200),
	Tornado = Color3.fromRGB(170, 180, 200),
	Flood = Color3.fromRGB(180, 210, 255),
	Blizzard = Color3.fromRGB(225, 235, 255),
	Blackout = Color3.fromRGB(190, 200, 255),
	UfoAbduction = Color3.fromRGB(200, 255, 200),
	PizzaRain = Color3.fromRGB(255, 235, 190),
	MeteorShower = Color3.fromRGB(255, 200, 170),
	LowGravity = Color3.fromRGB(205, 190, 255),
}

local displayName: { [string]: string } = {}
for _, def in Events do
	displayName[def.id] = def.displayName
end

local banner: Frame
local title: TextLabel
local subtitle: TextLabel
local countdown: TextLabel
local ping: Sound
local tint: ColorCorrectionEffect
local thanks: TextButton
local thankedFor: any = nil -- the ordered event (buyer id + phase end) already thanked

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CityEvent"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 72)
	banner.Size = UDim2.new(0.9, 0, 0, 64)
	banner.BackgroundColor3 = Color3.fromHex("#1F1B24")
	banner.BackgroundTransparency = 0.15
	banner.Visible = false
	banner.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = banner
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(620, 64)
	constraint.Parent = banner

	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -90, 0, 30)
	title.Position = UDim2.fromOffset(12, 4)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromHex("#FFD24A")
	title.Parent = banner

	subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -90, 0, 26)
	subtitle.Position = UDim2.fromOffset(12, 34)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 14
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromHex("#FFF3D6")
	subtitle.Parent = banner

	countdown = Instance.new("TextLabel")
	countdown.BackgroundTransparency = 1
	countdown.AnchorPoint = Vector2.new(1, 0.5)
	countdown.Position = UDim2.new(1, -12, 0.5, 0)
	countdown.Size = UDim2.fromOffset(70, 40)
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextSize = 30
	countdown.TextColor3 = Color3.new(1, 1, 1)
	countdown.Parent = banner

	-- "Thanks, Dani!" for the player who ordered the disaster (brief ch. 16)
	thanks = Instance.new("TextButton")
	thanks.Name = "Thanks"
	thanks.AnchorPoint = Vector2.new(0.5, 0)
	thanks.Position = UDim2.new(0.5, 0, 1, 8)
	thanks.Size = UDim2.fromOffset(220, 44)
	thanks.BackgroundColor3 = Color3.fromHex("#FF5C8A")
	thanks.Font = Enum.Font.FredokaOne
	thanks.TextSize = 20
	thanks.TextColor3 = Color3.new(1, 1, 1)
	thanks.Visible = false
	thanks.Parent = banner
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 12)
	tc.Parent = thanks

	gui.Parent = player:WaitForChild("PlayerGui")

	ping = Instance.new("Sound")
	ping.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	ping.Volume = 0.6
	ping.Parent = SoundService

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "EventTint"
	tint.Parent = Lighting
end

-- Hot magenta wash for MEGA CHAOS (brief ch. 15: unique light effect).
local MEGA_TINT = Color3.fromHex("#FFB3E6")

local function phaseText(phase: string): string
	if phase == "warning" then
		return "INCOMING!"
	elseif phase == "buildUp" or phase == "active" then
		return "NOW!"
	elseif phase == "windDown" then
		return "Calming down…"
	end
	return ""
end

local function refresh(state: Configuration)
	local id = state:GetAttribute("EventId")
	local phase = state:GetAttribute("EventPhase")
	local announcement = state:GetAttribute("Announcement")
	if
		typeof(id) == "string"
		and typeof(phase) == "string"
		and phase ~= "calm"
		and phase ~= "reset"
	then
		banner.Visible = true
		local combo = state:GetAttribute("ComboId")
		local name = displayName[id] or id
		if typeof(combo) == "string" then
			name ..= ` + {displayName[combo] or combo}`
		end
		local mega = state:GetAttribute("Mega") == true
		title.Text = if mega
			then `💥 MEGA CHAOS: {name} — {phaseText(phase)}`
			else `{name} — {phaseText(phase)}`
		subtitle.Text = if typeof(announcement) == "string" then announcement else ""
		local buyer = state:GetAttribute("OrderedBy")
		local buyerId = state:GetAttribute("OrderedById")
		thanks.Visible = typeof(buyer) == "string"
			and buyerId ~= player.UserId
			and thankedFor ~= buyerId
			and phase ~= "windDown"
		if thanks.Visible then
			thanks.Text = `❤️ Thanks, {buyer}!`
		end
		local target = if mega then MEGA_TINT else EVENT_TINT[id] or Color3.new(1, 1, 1)
		TweenService:Create(tint, TweenInfo.new(1.5), { TintColor = target }):Play()
	else
		banner.Visible = false
		thankedFor = nil
		TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1) }):Play()
	end
end

function EventController.start()
	build()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state or not state:IsA("Configuration") then
		warn("[EventController] CityState missing")
		return
	end
	local lastPhase: any = nil
	state.AttributeChanged:Connect(function(name)
		if name == "EventPhase" then
			local phase = state:GetAttribute("EventPhase")
			if phase == "warning" and lastPhase ~= "warning" then
				ping:Play()
				-- Visual twin of the warning ping (AGENTS 4.8): the banner flashes.
				local mega = state:GetAttribute("Mega") == true
				banner.BackgroundColor3 = if mega
					then Color3.fromHex("#FF3FA4")
					else Color3.fromHex("#D6452F")
				TweenService:Create(banner, TweenInfo.new(1.2), {
					BackgroundColor3 = Color3.fromHex("#1F1B24"),
				}):Play()
			end
			lastPhase = phase
		end
		if
			name == "EventPhase"
			or name == "EventId"
			or name == "ComboId"
			or name == "Mega"
			or name == "Announcement"
			or name == "OrderedBy"
		then
			refresh(state)
		end
	end)
	refresh(state)
	thanks.Activated:Connect(function()
		thankedFor = state:GetAttribute("OrderedById")
		thanks.Visible = false
		Net.event("ThankBuyer"):FireServer()
	end)

	-- Tornado outer-zone pull (client owns its character physics; the server
	-- decides the dangerous inner-zone launch).
	local INNER = 9
	RunService.Heartbeat:Connect(function(dt)
		local pos = state:GetAttribute("TornadoPos")
		local radius = state:GetAttribute("TornadoRadius")
		if
			typeof(pos) ~= "Vector3"
			or typeof(radius) ~= "number"
			or player:GetAttribute("Knocked")
		then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local offset = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		local distance = offset.Magnitude
		if distance < INNER or distance > radius then
			return
		end
		local inward = offset.Unit
		local swirl = Vector3.new(-inward.Z, 0, inward.X)
		local strength = 1 - (distance - INNER) / (radius - INNER) -- 1 near the funnel
		root.AssemblyLinearVelocity += (inward * 40 + swirl * 25) * strength * dt
	end)

	-- Snowfall around the camera during the Blizzard (visual only)
	local snowPart = Instance.new("Part")
	snowPart.Name = "LocalSnow"
	snowPart.Anchored = true
	snowPart.CanCollide = false
	snowPart.CanQuery = false
	snowPart.CanTouch = false
	snowPart.Transparency = 1
	snowPart.Size = Vector3.new(80, 1, 80)
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.35)
	snow.Lifetime = NumberRange.new(4, 6)
	snow.Rate = 0
	snow.Speed = NumberRange.new(6, 10)
	snow.SpreadAngle = Vector2.new(20, 20)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Parent = snowPart
	snowPart.Parent = Workspace
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		local snowing = (
			state:GetAttribute("EventId") == "Blizzard"
			or state:GetAttribute("ComboId") == "Blizzard"
		)
			and (
				state:GetAttribute("EventPhase") == "active"
				or state:GetAttribute("EventPhase") == "buildUp"
			)
		snow.Rate = if snowing then SNOW_RATE * particleScale() else 0
		if camera and snowing then
			snowPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 25, 0))
		end
	end)

	-- Scale server-built event particles to the chosen quality.
	for _, child in Workspace:GetChildren() do
		watchEventFolder(child)
	end
	Workspace.ChildAdded:Connect(watchEventFolder)
	player:GetAttributeChangedSignal("EffectQuality"):Connect(function()
		for emitter in baseRates do
			if emitter.Parent then
				emitter.Rate = baseRates[emitter] * particleScale()
			end
		end
	end)

	-- Countdown ticker
	task.spawn(function()
		while true do
			if banner.Visible then
				local endsAt = state:GetAttribute("PhaseEndsAt")
				if typeof(endsAt) == "number" then
					local left = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
					countdown.Text = tostring(left)
				end
			end
			task.wait(0.25)
		end
	end)
end

return EventController
