--!strict
-- Local decorative animation: no remotes, velocity writes or gameplay authority.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.MovementUpgrades)
local RideAnimation = {}
function RideAnimation.start(): () -> ()
	local connections: { RBXScriptConnection } = {}
	local characterConnections: { [Player]: RBXScriptConnection } = {}
	local playerConnections: { [Player]: RBXScriptConnection } = {}
	local wheels: { [Motor6D]: { root: BasePart, angle: number, radius: number } } = {}
	local function character(player: Player, model: Model)
		local old = characterConnections[player]
		if old then
			old:Disconnect()
		end
		local function inspect(instance: Instance)
			if not instance:IsA("Motor6D") or instance.Name ~= "RideWheel" then
				return
			end
			local root = model:FindFirstChild("HumanoidRootPart")
			local radius = instance:GetAttribute("Radius")
			if root and root:IsA("BasePart") and type(radius) == "number" and radius > 0 then
				wheels[instance] = { root = root, angle = 0, radius = radius }
			end
		end
		characterConnections[player] = model.DescendantAdded:Connect(inspect)
		for _, instance in model:GetDescendants() do
			inspect(instance)
		end
	end
	local function playerAdded(player: Player)
		playerConnections[player] = player.CharacterAdded:Connect(function(model)
			character(player, model)
		end)
		if player.Character then
			character(player, player.Character)
		end
	end
	table.insert(connections, Players.PlayerAdded:Connect(playerAdded))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			local child = characterConnections[player]
			local parent = playerConnections[player]
			if child then
				child:Disconnect()
			end
			if parent then
				parent:Disconnect()
			end
			characterConnections[player], playerConnections[player] = nil, nil
		end)
	)
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end
	table.insert(
		connections,
		RunService.PreSimulation:Connect(function(dt: number)
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			for motor, state in wheels do
				if not motor.Parent or not state.root.Parent then
					wheels[motor] = nil
				elseif
					(state.root.Position - camera.CFrame.Position).Magnitude
					<= Config.animationDistance
				then
					local speed =
						state.root.AssemblyLinearVelocity:Dot(state.root.CFrame.LookVector)
					state.angle = (
						state.angle
						+ speed / state.radius * math.min(dt, Config.maxAnimationDelta)
					) % (2 * math.pi)
					motor.Transform = CFrame.Angles(state.angle, 0, 0)
				end
			end
		end)
	)
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		for _, connection in playerConnections do
			connection:Disconnect()
		end
		for motor in wheels do
			if motor.Parent then
				motor.Transform = CFrame.identity
			end
		end
		table.clear(wheels)
	end
end
return RideAnimation
