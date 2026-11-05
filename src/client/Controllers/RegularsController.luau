--!strict
-- Regulars come alive in every pizzeria (brief ch. 10), locally on each client:
-- idle nodding, a slice of pizza now and then, and a cheer (hop + 🎉) when the
-- pizzeria model's "Cheer" attribute changes (owner delivered / emptied the jar).
-- The server only builds the static figures (tag "PizzeriaRegular").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)

local RegularsController = {}

local player = Players.LocalPlayer
local settings = SettingsUtil.new(SettingsConfig)
local ANIMATE_DISTANCE = 120
local EAT_EVERY = { 4, 9 }
local CHEER_SECONDS = 0.6

type Regular = {
	model: Model,
	head: BasePart,
	body: BasePart,
	headBase: CFrame,
	bodyBase: CFrame,
	phase: number,
	nextEat: number,
	slice: BasePart?,
	cheerUntil: number,
}

local regulars: { [Model]: Regular } = {}
local watchedPizzerias: { [Instance]: RBXScriptConnection } = {}

local function cheer(pizzeria: Instance)
	local now = os.clock()
	for model, r in regulars do
		if model.Parent == pizzeria then
			r.cheerUntil = now + CHEER_SECONDS + r.phase % 0.3
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(40, 40)
			billboard.StudsOffset = Vector3.new(0, 2.4, 0)
			billboard.Adornee = r.head
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			label.Text = "🎉"
			label.Parent = billboard
			billboard.Parent = r.head
			TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
			task.delay(1.2, function()
				billboard:Destroy()
			end)
		end
	end
end

local function watchPizzeria(pizzeria: Instance)
	if watchedPizzerias[pizzeria] then
		return
	end
	watchedPizzerias[pizzeria] = pizzeria:GetAttributeChangedSignal("Cheer"):Connect(function()
		cheer(pizzeria)
	end)
	pizzeria.Destroying:Connect(function()
		local connection = watchedPizzerias[pizzeria]
		if connection then
			connection:Disconnect()
		end
		watchedPizzerias[pizzeria] = nil
	end)
end

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local head = instance:WaitForChild("Head", 5)
	local body = instance:WaitForChild("Body", 5)
	if not head or not body or not head:IsA("BasePart") or not body:IsA("BasePart") then
		return
	end
	regulars[instance] = {
		model = instance,
		head = head,
		body = body,
		headBase = head.CFrame,
		bodyBase = body.CFrame,
		phase = math.random() * 10,
		nextEat = os.clock() + EAT_EVERY[1] + math.random() * (EAT_EVERY[2] - EAT_EVERY[1]),
		slice = nil,
		cheerUntil = 0,
	}
	if instance.Parent then
		watchPizzeria(instance.Parent)
	end
end

local function remove(instance: Instance)
	local r = regulars[instance :: Model]
	if r and r.slice then
		r.slice:Destroy()
	end
	regulars[instance :: Model] = nil
end

local function makeSlice(): Part
	local slice = Instance.new("WedgePart")
	slice.Name = "LocalSlice"
	slice.Anchored = true
	slice.CanCollide = false
	slice.CanQuery = false
	slice.CanTouch = false
	slice.CastShadow = false
	slice.Size = Vector3.new(0.2, 0.9, 0.9)
	slice.Color = Color3.fromHex("#FFC94A")
	slice.Parent = Workspace
	return slice :: any
end

local function step(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local me = if root and root:IsA("BasePart") then root.Position else nil
	local now = os.clock()
	local lively = settings.particleScale(player:GetAttribute("EffectQuality")) > 0.3
	for model, r in regulars do
		if not model.Parent then
			remove(model)
			continue
		end
		if me and (r.bodyBase.Position - me).Magnitude > ANIMATE_DISTANCE then
			continue
		end
		local t = now + r.phase
		local hop = 0
		if now < r.cheerUntil then
			hop = math.abs(math.sin((r.cheerUntil - now) / CHEER_SECONDS * math.pi * 2)) * 1.2
		end
		local lift = CFrame.new(0, hop, 0)
		r.body.CFrame = lift * r.bodyBase
		r.head.CFrame = lift
			* r.headBase
			* CFrame.Angles(math.sin(t * 2) * 0.12, math.sin(t * 0.7) * 0.2, 0)
		-- Eating: a slice rises to the mouth and disappears.
		if lively and now >= r.nextEat and not r.slice then
			r.slice = makeSlice()
			r.nextEat = now + 1.2
		end
		local slice = r.slice
		if slice then
			local k = 1 - math.clamp((r.nextEat - now) / 1.2, 0, 1)
			local from = r.bodyBase.Position + Vector3.new(0.9, 0, 0)
			local to = r.headBase.Position + Vector3.new(0.6, -0.3, 0)
			slice.CFrame = CFrame.new(from:Lerp(to, math.min(1, k * 1.6)))
				* CFrame.Angles(0, 0, math.rad(90))
			if k >= 1 then
				slice:Destroy()
				r.slice = nil
				r.nextEat = now + EAT_EVERY[1] + math.random() * (EAT_EVERY[2] - EAT_EVERY[1])
			end
		end
	end
	local _ = dt
end

function RegularsController.start()
	for _, instance in CollectionService:GetTagged("PizzeriaRegular") do
		task.spawn(add, instance)
	end
	CollectionService:GetInstanceAddedSignal("PizzeriaRegular"):Connect(function(instance)
		task.spawn(add, instance)
	end)
	CollectionService:GetInstanceRemovedSignal("PizzeriaRegular"):Connect(remove)
	RunService.Heartbeat:Connect(step)
end

return RegularsController
