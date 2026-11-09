--!strict
-- Golden pizza sparkles (#223): any courier whose "GoldenOrder" attribute is
-- set gets a sparkle emitter on their pizza box (fewer when scuffed, none on
-- low effect quality) and a small "✨ GOLDEN" tag. Visual only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local GoldenController = {}

local localPlayer = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local FX = "GoldenFx"

local function refresh(player: Player)
	local character = player.Character
	local box = character and character:FindFirstChild("PizzaBox")
	local state = player:GetAttribute("GoldenOrder")
	local existing = box and box:FindFirstChild(FX)
	if not box or typeof(state) ~= "string" then
		if existing then
			existing:Destroy()
		end
		return
	end
	local fx = existing
	if not fx then
		local folder = Instance.new("Folder")
		folder.Name = FX
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromHex("#FFE27A"))
		sparkle.LightEmission = 1
		sparkle.Lifetime = NumberRange.new(0.5, 0.9)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Parent = box
		sparkle:SetAttribute("GoldenFx", true)
		local tag = Instance.new("BillboardGui")
		tag.Name = "Tag"
		tag.Size = UDim2.fromOffset(110, 24)
		tag.StudsOffset = Vector3.new(0, 2, 0)
		tag.MaxDistance = 120
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("#FFC83D")
		text.TextStrokeTransparency = 0.3
		text.Parent = tag
		tag.Parent = folder
		folder.Parent = box
		fx = folder
	end
	local sparkle = box:FindFirstChild("Sparkle")
	local scale = settings.particleScale(localPlayer:GetAttribute("EffectQuality"))
	if sparkle and sparkle:IsA("ParticleEmitter") then
		sparkle.Rate = if state == "scuffed" then 4 * scale else 14 * scale
		sparkle.Enabled = scale > 0
	end
	local tag = (fx :: Instance):FindFirstChild("Tag")
	local text = tag and tag:FindFirstChildOfClass("TextLabel")
	if text then
		text.Text = if state == "scuffed" then "✨ golden-ish" else "✨ GOLDEN"
	end
	if tag and tag:IsA("BillboardGui") then
		tag.Adornee = box :: BasePart
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("GoldenOrder"):Connect(function()
		refresh(player)
		if player:GetAttribute("GoldenOrder") == nil then
			-- also drop the sparkle emitter that lives on the box itself
			local box = player.Character and player.Character:FindFirstChild("PizzaBox")
			local sparkle = box and box:FindFirstChild("Sparkle")
			if sparkle then
				sparkle:Destroy()
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		refresh(player)
	end)
	refresh(player)
end

function GoldenController.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- the box is (re)attached by the server after the attribute may already be set
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("GoldenOrder") ~= nil then
					refresh(player)
				end
			end
		end
	end)
end

return GoldenController
