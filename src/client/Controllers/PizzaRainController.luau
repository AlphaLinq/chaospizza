--!strict
-- Pizza Rain visuals (#182): every drop in CityState "PizzaRain" gets a
-- shadow that darkens and grows as the pizza falls, and a spinning pizza that
-- lands exactly at the server time. A top strip counts the shared catches.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local PizzaRainController = {}

local player = Players.LocalPlayer
local GROUND_Y = MapLayout.streetY + 0.2
local cfg = Tuning.PizzaRain
local HEIGHT = 70

type Live = { x: number, z: number, t: number, shadow: BasePart, pizza: Model }

local folder: Folder
local live: { [number]: Live } = {}
local strip: TextLabel

local function part(model: Instance, shape: Enum.PartType, size: Vector3, color: string): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

local function makePizza(): Model
	local m = Instance.new("Model")
	m.Name = "FallingPizza"
	local crust = part(m, Enum.PartType.Cylinder, Vector3.new(0.4, 3.2, 3.2), "#E3A857")
	part(m, Enum.PartType.Cylinder, Vector3.new(0.45, 2.7, 2.7), "#F7C948")
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local dot = part(m, Enum.PartType.Cylinder, Vector3.new(0.5, 0.6, 0.6), "#C8342B")
		dot.CFrame = CFrame.new(0, math.cos(a) * 0.8, math.sin(a) * 0.8)
	end
	m.PrimaryPart = crust
	m.Parent = folder
	return m
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

local function sync(raw: unknown)
	local seen: { [number]: boolean } = {}
	for _, d in parse(raw) do
		if typeof(d) == "table" and typeof(d.id) == "number" then
			seen[d.id] = true
			if not live[d.id] then
				local shadow =
					part(folder, Enum.PartType.Cylinder, Vector3.new(0.1, 1, 1), "#000000")
				shadow.Transparency = 0.8
				live[d.id] = { x = d.x, z = d.z, t = d.t, shadow = shadow, pizza = makePizza() }
			end
		end
	end
	for id, l in live do
		if not seen[id] then
			l.shadow:Destroy()
			l.pizza:Destroy()
			live[id] = nil
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, l in live do
		local k = math.clamp(1 - (l.t - now) / cfg.fallSeconds, 0, 1)
		local d = cfg.catchRadius * 2 * (0.4 + 0.6 * k)
		l.shadow.Size = Vector3.new(0.1, d, d)
		l.shadow.CFrame = CFrame.new(l.x, GROUND_Y + 0.07, l.z) * CFrame.Angles(0, 0, math.rad(90))
		l.shadow.Transparency = 0.85 - 0.45 * k
		local y = GROUND_Y + 1.5 + HEIGHT * (1 - k) ^ 1.6
		l.pizza:PivotTo(CFrame.new(l.x, y, l.z) * CFrame.Angles(0, now * 6, math.rad(90)))
	end
end

local function buildStrip()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PizzaRainHUD"
	gui.ResetOnSpawn = false
	strip = Instance.new("TextLabel")
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 134)
	strip.Size = UDim2.fromOffset(260, 30)
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

function PizzaRainController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalPizzaRain"
	folder.Parent = Workspace
	buildStrip()
	local state = ReplicatedStorage:WaitForChild("CityState", 30)
	if not state then
		return
	end
	local function refreshCount()
		local n, goal = state:GetAttribute("PizzaRainCount"), state:GetAttribute("PizzaRainGoal")
		strip.Visible = typeof(n) == "number" and typeof(goal) == "number"
		if strip.Visible then
			strip.Text = if n :: number >= goal :: number
				then `🍕🎉 City goal reached! {n} caught`
				else `🍕 Caught together: {n}/{goal}`
		end
	end
	state:GetAttributeChangedSignal("PizzaRain"):Connect(function()
		sync(state:GetAttribute("PizzaRain"))
	end)
	state:GetAttributeChangedSignal("PizzaRainCount"):Connect(refreshCount)
	state:GetAttributeChangedSignal("PizzaRainGoal"):Connect(refreshCount)
	sync(state:GetAttribute("PizzaRain"))
	refreshCount()
	RunService.Heartbeat:Connect(step)
end

return PizzaRainController
