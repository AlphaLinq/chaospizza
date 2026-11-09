--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.BatchAudio)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local dayModule = ReplicatedStorage.Shared.Util:FindFirstChild("DayCycle")
local Day: any = if dayModule then require(dayModule) else nil
local Logic = require(ReplicatedStorage.Shared.Util.BatchAudio)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.SoundController)
local Controller = {}
local alive = false
local connections: { RBXScriptConnection } = {}
local function decode(raw: any): any
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(data) == "table" then data else nil
end
local function play(cues: { string })
	for _, cue in cues do
		Sound.play(cue)
		if cue == "RushStart" then
			Sound.play("RushDrum")
		end
	end
end
function Controller.start()
	if alive then
		return
	end
	alive = true
	local player = Players.LocalPlayer
	local city = ReplicatedStorage:WaitForChild("CityState")
	if not alive then
		return
	end
	local state = Logic.new()
	local function rush(emit: boolean)
		local data = decode(city:GetAttribute("CityRush"))
		play(Logic.rush(state, data and data.combo, emit))
	end
	local function errand(emit: boolean)
		play(Logic.errand(state, decode(player:GetAttribute("Errand")), emit))
	end
	local function hero(emit: boolean)
		play(
			Logic.hero(
				state,
				player:GetAttribute("FinaleHeroUntil"),
				Workspace:GetServerTimeNow(),
				emit
			)
		)
	end
	-- A joining courier hears future transitions, never past rewards or rings.
	rush(false)
	errand(false)
	hero(false)
	table.insert(
		connections,
		city:GetAttributeChangedSignal("CityRush"):Connect(function()
			rush(true)
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal("Errand"):Connect(function()
			errand(true)
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal("FinaleHeroUntil"):Connect(function()
			hero(true)
		end)
	)
	table.insert(
		connections,
		Net.event("Hint").OnClientEvent:Connect(function(raw)
			local cue = Logic.hint(raw, Config)
			if cue then
				Sound.play(cue)
			end
		end)
	)
	local function tick()
		if not Sound.isReady() then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local closest: Vector3? = nil
		local distance = Config.hearingStuds
		if root and root:IsA("BasePart") then
			for _, courier in Players:GetPlayers() do
				local model = courier.Character
				local box = model and model:FindFirstChild("PizzaBox")
				local golden = courier:GetAttribute("GoldenOrder")
				if (golden == "shiny" or golden == "scuffed") and box and box:IsA("BasePart") then
					local delta = (box.Position - root.Position).Magnitude
					if delta <= distance then
						closest, distance = box.Position, delta
					end
				end
			end
		end
		Sound.setSpatialLoop(if closest then "GoldenSparkLoop" else nil, closest, "golden")
		local night = false
		if Day and Tuning.DayCycle and city:GetAttribute("EventPhase") == "calm" then
			local offset = city:GetAttribute("DayOffset")
			local fraction = Day.fraction(
				Workspace:GetServerTimeNow(),
				if type(offset) == "number" then offset else 0,
				Tuning.DayCycle
			)
			night = Day.phase(fraction, Tuning.DayCycle) == "night"
		end
		Sound.setBed(if night then "NightAmbience" else nil)
	end
	local elapsed = Config.pollSeconds
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= Config.pollSeconds then
				elapsed = 0
				tick()
			end
		end)
	)
end
function Controller.destroy()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	Sound.setSpatialLoop(nil, nil, "golden")
	Sound.setBed(nil)
end
return Controller
