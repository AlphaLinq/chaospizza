--!strict
-- Style deliveries (brief ch. 14). Collects delivery facts on the server only
-- (hazard near-misses, accidents, airborne at the door, speed) and turns them
-- into style tags via the pure StyleLogic. The client never reports tags.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StyleConfig = require(ReplicatedStorage.Shared.Config.Style)
local StyleLogic = require(ReplicatedStorage.Shared.Util.StyleLogic)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local CharacterService = require(script.Parent.CharacterService)
local DebugService = require(script.Parent.DebugService)
local KnockbackService = require(script.Parent.KnockbackService)

export type HazardKind =
	"shark"
	| "horse"
	| "cheese"
	| "bubble"
	| "dive"
	| "moon"
	| "meteor"
	| "ufo"
	| "gust"
export type StyleResult = { tags: { string }, names: { string }, bonus: number }

local StyleService = {}

type HazardTimes = {
	shark: number?,
	horse: number?,
	cheese: number?,
	bubble: number?,
	dive: number?,
	moon: number?,
}
local lastHazard: { [Player]: HazardTimes } = {}
local lastAccident: { [Player]: number } = {}
local forced: { [Player]: { [string]: boolean } } = {}

local nameById: { [string]: string } = {}
for _, tag in StyleConfig.style.tags do
	nameById[tag.id] = tag.name
end

local hazardCallbacks: { (Player, HazardKind) -> () } = {}

