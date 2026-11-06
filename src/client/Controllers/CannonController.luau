--!strict
-- Pizza cannon visuals (#147): a smoke-and-confetti puff at the muzzle when a
-- cannon fires (model attribute "FiredAt", tag "PizzaCannon") and a short FOV
-- punch for the courier who was launched. Visual only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local CannonController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local PUFF_COLORS = { "#FFFFFF", "#E8E2D6", "#F2C14E", "#D6452F" }

local function puff(model: Model)
	local barrel = model:FindFirstChild("Barrel")
	if not barrel or not barrel:IsA("BasePart") then
		return
	end
	local scale = settings.particleScale(player:GetAttribute("EffectQuality"))
	local count = math.clamp(math.floor(4 + 10 * scale), 3, 14)
	-- muzzle = barrel end along its axis (local X)
	local tip = barrel.CFrame * CFrame.new(barrel.Size.X / 2, 0, 0)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromHex(PUFF_COLORS[math.random(1, #PUFF_COLORS)])
		p.Size = Vector3.new(1.2, 1.2, 1.2)
		p.CFrame = tip
		p.Transparency = 0.2
		p.Parent = Workspace
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
			* 6
		local goal = tip * CFrame.new(4 + math.random() * 4, 0, 0)
		TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(goal.Position + spread),
			Size = Vector3.new(3, 3, 3),
			Transparency = 1,
		}):Play()
		task.delay(1, function()
			p:Destroy()
		end)
	end
end

local function watch(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst
	model:GetAttributeChangedSignal("FiredAt"):Connect(function()
		puff(model)
	end)
end

local function punch()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	camera.FieldOfView = base + 18
	TweenService:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { FieldOfView = base })
		:Play()
end

function CannonController.start()
	for _, inst in CollectionService:GetTagged("PizzaCannon") do
		watch(inst)
	end
	CollectionService:GetInstanceAddedSignal("PizzaCannon"):Connect(watch)
	Net.event("Knockback").OnClientEvent:Connect(function(_impulse, _duration, source)
		if source == "Cannon" then
			punch()
		end
	end)
end

return CannonController
