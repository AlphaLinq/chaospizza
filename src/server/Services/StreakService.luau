--!strict
-- Delivery streak (#138): consecutive deliveries without being knocked over
-- raise a tip multiplier (Tuning.Streak). A knockback or a long pause resets it.
-- Replicated as the player attribute "Streak" (count) for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Streak = require(ReplicatedStorage.Shared.Util.Streak)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)
local KnockbackService = require(script.Parent.KnockbackService)

local StreakService = {}

local states: { [Player]: Streak.State } = {}

local function stateFor(player: Player): Streak.State
	local s = states[player]
	if not s then
		s = Streak.new()
		states[player] = s
	end
	return s
end

-- Called once per paid delivery; returns the multiplier for that delivery.
function StreakService.onDelivery(player: Player): (number, number)
	local count, multiplier = Streak.deliver(stateFor(player), os.clock(), Tuning.Streak)
	player:SetAttribute("Streak", count)
	return count, multiplier
end

function StreakService.reset(player: Player, reason: string?)
	local s = states[player]
	if not s or s.count <= 0 then
		return
	end
	local lost = s.count
	Streak.reset(s)
	player:SetAttribute("Streak", 0)
	if reason and lost >= Tuning.Streak.announceLossFrom then
		Net.event("Hint"):FireClient(player, `🔥 Streak lost at {lost}! {reason}`)
	end
end

function StreakService.init()
	DebugService.register(
		"streak",
		"Show / set your delivery streak",
		"streak [set <n>|reset]",
		function(player, args)
			local s = stateFor(player)
			if args[1] == "set" then
				local n = tonumber(args[2] or "")
				if not n or n < 0 or n > 100 then
					return false, "usage: streak set <0-100>"
				end
				s.count = math.floor(n)
				s.lastAt = os.clock()
				player:SetAttribute("Streak", s.count)
			elseif args[1] == "reset" then
				StreakService.reset(player)
			end
			return true, `streak={s.count} x{Streak.multiplier(s.count, Tuning.Streak)}`
		end
	)
end

function StreakService.start()
	KnockbackService.onHit(function(player)
		StreakService.reset(player, "Keep your balance next time.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return StreakService
