--!strict
-- Accidents and recovery (brief 1.0 ch. 15): short, funny knockdowns, the pizza
-- always stays, hit protection against immediate re-hits, falling off the map
-- returns you to the nearest safe spot, and a free "unstuck" request.
--
-- Character physics is owned by the client, so the visible knockback is applied
-- by the owner's client (Net "Knockback"); the server owns the rules: who is hit,
-- how hard, protection windows and the cooldowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Net = require(ReplicatedStorage.Shared.Net)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)

local UNSTUCK_COOLDOWN = 10
local FALL_LIMIT_Y = -25

local KnockbackService = {}

local protectedUntil: { [Player]: number } = {}
local lastUnstuck: { [Player]: number } = {}
local hitCallbacks: { (player: Player, source: string) -> () } = {}

function KnockbackService.isProtected(player: Player): boolean
	return (protectedUntil[player] or 0) > os.clock()
end

function KnockbackService.onHit(callback: (player: Player, source: string) -> ())
	table.insert(hitCallbacks, callback)
end

-- impulse: velocity change in studs/s (direction * power). Returns true if applied.
function KnockbackService.hit(
	player: Player,
	impulse: Vector3,
	source: string,
	ragdollSeconds: number?,
	maxImpulse: number?
): boolean
	if KnockbackService.isProtected(player) then
		return false
	end
	if not CharacterService.getRootPart(player) then
		return false
	end
	local duration = math.clamp(ragdollSeconds or 1.6, 0.3, Tuning.Events.maxRagdollSeconds)
	protectedUntil[player] = os.clock() + duration + Tuning.Events.hitProtectionSeconds
	player:SetAttribute("Knocked", true)
	task.delay(duration, function()
		if player.Parent then
			player:SetAttribute("Knocked", nil)
		end
	end)
	Net.event("Knockback"):FireClient(player, impulse, duration, source, maxImpulse or 200)
	for _, callback in hitCallbacks do
		task.spawn(callback, player, source)
	end
	return true
end

-- Gives a short protection window without knockback (e.g. after a teleport).
function KnockbackService.protect(player: Player, seconds: number)
	protectedUntil[player] = math.max(protectedUntil[player] or 0, os.clock() + seconds)
end

local function rescue(player: Player)
	CharacterService.teleportToSafety(player)
	KnockbackService.protect(player, 2)
end

function KnockbackService.init()
	DebugService.register(
		"knock",
		"Knock yourself over (test)",
		"knock [power]",
		function(player, args)
			local power = tonumber(args[1]) or 60
			local root = CharacterService.getRootPart(player)
			if not root then
				return false, "no character"
			end
			local dir = -root.CFrame.LookVector
			local ok =
				KnockbackService.hit(player, dir * power + Vector3.new(0, power * 0.6, 0), "debug")
			return ok, if ok then `knocked with power {power}` else "protected right now"
		end
	)
end

function KnockbackService.start()
	Net.onServerEvent("RequestUnstuck", { ratePerSecond = 1, burst = 2 }, function(player)
		local now = os.clock()
		if now - (lastUnstuck[player] or -math.huge) < UNSTUCK_COOLDOWN then
			Net.event("Hint"):FireClient(
				player,
				`Unstuck is cooling down ({math.ceil(
					UNSTUCK_COOLDOWN - (now - (lastUnstuck[player] or 0))
				)}s)`
			)
			return
		end
		lastUnstuck[player] = now
		rescue(player)
	end)

	-- Fall rescue: never an endless fall, never lose the order.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local root = CharacterService.getRootPart(player)
			if root and root.Position.Y < FALL_LIMIT_Y then
				rescue(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		protectedUntil[player] = nil
		lastUnstuck[player] = nil
	end)
end

return KnockbackService
