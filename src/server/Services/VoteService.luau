--!strict
-- Event vote (#186, docs/GAMEPLAY_LOOP.md G5). In the second half of the calm
-- the server votes on the next event: three options, one vote per courier
-- (changeable), on the HUD and the plaza board. When the calm ends the
-- winner runs (ties at random); no votes = the usual random pick. A paid
-- "order a disaster" still goes first, and there is no ballot while a MEGA
-- is pending or the chaos finale is near.
--
-- Replication: CityState "EventVote" = JSON { options, counts, endsAt }
-- (server time). The client sends only the option index ("CastVote").

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EventVote = require(ReplicatedStorage.Shared.Util.EventVote)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local OrderOffers = require(ReplicatedStorage.Shared.Util.OrderOffers)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)
local FeatureTipService = require(script.Parent.FeatureTipService)
local FinaleService = require(script.Parent.FinaleService)
local MapService = require(script.Parent.MapService)

local VoteService = {}

type Ballot = { options: { string }, votes: { [number]: number } }

local cfg = Tuning.Vote
local ballot: Ballot? = nil
local boardText: TextLabel? = nil
local names: { [string]: string } = {}
for _, e in Events do
	names[e.id] = e.displayName
end

local function rng(): number
	return math.random()
end

local function cityState(): Instance
	return ReplicatedStorage:WaitForChild("CityState")
end

local function counts(b: Ballot): { number }
	return EventVote.tally(b.votes, #b.options)
end

local function renderBoard()
	local text = boardText
	if not text then
		return
	end
	local lines = { "🗳️ NEXT EVENT" }
	local b = ballot
	if b then
		local c = counts(b)
		local featured = EventService.getFeatured()
		for i, id in b.options do
			local star = if id == featured then "⭐ " else ""
			table.insert(lines, `{i}. {star}{names[id] or id} — {c[i]}`)
		end
	else
		table.insert(lines, "Voting opens mid-calm")
	end
	local finaleLeft = FinaleService.secondsLeft()
	table.insert(lines, `🎆 Finale in {EventVote.clock(finaleLeft)}`)
	text.Text = table.concat(lines, "\n")
end

local function publish()
	local b = ballot
	if not b then
		cityState():SetAttribute("EventVote", nil)
	else
		local _, left = EventService.getCalm()
		cityState():SetAttribute(
			"EventVote",
			HttpService:JSONEncode({
				options = b.options,
				counts = counts(b),
				endsAt = Workspace:GetServerTimeNow() + (left or 0),
			})
		)
	end
	renderBoard()
end

function VoteService.open(): (boolean, string)
	if ballot then
		return false, "already open"
	end
	local options = EventVote.pickOptions(EventService.voteCandidates(), cfg.options, rng)
	if #options < 2 then
		return false, "not enough events to vote on"
	end
	ballot = { options = options, votes = {} }
	FeatureTipService.showAll("Vote")
	-- #202: everyone online saw a ballot (participation = vote_cast / this).
	for _, player in Players:GetPlayers() do
		AnalyticsService.custom(player, "vote_ballot")
	end
	publish()
	return true, `ballot: {table.concat(options, ", ")}`
end

local function close()
	if ballot then
		ballot = nil
		publish()
	end
end

-- Called by EventService when the calm ends: the winner, or nil.
local function takeWinner(): string?
	local b = ballot
	if not b then
		return nil
	end
	local index = EventVote.winner(counts(b), rng)
	close()
	if not index then
		return nil
	end
	local id = b.options[index]
	Net.event("Hint"):FireAllClients(`🗳️ The city voted: {names[id] or id}!`)
	for _, player in Players:GetPlayers() do
		if b.votes[player.UserId] == index then
			AnalyticsService.custom(player, `vote_won_{id}`)
		end
	end
	return id
end

function VoteService.cast(player: Player, index: number): (boolean, string)
	local b = ballot
	if not b then
		return false, "no vote right now"
	end
	if b.votes[player.UserId] == nil then
		AnalyticsService.custom(player, "vote_cast")
	end
	b.votes[player.UserId] = index
	publish()
	return true, `voted for {b.options[index]}`
end

local function buildBoard()
	local map = MapService.getMapFolder()
	local pos = MapLayout.voteBoard
	local model = Instance.new("Model")
	model.Name = "VoteBoard"
	local function part(name: string, size: Vector3, cframe: CFrame, color: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = Color3.fromHex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	part("PostL", Vector3.new(0.6, 9, 0.6), CFrame.new(pos.x - 4.5, 4.9, pos.z), "#2B2633")
	part("PostR", Vector3.new(0.6, 9, 0.6), CFrame.new(pos.x + 4.5, 4.9, pos.z), "#2B2633")
	local board = part("Board", Vector3.new(10, 5, 0.5), CFrame.new(pos.x, 8, pos.z), "#3A2B4A")
	local front: TextLabel? = nil
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(500, 250)
		gui.LightInfluence = 0
		gui.MaxDistance = 200
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -20, 1, -16)
		text.Position = UDim2.fromOffset(10, 8)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromHex("#FFF3D6")
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Parent = gui
		gui.Parent = board
		if not front then
			front = text
			boardText = text
		else
			local source = front
			source:GetPropertyChangedSignal("Text"):Connect(function()
				text.Text = source.Text
			end)
		end
	end
	model.Parent = map
end

function VoteService.init()
	DebugService.register(
		"vote",
		"Event vote: open the ballot now, vote, or show the tally",
		"vote [open|<1-3>|tally]",
		function(player, args)
			local sub = args[1] or "open"
			if sub == "open" then
				return VoteService.open()
			elseif sub == "tally" then
				local b = ballot
				if not b then
					return false, "no ballot"
				end
				return true, HttpService:JSONEncode(counts(b))
			end
			local b = ballot
			local index = b and OrderOffers.validIndex(tonumber(sub), #b.options)
			if not index then
				return false, "usage: vote [open|<1-3>|tally]"
			end
			return VoteService.cast(player, index)
		end
	)
end

function VoteService.start()
	-- Disaster of the week (#224): tell each courier once they settle in.
	Players.PlayerAdded:Connect(function(player)
		task.delay(Tuning.Featured.joinHintDelaySeconds, function()
			local id = EventService.getFeatured()
			if player.Parent and id then
				Net.event("Hint"):FireClient(
					player,
					`⭐ Disaster of the week: {names[id] or id}! It comes more often and its challenge pays double.`
				)
			end
		end)
	end)
	buildBoard()
	EventService.setNextPicker(takeWinner)
	Net.onServerEvent("CastVote", { ratePerSecond = 2, burst = 3 }, function(player, raw)
		local b = ballot
		if not b then
			return
		end
		local index = OrderOffers.validIndex(raw, #b.options)
		if index then
			VoteService.cast(player, index)
		end
	end)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.5)
			local total, left = EventService.getCalm()
			-- A MEGA or the finale takes this slot; outside the calm there is
			-- nothing to vote on.
			local blocked = EventService.isMegaPending() or FinaleService.blocksVote()
			if not total or not left or blocked then
				close()
			elseif
				not ballot
				and EventVote.shouldOpen(total, left, cfg :: any)
				and not EventService.hasQueuedOrder()
			then
				VoteService.open()
			end
			tick += 1
			if tick % 2 == 0 then
				renderBoard() -- the finale clock
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local b = ballot
		if b and b.votes[player.UserId] then
			b.votes[player.UserId] = nil
			publish()
		end
	end)
end

return VoteService
