--!strict
-- Wishing well UI (#162): the amount picker with the odds (shown before you
-- pay, AGENTS 4.7), the coin toss + splash, the result card, a buff timer and
-- the Golden Compass arrow (points to your nearest active golden pepperoni).
-- The server decides everything; this only sends the chosen tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Collectibles = require(ReplicatedStorage.Shared.Config.Collectibles)
local Config = require(ReplicatedStorage.Shared.Config.Wish)
local Net = require(ReplicatedStorage.Shared.Net)
local Wish = require(ReplicatedStorage.Shared.Util.Wish)

local WishController = {}

local player = Players.LocalPlayer
local CREAM = Color3.fromHex("#FFF3D6")
local PANEL = Color3.fromHex("#2B2633")
local CHEESE = Color3.fromHex("#F2C14E")

local gui: ScreenGui
local panel: Frame
local resultCard: TextLabel
local buffLabel: TextLabel
local compass: Part? = nil

local spotPositions: { [string]: Vector3 } = {}
for _, s in Collectibles.spots do
	spotPositions[s.id] = Vector3.new(s.x, s.y, s.z)
end

local function text(parent: Instance, size: number, value: string): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextColor3 = CREAM
	l.TextWrapped = true
	l.Text = value
	l.Parent = parent
	return l
end

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function buildPanel()
	panel = Instance.new("Frame")
	panel.Name = "WishPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 330)
	panel.BackgroundColor3 = PANEL
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 16)
	local title = text(panel, 26, "⛲ Wishing well")
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Position = UDim2.fromOffset(16, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(44, 44)
	close.Position = UDim2.new(1, -52, 0, 8)
	close.BackgroundColor3 = CHEESE
	close.Text = "×"
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 24
	close.Parent = panel
	corner(close, 10)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local oddsText = {}
	for _, o in Wish.odds(Config.outcomes :: any) do
		table.insert(oddsText, `{o.percent}% · {o.name}: {o.text}`)
	end
	local odds = text(panel, 14, table.concat(oddsText, "\n"))
	odds.Size = UDim2.new(1, -32, 0, 130)
	odds.Position = UDim2.fromOffset(16, 52)
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextYAlignment = Enum.TextYAlignment.Top
	odds.Name = "Odds"
	local note = text(panel, 13, "Once a day. Bigger tosses make buffs last longer.")
	note.Size = UDim2.new(1, -32, 0, 20)
	note.Position = UDim2.fromOffset(16, 186)
	note.TextColor3 = Color3.fromHex("#BDB4C7")
	note.Name = "Note"
	for i, tier in Config.tiers do
		local b = Instance.new("TextButton")
		b.Name = `Tier{i}`
		b.Size = UDim2.new(1 / 3, -16, 0, 64)
		b.Position = UDim2.new((i - 1) / 3, 12, 0, 220)
		b.BackgroundColor3 = CHEESE
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 18
		b.TextColor3 = Color3.fromHex("#3B2A20")
		b.Text = `🪙 {tier.amount}\n{tier.minutes} min`
		b.Parent = panel
		corner(b, 12)
		b.Activated:Connect(function()
			Net.event("MakeWish"):FireServer(i)
			panel.Visible = false
		end)
	end
end

local function buildResult()
	resultCard = text(gui, 22, "")
	resultCard.Name = "WishResult"
	resultCard.AnchorPoint = Vector2.new(0.5, 0)
	resultCard.Position = UDim2.new(0.5, 0, 0, 140)
	resultCard.Size = UDim2.fromOffset(380, 70)
	resultCard.BackgroundColor3 = PANEL
	resultCard.BackgroundTransparency = 0.05
	resultCard.Visible = false
	corner(resultCard, 14)
	buffLabel = text(gui, 14, "")
	buffLabel.Name = "WishBuff"
	buffLabel.AnchorPoint = Vector2.new(1, 0)
	buffLabel.Position = UDim2.new(1, -12, 0, 140)
	buffLabel.Size = UDim2.fromOffset(150, 20)
	buffLabel.TextXAlignment = Enum.TextXAlignment.Right
	buffLabel.TextStrokeTransparency = 0.4
	buffLabel.Visible = false
end

local function tossCoin()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local basin = Workspace:FindFirstChild("FountainBasin", true)
	if not root or not root:IsA("BasePart") or not basin or not basin:IsA("BasePart") then
		return
	end
	local coin = Instance.new("Part")
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.2, 1, 1)
	coin.Material = Enum.Material.Neon
	coin.Color = CHEESE
	coin.Parent = Workspace
	local from = root.Position + Vector3.new(0, 2, 0)
	local to = basin.Position + Vector3.new(0, 1, 0)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(t: number)
		local p = from:Lerp(to, t) + Vector3.new(0, math.sin(math.pi * t) * 8, 0)
		coin.CFrame = CFrame.new(p) * CFrame.Angles(t * 20, 0, 0)
	end)
	local tween =
		TweenService:Create(value, TweenInfo.new(0.8, Enum.EasingStyle.Linear), { Value = 1 })
	tween.Completed:Connect(function()
		coin:Destroy()
		value:Destroy()
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromHex("#9FE3FF")
		ring.Size = Vector3.new(0.2, 1, 1)
		ring.CFrame = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = Workspace
		local grow = TweenService:Create(
			ring,
			TweenInfo.new(0.7),
			{ Size = Vector3.new(0.2, 12, 12), Transparency = 1 }
		)
		grow.Completed:Connect(function()
			ring:Destroy()
		end)
		grow:Play()
	end)
	tween:Play()
