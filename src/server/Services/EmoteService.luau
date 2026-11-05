--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Emotes)
local Cosmetics = require(ReplicatedStorage.Shared.Util.Cosmetics).new(
	require(ReplicatedStorage.Shared.Config.Cosmetics)
)
local Logic = require(ReplicatedStorage.Shared.Util.Emotes)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local DebugService = require(script.Parent.DebugService)
local EmoteService = {}
local ready: { [Player]: number } = {}
function EmoteService.play(player: Player, id: string): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile or not Logic.allowed(profile, id, Cosmetics) then
		return false, "Unlock that emote in Looks first."
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return false, "Stand up before striking a pose."
	end
	if os.clock() < (ready[player] or 0) then
		return false, "Give your next pose a moment."
	end
	ready[player] = os.clock() + Config.cooldownSeconds
	player:SetAttribute("CourierEmote", id)
	player:SetAttribute("CourierEmoteStarted", Workspace:GetServerTimeNow())
	return true, "Pose time! Move to cancel."
end
function EmoteService.init()
	DebugService.register(
		"emote",
		"Play an owned cosmetic emote",
		"emote <WaveEmote|DanceEmote|PizzaPoseEmote>",
		function(player, args)
			return EmoteService.play(player, args[1] or "")
		end
	)
end
function EmoteService.start()
	MonetizationService.registerAction("emote", EmoteService.play)
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)
end
return EmoteService
