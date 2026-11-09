--!strict
-- Story orders (#254). Now and then, in the calm and after a few
-- deliveries, the order board's third card is a story chapter
-- (Config/Stories): a fixed everyday customer and address, ×1.5 tips and a
-- line of the story when delivered. Three chapters finish a story (+tips,
-- "📖 Story complete!"); progress is saved in claims["story.<id>"] and the
-- count of finished stories in claims["story.done"].
--
-- OfferService asks StoryService.offer() for the card and calls begin()
-- when it is chosen; StoryService never requires OfferService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Stories = require(ReplicatedStorage.Shared.Config.Stories)
local Story = require(ReplicatedStorage.Shared.Util.Story)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local StoryService = {}

export type Pick = { story: string, chapter: number }
type Active = { orderId: string, story: Story.Def, chapter: number }

local cfg = Tuning.Stories
local byId: { [string]: Story.Def } = {}
for _, s in Stories do
	byId[s.id] = s
end
local active: { [Player]: Active } = {}
local lastChapterAt: { [Player]: number } = {}
local forceNext: { [Player]: boolean } = {}

local function progressOf(player: Player): { [string]: number }?
	local profile = DataService.getProfile(player)
	if not profile then
		return nil
	end
	return Story.fromClaims(profile.claims, Stories :: any)
end

-- A story card for this board, or nil. Returns the spec, the card title
-- line and the pick to hand back to begin().
function StoryService.offer(player: Player): (OrderService.Spec?, string?, Pick?)
	local forced = forceNext[player] == true
	if not forced then
		if EconomyService.getDeliveries(player) < cfg.minDeliveries then
			return nil, nil, nil
		end
		if #EventService.getActiveEvents() > 0 then
			return nil, nil, nil -- stories belong to the calm
		end
		if os.clock() - (lastChapterAt[player] or -math.huge) < cfg.cooldownSeconds then
			return nil, nil, nil
		end
		if math.random() >= cfg.chance then
			return nil, nil, nil
		end
	end
	local progress = progressOf(player)
	if not progress then
		return nil, nil, nil
	end
	local story, chapter = Story.next(Stories :: any, progress)
	if not story or not chapter then
		return nil, nil, nil
	end
	local c = story.chapters[chapter]
	if not MapService.getAddress(c.address) then
		return nil, nil, nil
	end
	forceNext[player] = nil
	local spec: OrderService.Spec = {
		addressId = c.address,
		customerId = c.customer,
		kind = "normal",
		multiplier = cfg.tipMultiplier,
		label = "Story",
	}
	return spec, Story.label(story, chapter), { story = story.id, chapter = chapter }
end

function StoryService.begin(player: Player, orderId: string, pick: Pick)
	local story = byId[pick.story]
	if story then
		active[player] = { orderId = orderId, story = story, chapter = pick.chapter }
		AnalyticsService.custom(player, `story_start_{story.id}`, pick.chapter)
	end
end

local function delivered(player: Player, order: OrderService.Order)
	local a = active[player]
	if not a or a.orderId ~= order.id then
		return
	end
	active[player] = nil
	lastChapterAt[player] = os.clock()
	local story, chapter = a.story, a.chapter
	DataService.update(player, function(profile)
		local key = `story.{story.id}`
		profile.claims[key] = math.max(tonumber(profile.claims[key]) or 0, chapter)
	end)
	local c = story.chapters[chapter]
	Net.event("Hint"):FireClient(player, `📖 "{c.line}"`)
	if Story.isLast(story, chapter) then
		EconomyService.addTips(player, cfg.completeTips, "story")
		DataService.update(player, function(profile)
			profile.claims["story.done"] = (tonumber(profile.claims["story.done"]) or 0) + 1
		end)
		AnalyticsService.custom(player, `story_done_{story.id}`)
		task.delay(3, function()
			if player.Parent then
				Net.event("Hint"):FireClient(
					player,
					`📖 Story complete: {story.title}! {story.ending} +{cfg.completeTips} tips`
				)
			end
		end)
	end
end

function StoryService.init()
	DebugService.register(
		"story",
		"Story orders: show progress, force the next card, or reset",
		"story [show|next|reset]",
		function(player, args)
			local sub = args[1] or "show"
			local progress = progressOf(player)
			if not progress then
				return false, "no profile"
			end
			if sub == "next" then
				forceNext[player] = true
				lastChapterAt[player] = nil
				return true, "the next order board shows a story card"
			elseif sub == "reset" then
				DataService.update(player, function(profile)
					for _, s in Stories do
						profile.claims[`story.{s.id}`] = nil
					end
				end)
				active[player] = nil
				return true, "story progress cleared"
			end
			local parts = {}
			for _, s in Stories do
				table.insert(parts, `{s.id}={progress[s.id] or 0}/{#s.chapters}`)
			end
			return true, table.concat(parts, " ")
		end
	)
end

function StoryService.start()
	OrderService.onDelivered(function(player, order)
		delivered(player, order)
	end)
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		lastChapterAt[player] = nil
		forceNext[player] = nil
	end)
end

return StoryService
