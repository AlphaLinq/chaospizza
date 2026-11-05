--!strict
-- The player's own pizzeria on the shared plaza (brief ch. 10–11):
--   * a plot per player for this server session (12 plots)
--   * 6 levels, upgraded with tips at the plot (server-validated, atomic spend)
--   * regulars: rare+ customers seated at the pizzeria produce passive tips
--   * offline earnings on return (Progression.offlineEarnings)
-- Passive tips are credited straight to the saved profile every tick, so
-- nothing is lost when a player leaves. The plot shows the income rate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Pizzeria = require(ReplicatedStorage.Shared.Config.Pizzeria)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)

local AnalyticsService = require(script.Parent.AnalyticsService)
local CustomerService = require(script.Parent.CustomerService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local OrderService = require(script.Parent.OrderService)
local TipJarService = require(script.Parent.TipJarService)

local TICK_SECONDS = 15 -- also limits analytics economy events
local MAX_LEVEL = #Pizzeria

local PizzeriaService = {}

local plotOwner: { [number]: Player } = {}
local playerPlot: { [Player]: number } = {}
local models: { [Player]: Model } = {}
local fraction: { [Player]: number } = {}

local rarityOf: { [string]: string } = {}
local nameOf: { [string]: string } = {}
local passiveOf: { [string]: number } = {}
local rarityColor: { [string]: Color3 } = {}

local progression = EconomyService.getProgression()

local function levelDef(level: number)
	return Pizzeria[math.clamp(level, 1, MAX_LEVEL)]
end

local function hasPass(player: Player, key: string): boolean
	local ok, owns = pcall(MonetizationService.ownsPass, player, key)
	return ok and owns == true
end

local function slotsFor(player: Player, level: number): number
	return progression.regularSlots(level, hasPass(player, "ExtraRegularSlots"))
end

-- Tips per minute from all seated regulars (before pass multipliers).
function PizzeriaService.incomePerMinute(player: Player): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, id in profile.regulars do
		local entry = profile.customerBook[id]
		total += progression.passivePerMinute(
			rarityOf[id] or "Common",
			if entry then entry.stars else 0
		)
	end
	if hasPass(player, "DoubleTips") then
		total *= 2
	end
	return total
end

-- Model building ------------------------------------------------------------

local function block(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: string,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function plotCFrame(index: number): CFrame
	local p = MapLayout.plots[index]
	local base = Vector3.new(p.x, MapLayout.streetY + 0.2, p.z)
	-- Face the plaza centre
	return CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
end

local function buildBody(model: Model, level: number, origin: CFrame)
	-- Back of the plot is +Z in local space (front faces the plaza at -Z).
	local back = CFrame.new(0, 0, 2.5)
	if level == 1 then
		block(model, Vector3.new(7, 3.5, 4), origin * back * CFrame.new(0, 2.25, 0), "#D6452F")
		for _, x in { -2.5, 2.5 } do
			local wheel = block(
				model,
				Vector3.new(0.6, 1.6, 1.6),
				origin * back * CFrame.new(x, 0.8, 2.2),
				"#2B2B2B"
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
		block(model, Vector3.new(0.3, 4, 0.3), origin * back * CFrame.new(0, 6, 0), "#DDDDDD")
		local umbrella = block(
			model,
			Vector3.new(0.4, 8, 8),
			origin * back * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			"#F4F1EA",
			Enum.Material.Fabric
		)
		umbrella.Shape = Enum.PartType.Cylinder
	elseif level == 2 then
		block(
			model,
			Vector3.new(10, 6, 6),
			origin * back * CFrame.new(0, 3, 0),
			"#E59A5C",
			Enum.Material.Wood
		)
		block(
			model,
			Vector3.new(11, 0.5, 4),
			origin * back * CFrame.new(0, 6.5, -4),
			"#D6452F",
			Enum.Material.Fabric
		)
	else
		local heights = { [3] = 10, [4] = 16, [5] = 22, [6] = 34 }
		local colors = { [3] = "#F2C14E", [4] = "#C96F53", [5] = "#F4E3C1", [6] = "#2B1E3F" }
		local h = heights[level] or 10
		block(
			model,
			Vector3.new(12, h, 10),
			origin * back * CFrame.new(0, h / 2, 0),
			colors[level] or "#F2C14E",
			if level == 6 then Enum.Material.SmoothPlastic else Enum.Material.Brick
		)
		block(
			model,
			Vector3.new(6, 6, 0.5),
			origin * back * CFrame.new(0, 3, -5.2),
			"#5A3A22",
			Enum.Material.Wood
		)
		block(
			model,
			Vector3.new(12.5, 0.5, 3),
			origin * back * CFrame.new(0, 7, -6.2),
			"#D6452F",
			Enum.Material.Fabric
		)
		if level >= 4 then
			block(
				model,
				Vector3.new(10, 0.6, 3),
				origin * back * CFrame.new(0, 11, -6),
				"#E0E0E0",
				Enum.Material.Concrete
			)
		end
		if level == 5 then
			local dome = block(
				model,
				Vector3.new(9, 9, 9),
				origin * back * CFrame.new(0, h + 2, 0),
				"#FFD24A",
				Enum.Material.Metal
			)
			dome.Shape = Enum.PartType.Ball
		end
		if level == 6 then
			for i = 1, 4 do
				local stripe = block(
					model,
					Vector3.new(12.2, 0.4, 10.2),
					origin * back * CFrame.new(0, i * 7, 0),
					if i % 2 == 0 then "#FF4FD8" else "#33E1FF",
					Enum.Material.Neon
				)
				stripe.CanCollide = false
			end
			local sign = block(
				model,
				Vector3.new(8, 8, 0.6),
				origin * back * CFrame.new(0, h + 5, 0),
				"#FFD24A",
				Enum.Material.Neon
			)
			sign.Shape = Enum.PartType.Cylinder
			sign.CFrame = origin
				* back
				* CFrame.new(0, h + 5, 0)
				* CFrame.Angles(0, math.rad(90), 0)
		end
	end
end

local function regularFigure(pizzeria: Instance, cf: CFrame, customerId: string)
	local rarity = rarityOf[customerId] or "Common"
	local color = rarityColor[rarity] or Color3.new(1, 1, 1)
	-- Grouped + tagged so clients can animate it locally (RegularsController).
	local parent = Instance.new("Model")
	parent.Name = "Regular"
	parent:SetAttribute("CustomerId", customerId)
	parent:AddTag("PizzeriaRegular")
	parent.Parent = pizzeria
	local body = block(parent, Vector3.new(1.6, 2.2, 1), cf * CFrame.new(0, 1.9, 0), "#FFFFFF")
	body.Color = color
	body.CanCollide = false
	body.Name = "Body"
	local head = block(parent, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 3.6, 0), "#F1C27D")
	head.Name = "Head"
	head.CanCollide = false
	local stool = block(
		parent,
		Vector3.new(1.4, 0.8, 1.4),
		cf * CFrame.new(0, 0.4, 0),
		"#8B5A2B",
		Enum.Material.Wood
	)
	stool.CanCollide = false
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 24)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	tag.MaxDistance = 60
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = nameOf[customerId] or customerId
	label.Parent = tag
	tag.Parent = head
end

local function updateSign(player: Player)
	local model = models[player]
	local sign = model and model:FindFirstChild("SignLabel", true)
	local profile = DataService.getProfile(player)
	if sign and sign:IsA("TextLabel") and profile then
		local def = levelDef(profile.pizzeriaLevel)
		local income = PizzeriaService.incomePerMinute(player)
		local incomeText = if income > 0 then `\n💰 {math.floor(income + 0.5)}/min` else ""
		sign.Text = `{player.DisplayName}'s {def.displayName}{incomeText}`
	end
end

local function rebuild(player: Player, celebrate: boolean?)
	local index = playerPlot[player]
	local profile = DataService.getProfile(player)
	if not index or not profile then
		return
	end
	local old = models[player]
	if old then
		old:Destroy()
	end
	local level = math.clamp(profile.pizzeriaLevel, 1, MAX_LEVEL)
	local origin = plotCFrame(index)
	local model = Instance.new("Model")
	model.Name = `Pizzeria_{player.UserId}`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Level", level)

	buildBody(model, level, origin)

	-- Counter with the two prompts (front of the plot)
	local counter = block(
		model,
		Vector3.new(6, 2.4, 1.6),
		origin * CFrame.new(0, 1.2, -3.5),
		"#F4E3C1",
		Enum.Material.Wood
	)
	counter.Name = "PizzeriaCounter"

	local nextDef = Pizzeria[level + 1]
	local upgrade = Instance.new("ProximityPrompt")
	upgrade.Name = "UpgradePrompt"
	upgrade.ActionText = if nextDef then `Upgrade ({nextDef.cost} 💰)` else "Max level!"
	upgrade.ObjectText = if nextDef
		then `→ {nextDef.displayName}`
		else levelDef(level).displayName
	upgrade.HoldDuration = 0.4
	upgrade.MaxActivationDistance = 10
	upgrade.RequiresLineOfSight = false
	upgrade.KeyboardKeyCode = Enum.KeyCode.F
	upgrade.Enabled = nextDef ~= nil
	upgrade.Parent = counter
	upgrade.Triggered:Connect(function(who)
		PizzeriaService.tryUpgrade(who, player)
	end)
	TipJarService.attach(player, counter)

	-- Sign
	local signPart = block(model, Vector3.new(1, 1, 1), origin * CFrame.new(0, 0.5, 2.5), "#FFFFFF")
	signPart.Transparency = 1
	signPart.CanCollide = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, ({ 11, 9, 13, 19, 30, 40 })[level] or 12, 0)
	billboard.MaxDistance = 120
	billboard.Adornee = signPart
	local label = Instance.new("TextLabel")
	label.Name = "SignLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex("#FFF3D6")
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard
	billboard.Parent = signPart

	-- Regulars on stools in front of the counter (2 rows of 4)
	for i, id in profile.regulars do
		local row = math.floor((i - 1) / 4)
		local col = (i - 1) % 4
		local seat = origin
			* CFrame.new(-4.5 + col * 3, 0, -6 - row * 2.6)
			* CFrame.Angles(0, math.pi, 0)
		regularFigure(model, seat, id)
	end

	model.Parent = Workspace:FindFirstChild("PizzaMap") or Workspace
	models[player] = model
	updateSign(player)
	player:SetAttribute("PizzeriaLevel", level)
	player:SetAttribute("RegularSeats", slotsFor(player, level))
	player:SetAttribute("Regulars", #profile.regulars)

	if celebrate then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local target = d.Transparency
				d.Transparency = 1
				TweenService
					:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Transparency = target })
					:Play()
			end
		end
	end