-- Fired on every markHazard (event challenges, #200). Callbacks must be cheap:
-- some hazards are marked every tick while they last (bubble rides).
function StyleService.onHazard(callback: (Player, HazardKind) -> ())
	table.insert(hazardCallbacks, callback)
end

-- Called by events when a courier is close to a hazard but (maybe) not hit.
function StyleService.markHazard(player: Player, kind: HazardKind)
	for _, callback in hazardCallbacks do
		callback(player, kind)
	end
	local entry: HazardTimes = lastHazard[player] or {}
	lastHazard[player] = entry
	if kind == "shark" then
		entry.shark = os.clock()
	elseif kind == "cheese" then
		entry.cheese = os.clock()
	elseif kind == "bubble" then
		entry.bubble = os.clock()
	elseif kind == "dive" then
		entry.dive = os.clock()
	elseif kind == "gust" then
		entry.gust = os.clock()
	elseif kind == "ufo" then
		entry.ufo = os.clock()
	elseif kind == "meteor" then
		entry.meteor = os.clock()
	elseif kind == "moon" then
		entry.moon = os.clock()
	else
		entry.horse = os.clock()
	end
end

-- Knockbacks are recorded automatically; events call this for other mishaps
-- (e.g. being fished out of the flood).
function StyleService.noteAccident(player: Player)
	lastAccident[player] = os.clock()
end

local function heightAboveGround(player: Player): number?
	local root = CharacterService.getRootPart(player)
	if not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
	if not hit then
		return math.huge
	end
	-- Distance from the bottom of the legs, not from the root centre.
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local legs = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	return math.max(0, (root.Position.Y - hit.Position.Y) - legs)
end

-- Evaluate a finished delivery. `startedAt` = os.clock() at pickup,
-- `straightDistance` = flat counter→door distance in studs.
function StyleService.evaluate(
	player: Player,
	startedAt: number,
	straightDistance: number
): StyleResult
	local now = os.clock()
	local hazards: HazardTimes = lastHazard[player] or {}
	local height = heightAboveGround(player)
	local accidentAt = lastAccident[player]
	local seconds = now - startedAt
	local target = straightDistance / Tuning.Movement.baseWalkSpeed * Tuning.Style.lightningFactor

	local facts: StyleLogic.Facts = {
		airborne = height ~= nil and height >= Tuning.Style.airborneMinHeight,
		secondsSinceSharkZone = if hazards.shark then now - hazards.shark else nil,
		secondsSinceHorseLane = if hazards.horse then now - hazards.horse else nil,
		secondsSinceCheeseJump = if hazards.cheese then now - hazards.cheese else nil,
		secondsSinceBubbleRide = if hazards.bubble then now - hazards.bubble else nil,
		secondsSinceDive = if hazards.dive then now - hazards.dive else nil,
		secondsSinceGustRide = if hazards.gust then now - hazards.gust else nil,
		secondsSinceAbduction = if hazards.ufo then now - hazards.ufo else nil,
		secondsSinceNearMiss = if hazards.meteor then now - hazards.meteor else nil,
		secondsSinceMoonJump = if hazards.moon then now - hazards.moon else nil,
		hadAccident = accidentAt ~= nil and accidentAt >= startedAt,
		seconds = seconds,
		targetSeconds = target,
		giantOrderClean = nil, -- M7 giant order
	}
	local force = forced[player]
	if force then
		forced[player] = nil
		if force.AirDelivery then
			facts.airborne = true
		end
		if force.SharkEscape then
			facts.secondsSinceSharkZone = 0
		end
		if force.Hoofbeat then
			facts.secondsSinceHorseLane = 0
		end
		if force.CheeseJump then
			facts.secondsSinceCheeseJump = 0
		end
		if force.BubbleRider then
			facts.secondsSinceBubbleRide = 0
		end
		if force.Superman then
			facts.secondsSinceDive = 0
		end
		if force.Tailwind then
			facts.secondsSinceGustRide = 0
		end
		if force.Abducted then
			facts.secondsSinceAbduction = 0
		end
		if force.CloseCall then
			facts.secondsSinceNearMiss = 0
		end
		if force.Moonwalk then
			facts.secondsSinceMoonJump = 0
		end
	end

	local result = StyleLogic.evaluate(facts, StyleConfig.style, Tuning.Style.maxTotalBonus)
	local names = {}
	for _, id in result.tags do
		table.insert(names, nameById[id] or id)
	end
	return { tags = result.tags, names = names, bonus = result.bonus }
end

-- Giant co-op order: only the "clean" (never dropped) fact applies.
function StyleService.evaluateGiant(clean: boolean): StyleResult
	local result = StyleLogic.evaluate(
		{ giantOrderClean = clean, hadAccident = not clean },
		StyleConfig.style,
		Tuning.Style.maxTotalBonus
	)
	local names = {}
	for _, id in result.tags do
		table.insert(names, nameById[id] or id)
	end
	return { tags = result.tags, names = names, bonus = result.bonus }
end

function StyleService.init()
	DebugService.register(
		"style",
		"Force style facts for your next delivery",
		"style <AirDelivery|SharkEscape|Hoofbeat|CheeseJump|BubbleRider|Superman|Moonwalk|accident|clear>",
		function(player, args)
			local id = args[1]
			if id == "clear" then
				forced[player] = nil
				lastHazard[player] = nil
				lastAccident[player] = nil
				return true, "style facts cleared"
			elseif id == "accident" then
				StyleService.noteAccident(player)
				return true, "accident recorded"
			elseif
				id == "AirDelivery"
				or id == "SharkEscape"
				or id == "Hoofbeat"
				or id == "CheeseJump"
				or id == "BubbleRider"
				or id == "Superman"
				or id == "Tailwind"
				or id == "Abducted"
				or id == "CloseCall"
				or id == "Moonwalk"
			then
				local entry = forced[player] or {}
				entry[id] = true
				forced[player] = entry
				return true, `{id} forced for the next delivery`
			end
			return false,
				"usage: style <AirDelivery|SharkEscape|Hoofbeat|CheeseJump|BubbleRider|Superman|Moonwalk|accident|clear>"
		end
	)
end

function StyleService.start()
	KnockbackService.onHit(function(player)
		StyleService.noteAccident(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHazard[player] = nil
		lastAccident[player] = nil
		forced[player] = nil
	end)
end

return StyleService
