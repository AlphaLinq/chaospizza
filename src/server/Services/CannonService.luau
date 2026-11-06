--!strict
-- Pizza cannons (#147). Step in, hold E, and get shot across town on a fixed
-- ballistic arc to an open street spot (MapLayout.cannons). The server decides
-- everything (cooldown, arc, landing); the owner's client applies the launch
-- velocity like a knockback (KnockbackService.launch — not an accident, so
-- streaks and fragile cakes survive). The flight counts as travel time for the
-- order's anti-teleport check.
--
-- Clients see a muzzle puff via the cannon model's "FiredAt" attribute
-- (CannonController, tag "PizzaCannon").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ballistic = require(ReplicatedStorage.Shared.Util.Ballistic)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local KnockbackService = require(script.Parent.KnockbackService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local CannonService = {}

local cfg = Tuning.Cannon
local GROUND_Y = MapLayout.streetY + 0.2
local lastShot: { [Player]: number } = {}
local models: { Model } = {}

type CannonDef = { name: string, x: number, z: number, to: { x: number, z: number } }

local function muzzle(def: CannonDef): Vector3
	return Vector3.new(def.x, GROUND_Y + cfg.muzzleHeight, def.z)
end

local function landing(def: CannonDef): Vector3
	-- Aim at hip height so the courier lands on their feet-ish.
	return Vector3.new(def.to.x, GROUND_Y + 3, def.to.z)
end

local function launchVelocity(def: CannonDef): Vector3
	local from, to = muzzle(def), landing(def)
	local v = Ballistic.velocity(
		{ x = from.X, y = from.Y, z = from.Z },
		{ x = to.X, y = to.Y, z = to.Z },
		cfg.flightSeconds,
		Workspace.Gravity
	)
	return Vector3.new(v.x, v.y, v.z)
end

-- Fires `player` from cannon `index`. Returns ok + message (debug uses it too).
function CannonService.fire(player: Player, index: number, skipChecks: boolean?): (boolean, string)
	local def = (MapLayout.cannons :: { CannonDef })[index]
	local model = models[index]
	if not def or not model then
		return false, "unknown cannon"
	end
	local root = CharacterService.getRootPart(player)
	if not root then
		return false, "no character"
	end
	if not skipChecks then
		if os.clock() - (lastShot[player] or -math.huge) < cfg.cooldownSeconds then
			return false, "cannon is reloading"
		end
		if player:GetAttribute("Knocked") then
			return false, "knocked over"
		end
		if player:GetAttribute("GiantOrderId") then
			Net.event("Hint")
				:FireClient(player, "🍕🍕 Too heavy! Giant pizzas don't fit in the cannon.")
			return false, "carrying a giant order"
		end
		if (root.Position - muzzle(def)).Magnitude > 14 then
			return false, "too far from the cannon"
		end
	end
	if KnockbackService.isProtected(player) then
		return false, "protected right now"
	end
	-- Start from the muzzle so every shot flies the same checked arc.
	CharacterService.teleport(player, muzzle(def))
	local velocity = launchVelocity(def)
	if
		not KnockbackService.launch(
			player,
			velocity,
			"Cannon",
			cfg.flightSeconds + 0.2,
			cfg.maxImpulse,
			muzzle(def)
		)
	then
		return false, "protected right now"
	end
	lastShot[player] = os.clock()
	model:SetAttribute("FiredAt", Workspace:GetServerTimeNow())
	-- Credit the time a fast courier would need for this distance.
	local flat = ((landing(def) - muzzle(def)) * Vector3.new(1, 0, 1)).Magnitude
	local fastest = Tuning.Movement.baseWalkSpeed * (1 + Tuning.Movement.maxSpeedBonus)
	OrderService.creditTravel(player, flat / fastest * Tuning.Orders.minTravelTimeFactor)
	task.delay(cfg.flightSeconds, function()
		if player.Parent then
			KnockbackService.protect(player, cfg.landingProtectSeconds)
		end
	end)
	Net.event("Hint"):FireClient(player, `💥 {def.name}! Wheeee!`)
	return true, `fired {def.name}`
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function build(index: number, def: CannonDef, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = `PizzaCannon_{index}`
	local base = Vector3.new(def.x, GROUND_Y, def.z)
	local dir = Vector3.new(def.to.x - def.x, 0, def.to.z - def.z).Unit
	local yaw = CFrame.lookAt(base, base + dir)
	part(model, "Base", Vector3.new(6, 1.2, 6), yaw * CFrame.new(0, 0.6, 0), "#3B3B46")
	for _, side in { -1, 1 } do
		local wheel = part(
			model,
			"Wheel",
			Vector3.new(0.8, 3.4, 3.4),
			yaw * CFrame.new(side * 2.4, 1.9, 0),
			"#5A3A22"
		)
		wheel.Shape = Enum.PartType.Cylinder
	end
	-- Barrel tilted 40° up along the shot direction (cylinder axis = local X).
	local barrel = part(
		model,
		"Barrel",
		Vector3.new(6, 2.6, 2.6),
		yaw
			* CFrame.new(0, 3.4, -0.8)
			* CFrame.Angles(math.rad(40), 0, 0)
			* CFrame.Angles(0, math.rad(90), 0),
		"#D6452F"
	)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CanCollide = false
	local sign =
		part(model, "Sign", Vector3.new(0.3, 0.3, 0.3), yaw * CFrame.new(0, 7.5, 0), "#FFFFFF")
	sign.Transparency = 1
	sign.CanCollide = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.MaxDistance = 120
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#FFF3D6")
	text.TextStrokeTransparency = 0.2
	text.Text = `💥 {def.name}`
	text.Parent = billboard
	billboard.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Launch!"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model:FindFirstChild("Base")
	prompt.Triggered:Connect(function(player)
		CannonService.fire(player, index)
	end)

	CollectionService:AddTag(model, "PizzaCannon")
	model.Parent = parent
	return model
end

function CannonService.init()
	DebugService.register(
		"cannon",
		"Fire a pizza cannon (skips cooldown/distance)",
		"cannon <1-4>",
		function(player, args)
			local index = tonumber(args[1]) or 1
			return CannonService.fire(player, index, true)
		end
	)
end

function CannonService.start()
	local map = MapService.getMapFolder()
	local folder = Instance.new("Folder")
	folder.Name = "Cannons"
	folder.Parent = map
	for index, def in MapLayout.cannons :: { CannonDef } do
		models[index] = build(index, def, folder)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

return CannonService
