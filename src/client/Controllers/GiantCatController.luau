--!strict
-- Giant Cat visuals (#184): a big blocky tabby sits on Fountain Square
-- (CityState "GiantCat"), its tail swishing and head tracking the nearest
-- courier. Each paw in "CatPaws" shows a growing shadow and a paw that rises
-- and slams down at the server time. When fed the cat curls up with floating
-- "z"s. A strip shows the shared feeding progress (the bowl itself is a
-- server part with the prompt). Visual only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local GiantCatController = {}

local player = Players.LocalPlayer
local cfg = Tuning.GiantCat
local GROUND_Y = MapLayout.streetY + 0.2
local FUR = "#E8913A"
local STRIPE = "#B5651D"

type PawFx = { x: number, z: number, t: number, r: number, shadow: BasePart, paw: BasePart }

local folder: Folder
local cat: Model? = nil
local head: BasePart? = nil
local tail: BasePart? = nil
local paws: { [number]: PawFx } = {}
local mood = "angry"
local strip: TextLabel

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: string,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function buildCat(): Model
	local m = Instance.new("Model")
	m.Name = "GiantCat"
	local base = CFrame.new(cfg.x, GROUND_Y, cfg.z + 8)
	part(m, Vector3.new(22, 16, 30), base * CFrame.new(0, 8, 4), FUR) -- body
	for i = -1, 1 do
		part(m, Vector3.new(22.2, 3, 3), base * CFrame.new(0, 12, 4 + i * 8), STRIPE)
	end
	local h = part(m, Vector3.new(16, 13, 13), base * CFrame.new(0, 20, -12), FUR) -- head
	for _, side in { -1, 1 } do
		part(
			m,
			Vector3.new(4, 5, 2),
			h.CFrame * CFrame.new(side * 5, 8, 0) * CFrame.Angles(0, 0, math.rad(side * -15)),
			FUR
		)
		part(m, Vector3.new(2.6, 2.6, 0.4), h.CFrame * CFrame.new(side * 3.5, 2, -6.6), "#7CFF8A") -- eyes
		part(m, Vector3.new(1, 2, 0.5), h.CFrame * CFrame.new(side * 3.5, 2, -6.8), "#111111") -- pupils
	end
	part(m, Vector3.new(2, 1.4, 0.4), h.CFrame * CFrame.new(0, -1, -6.6), "#FF9AA8") -- nose
	for _, side in { -1, 1 } do
		part(m, Vector3.new(6, 4, 7), base * CFrame.new(side * 8, 2, -12), FUR) -- front paws
	end
	local t = part(m, Vector3.new(3, 3, 18), base * CFrame.new(10, 4, 22), FUR)
	m.Parent = folder
	head, tail = h, t
	return m
end

local function clearCat()
	if cat then
		cat:Destroy()
		cat = nil
		head, tail = nil, nil
	end
end

local function parse(raw: unknown): { any }
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(d) == "table" then d else {}
end

local function syncPaws(raw: unknown)
	local seen: { [number]: boolean } = {}
	for _, p in parse(raw) do
		if typeof(p) == "table" and typeof(p.id) == "number" then
			seen[p.id] = true
			if not paws[p.id] then
				local shadow = part(
					folder,
					Vector3.new(0.1, 1, 1),
					CFrame.new(),
					"#000000",
					Enum.PartType.Cylinder
				)
				shadow.Transparency = 0.8
				local paw = part(
					folder,
					Vector3.new(p.r * 1.4, 4, p.r * 1.4),
					CFrame.new(p.x, GROUND_Y + 30, p.z),
					FUR
				)
				paws[p.id] = { x = p.x, z = p.z, t = p.t, r = p.r, shadow = shadow, paw = paw }
			end
		end
	end
	for id, fx in paws do
		if not seen[id] then
			fx.shadow:Destroy()
			local paw = fx.paw
			paw.Position = Vector3.new(fx.x, GROUND_Y + 2, fx.z) -- SLAM
			task.delay(0.35, function()
				paw:Destroy()
			end)
			paws[id] = nil
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, fx in paws do
		local k = math.clamp(1 - (fx.t - now) / cfg.swipeWarnSeconds, 0, 1)
		local d = fx.r * 2 * (0.5 + 0.5 * k)
		fx.shadow.Size = Vector3.new(0.1, d, d)
		fx.shadow.CFrame = CFrame.new(fx.x, GROUND_Y + 0.07, fx.z)
			* CFrame.Angles(0, 0, math.rad(90))
		fx.shadow.Transparency = 0.8 - 0.4 * k
		fx.paw.Position = Vector3.new(fx.x, GROUND_Y + 30 - 10 * k * k, fx.z)
	end
	local t, h = tail, head
	if t and cat then
		local swish = math.sin(now * (if mood == "fed" then 1 else 3))
			* (if mood == "fed" then 0.15 else 0.5)
		local base = CFrame.new(cfg.x, GROUND_Y, cfg.z + 8)
		t.CFrame = base * CFrame.new(10, 4, 22) * CFrame.Angles(0, swish, 0) * CFrame.new(0, 0, 6)
	end
	if h and cat and mood ~= "fed" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local base = CFrame.new(cfg.x, GROUND_Y, cfg.z + 8) * CFrame.new(0, 20, -12)
			local look = Vector3.new(root.Position.X, base.Position.Y, root.Position.Z)
			if (look - base.Position).Magnitude > 1 then
				h.CFrame = CFrame.lookAt(base.Position, look)
			end
		end
	end
end

local function buildStrip()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GiantCatHUD"
	gui.ResetOnSpawn = false
	strip = Instance.new("TextLabel")
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 134)
	strip.Size = UDim2.fromOffset(280, 30)
	strip.BackgroundColor3 = Color3.fromHex("#8A4B12")
	strip.BackgroundTransparency = 0.1
	strip.TextColor3 = Color3.fromHex("#FFF3D6")
	strip.Font = Enum.Font.FredokaOne
	strip.TextSize = 18
	strip.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = strip
	strip.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

function GiantCatController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalCat"
	folder.Parent = Workspace
	buildStrip()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local function refresh()
		local m = state:GetAttribute("GiantCat")
		if typeof(m) ~= "string" then
			clearCat()
			strip.Visible = false
			mood = "angry"
			return
		end
		mood = m
		if not cat then
			cat = buildCat()
		end
		local fed, goal = state:GetAttribute("CatFed"), state:GetAttribute("CatFeedGoal")
		strip.Visible = typeof(goal) == "number"
		strip.Text = if mood == "fed"
			then "🐈💤 Fed and purring!"
			else `🐈 Feed the cat (bowl / deliveries): {fed or 0}/{goal or "?"}`
	end
	for _, name in { "GiantCat", "CatFed", "CatFeedGoal" } do
		state:GetAttributeChangedSignal(name):Connect(refresh)
	end
	state:GetAttributeChangedSignal("CatPaws"):Connect(function()
		syncPaws(state:GetAttribute("CatPaws"))
	end)
	refresh()
	RunService.Heartbeat:Connect(step)
end

return GiantCatController
