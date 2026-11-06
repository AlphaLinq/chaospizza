--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Util.Settings).new(
	require(ReplicatedStorage.Shared.Config.Settings)
)
local AccessibilityController = {}
local own = {
	CustomerBook = true,
	Help = true,
	Shop = true,
	Daily = true,
	Settings = true,
	Cosmetics = true,
	Rides = true,
	CourierProfile = true,
	Visits = true,
	Emotes = true,
}
local panels: { [GuiObject]: any } = {}
local connections: { RBXScriptConnection } = {}
local function apply()
	local scale = Settings.textScale(Players.LocalPlayer)
	for panel, data in panels do
		if not panel.Parent then
			panels[panel] = nil
		else
			if not data.constraint then
				local c = panel:FindFirstChildOfClass("UISizeConstraint")
				if c then
					data.constraint, data.max, data.min = c, c.MaxSize, c.MinSize
				end
			end
			data.scale.Scale = scale
			local size = data.size
			panel.Size = UDim2.new(
				size.X.Scale / scale,
				size.X.Offset / scale,
				size.Y.Scale / scale,
				size.Y.Offset / scale
			)
			if data.constraint then
				data.constraint.MaxSize = data.max / scale
				data.constraint.MinSize = data.min / scale
			end
		end
	end
end
function AccessibilityController.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function inspect(instance: Instance)
		if
			not instance:IsA("Frame")
			or not (
				instance.Name == "Panel"
				or instance.Name == "ShopPanel"
				or instance.Name == "BookPanel"
			)
		then
			return
		end
		local screen = instance:FindFirstAncestorOfClass("ScreenGui")
		if not screen or not own[screen.Name] or panels[instance] then
			return
		end
		local constraint = instance:FindFirstChildOfClass("UISizeConstraint")
		local scale = Instance.new("UIScale")
		scale.Name = "TextPreferenceScale"
		scale.Parent = instance
		panels[instance] = {
			size = instance.Size,
			constraint = constraint,
			max = if constraint then constraint.MaxSize else Vector2.zero,
			min = if constraint then constraint.MinSize else Vector2.zero,
			scale = scale,
		}
		task.defer(apply)
	end
	for _, instance in pg:GetDescendants() do
		inspect(instance)
	end
	table.insert(connections, pg.DescendantAdded:Connect(inspect))
	table.insert(
		connections,
		Players.LocalPlayer:GetAttributeChangedSignal("TextSize"):Connect(apply)
	)
end
function AccessibilityController.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for panel, data in panels do
		if panel.Parent then
			data.scale:Destroy()
			panel.Size = data.size
			if data.constraint then
				data.constraint.MaxSize = data.max
				data.constraint.MinSize = data.min
			end
		end
	end
	table.clear(panels)
end
return AccessibilityController