end

-- Gameplay ------------------------------------------------------------------

function PizzeriaService.tryUpgrade(who: Player, owner: Player)
	if who ~= owner then
		Net.event("Hint"):FireClient(who, `That's {owner.DisplayName}'s pizzeria!`)
		return
	end
	local profile = DataService.getProfile(owner)
	if not profile then
		return
	end
	local nextDef = Pizzeria[profile.pizzeriaLevel + 1]
	if not nextDef then
		Net.event("Hint"):FireClient(owner, "Your pizzeria is already a Neon Pizza Tower!")
		return
	end
	if not EconomyService.spendTips(owner, nextDef.cost, `pizzeria_level_{nextDef.level}`) then
		Net.event("Hint")
			:FireClient(owner, `You need {nextDef.cost} 💰 for the {nextDef.displayName}.`)
		return
	end
	DataService.update(owner, function(p)
		p.pizzeriaLevel = math.min(MAX_LEVEL, nextDef.level)
	end)
	if nextDef.level == 2 then
		AnalyticsService.funnel(owner, "first_upgrade")
	end
	AnalyticsService.custom(owner, `pizzeria_level_{nextDef.level}`)
	Net.event("Hint"):FireClient(owner, `🎉 Your pizzeria is now a {nextDef.displayName}!`)
	rebuild(owner, true)
