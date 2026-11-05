--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Community)
local Policy = require(ReplicatedStorage.Shared.Util.VisitPolicy)
local CharacterService = require(script.Parent.CharacterService)
local GiantOrderService = require(script.Parent.GiantOrderService)
local EventService = require(script.Parent.EventService)
local MonetizationService = require(script.Parent.MonetizationService)
local DebugService = require(script.Parent.DebugService)
local VisitService = {}
local cooldowns: { [Player]: number } = {}
function VisitService.visit(player: Player, ownerId: number): (boolean, string)
	if ownerId ~= ownerId or ownerId <= 0 or ownerId % 1 ~= 0 or ownerId >= math.huge then
		return false, "Choose a pizzeria from the list."
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local now = os.clock()
	local allowed, reason = Policy.check(
		EventService.getPhase(),
		now,
		cooldowns[player] or 0,
		humanoid ~= nil and humanoid.Health > 0,
		GiantOrderService.isCarrier(player)
	)
	if not allowed then
		return false, reason
	end
	local map = Workspace:FindFirstChild("PizzaMap")
	if map and Players:GetPlayerByUserId(ownerId) then
		for _, model in map:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == ownerId then
				local counter = model:FindFirstChild("PizzeriaCounter")
				if counter and counter:IsA("BasePart") and CharacterService.getRootPart(player) then
					cooldowns[player] = now + Config.visitCooldownSeconds
					CharacterService.teleport(
						player,
						counter.Position
							+ counter.CFrame.LookVector * Config.visitOffsetStuds
							+ Vector3.new(0, Config.visitHeightStuds, 0)
					)
					return true, "Welcome! Walk up to the counter to leave a like."
				end
			end
		end
	end
	return false, "That pizzeria isn't here anymore. Choose another."
end
function VisitService.init()
	DebugService.register(
		"visit",
		"Visit a live pizzeria (normal safety gates)",
		"visit <userId>",
		function(player, args)
			return VisitService.visit(player, tonumber(args[1] or "") or 0)
		end
	)
end
function VisitService.start()
	MonetizationService.registerAction("visit", function(player, id)
		return VisitService.visit(player, tonumber(id) or 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end
return VisitService
