--!strict
-- Event: Moon Walk (#180). Gravity eases down to a fraction of normal, so
-- every jump turns into a floaty leap — rooftops and overpass become
-- shortcuts. Workspace.Gravity replicates, and each client simulates its own
-- character with it, so the server only sets the value (and always restores
-- the exact original at the end). Couriers seen high in the air during the
-- event get the "Moonwalk" style tag for their next delivery.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local StyleService = require(Services.StyleService)

local LowGravity = {
	id = "LowGravity",
	buildUpSeconds = 3,
}

local normalGravity: number? = nil

local function ease(from: number, to: number, seconds: number, keepGoing: () -> boolean)
	local t0 = os.clock()
	while keepGoing() do
		local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
		Workspace.Gravity = from + (to - from) * (k * k * (3 - 2 * k))
		if k >= 1 then
			break
		end
		task.wait()
	end
end

local function feetHeight(root: BasePart): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -80, 0), params)
	if not hit then
		return math.huge
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	return root.Position.Y - hit.Position.Y - legs
end

function LowGravity.warning(ctx: any)
	ctx.announce("🌙 The moon is acting weird… gravity is about to get FLOATY!")
end

function LowGravity.buildUp(ctx: any)
	normalGravity = normalGravity or Workspace.Gravity
	ctx.setState("LowGravity", true)
	local target = (normalGravity :: number) * Tuning.LowGravity.gravityFactor
	ease(Workspace.Gravity, target, Tuning.LowGravity.easeSeconds, function()
		return ctx.isRunning()
	end)
end

function LowGravity.active(ctx: any)
	local cfg = Tuning.LowGravity
	local target = (normalGravity or 196.2) * cfg.gravityFactor
	Workspace.Gravity = target
	local elapsed = 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root and feetHeight(root) >= cfg.moonFeetHeight then
				StyleService.markHazard(player, "moon")
			end
		end
	end)
	ctx.track(heartbeat)
	while ctx.phase() == "active" and ctx.isRunning() do
		task.wait(0.2)
	end
end

function LowGravity.windDown(ctx: any)
	ctx.announce("🌙 Gravity is coming back. Mind the landing!")
	local normal = normalGravity or 196.2
	ease(Workspace.Gravity, normal, Tuning.LowGravity.easeSeconds, function()
		return ctx.isRunning()
	end)
	Workspace.Gravity = normal
end

function LowGravity.cleanup(ctx: any)
	Workspace.Gravity = normalGravity or 196.2
	ctx.setState("LowGravity", nil)
end

return LowGravity
