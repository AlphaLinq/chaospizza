--!strict
-- Pizzeria tip jar (brief ch. 10): passive tips from regulars collect in a jar
-- on the pizzeria counter; the owner walks over and taps it to collect. The
-- jar has a capacity (minutes of income), which gently brings players back to
-- the plaza. The AutoCollect gamepass credits passive tips directly.
-- Server-authoritative: amounts live only here; the client just triggers the prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)

local JAR_HEIGHT = 2.2
local T = Tuning.Regulars

type Jar = { amount: number, capacity: number, fill: BasePart?, label: TextLabel? }

local TipJarService = {}

local jars: { [Player]: Jar } = {}

local function jarFor(player: Player): Jar
	local jar = jars[player]
	if not jar then
		jar = { amount = 0, capacity = T.jarMinCapacity, fill = nil, label = nil }
		jars[player] = jar
	end
	return jar
end

local function autoCollect(player: Player): boolean
	local ok, owns = pcall(MonetizationService.hasPass, player, "AutoCollect")
	return ok and owns == true
end

local function render(player: Player)
	local jar = jars[player]
	if not jar then
		return
	end
	player:SetAttribute("TipJar", jar.amount)
	player:SetAttribute("TipJarCapacity", jar.capacity)
	local ratio = if jar.capacity > 0 then math.clamp(jar.amount / jar.capacity, 0, 1) else 0
	local fill = jar.fill
	if fill and fill.Parent then
		local base = fill:GetAttribute("BaseY") :: number
		local height = math.max(0.05, JAR_HEIGHT * ratio)
		TweenService:Create(fill, TweenInfo.new(0.4), {
			Size = Vector3.new(fill.Size.X, height, fill.Size.Z),
			CFrame = CFrame.new(fill.Position.X, base + height / 2, fill.Position.Z),
		}):Play()
	end
	local label = jar.label
	if label and label.Parent then
		label.Text = if autoCollect(player)
			then "🫙 Auto-collect"
			elseif ratio >= 1 then `🫙 FULL! {jar.amount} 💰`
			else `🫙 {jar.amount}/{jar.capacity} 💰`
	end
end

-- Builds the jar on the pizzeria counter (called on every pizzeria rebuild).
function TipJarService.attach(player: Player, counter: BasePart)
	local jar = jarFor(player)
	local top = counter.CFrame * CFrame.new(1.8, counter.Size.Y / 2, 0)
	local glass = Instance.new("Part")
	glass.Name = "TipJar"
	glass.Shape = Enum.PartType.Cylinder
	glass.Anchored = true
	glass.CanCollide = false
	glass.CanTouch = false
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.55
	glass.Color = Color3.fromHex("#CFEFFF")
	glass.Size = Vector3.new(JAR_HEIGHT + 0.2, 1.6, 1.6)
	glass.CFrame = CFrame.new(top.Position + Vector3.new(0, (JAR_HEIGHT + 0.2) / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	glass.Parent = counter.Parent

	local fill = Instance.new("Part")
	fill.Name = "TipJarFill"
	fill.Anchored = true
	fill.CanCollide = false
	fill.CanQuery = false
	fill.CanTouch = false
	fill.Material = Enum.Material.Neon
	fill.Color = Color3.fromHex("#FFD24A")
	fill.Size = Vector3.new(1.2, 0.05, 1.2)
	fill:SetAttribute("BaseY", top.Position.Y + 0.1)
	fill.CFrame = CFrame.new(top.Position + Vector3.new(0, 0.12, 0))
	fill.Parent = counter.Parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 34)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex("#FFD24A")
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard
	billboard.Parent = glass

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect tips"
	prompt.ObjectText = "Tip jar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.Parent = glass
	prompt.Triggered:Connect(function(who)
		if who ~= player then
			Net.event("Hint"):FireClient(who, `That's {player.DisplayName}'s tip jar!`)
			return
		end
		TipJarService.collect(player)
	end)

	jar.fill = fill
	jar.label = label
	render(player)
end

-- Passive income from PizzeriaService (already whole tips).
function TipJarService.add(player: Player, amount: number, perMinute: number)
	if amount <= 0 then
		return
	end
	if autoCollect(player) then
		EconomyService.addTips(player, amount, "passive")
		return
	end
	local jar = jarFor(player)
	jar.capacity = math.max(T.jarMinCapacity, math.floor(perMinute * T.jarCapacityMinutes))
	jar.amount = math.min(jar.capacity, jar.amount + amount)
	render(player)
end

function TipJarService.collect(player: Player): number
	local jar = jars[player]
	if not jar or jar.amount <= 0 then
		Net.event("Hint"):FireClient(player, "The tip jar is empty — seat more regulars!")
		return 0
	end
	local amount = jar.amount
	-- Clear first, so a double tap can never pay twice.
	jar.amount = 0
	if not EconomyService.addTips(player, amount, "passive") then
		jar.amount = amount
		render(player)
		return 0
	end
	render(player)
	Net.event("Hint"):FireClient(player, `🫙 +{amount} 💰 from your regulars!`)
	return amount
end

function TipJarService.getAmount(player: Player): number
	local jar = jars[player]
	return if jar then jar.amount else 0
end

function TipJarService.init()
	DebugService.register(
		"jar",
		"Tip jar: show / fill / collect",
		"jar [fill|collect]",
		function(player, args)
			local jar = jarFor(player)
			if args[1] == "fill" then
				jar.amount = jar.capacity
				render(player)
			elseif args[1] == "collect" then
				return true, `collected {TipJarService.collect(player)}`
			end
			return true, `jar={jar.amount}/{jar.capacity} auto={autoCollect(player)}`
		end
	)
end

function TipJarService.start()
	Players.PlayerRemoving:Connect(function(player)
		-- Best effort: credit what is left before the profile is released.
		-- (At most one jar of passive tips is at stake; offline earnings continue.)
		local jar = jars[player]
		jars[player] = nil
		if jar and jar.amount > 0 then
			EconomyService.addTips(player, jar.amount, "passive")
		end
	end)
end

return TipJarService
