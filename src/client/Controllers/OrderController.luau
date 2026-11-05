--!strict
-- Client side of orders: target marker, direction beam, off-screen arrow and
-- the local "Deliver" prompt at the door. Purely visual + intent: the server
-- (OrderService) decides everything. State comes from player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local CustomerFigure = require(script.Parent.Parent.Util.CustomerFigure)

local RARITY: { [string]: { color: Color3, order: number } } = {}
for _, r in Rarities do
	RARITY[r.id] = { color = Color3.fromHex(r.colorHex), order = r.order }
end
local GLOW_FROM = (RARITY.Epic and RARITY.Epic.order) or 4

local OrderController = {}

local player = Players.LocalPlayer

local targetFolder: Folder? = nil
local beam: Beam? = nil
local characterAttachment: Attachment? = nil
local arrow: TextLabel? = nil
local distanceLabel: TextLabel? = nil
local renderConnection: RBXScriptConnection? = nil
local figure: CustomerFigure.Figure? = nil
local figureConnection: RBXScriptConnection? = nil

local function clearFigure()
	if figureConnection then
		figureConnection:Disconnect()
		figureConnection = nil
	end
	if figure then
		figure.leave()
		figure = nil
	end
end

local function clearTarget()
	clearFigure()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if targetFolder then
		targetFolder:Destroy()
		targetFolder = nil
	end
	if beam then
		beam:Destroy()
		beam = nil
	end
	if characterAttachment then
		characterAttachment:Destroy()
		characterAttachment = nil
	end
	if arrow then
		arrow.Visible = false
	end
end

local function makeArrowGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "OrderArrow"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Text arrow (no image asset needed); rotated toward the target.
	local image = Instance.new("TextLabel")
	image.Name = "Arrow"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromOffset(56, 56)
	image.BackgroundTransparency = 1
	image.Font = Enum.Font.GothamBlack
	image.TextSize = 48
	image.Text = "▲"
	image.TextColor3 = Color3.fromHex("#FFD24A")
	image.TextStrokeTransparency = 0.2
	image.Visible = false
	image.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Distance"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 0)
	label.Size = UDim2.fromOffset(80, 20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Visible = false
	label.Parent = gui -- not a child of the arrow, so it never rotates
	gui.Parent = player:WaitForChild("PlayerGui")
	arrow = image
	distanceLabel = label
end

local function showTarget(
	position: Vector3,
	label: string,
	customer: string,
	orderId: string,
	withPrompt: boolean
)
	clearTarget()

	local f = Instance.new("Folder")
	f.Name = "LocalOrderTarget"

	-- Local anchor part (exists even if the map is streamed out on this client)
	local anchor = Instance.new("Part")
	anchor.Name = "Target"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = f

	-- Glowing ring on the ground where to stand
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromHex("#FFD24A")
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.2, 9, 9)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = f

	-- Billboard marker, always on top
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#FFD24A")
	text.TextStrokeTransparency = 0.2
	text.Text = `🍕 {customer}\n{label}`
	text.Parent = billboard
	billboard.Parent = anchor

	-- Local delivery prompt: Triggered only fires here; the server validates.
	-- Giant orders deliver automatically when the box reaches the door.
	if withPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Deliver pizza"
		prompt.ObjectText = customer
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Tuning.Orders.deliveryRadiusStuds
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = anchor
		prompt.Triggered:Connect(function()
			Net.event("DeliverOrder"):FireServer(orderId)
		end)
	end

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	f.Parent = Workspace
	targetFolder = f

	-- The customer waits at the door (local figure, rarity-coloured hat).
	local rarityId = tostring(
		player:GetAttribute(if withPrompt then "OrderRarity" else "GiantRarity") or "Common"
	)
	local info = RARITY[rarityId] or RARITY.Common
	local seed = 0
	for i = 1, #customer do
		seed = (seed * 31 + string.byte(customer, i)) % 2147483647
	end
	figure = CustomerFigure.new(
		position - Vector3.new(0, 3, 0),
		info.color,
		info.order >= GLOW_FROM,
		seed
	)
	figureConnection = RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if figure then
			figure.step(dt, if root and root:IsA("BasePart") then root.Position else nil)
		end
	end)

	-- Direction beam from the character to the target
	local function attachBeam()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "OrderBeamAttachment"
		a0.Position = Vector3.new(0, -2, 0)
		a0.Parent = root
		characterAttachment = a0
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = targetAttachment
		b.Color = ColorSequence.new(Color3.fromHex("#FFD24A"))
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		b.Width0 = 0.6
		b.Width1 = 0.6
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = f
		beam = b
	end
	attachBeam()

	-- Off-screen arrow
	renderConnection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not camera or not arrow or not distanceLabel or not root then
			return
		end
		local distance = (root.Position - position).Magnitude
		distanceLabel.Text = `{math.floor(distance)} m`
		local screen, onScreen = camera:WorldToViewportPoint(position)
		local viewport = camera.ViewportSize
		if onScreen and screen.Z > 0 then
			arrow.Visible = false
			distanceLabel.Visible = false
			return
		end
		arrow.Visible = true
		distanceLabel.Visible = true
		local center = viewport / 2
		local dir = Vector2.new(screen.X, screen.Y) - center
		if screen.Z < 0 then
			dir = -dir
		end
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, -1)
		end
		dir = dir.Unit
		local margin = 70
		local edge = Vector2.new(viewport.X / 2 - margin, viewport.Y / 2 - margin)
		local scale = math.min(
			edge.X / math.max(math.abs(dir.X), 1e-3),
			edge.Y / math.max(math.abs(dir.Y), 1e-3)
		)
		local pos = center + dir * scale
		arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
		distanceLabel.Position = UDim2.fromOffset(pos.X, pos.Y + 30)
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
	end)
end

local function refresh()
	local giantId = player:GetAttribute("GiantOrderId")
	local giantTarget = player:GetAttribute("GiantTarget")
	local orderId = player:GetAttribute("OrderId")
	local target = player:GetAttribute("OrderTarget")
	if typeof(giantId) == "string" and typeof(giantTarget) == "Vector3" then
		showTarget(
			giantTarget,
			tostring(player:GetAttribute("GiantLabel") or ""),
			`GIANT · {player:GetAttribute("GiantCustomer") or "Customer"}`,
			giantId,
			false
		)
	elseif typeof(orderId) == "string" and typeof(target) == "Vector3" then
		showTarget(
			target,
			tostring(player:GetAttribute("OrderLabel") or ""),
			tostring(player:GetAttribute("OrderCustomer") or "Customer"),
			orderId,
			true
		)
	else
		clearTarget()
	end
end

function OrderController.start()
	makeArrowGui()
	player:GetAttributeChangedSignal("OrderId"):Connect(refresh)
	-- The same order can move (flood → balcony).
	player:GetAttributeChangedSignal("OrderTarget"):Connect(refresh)
	player:GetAttributeChangedSignal("GiantOrderId"):Connect(refresh)
	player:GetAttributeChangedSignal("GiantTarget"):Connect(refresh)
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 5)
			refresh()
		end)
	end)
	refresh()
end

return OrderController
