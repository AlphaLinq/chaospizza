--!strict
-- Dive (#169), server side. The dive itself is client movement (the owner's
-- client moves its character, DiveController); the client only reports that
-- it dived ("Dive" remote) so the server can grant the "Superman" style
-- tag. The report is rate limited, cooled down and only counts while the
-- server also sees the courier off the ground, so spamming it gives nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local StyleService = require(script.Parent.StyleService)

local DiveService = {}

local cfg = Tuning.Dive
local lastDive: { [Player]: number } = {}

local function feetHeight(player: Player): number?
	local root = CharacterService.getRootPart(player)
	if not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	if not hit then
		return math.huge
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	return root.Position.Y - hit.Position.Y - legs
end

function DiveService.report(player: Player): boolean
	local now = os.clock()
	if now - (lastDive[player] or -math.huge) < cfg.cooldownSeconds then
		return false
	end
	local feet = feetHeight(player)
	if not feet or feet < cfg.serverMinFeetHeight then
		return false
	end
	lastDive[player] = now
	StyleService.markHazard(player, "dive")
	return true
end

function DiveService.start()
	Net.onServerEvent("Dive", { ratePerSecond = 2, burst = 2 }, function(player)
		DiveService.report(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastDive[player] = nil
	end)
end

return DiveService
