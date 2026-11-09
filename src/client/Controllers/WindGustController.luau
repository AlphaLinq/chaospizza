--!strict
-- Gale Force (#230), client side. Reads CityState "Wind" (the next or
-- current gust, server time) and "WindGust" (event running):
--  * HUD: an arrow showing where the gust will push you on screen, the
--    direction it comes from and a countdown; "GUST!" while it blows.
--  * Physics: character physics belongs to this client, so it moves its own
--    courier — a short shove when the gust front hits (none when a wall
--    shelters you upwind, none while knocked down or seated), then a capped
--    push while it blows that mostly carries you in the air (Util/Wind).
--  * Streaks: thin white lines racing past the camera (fewer on low effect
--    quality or with Reduce Motion).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ComfortFlags = require(ReplicatedStorage.Shared.Util.ComfortFlags)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Wind = require(ReplicatedStorage.Shared.Util.Wind)

local WindGustController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local cfg = Tuning.WindGust :: any
local BG = Color3.fromHex("#2B2633")
local TEXT = Color3.fromHex("#FFF3D6")
local GUST = Color3.fromHex("#7FE7FF")
local RADIUS = 45
local STREAK_SPEED = 70

type Streak = { part: BasePart, offset: Vector3 }

local cityState: Instance
local gust: Wind.Gust? = nil
local gustKey = ""
local shoved = false
local panel: Frame
local arrow: TextLabel
local label: TextLabel
local folder: Folder? = nil
local streaks: { Streak } = {}

local function parse(raw: unknown): Wind.Gust?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(d) ~= "table" or typeof((d :: any).startsAt) ~= "number" then
		return nil
	end
	return d :: any
end

