--!strict
-- Event: Blackout (#131). The city goes dark: a harmless, moody event with a
-- smaller tip bonus (Tuning.Events.tipBonusByEvent) and its own night-time
-- customers. The server only replicates state:
--   CityState "Blackout" = true while dark (clients tween Lighting and light
--   up windows, the target door and pizza boxes — BlackoutController)
--   CityState "BlackoutWave" = JSON { t, x, z }: a neon wave starts there
-- Nothing is changed on the server's Lighting, so cleanup is just the state.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Blackout = {
	id = "Blackout",
	buildUpSeconds = 3,
}

function Blackout.warning(ctx: any)
	ctx.announce("💡 The lights are flickering… BLACKOUT incoming! Follow the glowing doors.")
end

function Blackout.buildUp(ctx: any)
	ctx.setState("Blackout", true)
end

function Blackout.active(ctx: any)
	local rng: Random = ctx.rng
	local cfg = Tuning.Blackout
	ctx.setState("Blackout", true)
	local origins = { { x = 0, z = 0 } }
	for _, spot in MapLayout.safeSpots do
		table.insert(origins, { x = spot.x, z = spot.z })
	end
	while ctx.phase() == "active" and ctx.isRunning() do
		local o = origins[rng:NextInteger(1, #origins)]
		ctx.setState(
			"BlackoutWave",
			HttpService:JSONEncode({ t = Workspace:GetServerTimeNow(), x = o.x, z = o.z })
		)
		local wait = cfg.waveMinSeconds
			+ rng:NextNumber() * (cfg.waveMaxSeconds - cfg.waveMinSeconds)
		local untilAt = os.clock() + wait
		while os.clock() < untilAt and ctx.phase() == "active" and ctx.isRunning() do
			task.wait(0.2)
		end
	end
end

function Blackout.windDown(ctx: any)
	ctx.announce("💡 Power's back! The city blinks awake.")
	ctx.setState("Blackout", nil)
	ctx.setState("BlackoutWave", nil)
end

function Blackout.cleanup(ctx: any)
	ctx.setState("Blackout", nil)
	ctx.setState("BlackoutWave", nil)
end

return Blackout
