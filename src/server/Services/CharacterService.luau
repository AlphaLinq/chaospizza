--!strict
-- Character setup: walk speed from Tuning (later + movement tier), spawn on the
-- plaza, and the "unstuck" debug/menu path (teleport to the nearest safe spot).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local DebugService = require(script.Parent.DebugService)
local MapService = require(script.Parent.MapService)

local CharacterService = {}

local speedBonus: { [Player]: number } = {}

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local bonus = math.min(speedBonus[player] or 0, Tuning.Movement.maxSpeedBonus)
		humanoid.WalkSpeed = Tuning.Movement.baseWalkSpeed * (1 + bonus)
	end
end

function CharacterService.getRootPart(player: Player): BasePart?
	return rootPart(player)
end

-- Fraction, capped by Tuning.Movement.maxSpeedBonus. Used by movement tiers (M5).
function CharacterService.setSpeedBonus(player: Player, bonus: number)
	speedBonus[player] = bonus
	applySpeed(player)
end

function CharacterService.teleport(player: Player, position: Vector3)
	local root = rootPart(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(position)
	end
end

function CharacterService.teleportToSafety(player: Player)
	local root = rootPart(player)
	local from = if root then root.Position else MapService.getSpawnPosition()
	CharacterService.teleport(player, MapService.nearestSafeSpot(from))
end

function CharacterService.init()
	StarterPlayer.CharacterWalkSpeed = Tuning.Movement.baseWalkSpeed

	DebugService.register(
		"tp",
		"Teleport to an address id, 'counter' or 'spawn'",
		"tp <A01|counter|spawn>",
		function(player, args)
			local target = args[1]
			if target == "counter" then
				CharacterService.teleport(
					player,
					MapService.getCounterPart().Position + Vector3.new(0, 3, 6)
				)
				return true, "teleported to counter"
			elseif target == "spawn" then
				CharacterService.teleport(player, MapService.getSpawnPosition())
				return true, "teleported to spawn"
			end
			local address = target and MapService.getAddress(target)
			if not address then
				return false, "usage: tp <A01..A14|counter|spawn>"
			end
			CharacterService.teleport(player, address.doorPosition)
			return true, `teleported to {address.id} ({address.label})`
		end
	)
	DebugService.register(
		"unstuck",
		"Teleport to the nearest safe spot",
		"unstuck",
		function(player)
			CharacterService.teleportToSafety(player)
			return true, "moved to safety"
		end
	)
end

function CharacterService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			applySpeed(player)
		end)
		if player.Character then
			applySpeed(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		speedBonus[player] = nil
	end)
end

return CharacterService