end

-- Seat a newly discovered rare+ customer as a regular, if there is room.
local function maybeSeat(player: Player, customerId: string)
	if (passiveOf[customerId] or 0) <= 0 then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile or table.find(profile.regulars, customerId) then
		return
	end
	if #profile.regulars >= slotsFor(player, profile.pizzeriaLevel) then
		Net.event("Hint"):FireClient(
			player,
			`{nameOf[customerId]} wants to be a regular — upgrade your pizzeria for more seats!`
		)
		return
	end
	DataService.update(player, function(p)
		if not table.find(p.regulars, customerId) then
			table.insert(p.regulars, customerId)
		end
	end)
	Net.event("Hint")
		:FireClient(player, `🪑 {nameOf[customerId]} is now a regular at your pizzeria!`)
	rebuild(player, false)
end

local function assignPlot(player: Player)
	if playerPlot[player] then
		return
	end
	for i = 1, #MapLayout.plots do
		if not plotOwner[i] then
			plotOwner[i] = player
			playerPlot[player] = i
			player:SetAttribute("PlotIndex", i)
			return
		end
	end
	warn(`[PizzeriaService] no free plot for {player.UserId}`)
end

local function onLoaded(player: Player)
	assignPlot(player)
	-- Offline earnings (once per session, on load)
	local profile = DataService.getProfile(player)
	if profile and profile.lastSeen > 0 then
		local rate = PizzeriaService.incomePerMinute(player)
		local tips, seconds = progression.offlineEarnings(
			rate,
			profile.lastSeen,
			os.time(),
			hasPass(player, "LongShift")
		)
		tips = math.floor(tips)
		if tips > 0 and EconomyService.addTips(player, tips, "offline") then
			Net.event("Hint"):FireClient(
				player,
				`While you were away ({math.floor(seconds / 60)} min) your regulars left {tips} 💰!`
			)
		end
	end
	rebuild(player, false)
