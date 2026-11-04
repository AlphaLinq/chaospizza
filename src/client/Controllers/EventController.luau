--!strict
-- Shows the shared city event state (ReplicatedStorage.CityState): announcer
-- banner, phase countdown, a warning ping and sky tint. Visual only.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.Events)

local EventController = {}

local player = Players.LocalPlayer

local EVENT_TINT: { [string]: Color3 } = {
	HorseRace = Color3.fromRGB(255, 236, 200),
	Tornado = Color3.fromRGB(170, 180, 200),
	Flood = Color3.fromRGB(180, 210, 255),
	Blizzard = Color3.fromRGB(225, 235, 255),
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

	gui.Parent = player:WaitForChild("PlayerGui")

	ping = Instance.new("Sound")
	ping.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	ping.Volume = 0.6
	ping.Parent = SoundService

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "EventTint"
	tint.Parent = Lighting
end

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
		title.Text = `{displayName[id] or id} — {phaseText(phase)}`
		subtitle.Text = if typeof(announcement) == "string" then announcement else ""
		local target = EVENT_TINT[id] or Color3.new(1, 1, 1)
		TweenService:Create(tint, TweenInfo.new(1.5), { TintColor = target }):Play()
	else
		banner.Visible = false
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
			end
			lastPhase = phase
		end
		if name == "EventPhase" or name == "EventId" or name == "Announcement" then
			refresh(state)
		end
	end)
	refresh(state)

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
