--!strict
-- Golden pepperoni visuals (#132): draws only YOUR active spots (player
-- attribute "GoldenActive") as spinning, bobbing golden pepperoni coins with a
-- soft glow. Pickup is decided by the server (CollectiblesService); a coin
-- disappears when the server drops it from the list. Visual only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Collectibles)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local GoldenPepperoniController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)

local GOLD = Color3.fromHex("#FFC83D")
local PEPPERONI = Color3.fromHex("#C8342B")
local SPIN = 1.6 -- rad/s
local BOB = 0.5

type Coin = { model: Model, base: CFrame, phase: number }

local positions: { [string]: Vector3 } = {}
for _, spot in Config.spots do
	positions[spot.id] = Vector3.new(spot.x, spot.y, spot.z)
end

local folder: Folder
local coins: { [string]: Coin } = {}

local function part(model: Model, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = model
	return p
end

local function makeCoin(id: string, at: Vector3): Coin
	local model = Instance.new("Model")
	model.Name = `Golden_{id}`
	-- Cylinder axis = local X; stand the coin up facing sideways.
	local base = CFrame.new(at)
	local disc = part(model, Vector3.new(0.4, 3, 3), GOLD, Enum.Material.Neon)
	disc.CFrame = base
	local dots = { Vector3.new(0, 0.6, 0.5), Vector3.new(0, -0.5, 0.6), Vector3.new(0, 0.1, -0.7) }
	for _, offset in dots do
		for side = -1, 1, 2 do
			local dot =
				part(model, Vector3.new(0.1, 0.7, 0.7), PEPPERONI, Enum.Material.SmoothPlastic)
			dot.CFrame = base * CFrame.new(side * 0.22, offset.Y, offset.Z)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = disc
	if settings.particleScale(player:GetAttribute("EffectQuality")) >= 0.75 then
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = GOLD
		sparkle.Parent = disc
	end
	model.PrimaryPart = disc
	model.Parent = folder
	return { model = model, base = base, phase = math.random() * math.pi * 2 }
end

local function sync()
	local raw = player:GetAttribute("GoldenActive")
	local wanted: { [string]: boolean } = {}
	if typeof(raw) == "string" then
		for id in string.gmatch(raw, "[^,]+") do
			if positions[id] then
				wanted[id] = true
			end
		end
	end
	for id, coin in coins do
		if not wanted[id] then
			coin.model:Destroy()
			coins[id] = nil
		end
	end
	for id in wanted do
		if not coins[id] then
			coins[id] = makeCoin(id, positions[id])
		end
	end
end

function GoldenPepperoniController.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalGoldenPepperoni"
	folder.Parent = Workspace
	player:GetAttributeChangedSignal("GoldenActive"):Connect(sync)
	sync()
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		for _, coin in coins do
			local bob = math.sin(t * 2 + coin.phase) * BOB
			coin.model:PivotTo(
				coin.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * SPIN + coin.phase, 0)
			)
		end
	end)
end

return GoldenPepperoniController
