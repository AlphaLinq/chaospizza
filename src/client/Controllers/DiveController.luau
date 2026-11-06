--!strict
-- Dive (#169): press jump again while airborne to dive forward. The courier
-- tips forward (a short tumble in the Physics state), slides on their belly
-- and gets up — like a knockback recovery, but voluntary and aimed where you
-- face when you press. Works with every jump input (keyboard, touch
-- jump button, gamepad) through JumpRequest. Held keys repeat JumpRequest
-- every frame, so a dive needs a fresh press (a short gap between requests).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DiveController = {}

local player = Players.LocalPlayer
local cfg = Tuning.Dive

local lastRequest = 0
local airborneSince: number? = nil
local divedThisAir = false
local lastDive = -math.huge
local diving = false

local function isAirborne(humanoid: Humanoid): boolean
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function dive(humanoid: Humanoid, root: BasePart)
	diving = true
	divedThisAir = true
	lastDive = os.clock()
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	local right = flat:Cross(Vector3.yAxis)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	local vy = math.max(root.AssemblyLinearVelocity.Y, 0) + cfg.upBoost
	root.AssemblyLinearVelocity = flat * cfg.speed + Vector3.new(0, vy, 0)
	-- pitch forward onto the belly
	root.AssemblyAngularVelocity = right * -7
	Net.event("Dive"):FireServer()
	task.spawn(function()
		-- fly until we touch down (or a safety timeout), then slide
		local t0 = os.clock()
		while os.clock() - t0 < 1.5 and humanoid.Health > 0 do
			task.wait()
			if root.AssemblyLinearVelocity.Y <= 0.5 and os.clock() - t0 > 0.15 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { root.Parent :: Instance }
				if workspace:Raycast(root.Position, Vector3.new(0, -3, 0), params) then
					break
				end
			end
		end
		root.AssemblyAngularVelocity = Vector3.zero
		local slideUntil = os.clock() + cfg.slideSeconds
		while os.clock() < slideUntil and humanoid.Health > 0 do
			local k = (slideUntil - os.clock()) / cfg.slideSeconds
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = flat * cfg.speed * 0.5 * k
				+ Vector3.new(0, math.min(v.Y, 0), 0)
			task.wait()
		end
		root.AssemblyLinearVelocity = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
		-- stand up facing the dive direction
		root.CFrame = CFrame.lookAt(
			root.Position + Vector3.new(0, 1.5, 0),
			root.Position + Vector3.new(0, 1.5, 0) + flat
		)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		diving = false
	end)
end

function DiveController.start()
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastRequest > cfg.freshPressGap
		lastRequest = now
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or diving then
			return
		end
		if player:GetAttribute("Knocked") or player:GetAttribute("BubbleRide") then
			return -- knocked couriers can't dive; in a bubble, jump pops it
		end
		if not isAirborne(humanoid) then
			airborneSince = nil
			divedThisAir = false
			return
		end
		local since = airborneSince
		if
			fresh
			and not divedThisAir
			and since ~= nil
			and now - since >= cfg.minAirSeconds
			and now - lastDive >= cfg.cooldownSeconds
		then
			dive(humanoid, root)
		end
	end)
	-- track take-off / landing
	local function hook(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
				if not airborneSince then
					airborneSince = os.clock()
				end
			elseif
				new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			then
				airborneSince = nil
				divedThisAir = false
			end
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

return DiveController