end

local function nearestSpot(from: Vector3): Vector3?
	local raw = player:GetAttribute("GoldenActive")
	if typeof(raw) ~= "string" then
		return nil
	end
	local best: Vector3? = nil
	local bestD = math.huge
	for id in string.gmatch(raw, "[^,]+") do
		local p = spotPositions[id]
		if p and (p - from).Magnitude < bestD then
			best, bestD = p, (p - from).Magnitude
		end
	end
	return best
end

local function updateBuff()
	local id = player:GetAttribute("WishBuff")
	local untilAt = player:GetAttribute("WishBuffUntil")
	local left = if typeof(untilAt) == "number" then untilAt - Workspace:GetServerTimeNow() else 0
	local active = typeof(id) == "string" and left > 0
	buffLabel.Visible = active
	if active then
		buffLabel.Text =
			`⛲ {if id == "LuckyTips" then "Lucky Tips" else "Golden Compass"} · {math.ceil(
				left / 60
			)}m`
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = if active
			and id == "GoldenCompass"
			and root
			and root:IsA("BasePart")
		then nearestSpot(root.Position)
		else nil
	if target and root and root:IsA("BasePart") then
		local arrow = compass
		if not arrow then
			local p = Instance.new("Part")
			p.Name = "GoldenCompass"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = CHEESE
			p.Size = Vector3.new(0.6, 0.6, 3)
			p.Parent = Workspace
			compass = p
			arrow = p
		end
		local origin = root.Position + Vector3.new(0, 4.5, 0)
		local flat = Vector3.new(target.X, origin.Y, target.Z)
		if (flat - origin).Magnitude > 0.5 then
			(arrow :: Part).CFrame = CFrame.lookAt(origin, flat) * CFrame.new(0, 0, -1.5)
		end
	elseif compass then
		compass:Destroy()
		compass = nil
	end
end

function WishController.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "WishHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	buildPanel()
	buildResult()
	Net.event("WishOpen").OnClientEvent:Connect(function(alreadyWished: unknown)
		local note = panel:FindFirstChild("Note") :: TextLabel?
		if note then
			note.Text = if alreadyWished == true
				then "You already wished today. Come back tomorrow!"
				else "Once a day. Bigger tosses make buffs last longer."
		end
		panel.Visible = true
	end)
	Net.event("WishResult").OnClientEvent:Connect(function(result: unknown)
		if typeof(result) ~= "table" then
			return
		end
		local r = result :: any
		tossCoin()
		task.delay(0.9, function()
			resultCard.Text = `⛲ {tostring(r.name)}\n{tostring(r.detail)}`
			resultCard.Visible = true
			task.delay(4, function()
				resultCard.Visible = false
			end)
		end)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			updateBuff()
		end
	end)
end

return WishController
