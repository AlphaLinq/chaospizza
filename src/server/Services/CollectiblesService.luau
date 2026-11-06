--!strict
-- Golden pepperoni (#132): 30 hidden spots (Config/Collectibles). Each UTC
-- day every courier gets 10 active spots (unfound first), saved in the
-- profile. Walk within `pickupRadius` of one of YOUR active spots and the
-- server collects it: tips, a hint and, once all 30 are found, a big bonus
-- and the onCompleted signal (the Codex UI/cosmetic hooks in there).
--
-- Replication: player attributes `GoldenActive` (comma-separated spot ids,
-- the client draws only these) and `GoldenFound` (all-time count).
-- API: CollectiblesService.getState(player), CollectiblesService.onCompleted(cb).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Collectibles = require(ReplicatedStorage.Shared.Util.Collectibles)
local Config = require(ReplicatedStorage.Shared.Config.Collectibles)
local Net = require(ReplicatedStorage.Shared.Net)

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)

export type PublicState = {
	day: number,
	found: number,
	total: number,
	foundIds: { [string]: boolean },
	active: { string },
	hints: { [string]: string },
}

local CollectiblesService = {}

local ids: { string } = {}
local positions: { [string]: Vector3 } = {}
local hints: { [string]: string } = {}
for _, spot in Config.spots do
	table.insert(ids, spot.id)
	positions[spot.id] = Vector3.new(spot.x, spot.y, spot.z)
	hints[spot.id] = spot.hint
end

local rng = Random.new()
local completedCallbacks: { (Player) -> () } = {}

local function pick(n: number): number
	return rng:NextInteger(1, n)
end

local function today(): number
	return Collectibles.dayOf(Workspace:GetServerTimeNow(), Config.daySeconds)
end

local function stateOf(player: Player): Collectibles.State?
	local profile = DataService.getProfile(player)
	return if profile then (profile :: any).collectibles else nil
end

local function publish(player: Player)
	local state = stateOf(player)
	if not state then
		return
	end
	player:SetAttribute("GoldenActive", table.concat(state.active, ","))
	player:SetAttribute("GoldenFound", Collectibles.foundCount(state, ids))
end

local function ensureDay(player: Player)
	local state = stateOf(player)
	if not state or state.day == today() then
		return
	end
	DataService.update(player, function(profile)
		Collectibles.roll((profile :: any).collectibles, today(), ids, Config.perDay, pick)
	end)
	publish(player)
end

function CollectiblesService.getState(player: Player): PublicState?
	local state = stateOf(player)
	if not state then
		return nil
	end
	return {
		day = state.day,
		found = Collectibles.foundCount(state, ids),
		total = #ids,
		foundIds = table.clone(state.found),
		active = table.clone(state.active),
		hints = hints,
	}
end

function CollectiblesService.onCompleted(callback: (Player) -> ())
	table.insert(completedCallbacks, callback)
end

-- Collects `id` for `player` if it is one of their active spots.
function CollectiblesService.collect(player: Player, id: string): boolean
	local before = stateOf(player)
	if not before or not table.find(before.active, id) then
		return false
	end
	local result: Collectibles.Result? = nil
	DataService.update(player, function(profile)
		result = Collectibles.collect((profile :: any).collectibles, id)
	end)
	if not result then
		return false
	end
	local state = stateOf(player) :: Collectibles.State
	local found = Collectibles.foundCount(state, ids)
	if result == "new" then
		EconomyService.addTips(player, Config.tipsPerFind, "golden_pepperoni")
		Net.event("Hint"):FireClient(
			player,
			`🍕✨ Golden pepperoni! {found}/{#ids} · +{Config.tipsPerFind} tips`
		)
		if found == #ids then
			EconomyService.addTips(player, Config.completeTips, "golden_pepperoni")
			Net.event("Hint"):FireClient(
				player,
				`🏆 ALL {#ids} GOLDEN PEPPERONI! +{Config.completeTips} tips. Legend.`
			)
			for _, callback in completedCallbacks do
				task.spawn(callback, player)
			end
		end
	else
		EconomyService.addTips(player, Config.repeatTips, "golden_pepperoni")
		Net.event("Hint")
			:FireClient(player, `🍕✨ Golden pepperoni again! +{Config.repeatTips} tips`)
	end
	publish(player)
	return true
end

function CollectiblesService.init()
	DebugService.register(
		"gold",
		"Golden pepperoni: state, teleport to an active spot, collect, reroll",
		"gold [near|collect <id>|reroll|reset]",
		function(player, args)
			local state = stateOf(player)
			if not state then
				return false, "profile not loaded"
			end
			local sub = args[1]
			if sub == "near" then
				local id = state.active[1]
				if not id then
					return false, "no active spot today"
				end
				CharacterService.teleport(player, positions[id] + Vector3.new(6, 2, 0))
				return true, `next to {id}: {hints[id]}`
			elseif sub == "collect" then
				local id = args[2] or state.active[1]
				return CollectiblesService.collect(player, id or ""), `collect {id}`
			elseif sub == "reroll" or sub == "reset" then
				DataService.update(player, function(profile)
					local c = (profile :: any).collectibles
					if sub == "reset" then
						c.found = {}
					end
					c.day = -1
				end)
				ensureDay(player)
			end
			local s = stateOf(player) :: Collectibles.State
			return true,
				`golden {Collectibles.foundCount(s, ids)}/{#ids} · day {s.day} · active {table.concat(
					s.active,
					","
				)}`
		end
	)
end

function CollectiblesService.start()
	DataService.onLoaded(function(player)
		ensureDay(player)
		publish(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			task.spawn(ensureDay, player)
		end
	end
	local elapsed, dayCheck = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		dayCheck += dt
		if dayCheck >= 30 then
			dayCheck = 0
			for _, player in Players:GetPlayers() do
				ensureDay(player) -- midnight UTC rolls a fresh set
			end
		end
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local state = stateOf(player)
			local root = CharacterService.getRootPart(player)
			if state and root and #state.active > 0 then
				for _, id in table.clone(state.active) do
					local pos = positions[id]
					if pos and (pos - root.Position).Magnitude <= Config.pickupRadius then
						CollectiblesService.collect(player, id)
					end
				end
			end
		end
	end)
end

return CollectiblesService
