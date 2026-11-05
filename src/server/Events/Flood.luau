--!strict
-- Event: Shark Flood (brief 1.0 ch. 12).
-- Lower town fills with water. Floating crates/cars form stepping-stone paths
-- along Harbor Lane and up to every lower-town door; balconies stay reachable.
-- Couriers who end up in the water are rescued (comic splash) onto the nearest
-- platform after a short moment. A shark fin patrols the lane and only hits
-- couriers who are swimming — platforms are always safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)
local StyleService = require(Services.StyleService)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local MapService = require(Services.MapService)

local ZONE = MapLayout.zones.LowerTown
local WATER_TOP = 4.5
local IN_WATER_MARGIN = 2.6 -- root below WATER_TOP + this = swimming
local RESCUE_AFTER = 1.2
local SHARK_SPEED = 24
local SHARK_HIT_RADIUS = 6
local LANE_Z = 150

local Flood = {
	id = "Flood",
	buildUpSeconds = 5,
}

local function inZone(p: Vector3): boolean
	return math.abs(p.X - ZONE.x) < ZONE.sx / 2 and math.abs(p.Z - ZONE.z) < ZONE.sz / 2
end

local function platform(parent: Instance, position: Vector3, size: Vector3, color: string): Part
	local p = Instance.new("Part")
	p.Name = "Platform"
	p:AddTag("FloodPlatform")
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Stepping stones along the lane plus spurs to each lower-town door.
local function buildPlatforms(folder: Folder, rng: Random): { Part }
	local list: { Part } = {}
	local y = WATER_TOP + 0.5
	local colors = { "#D6452F", "#2F7BD6", "#F2C14E", "#EDE6DA", "#3FA34D" }
	local x = ZONE.x - ZONE.sx / 2 + 16
	local i = 0
	while x < ZONE.x + ZONE.sx / 2 - 10 do
		i += 1
		local z = LANE_Z + (if i % 2 == 0 then 5 else -5)
		local size = Vector3.new(9, 1.2, 6) -- car-roof sized
		table.insert(
			list,
			platform(folder, Vector3.new(x, y, z), size, colors[rng:NextInteger(1, #colors)])
		)
		x += 12
	end
	-- Spurs toward doors and the south avenue entry
	for _, address in MapService.getAddresses() do
		local door = address.doorPosition
		if inZone(door) then
			table.insert(
				list,
				platform(
					folder,
					Vector3.new(door.X, y, door.Z - 4),
					Vector3.new(8, 1.2, 8),
					"#8B5A2B"
				)
			)
		end
	end
	table.insert(
		list,
		platform(
			folder,
			Vector3.new(0, y, ZONE.z - ZONE.sz / 2 + 6),
			Vector3.new(10, 1.2, 8),
			"#8B5A2B"
		)
	)
	return list
end

local function nearestPlatform(platforms: { Part }, from: Vector3): Vector3
	local best, bestDistance = MapService.getSpawnPosition(), math.huge
	for _, p in platforms do
		local d = (p.Position - from).Magnitude
		if d < bestDistance then
			best, bestDistance = p.Position + Vector3.new(0, 3.5, 0), d
		end
	end
	return best
end

local function makeFin(parent: Instance): BasePart
	local fin = Instance.new("WedgePart")
	fin.Name = "SharkFin"
	fin.Anchored = true
	fin.CanCollide = false
	fin.CanQuery = false
	fin.CanTouch = false
	fin.Size = Vector3.new(0.8, 4, 4)
	fin.Color = Color3.fromHex("#5D6D7E")
	fin.Material = Enum.Material.SmoothPlastic
	fin.Parent = parent
	return fin
end

function Flood.warning(ctx: any)
	ctx.announce("🌊 A pipe burst! Harbor Lane is flooding — jump on the floating cars!")
end

function Flood.buildUp(ctx: any)
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Anchored = true
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.Material = Enum.Material.Glass
	water.Color = Color3.fromHex("#3A8DDE")
	water.Transparency = 0.35
	water.Size = Vector3.new(ZONE.sx, 0.2, ZONE.sz)
	water.CFrame = CFrame.new(ZONE.x, 0.3, ZONE.z)
	water.Parent = ctx.folder
	TweenService:Create(water, TweenInfo.new(4, Enum.EasingStyle.Sine), {
		Size = Vector3.new(ZONE.sx, WATER_TOP, ZONE.sz),
		CFrame = CFrame.new(ZONE.x, WATER_TOP / 2, ZONE.z),
	}):Play()
	ctx.setState("FloodLevel", WATER_TOP)
	buildPlatforms(ctx.folder, ctx.rng)
end

function Flood.active(ctx: any)
	local platforms: { Part } = {}
	for _, child in ctx.folder:GetChildren() do
		if child:IsA("Part") and child.Name == "Platform" then
			table.insert(platforms, child)
		end
	end

	local fin = makeFin(ctx.folder)
	local finX = ZONE.x - ZONE.sx / 2 + 10
	local finDir = 1
	local bob = 0
	local wetSince: { [Player]: number } = {}

	ctx.announce("🦈 Something is swimming in Harbor Lane… stay on the cars!")

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if ctx.phase() ~= "active" then
			return
		end
		bob += dt
		-- Platform bobbing is visual only and runs on each client (EventFxController).
		-- Shark patrol
		finX += finDir * SHARK_SPEED * dt
		if finX > ZONE.x + ZONE.sx / 2 - 10 then
			finDir = -1
		elseif finX < ZONE.x - ZONE.sx / 2 + 10 then
			finDir = 1
		end
		local finZ = LANE_Z + math.sin(bob * 0.7) * 10
		fin.CFrame = CFrame.new(finX, WATER_TOP + 1.6, finZ)
			* CFrame.Angles(0, if finDir > 0 then math.rad(90) else math.rad(-90), 0)

		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root and inZone(root.Position) and root.Position.Y < WATER_TOP + IN_WATER_MARGIN then
				-- Shark bite (only swimmers)
				local finDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
					finX,
					0,
					finZ
				)).Magnitude
				if finDistance < Tuning.Style.sharkNearRadius then
					StyleService.markHazard(player, "shark")
				end
				if finDistance < SHARK_HIT_RADIUS then
					local target = nearestPlatform(platforms, root.Position)
					KnockbackService.hit(player, Vector3.new(0, 70, 0), "Shark", 0.8)
					task.delay(0.8, function()
						CharacterService.teleport(player, target)
					end)
					wetSince[player] = nil
					continue
				end
				-- Swimming for too long → comic rescue onto the nearest platform
				wetSince[player] = wetSince[player] or now
				if
					now - (wetSince[player] :: number) > RESCUE_AFTER
					and not KnockbackService.isProtected(player)
				then
					wetSince[player] = nil
					StyleService.noteAccident(player)
					CharacterService.teleport(player, nearestPlatform(platforms, root.Position))
					KnockbackService.protect(player, 1.5)
				end
			else
				wetSince[player] = nil
			end
		end
	end)
	ctx.track(heartbeat)

	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function Flood.windDown(ctx: any)
	ctx.announce("🌊 The water is going down. Mind the puddles!")
	local water = ctx.folder:FindFirstChild("Water")
	if water and water:IsA("BasePart") then
		TweenService:Create(water, TweenInfo.new(4, Enum.EasingStyle.Sine), {
			Size = Vector3.new(ZONE.sx, 0.2, ZONE.sz),
			CFrame = CFrame.new(ZONE.x, 0.3, ZONE.z),
		}):Play()
	end
	local fin = ctx.folder:FindFirstChild("SharkFin")
	if fin then
		fin:Destroy()
	end
	ctx.setState("FloodLevel", nil)
end

return Flood
