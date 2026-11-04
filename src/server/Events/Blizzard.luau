--!strict
-- Event: Blizzard (Christmas season, M9).
-- Streets turn icy (low friction → couriers slide), and giant snowballs roll
-- down the long connector streets. Lanes flash blue before a snowball comes.
-- Seasonal customers (Snowman Sam … Santa Himself) only order during it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local KnockbackService = require(Services.KnockbackService)

local SNOWBALL_DIAMETER = 9
local SNOWBALL_SPEED = 38
local TELEGRAPH_SECONDS = 1.5
local WAVE_INTERVAL = { 5, 8 }
local ICE = PhysicalProperties.new(0.9, 0.06, 0, 100, 1)

local Blizzard = {
	id = "Blizzard",
	buildUpSeconds = 4,
}

-- Rolling lanes: long north–south streets from MapLayout.
type Lane = { x: number, z0: number, z1: number, width: number }
local function lanes(): { Lane }
	local list: { Lane } = {}
	for _, s in MapLayout.streets do
		if s.name == "WestConnector" or s.name == "EastConnector" or s.name == "SouthAvenue" then
			table.insert(list, { x = s.x, z0 = s.z - s.sz / 2, z1 = s.z + s.sz / 2, width = s.sx })
		end
	end
	return list
end

function Blizzard.warning(ctx: any)
	ctx.announce("❄️ BLIZZARD! The streets are icy — watch out for rolling snowballs!")
end

function Blizzard.buildUp(ctx: any)
	local map = Workspace:FindFirstChild("PizzaMap")
	local streets = map and map:FindFirstChild("Streets")
	if not streets then
		return
	end
	local originals: { [BasePart]: { color: Color3, props: PhysicalProperties? } } = {}
	for _, part in streets:GetChildren() do
		if part:IsA("BasePart") then
			originals[part] = { color = part.Color, props = part.CustomPhysicalProperties }
			part.CustomPhysicalProperties = ICE
			part.Color = part.Color:Lerp(Color3.fromHex("#F2F7FF"), 0.75)
		end
	end
	ctx.track(function()
		for part, original in originals do
			if part.Parent then
				part.Color = original.color
				part.CustomPhysicalProperties = original.props :: any -- nil restores defaults
			end
		end
	end)
end

function Blizzard.active(ctx: any)
	local rng: Random = ctx.rng
	local laneList = lanes()
	type Ball = { part: Part, lane: Lane, z: number, dir: number, spin: number }
	local balls: { Ball } = {}

	local strips: { Part } = {}
	for i, lane in laneList do
		local strip = Instance.new("Part")
		strip.Name = "SnowLaneWarning"
		strip.Anchored = true
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CanTouch = false
		strip.Material = Enum.Material.Neon
		strip.Color = Color3.fromHex("#6FC3FF")
		strip.Transparency = 1
		strip.Size = Vector3.new(lane.width - 2, 0.15, lane.z1 - lane.z0)
		strip.CFrame = CFrame.new(lane.x, 0.5, (lane.z0 + lane.z1) / 2)
		strip.Parent = ctx.folder
		strips[i] = strip
	end

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		for i = #balls, 1, -1 do
			local b = balls[i]
			b.z += b.dir * SNOWBALL_SPEED * dt
			b.spin += dt * SNOWBALL_SPEED / (SNOWBALL_DIAMETER / 2)
			b.part.CFrame = CFrame.new(b.lane.x, SNOWBALL_DIAMETER / 2 + 0.4, b.z)
				* CFrame.Angles(b.dir * b.spin, 0, 0)
			if (b.dir > 0 and b.z > b.lane.z1 + 10) or (b.dir < 0 and b.z < b.lane.z0 - 10) then
				b.part:Destroy()
				table.remove(balls, i)
				continue
			end
			for _, player in Players:GetPlayers() do
				local root = CharacterService.getRootPart(player)
				if root then
					local offset = root.Position - b.part.Position
					if
						Vector3.new(offset.X, 0, offset.Z).Magnitude
							< SNOWBALL_DIAMETER / 2 + 1.5
						and root.Position.Y < 14
					then
						local side = if offset.X >= 0 then 1 else -1
						KnockbackService.hit(
							player,
							Vector3.new(side * 40, 50, b.dir * 45),
							"Snowball",
							1.5
						)
					end
				end
			end
		end
	end)
	ctx.track(heartbeat)

	while ctx.phase() == "active" and ctx.isRunning() do
		local index = rng:NextInteger(1, #laneList)
		local lane = laneList[index]
		local dir = if rng:NextNumber() < 0.5 then 1 else -1
		strips[index].Transparency = 0.7
		task.wait(TELEGRAPH_SECONDS)
		strips[index].Transparency = 1

		local ball = Instance.new("Part")
		ball.Name = "Snowball"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Size = Vector3.new(SNOWBALL_DIAMETER, SNOWBALL_DIAMETER, SNOWBALL_DIAMETER)
		ball.Material = Enum.Material.Snow
		ball.Color = Color3.fromHex("#FFFFFF")
		local startZ = if dir > 0 then lane.z0 - 8 else lane.z1 + 8
		ball.CFrame = CFrame.new(lane.x, SNOWBALL_DIAMETER / 2 + 0.4, startZ)
		ball.Parent = ctx.folder
		table.insert(balls, { part = ball, lane = lane, z = startZ, dir = dir, spin = 0 })

		local untilAt = os.clock()
			+ WAVE_INTERVAL[1]
			+ rng:NextNumber() * (WAVE_INTERVAL[2] - WAVE_INTERVAL[1])
		while os.clock() < untilAt and ctx.phase() == "active" and ctx.isRunning() do
			task.wait(0.1)
		end
	end
end

function Blizzard.windDown(ctx: any)
	ctx.announce("☃️ The blizzard is easing off. Merry deliveries!")
end

return Blizzard