local function character(): (BasePart?, Humanoid?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function canPush(humanoid: Humanoid): boolean
	return player:GetAttribute("Knocked") ~= true
		and not humanoid.Sit
		and not humanoid.PlatformStand
end

-- A solid, building-sized part close upwind shelters you from the shove.
local function sheltered(root: BasePart, g: Wind.Gust): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { root.Parent :: Instance }
	if folder then
		table.insert(ignore, folder)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local upwind = Vector3.new(-g.x, 0, -g.z) * cfg.shelterStuds
	local hit = Workspace:Raycast(root.Position, upwind, params)
	if not hit then
		return false
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return false -- another courier is not a wall
	end
	local size = hit.Instance.Size
	return math.max(size.X, size.Z) >= 6 and size.Y >= 5
end

local function shove(root: BasePart, humanoid: Humanoid, g: Wind.Gust)
	if not canPush(humanoid) or sheltered(root, g) then
		return
	end
	local v = root.AssemblyLinearVelocity
	local along = v.X * g.x + v.Z * g.z
	local add = math.max(0, cfg.shoveSpeed - along)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	root.AssemblyLinearVelocity = v
		+ Vector3.new(g.x * add, if grounded then cfg.shoveLift else 0, g.z * add)
end

local function push(root: BasePart, humanoid: Humanoid, g: Wind.Gust, dt: number)
	if not canPush(humanoid) then
		return
	end
	local v = root.AssemblyLinearVelocity
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local ax, az = Wind.push(g, v.X, v.Z, grounded, dt, cfg)
	if ax ~= 0 or az ~= 0 then
		root.AssemblyLinearVelocity = v + Vector3.new(ax, 0, az)
	end
end

local function clearStreaks()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(streaks)
end

local function buildStreaks()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "LocalWind"
	root.Parent = Workspace
	folder = root
	local scale = settings.particleScale(player:GetAttribute("EffectQuality"))
	local count = math.floor(cfg.lowQualityStreaks + (cfg.streaks - cfg.lowQualityStreaks) * scale)
	if ComfortFlags.reduced(player:GetAttribute("ReduceMotion")) then
		count = math.min(count, cfg.lowQualityStreaks)
	end
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Name = "Streak"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(245, 250, 255)
		p.Size = Vector3.new(0.08, 0.08, 3 + math.random() * 4)
		p.Transparency = 1
		p.Parent = root
		table.insert(streaks, {
			part = p,
			offset = Vector3.new(
				(math.random() - 0.5) * RADIUS * 2,
				(math.random() - 0.3) * 18,
				(math.random() - 0.5) * RADIUS * 2
			),
		})
	end
end

local function moveStreaks(g: Wind.Gust?, phase: Wind.Phase, dt: number)
	local camera = Workspace.CurrentCamera
	if not camera or not g then
		for _, s in streaks do
			s.part.Transparency = 1
		end
		return
	end
	local dir = Vector3.new(g.x, 0, g.z)
	local speed = if phase == "blowing" then STREAK_SPEED else STREAK_SPEED * 0.35
	local transparency = if phase == "blowing" then 0.35 elseif phase == "telegraph" then 0.75 else 1
	local centre = camera.CFrame.Position
	for _, s in streaks do
		local o = s.offset + dir * speed * dt
		-- wrap the streak back upwind once it leaves the circle
		if Vector3.new(o.X, 0, o.Z).Magnitude > RADIUS then
			o = Vector3.new(-o.X, o.Y, -o.Z) * 0.98
		end
		s.offset = o
		local at = centre + o
		s.part.CFrame = CFrame.lookAt(at, at + dir)
		s.part.Transparency = transparency
	end
end

local function updateHud(g: Wind.Gust?, phase: Wind.Phase, now: number)
	panel.Visible = g ~= nil and phase ~= "calm"
	if not g or phase == "calm" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		arrow.Rotation = Wind.arrowRotation(g, look.X, look.Z)
	end
	if phase == "telegraph" then
		label.Text = `💨 Gust from the {g.name} in {math.max(1, math.ceil(g.startsAt - now))}…`
		label.TextColor3 = TEXT
		arrow.TextColor3 = TEXT
	else
		label.Text = "💨 GUST!"
		label.TextColor3 = GUST
		arrow.TextColor3 = GUST
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WindGust"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	panel = Instance.new("Frame")
	panel.Name = "Gust"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 158) -- below the event banner
	panel.Size = UDim2.fromOffset(260, 96)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Position = UDim2.fromScale(0.5, 0)
	arrow.Size = UDim2.fromOffset(56, 56)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "⬆"
	arrow.TextScaled = true
	arrow.TextStrokeTransparency = 0.2
	arrow.TextColor3 = TEXT
	arrow.Parent = panel
	label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundColor3 = BG
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 19
	label.TextColor3 = TEXT
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = panel
	panel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function step(dt: number)
	local g = gust
	local now = Workspace:GetServerTimeNow()
	local phase = Wind.phase(g, now)
	updateHud(g, phase, now)
	moveStreaks(g, phase, dt)
	if not g or phase ~= "blowing" then
		return
	end
	local root, humanoid = character()
	if not root or not humanoid then
		return
	end
	if not shoved then
		shoved = true
		shove(root, humanoid, g)
	end
	push(root, humanoid, g, dt)
end

function WindGustController.start()
	cityState = ReplicatedStorage:WaitForChild("CityState")
	build()
	local connection: RBXScriptConnection? = nil
	local function sync()
		local g = parse(cityState:GetAttribute("Wind"))
		local key = if g then `{g.name}@{g.startsAt}` else ""
		if key ~= gustKey then
			gustKey = key
			shoved = false
		end
		gust = g
	end
	local function refresh()
		if cityState:GetAttribute("WindGust") == true then
			buildStreaks()
			if not connection then
				connection = RunService.Heartbeat:Connect(step)
			end
		else
			if connection then
				connection:Disconnect()
				connection = nil
			end
			clearStreaks()
			panel.Visible = false
		end
	end
	cityState:GetAttributeChangedSignal("Wind"):Connect(sync)
	cityState:GetAttributeChangedSignal("WindGust"):Connect(refresh)
	sync()
	refresh()
end

return WindGustController
