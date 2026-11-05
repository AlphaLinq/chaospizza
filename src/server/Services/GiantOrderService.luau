--!strict
-- Giant co-op order (brief ch. 13). A giant pizza appears on the plaza every
-- few minutes; 2–4 couriers grab it together and walk it to a Rare+ customer.
-- The box rides above the carriers (server moves it to their centroid). If a
-- carrier is knocked over or too few stay close, the box drops where it is and
-- anyone can grab it again. Everyone who carries it to the door is paid.
--
-- Server-authoritative: the client only triggers the grab prompt. Replicated
-- state: carrier attributes GiantOrderId / GiantTarget / GiantLabel / GiantCustomer.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local CustomerOdds = require(ReplicatedStorage.Shared.Util.CustomerOdds)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local OrderLogic = require(ReplicatedStorage.Shared.Util.OrderLogic)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local CustomerService = require(script.Parent.CustomerService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local KnockbackService = require(script.Parent.KnockbackService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)
local StyleService = require(script.Parent.StyleService)
local MonetizationService = require(script.Parent.MonetizationService)

local G = Tuning.GiantOrder
local FLAT = Vector3.new(1, 0, 1)
local BOX_SIZE = Vector3.new(9, 1.4, 9)

type Phase = "waiting" | "carrying"
type Giant = {
	id: string,
	customerId: string,
	addressId: string,
	door: Vector3,
	label: string,
	box: Part,
	prompt: ProximityPrompt,
	status: TextLabel,
	phase: Phase,
	carriers: { [Player]: boolean },
	clean: boolean,
	spawnedAt: number,
	liftedAt: number?,
	lastTouchedAt: number,
	home: Vector3,
	heartbeat: RBXScriptConnection?,
	lastCentroid: Vector3?,
	lastStepAt: number?,
}

local GiantOrderService = {}

local current: Giant? = nil
local nextSpawnAt = math.huge
local soloMode = false -- debug: allow a single carrier (Studio testing)
local friendCache: { [string]: boolean } = {}
local rngObject = Random.new()

local function rand(): number
	return rngObject:NextNumber()
end

local function minCarriers(): number
	return if soloMode then 1 else G.minCarriers
end

local function carrierCount(giant: Giant): number
	local n = 0
	for _ in giant.carriers do
		n += 1
	end
	return n
end

local function customerName(id: string): string
	local def = CustomerService.get(id)
	return if def then def.displayName else id
end

local function rollRarity(): string
	local weights = if EventService.isHazardActive() then G.eventRarityWeights else G.rarityWeights
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rand() * total
	for _, rarity in { "Rare", "Epic", "Legendary" } do
		local w = (weights :: any)[rarity] or 0
		if roll < w then
			return rarity
		end
		roll -= w
	end
	return "Rare"
end

local function pickCustomer(): string
	local active = EventService.getActiveEvents()
	local eventId = if #active > 0
		then active[math.min(#active, math.floor(rand() * #active) + 1)]
		else nil
	return CustomerOdds.pickCustomer(Customers :: any, rollRarity(), eventId, rand)
		or CustomerService.pickForOrder(Players:GetPlayers()[1])
end

local function pickAddress(home: Vector3): MapService.Address?
	local far: { MapService.Address } = {}
	local all = MapService.getAddresses()
	for _, address in all do
		if ((address.doorPosition - home) * FLAT).Magnitude > 80 and not address.starter then
			table.insert(far, address)
		end
	end
	local pool = if #far > 0 then far else all
	if #pool == 0 then
		return nil
	end
	return pool[math.min(#pool, math.floor(rand() * #pool) + 1)]
end

local function groundBelow(position: Vector3, giant: Giant): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { giant.box }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else MapLayout.streetY
	return Vector3.new(position.X, y + BOX_SIZE.Y / 2, position.Z)
end

local function publishCarrier(player: Player, giant: Giant?)
	if giant then
		player:SetAttribute("GiantLabel", giant.label)
		player:SetAttribute("GiantCustomer", customerName(giant.customerId))
		player:SetAttribute(
			"GiantTarget",
			if giant.phase == "carrying" or giant.liftedAt then giant.door else nil
		)
		player:SetAttribute("GiantOrderId", giant.id) -- last: clients refresh on this
	else
		player:SetAttribute("GiantOrderId", nil)
		player:SetAttribute("GiantTarget", nil)
		player:SetAttribute("GiantLabel", nil)
		player:SetAttribute("GiantCustomer", nil)
	end
end

local function updateStatus(giant: Giant)
	local count = carrierCount(giant)
	local need = minCarriers()
	local customer = customerName(giant.customerId)
	if giant.phase == "carrying" then
		giant.status.Text =
			`🍕 GIANT PIZZA for {customer}\n{count}/{G.maxCarriers} couriers · {giant.label}`
	else
		local missing = math.max(0, need - count)
		giant.status.Text = if missing > 0
			then `🍕 GIANT PIZZA for {customer}\nNeeds {missing} more courier{if missing == 1
				then ""
				else "s"}!`
			else `🍕 GIANT PIZZA for {customer}`
	end
	giant.prompt.Enabled = count < G.maxCarriers
end

local function release(giant: Giant, player: Player, reason: string?)
	if not giant.carriers[player] then
		return
	end
	giant.carriers[player] = nil
	publishCarrier(player, nil)
	if reason then
		Net.event("Hint"):FireClient(player, reason)
	end
	updateStatus(giant)
end

local function drop(giant: Giant, reason: string)
	giant.lastCentroid = nil
	giant.lastStepAt = nil
	giant.phase = "waiting"
	giant.clean = false
	giant.lastTouchedAt = os.clock()
	for player in giant.carriers do
		release(giant, player, reason)
	end
	giant.box.CFrame = CFrame.new(groundBelow(giant.box.Position, giant))
	updateStatus(giant)
end

local function finish(giant: Giant)
	if giant.heartbeat then
		giant.heartbeat:Disconnect()
	end
	for player in giant.carriers do
		publishCarrier(player, nil)
	end
	table.clear(giant.carriers)
	giant.box:Destroy()
	if current == giant then
		current = nil
	end
	nextSpawnAt = os.clock() + G.intervalSeconds
end

local function friendsWith(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	friendCache[key] = false -- until the web call answers
	task.spawn(function()
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end)
	return false
end

local function hasFriendAmong(player: Player, carriers: { Player }): boolean
	for _, other in carriers do
		if other ~= player and friendsWith(player, other) then
			return true
		end
	end
	return false
end

local function deliver(giant: Giant)
	-- Anti-teleport: same plausibility check as normal orders (counter → door).
	local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
	local minSeconds = ((giant.door - giant.home) * FLAT).Magnitude
		/ fastest
		* Tuning.Orders.minTravelTimeFactor
	if os.clock() - (giant.liftedAt or os.clock()) < minSeconds then
		return
	end

	local list: { Player } = {}
	for player in giant.carriers do
		table.insert(list, player)
	end
	-- Clear first so the reward can never be paid twice.
	finish(giant)

	local eventBonus = if EventService.isOrderedActive()
		then Tuning.OrderedEvents.tipBonusForEveryone
		elseif EventService.isHazardActive() then Tuning.Events.tipBonusDuringEvent
		else 0
	local style = StyleService.evaluateGiant(giant.clean)
	local mega = EventService.isMega()
	local customer = CustomerService.get(giant.customerId)
	for _, player in list do
		local social = G.socialBonus + (if hasFriendAmong(player, list) then G.friendBonus else 0)
		local tips = OrderLogic.tip(
			Tuning.Orders.baseTip * G.tipMultiplier,
			eventBonus + style.bonus,
			Tuning.Style.maxTotalBonus
		)
		tips = math.floor(tips * (1 + social) + 0.5)
		local boost = MonetizationService.getTipMultiplier(player)
		if boost > 1 then
			tips = math.floor(tips * boost + 0.5)
		end
		if mega then
			tips *= Tuning.ChaosMeter.megaTipMultiplier
		end
		EconomyService.addTips(player, tips, "giant_order")
		EconomyService.addXp(player, G.xp)
		local deliveries = EconomyService.recordDelivery(player)
		local served = CustomerService.recordServed(player, giant.customerId)
		Net.event("DeliveryResult"):FireClient(player, {
			tips = tips,
			customer = customerName(giant.customerId),
			line = if customer then customer.line else "",
			deliveries = deliveries,
			eventBonus = eventBonus > 0,
			isNew = if served then served.isNew else false,
			rarity = if served then served.rarity else "Rare",
			stars = if served then served.stars else 0,
			style = style.names,
			mega = mega,
			giant = true,
			social = social,
			boost = boost,
		})
		OrderService.notifyDelivered(
			player,
			{
				id = giant.id,
				addressId = giant.addressId,
				customerId = giant.customerId,
				createdAt = giant.liftedAt or giant.spawnedAt,
			},
			tips,
			deliveries,
			{
				isNew = if served then served.isNew else false,
				duringEvent = eventBonus > 0,
				giant = true,
			}
		)
	end
end

local function step(giant: Giant)
	local now = os.clock()
	if now - giant.spawnedAt > G.timeLimitSeconds then
		for player in giant.carriers do
			Net.event("Hint"):FireClient(player, "The giant pizza got cold… maybe next time!")
		end
		finish(giant)
		return
	end

	-- Leash: carriers who wander off let go.
	local positions: { Vector3 } = {}
	for player in giant.carriers do
		local root = CharacterService.getRootPart(player)
		if not root or player.Parent ~= Players then
			release(giant, player)
		elseif ((root.Position - giant.box.Position) * FLAT).Magnitude > G.leashStuds then
			release(giant, player, "You let go of the giant pizza!")
		else
			table.insert(positions, root.Position)
		end
	end
	local count = #positions

	if giant.phase == "carrying" then
		if count < minCarriers() then
			drop(giant, "Too few hands — the giant pizza dropped!")
			return
		end
		local sum = Vector3.zero
		for _, p in positions do
			sum += p
		end
		local centroid = sum / count
		-- Nobody carries a giant pizza faster than they can run: a sudden
		-- jump (teleport, launch) drops it instead of dragging it along.
		local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
		local lastAt = giant.lastStepAt or now
		local flatMove = ((centroid - (giant.lastCentroid or centroid)) * FLAT).Magnitude
		giant.lastCentroid = centroid
		giant.lastStepAt = now
		if now > lastAt and flatMove / (now - lastAt) > fastest * G.maxCarrySpeedFactor then
			drop(giant, "Whoa, too fast — the giant pizza slipped!")
			return
		end
		local spread = 0
		for _, p in positions do
			spread = math.max(spread, ((p - centroid) * FLAT).Magnitude)
		end
		-- Wobble grows when the carriers spread out (brief: the box tilts).
		local wobble = math.rad(12) * math.clamp(spread / G.leashStuds, 0.15, 1)
		local t = now * 4
		giant.box.CFrame = CFrame.new(centroid + Vector3.new(0, G.boxHeightAboveRoot, 0))
			* CFrame.Angles(math.sin(t) * wobble, 0, math.cos(t * 0.8) * wobble)
		giant.lastTouchedAt = now
		if ((giant.box.Position - giant.door) * FLAT).Magnitude < G.deliveryRadiusStuds then
			deliver(giant)
		end
	else
		if count >= minCarriers() then
			giant.phase = "carrying"
			giant.liftedAt = giant.liftedAt or now
			for player in giant.carriers do
				publishCarrier(player, giant)
				Net.event("Hint"):FireClient(player, `Lift! Carry it to {giant.label} together!`)
			end
			updateStatus(giant)
		elseif count == 0 and now - giant.lastTouchedAt > G.abandonSeconds then
			-- Nobody wants it here: back to the plaza.
			if ((giant.box.Position - giant.home) * FLAT).Magnitude > 2 then
				giant.box.CFrame = CFrame.new(giant.home)
			end
			giant.lastTouchedAt = now
		end
	end
end

local function grab(giant: Giant, player: Player)
	if giant.carriers[player] then
		return
	end
	if carrierCount(giant) >= G.maxCarriers then
		return
	end
	if OrderService.getOrder(player) then
		Net.event("Hint"):FireClient(player, "Deliver your current pizza first!")
		return
	end
	if not EconomyService.isReady(player) then
		return
	end
	local root = CharacterService.getRootPart(player)
	if
		not root
		or ((root.Position - giant.box.Position) * FLAT).Magnitude > G.grabRadiusStuds + 4
	then
		return
	end
	giant.carriers[player] = true
	giant.lastTouchedAt = os.clock()
	publishCarrier(player, giant)
	local missing = minCarriers() - carrierCount(giant)
	if missing > 0 and giant.phase == "waiting" then
		Net.event("Hint"):FireClient(player, `Hold on! Need {missing} more courier(s) to lift it.`)
	end
	updateStatus(giant)
end

function GiantOrderService.spawn(): (boolean, string)
	if current then
		return false, "a giant order is already active"
	end
	local spot = MapLayout.giantOrder
	local home = Vector3.new(spot.x, MapLayout.streetY + 0.2 + BOX_SIZE.Y / 2, spot.z)
	local address = pickAddress(home)
	if not address then
		return false, "no addresses"
	end

	local box = Instance.new("Part")
	box.Name = "GiantPizza"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = true
	box.CanTouch = false
	box.Size = BOX_SIZE
	box.Material = Enum.Material.Cardboard
	box.Color = Color3.fromHex("#E8C48A")
	box.CFrame = CFrame.new(home)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 64)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 220
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.fromScale(1, 1)
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.fromHex("#FFD24A")
	status.TextStrokeTransparency = 0.2
	status.Parent = billboard
	billboard.Parent = box

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab giant pizza"
	prompt.ObjectText = "Co-op order"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = G.grabRadiusStuds
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = box

	local giant: Giant = {
		id = HttpService:GenerateGUID(false),
		customerId = pickCustomer(),
		addressId = address.id,
		door = address.doorPosition,
		label = address.label,
		box = box,
		prompt = prompt,
		status = status,
		phase = "waiting",
		carriers = {},
		clean = true,
		spawnedAt = os.clock(),
		liftedAt = nil,
		lastTouchedAt = os.clock(),
		home = home,
		heartbeat = nil,
		lastCentroid = nil,
		lastStepAt = nil,
	}
	current = giant
	prompt.Triggered:Connect(function(player)
		if current == giant then
			grab(giant, player)
		end
	end)
	giant.heartbeat = RunService.Heartbeat:Connect(function()
		if current == giant then
			local ok, err = pcall(step, giant)
			if not ok then
				warn(`[GiantOrderService] step failed: {err}`)
				finish(giant)
			end
		end
	end)
	updateStatus(giant)
	box.Parent = MapService.getMapFolder()
	Net.event("Hint")
		:FireAllClients(
			"🍕 A GIANT PIZZA order is waiting on the plaza — grab it with a friend!"
		)
	return true, `giant order for {customerName(giant.customerId)} → {address.id}`
end

function GiantOrderService.isCarrier(player: Player): boolean
	return current ~= nil and current.carriers[player] == true
end

function GiantOrderService.init()
	DebugService.register(
		"giant",
		"Giant co-op order",
		"giant [spawn|solo|grab|cancel|state]",
		function(player, args)
			local sub = args[1]
			if sub == "spawn" then
				return GiantOrderService.spawn()
			elseif sub == "solo" then
				soloMode = not soloMode
				return true, `solo carrying {if soloMode then "ON" else "OFF"}`
			elseif sub == "grab" then
				-- Same path as the box prompt (QA without input simulation).
				if not current then
					return false, "no giant order"
				end
				grab(current, player)
				return true, `carrier={GiantOrderService.isCarrier(player)}`
			elseif sub == "cancel" then
				if current then
					finish(current)
					return true, "giant order cancelled"
				end
				return true, "no giant order"
			end
			local giant = current
			if not giant then
				return true,
					`no giant order (next in {math.max(0, math.floor(nextSpawnAt - os.clock()))}s)`
			end
			return true,
				`phase={giant.phase} carriers={carrierCount(giant)} clean={giant.clean} → {giant.addressId} for {customerName(
					giant.customerId
				)} you={giant.carriers[player] == true}`
		end
	)
end

function GiantOrderService.start()
	OrderService.addPickupGuard(function(player)
		if GiantOrderService.isCarrier(player) then
			return "You're carrying the giant pizza!"
		end
		return nil
	end)
	KnockbackService.onHit(function(player)
		local giant = current
		if giant and giant.carriers[player] and giant.phase == "carrying" then
			drop(giant, `{player.DisplayName} tripped — the giant pizza dropped! Grab it again!`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if current then
			release(current, player)
		end
	end)

	nextSpawnAt = os.clock() + G.firstSpawnDelaySeconds
	task.spawn(function()
		while true do
			task.wait(5)
			if
				not current
				and os.clock() >= nextSpawnAt
				and #Players:GetPlayers() >= G.minPlayersOnline
			then
				GiantOrderService.spawn()
			end
		end
	end)
end

return GiantOrderService