end

local function release(player: Player)
	local index = playerPlot[player]
	if index then
		plotOwner[index] = nil
	end
	playerPlot[player] = nil
	fraction[player] = nil
	local model = models[player]
	if model then
		model:Destroy()
	end
	models[player] = nil
end

function PizzeriaService.init()
	for _, c in Customers do
		rarityOf[c.id] = c.rarity
		nameOf[c.id] = c.displayName
	end
	for _, r in Rarities do
		rarityColor[r.id] = Color3.fromHex(r.colorHex)
		for _, c in Customers do
			if c.rarity == r.id then
				passiveOf[c.id] = r.passiveMultiplier
			end
		end
	end

	-- Pizzeria level makes rarer customers a little more likely (level 4+).
	CustomerService.addModifierProvider(function(player)
		local level = player:GetAttribute("PizzeriaLevel")
		if typeof(level) == "number" and level >= 4 then
			return { pizzeriaLevelBonus = (level - 3) * 0.1 }
		end
		return nil
	end)

	DebugService.register(
		"pizzeria",
		"Set or show your pizzeria level",
		"pizzeria [1-6]",
		function(player, args)
			local level = tonumber(args[1])
			if level then
				if level ~= math.floor(level) or level < 1 or level > MAX_LEVEL then
					return false, "usage: pizzeria [1-6]"
				end
				DataService.update(player, function(p)
					p.pizzeriaLevel = level
				end)
				rebuild(player, true)
			end
			local profile = DataService.getProfile(player)
			return true,
				if profile
					then `level {profile.pizzeriaLevel}, regulars {#profile.regulars}/{slotsFor(
						player,
						profile.pizzeriaLevel
					)}, income {PizzeriaService.incomePerMinute(player)}/min`
					else "profile not loaded"
		end
	)
	DebugService.register(
		"regular",
		"Seat a customer as a regular",
		"regular <CustomerId>",
		function(player, args)
			local id = args[1]
			if not id or not rarityOf[id] then
				return false, "usage: regular <CustomerId>"
			end
			CustomerService.recordServed(player, id)
			maybeSeat(player, id)
			return true, `regulars now {player:GetAttribute("Regulars")}`
		end
	)
end

function PizzeriaService.start()
	DataService.onLoaded(function(player)
		onLoaded(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			onLoaded(player)
		end
	end
	Players.PlayerRemoving:Connect(release)

	OrderService.onDelivered(function(player, order)
		maybeSeat(player, order.customerId)
		-- Regulars cheer when their courier delivers (clients animate it).
		local model = models[player]
		if model then
			model:SetAttribute("Cheer", os.clock())
		end
	end)

	-- Passive income loop
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for player in playerPlot do
				local perMinute = PizzeriaService.incomePerMinute(player)
				if perMinute > 0 then
					local amount = (fraction[player] or 0) + perMinute * TICK_SECONDS / 60
					local whole = math.floor(amount)
					fraction[player] = amount - whole
					if whole > 0 then
						TipJarService.add(player, whole, perMinute)
					end
				end
			end
		end
	end)
end

return PizzeriaService
