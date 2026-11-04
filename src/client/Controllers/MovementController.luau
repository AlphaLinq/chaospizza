--!strict
-- Forgiving jumps (brief ch. 7): coyote time (jump shortly after leaving a
-- ledge) and jump buffering (jump pressed shortly before landing still jumps).
-- Client-only feel; the server still owns speed (CharacterService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local MovementController = {}

local player = Players.LocalPlayer

local connections: { RBXScriptConnection } = {}

local function disconnectAll()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

local function setup(character: Model)
	disconnectAll()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local lastGrounded = os.clock()
	local jumpedSinceGrounded = false
	local bufferedAt = -math.huge

	table.insert(
		connections,
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				jumpedSinceGrounded = true
			elseif
				new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			then
				lastGrounded = os.clock()
				jumpedSinceGrounded = false
				if os.clock() - bufferedAt <= Tuning.Movement.jumpBufferSeconds then
					bufferedAt = -math.huge
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.JumpRequest:Connect(function()
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				lastGrounded = os.clock()
				return -- normal jump, the engine handles it
			end
			local state = humanoid:GetState()
			if
				state == Enum.HumanoidStateType.Freefall
				and not jumpedSinceGrounded
				and os.clock() - lastGrounded <= Tuning.Movement.coyoteTimeSeconds
			then
				jumpedSinceGrounded = true
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			else
				bufferedAt = os.clock()
			end
		end)
	)

	-- Track the last moment we stood on something (for coyote time).
	table.insert(
		connections,
		humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				lastGrounded = os.clock()
				jumpedSinceGrounded = false
			end
		end)
	)
end

function MovementController.start()
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return MovementController
