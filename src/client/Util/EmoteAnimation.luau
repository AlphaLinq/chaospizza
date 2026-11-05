--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Emotes)
local EmoteAnimation = {}
function EmoteAnimation.start(): () -> ()
	local active: { [Player]: any } = {}
	local observed: { [Player]: RBXScriptConnection } = {}
	local function reset(player: Player)
		local pose = active[player]
		if pose then
			for _, motor in pose.motors do
				if motor.Parent then
					motor.Transform = CFrame.identity
				end
			end
		end
		active[player] = nil
	end
	local function watch(player: Player)
		observed[player] = player
			:GetAttributeChangedSignal("CourierEmoteStarted")
			:Connect(function()
				reset(player)
				local character = player.Character
				local id, started =
					player:GetAttribute("CourierEmote"), player:GetAttribute("CourierEmoteStarted")
				if not character or type(id) ~= "string" or type(started) ~= "number" then
					return
				end
				local motors = {}
				for _, instance in character:GetDescendants() do
					if
						instance:IsA("Motor6D")
						and (
							instance.Name == "RightShoulder"
							or instance.Name == "Right Shoulder"
							or (
								id ~= "WaveEmote"
								and (
									instance.Name == "LeftShoulder"
									or instance.Name == "Left Shoulder"
								)
							)
						)
					then
						table.insert(motors, instance)
					end
				end
				active[player] =
					{ character = character, id = id, started = started, motors = motors }
			end)
	end
	local connections = {
		Players.PlayerAdded:Connect(watch),
		Players.PlayerRemoving:Connect(function(player)
			reset(player)
			local c = observed[player]
			if c then
				c:Disconnect()
			end
			observed[player] = nil
		end),
	}
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	table.insert(
		connections,
		RunService.PreSimulation:Connect(function()
			for player, pose in active do
				local humanoid = pose.character:FindFirstChildOfClass("Humanoid")
				local t = Workspace:GetServerTimeNow() - pose.started
				if
					player.Character ~= pose.character
					or not humanoid
					or humanoid.Health <= 0
					or humanoid.Sit
					or humanoid.MoveDirection.Magnitude > Config.cancelMoveThreshold
					or t >= Config.durationSeconds
					or t < 0
				then
					reset(player)
				else
					for _, motor in pose.motors do
						local side = if string.find(motor.Name, "Left") then 1 else -1
						motor.Transform = if pose.id == "PizzaPoseEmote"
							then CFrame.Angles(math.rad(-65), 0, side * math.rad(15))
							else CFrame.Angles(
								math.sin(t * 7) * 0.15,
								0,
								side * math.rad(100 + math.sin(t * 9) * 20)
							)
					end
				end
			end
		end)
	)
	return function()
		for player in active do
			reset(player)
		end
		for _, c in connections do
			c:Disconnect()
		end
		for _, c in observed do
			c:Disconnect()
		end
	end
end
return EmoteAnimation
