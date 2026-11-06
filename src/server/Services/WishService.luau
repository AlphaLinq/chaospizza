--!strict
-- Wishing well (#162). The Fountain Square basin gets a "Make a wish" prompt.
-- Once per UTC day a courier can toss 50/200/500 tips for a random buff
-- (Config/Wish, odds shown in the client UI). Tips only — no Robux — so it's
-- an economy sink, not pay-to-win. The server validates distance, the daily
-- claim (profile.claims["wish.day"]), the balance, rolls and applies.
--
-- Buffs are session-only: player attributes "WishBuff" (id) and
-- "WishBuffUntil" (server time). OrderService reads tipMultiplier().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Wish)
local Net = require(ReplicatedStorage.Shared.Net)
local Wish = require(ReplicatedStorage.Shared.Util.Wish)

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)

local WishService = {}

local basin: BasePart? = nil
local rng = Random.new()
local forced: { [Player]: string } = {} -- debug: next outcome id

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function today(): number
	return Wish.dayOf(now(), Config.daySeconds)
end

local function activeBuff(player: Player): string?
	local id = player:GetAttribute("WishBuff")
	local untilAt = player:GetAttribute("WishBuffUntil")
	if typeof(id) == "string" and typeof(untilAt) == "number" and untilAt > now() then
		return id
	end
	return nil
end

function WishService.tipMultiplier(player: Player): number
	return if activeBuff(player) == "LuckyTips" then 1 + Config.luckyTipsBonus else 1
end

function WishService.hasWishedToday(player: Player): boolean
	local profile = DataService.getProfile(player)
	return profile ~= nil and profile.claims[Config.claimKey] == today()
end

-- Returns ok + message; on success fires WishResult to the player.
function WishService.makeWish(
	player: Player,
	tierIndex: number,
	skipDistance: boolean?
): (boolean, string)
	local tier = Config.tiers[tierIndex]
	if not tier then
		return false, "unknown amount"
	end
	if not skipDistance then
		local root = CharacterService.getRootPart(player)
		local b = basin
		if not root or not b or (root.Position - b.Position).Magnitude > Config.maxDistance then
			return false, "too far from the fountain"
		end
	end
	if WishService.hasWishedToday(player) then
		return false, "the fountain needs a rest — come back tomorrow"
	end
	if not EconomyService.spendTips(player, tier.amount, "wish") then
		return false, "not enough tips"
	end
	DataService.update(player, function(profile)
		profile.claims[Config.claimKey] = today()
	end)
	local outcome = Wish.roll(Config.outcomes :: any, rng:NextNumber())
	local force = forced[player]
	if force then
		forced[player] = nil
		for _, o in Config.outcomes do
			if o.id == force then
				outcome = o :: any
			end
		end
	end
	local detail = outcome.text
	if outcome.id == "LuckyTips" or outcome.id == "GoldenCompass" then
		player:SetAttribute("WishBuff", outcome.id)
		player:SetAttribute("WishBuffUntil", now() + tier.minutes * 60)
		detail = `{outcome.text} for {tier.minutes} min`
	elseif outcome.id == "Jackpot" then
		local back = tier.amount * Config.jackpotMultiplier
		EconomyService.addTips(player, back, "wish_jackpot")
		detail = `+{back} tips!`
	elseif outcome.id == "Splash" then
		local back = math.floor(tier.amount * Config.splashRefund)
		EconomyService.addTips(player, back, "wish_splash")
		detail = `You get soaked… +{back} tips back`
	end
	Net.event("WishResult"):FireClient(player, {
		id = outcome.id,
		name = outcome.name,
		detail = detail,
		amount = tier.amount,
	})
	return true, `{outcome.id}: {detail}`
end

local function buildPrompt()
	local map = MapService.getMapFolder()
	local part = map:FindFirstChild("FountainBasin", true)
	if not part or not part:IsA("BasePart") then
		warn("[WishService] FountainBasin not found; wishing well disabled")
		return
	end
	basin = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WishPrompt"
	prompt.ActionText = "Make a wish"
	prompt.ObjectText = "Wishing well"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.2
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		Net.event("WishOpen"):FireClient(player, WishService.hasWishedToday(player))
	end)
end

function WishService.init()
	DebugService.register(
		"wish",
		"Wishing well: toss tips (skips distance), force an outcome, reset the day",
		"wish [1-3|force <LuckyTips|GoldenCompass|Jackpot|Splash>|reset]",
		function(player, args)
			local sub = args[1] or "1"
			if sub == "force" then
				forced[player] = args[2] or "LuckyTips"
				return true, `next wish forced to {forced[player]}`
			elseif sub == "reset" then
				DataService.update(player, function(profile)
					profile.claims[Config.claimKey] = nil
				end)
				player:SetAttribute("WishBuff", nil)
				player:SetAttribute("WishBuffUntil", nil)
				return true, "wish reset for today"
			end
			return WishService.makeWish(player, tonumber(sub) or 1, true)
		end
	)
end

function WishService.start()
	buildPrompt()
	Net.onServerEvent("MakeWish", { ratePerSecond = 1, burst = 2 }, function(player, tierIndex)
		if typeof(tierIndex) ~= "number" or tierIndex ~= math.floor(tierIndex) then
			return
		end
		local ok, message = WishService.makeWish(player, tierIndex)
		if not ok then
			Net.event("Hint"):FireClient(player, `⛲ {message}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		forced[player] = nil
	end)
end

return WishService
