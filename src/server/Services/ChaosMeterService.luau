--!strict
-- City chaos meter (brief ch. 15). Every delivery fills it on the server
-- (double during an event); when full, MEGA CHAOS starts. Fill math lives in
-- the pure Util/ChaosMeterLogic. Replicated as CityState attribute "Chaos" (0–1).
-- At the end of a MEGA the top contributors are announced.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ChaosMeterLogic = require(ReplicatedStorage.Shared.Util.ChaosMeterLogic)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local StyleConfig = require(ReplicatedStorage.Shared.Config.Style)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)
local EventService = require(script.Parent.EventService)
local MapService = require(script.Parent.MapService)
local OrderService = require(script.Parent.OrderService)

local METER_HEIGHT = 22
local METER_COLOR_LOW = Color3.fromHex("#FFD24A")
local METER_COLOR_FULL = Color3.fromHex("#FF3FA4")

local ChaosMeterService = {}

local state: ChaosMeterLogic.State
-- Contribution per UserId for the current fill (names kept so leavers still show).
local contributions: { [number]: { name: string, amount: number } } = {}
local fill: BasePart? = nil
local label: TextLabel? = nil

local function cityState(): Instance?
	return ReplicatedStorage:FindFirstChild("CityState")
end

local function render()
	local value = state.value
	local cs = cityState()
	if cs then
		cs:SetAttribute("Chaos", math.floor(value * 1000 + 0.5) / 1000)
	end
	if fill then
		local height = math.max(0.2, METER_HEIGHT * value)
		local base = fill:GetAttribute("BaseY") :: number
		TweenService:Create(fill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = Vector3.new(fill.Size.X, height, fill.Size.Z),
			CFrame = CFrame.new(fill.Position.X, base + height / 2, fill.Position.Z),
			Color = METER_COLOR_LOW:Lerp(METER_COLOR_FULL, value),
		}):Play()
	end
	if label then
		label.Text = if EventService.isMega()
			then "💥 MEGA CHAOS!"
			elseif EventService.isMegaPending() then "💥 MEGA INCOMING!"
			else `CHAOS {math.floor(value * 100)}%`
	end
end

local function buildMeter()
	local map = MapService.getMapFolder()
	local plaza = map:FindFirstChild("Plaza") or map
	local pos = MapLayout.chaosMeter
	local model = Instance.new("Model")
	model.Name = "ChaosMeter"

	local function part(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: string,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = Color3.fromHex(color)
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local baseY = 0.5
	part(
		"Base",
		Vector3.new(7, 1.5, 7),
		CFrame.new(pos.x, baseY + 0.75, pos.z),
		"#2B2633",
		Enum.Material.SmoothPlastic
	)
	local tube = part(
		"Tube",
		Vector3.new(4, METER_HEIGHT, 4),
		CFrame.new(pos.x, baseY + 1.5 + METER_HEIGHT / 2, pos.z),
		"#BFE9FF",
		Enum.Material.Glass
	)
	tube.Transparency = 0.6
	tube.CanCollide = true
	local f = part(
		"Fill",
		Vector3.new(3.2, 0.2, 3.2),
		CFrame.new(pos.x, baseY + 1.6, pos.z),
		"#FFD24A",
		Enum.Material.Neon
	)
	f.CanCollide = false
	f.CanQuery = false
	f:SetAttribute("BaseY", baseY + 1.5)
	part(
		"Cap",
		Vector3.new(6, 1, 6),
		CFrame.new(pos.x, baseY + 2 + METER_HEIGHT, pos.z),
		"#2B2633",
		Enum.Material.SmoothPlastic
	)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 250
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#FFF3D6")
	text.TextStrokeTransparency = 0.2
	text.Text = "CHAOS 0%"
	text.Parent = billboard
	billboard.Parent = model:FindFirstChild("Cap")

	model.Parent = plaza
	fill = f
	label = text
end

local function topContributors(): { string }
	local list = {}
	for _, entry in contributions do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.amount > b.amount
	end)
	local names = {}
	for i = 1, math.min(Tuning.ChaosMeter.topContributors, #list) do
		table.insert(names, list[i].name)
	end
	return names
end

-- Adds one delivery worth of chaos. Returns the new fill (0–1).
function ChaosMeterService.addDelivery(player: Player?): number
	if EventService.isMega() or EventService.isMegaPending() then
		return state.value -- the meter is "spent" until the MEGA ends
	end
	ChaosMeterLogic.setPlayers(state, #Players:GetPlayers())
	local before = state.value
	local value = ChaosMeterLogic.addDelivery(state, EventService.isHazardActive(), os.clock())
	if player then
		local entry = contributions[player.UserId]
		if not entry then
			entry = { name = player.DisplayName, amount = 0 }
			contributions[player.UserId] = entry
		end
		entry.amount += value - before
	end
	if ChaosMeterLogic.isFull(state) then
		EventService.requestMega("meter")
	end
	render()
	return value
end

function ChaosMeterService.getValue(): number
	return state.value
end

function ChaosMeterService.init()
	state = ChaosMeterLogic.new(StyleConfig.chaos, 1, os.clock())

	DebugService.register(
		"chaos",
		"Show / change the city chaos meter",
		"chaos [fill|add <0-1>|reset]",
		function(player, args)
			local sub = args[1]
			if sub == "fill" then
				state.value = 1 - 1e-6
				ChaosMeterService.addDelivery(player)
			elseif sub == "add" then
				local amount = tonumber(args[2] or "")
				if not amount or amount ~= amount or amount < 0 or amount > 1 then
					return false, "usage: chaos add <0-1>"
				end
				state.value = math.min(1 - 1e-6, state.value + amount)
				render()
			elseif sub == "reset" then
				ChaosMeterLogic.reset(state, os.clock())
				table.clear(contributions)
				render()
			elseif sub ~= nil then
				return false, "usage: chaos [fill|add <0-1>|reset]"
			end
			return true,
				`chaos={math.floor(state.value * 1000) / 10}% players={state.players} mega={EventService.isMega()} pending={EventService.isMegaPending()}`
		end
	)
end

function ChaosMeterService.start()
	buildMeter()
	render()

	OrderService.onDelivered(function(player)
		ChaosMeterService.addDelivery(player)
	end)

	EventService.onStarted(function(_, by)
		if by == "mega" then
			render()
		end
	end)
	EventService.onEnded(function(_, by)
		if by ~= "mega" then
			return
		end
		local names = topContributors()
		ChaosMeterLogic.reset(state, os.clock())
		table.clear(contributions)
		render()
		if #names > 0 then
			Net.event("Hint"):FireAllClients(`🏆 Top chaos couriers: {table.concat(names, ", ")}`)
		end
	end)
end

return ChaosMeterService
