--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.LoopAudio)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout)
local geometry = ReplicatedStorage.Shared.Util:FindFirstChild("MicroChaos")
local Micro: any = if geometry then require(geometry) else nil
local Logic = require(ReplicatedStorage.Shared.Util.LoopAudio)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.SoundController)
local Controller = {}
local alive = false
local connections: { RBXScriptConnection } = {}
local buttons: { [Instance]: RBXScriptConnection } = {}
local function decode(raw: any): any
	if type(raw) ~= "string" then
		return nil
	end
	local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(result) == "table" then result else nil
end
function Controller.start()
	if alive then
		return
	end
	-- Parallel workspaces may not have Claude's loop producers synced yet.
	if not Micro or not Tuning.Finale or not Tuning.MicroChaos then
		warn("[LoopAudioController] Loop systems unavailable; audio adapter disabled.")
		return
	end
	alive = true
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local city = ReplicatedStorage:WaitForChild("CityState")
	if not alive then
		return
	end
	local state = Logic.new()
	local micro = decode(city:GetAttribute("MicroChaos"))
	local ballot = decode(city:GetAttribute("EventVote"))
	local function play(cues: { string })
		for _, cue in cues do
			Sound.play(cue)
		end
	end
	local function tick()
		if not Sound.isReady() then
			return
		end
		local now = Workspace:GetServerTimeNow()
		play(
			Logic.finale(
				state,
				now,
				city:GetAttribute("FinaleAt"),
				city:GetAttribute("Finale") == true,
				Tuning.Finale.noticeSeconds,
				Config
			)
		)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local at: Vector3? = nil
		local calm = city:GetAttribute("EventPhase") == "calm"
		if calm and root and root:IsA("BasePart") and micro then
			local ok, point = pcall(function()
				if micro.kind == "Cart" then
					return Micro.moverAt(micro.from, micro.to, micro.t0, micro.speed, now, 0)
				elseif micro.kind == "Geese" then
					local closest, distance = nil, math.huge
					for i = 0, math.min(micro.count or 1, Tuning.MicroChaos.kinds.Geese.count) - 1 do
						local candidate = Micro.moverAt(
							micro.from,
							micro.to,
							micro.t0,
							micro.speed,
							now,
							i * (micro.spacing or 0)
						)
						if candidate then
							local delta = (root.Position.X - candidate.x) ^ 2
								+ (root.Position.Z - candidate.z) ^ 2
							if delta < distance then
								closest, distance = candidate, delta
							end
						end
					end
					return closest
				end
				return micro.spot
			end)
			if
				ok
				and type(point) == "table"
				and type(point.x) == "number"
				and type(point.z) == "number"
			then
				at = Vector3.new(point.x, MapLayout.streetY + 1, point.z)
			end
		end
		local near = at ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and (root.Position - at).Magnitude <= Config.hearingStuds
		Sound.setSpatialLoop(
			if near and micro.kind == "Cart" then "CartRattle" else nil,
			if near then at else nil
		)
		play(Logic.micro(state, if calm then micro else nil, now, near, Config))
	end
	table.insert(
		connections,
		city:GetAttributeChangedSignal("MicroChaos"):Connect(function()
			micro = decode(city:GetAttribute("MicroChaos"))
		end)
	)
	table.insert(
		connections,
		city:GetAttributeChangedSignal("EventVote"):Connect(function()
			ballot = decode(city:GetAttribute("EventVote"))
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
	local function vote(index: number)
		if
			ballot
			and type(ballot.options) == "table"
			and ballot.options[index]
			and type(ballot.endsAt) == "number"
			and ballot.endsAt > Workspace:GetServerTimeNow()
		then
			Sound.play("VoteCast")
		end
	end
	local function inspect(instance: Instance)
		if not instance:IsA("TextButton") or buttons[instance] then
			return
		end
		local screen = instance:FindFirstAncestorOfClass("ScreenGui")
		local index = tonumber(string.match(instance.Name, "^Vote([123])$"))
		if screen and screen.Name == "EventVote" and index then
			buttons[instance] = instance.Activated:Connect(function()
				vote(index)
			end)
		end
	end
	for _, instance in pg:GetDescendants() do
		inspect(instance)
	end
	table.insert(connections, pg.DescendantAdded:Connect(inspect))
	table.insert(
		connections,
		pg.DescendantRemoving:Connect(function(instance)
			local c = buttons[instance]
			if c then
				c:Disconnect()
				buttons[instance] = nil
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local index = table.find(Config.voteKeys, input.KeyCode.Name)
			if index then
				vote(index)
			end
		end)
	)
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
	for _, c in connections do
		c:Disconnect()
	end
	for _, c in buttons do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(buttons)
	Sound.setSpatialLoop(nil, nil)
end
return Controller
