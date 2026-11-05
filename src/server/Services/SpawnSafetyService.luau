--!strict
-- Joining or respawning during an event must never drop a courier into the
-- hazard (AGENTS 4.6): if the spawn is inside a live hazard zone, move the
-- character to the first safe spot and give a short hit protection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HazardZones = require(ReplicatedStorage.Shared.Util.HazardZones)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)
local KnockbackService = require(script.Parent.KnockbackService)

local SpawnSafetyService = {}

local function currentHazards(): HazardZones.Hazards
	local state = ReplicatedStorage:FindFirstChild("CityState")
	local pos = state and state:GetAttribute("TornadoPos")
	local radius = state and state:GetAttribute("TornadoRadius")
	return {
		events = if EventService.isHazardActive() then EventService.getActiveEvents() else {},
		tornadoX = if typeof(pos) == "Vector3" then pos.X else nil,
		tornadoZ = if typeof(pos) == "Vector3" then pos.Z else nil,
		tornadoRadius = if typeof(radius) == "number" then radius else nil,
	}
end

-- Returns true if the player was moved.
function SpawnSafetyService.ensureSafe(player: Player): boolean
	local root = CharacterService.getRootPart(player)
	if not root then
		return false
	end
	local hazards = currentHazards()
	local margin = Tuning.Events.safeSpawnMarginStuds
	local zones = MapLayout.zones :: any
	if not HazardZones.isUnsafe(root.Position.X, root.Position.Z, hazards, zones, margin) then
		return false
	end
	local spot = HazardZones.pickSafe(MapLayout.safeSpots :: any, hazards, zones, margin)
	if not spot then
		return false
	end
	CharacterService.teleport(player, Vector3.new(spot.x, MapLayout.streetY + 3, spot.z))
	KnockbackService.protect(player, Tuning.Events.hitProtectionSeconds)
	return true
end

function SpawnSafetyService.init()
	DebugService.register(
		"safespawn",
		"Check / fix your spawn safety",
		"safespawn",
		function(player)
			local moved = SpawnSafetyService.ensureSafe(player)
			return true, if moved then "moved to a safe spot" else "already safe"
		end
	)
end

function SpawnSafetyService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait(0.2) -- let the default spawn settle first
			SpawnSafetyService.ensureSafe(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SpawnSafetyService
