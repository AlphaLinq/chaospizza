--!strict
-- Event: Gale Force (#230). A storm front rolls over the city: every few
-- seconds a gust is announced from a random direction (HUD arrow and a
-- countdown), then it blows for a moment. Character physics belongs to the
-- client, so each client shoves and carries its own courier
-- (WindGustController); the server only schedules the gusts and judges the
-- reward: couriers seen riding a gust through the air (high enough, moving
-- with the wind) get the "Tailwind" style tag and challenge progress, once
-- per gust.
--
-- Replication: CityState "Wind" = JSON { name, x, z, startsAt, endsAt }
-- (server time), "WindGust" = true while the event runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Wind = require(ReplicatedStorage.Shared.Util.Wind)

local Services = ServerScriptService.Server.Services
local CharacterService = require(Services.CharacterService)
local FeatureTipService = require(Services.FeatureTipService)
local StyleService = require(Services.StyleService)

local WindGust = {
	id = "WindGust",
	buildUpSeconds = 3,
}

local POLL_SECONDS = 0.2

local function feetHeight(root: BasePart): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
	if not hit then
		return math.huge
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	return root.Position.Y - hit.Position.Y - legs
end

-- Marks each courier riding this gust (once per gust).
local function judge(gust: Wind.Gust, ridden: { [Player]: boolean })
	local cfg = Tuning.WindGust :: any
	for _, player in Players:GetPlayers() do
		if ridden[player] or player:GetAttribute("Knocked") == true then
			continue
		end
		local root = CharacterService.getRootPart(player)
		if not root then
			continue
		end
		local v = root.AssemblyLinearVelocity
		if Wind.riding(gust, v.X, v.Z, feetHeight(root), cfg) then
			ridden[player] = true
			StyleService.markHazard(player, "gust")
		end
	end
end

function WindGust.warning(ctx: any)
	ctx.announce("💨 A storm front is coming! Hide behind buildings — or ride the gusts!")
end

function WindGust.buildUp(ctx: any)
	ctx.setState("WindGust", true)
	FeatureTipService.showAll("Wind") -- once per courier (#238)
end

function WindGust.active(ctx: any)
	local cfg = Tuning.WindGust :: any
	local last: number? = nil
	local function going(): boolean
		return ctx.phase() == "active" and ctx.isRunning()
	end
	while going() do
		local index = Wind.pickIndex(function(a, b)
			return ctx.rng:NextInteger(a, b)
		end, last)
		last = index
		local gust = Wind.schedule(Workspace:GetServerTimeNow(), index, cfg)
		ctx.setState("Wind", HttpService:JSONEncode(gust))
		local ridden: { [Player]: boolean } = {}
		while going() do
			local phase = Wind.phase(gust, Workspace:GetServerTimeNow())
			if phase == "calm" then
				break
			elseif phase == "blowing" then
				judge(gust, ridden)
			end
			task.wait(POLL_SECONDS)
		end
		local calm = Wind.calmSeconds(function()
			return ctx.rng:NextNumber()
		end, cfg)
		local untilAt = os.clock() + calm
		while going() and os.clock() < untilAt do
			task.wait(POLL_SECONDS)
		end
	end
end

function WindGust.windDown(ctx: any)
	ctx.setState("Wind", nil)
	ctx.announce("💨 The wind is dying down. Fix your hair!")
end

function WindGust.cleanup(ctx: any)
	ctx.setState("Wind", nil)
	ctx.setState("WindGust", nil)
end

return WindGust
