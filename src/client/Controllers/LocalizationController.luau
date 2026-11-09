--!strict
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Localize = require(ReplicatedStorage.Shared.Util.Localize)
local Text = require(ReplicatedStorage.Shared.Util.LocalizedText)
local Config = require(ReplicatedStorage.Shared.Config.Localization)
local translate = Localize.new(require(ReplicatedStorage.Shared.Config.Strings))
local LocalizationController = {}
local alive = false
local records: { [Instance]: any } = {}
local connections: { RBXScriptConnection } = {}
function LocalizationController.start()
	if alive then
		return
	end
	alive = true
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	if not alive then
		return
	end
	local function locale(): string
		return Localize.locale(
			pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		)
	end
	local function apply(instance: any, record: any)
		local current = instance[record.property]
		local rendered = Text.render(record.state, current, locale(), translate)
		if current ~= rendered then
			instance[record.property] = rendered
		end
	end
	local function inspect(instance: Instance)
		if
			records[instance]
			or not (
				instance:IsA("TextLabel")
				or instance:IsA("TextButton")
				or instance:IsA("TextBox")
			)
		then
			return
		end
		local screen = instance:FindFirstAncestorOfClass("ScreenGui")
		if not screen or not Config.screens[screen.Name] then
			return
		end
		local property = if instance:IsA("TextBox") then "PlaceholderText" else "Text"
		local record: any = { property = property, state = Text.new((instance :: any)[property]) }
		records[instance] = record
		record.changed = instance:GetPropertyChangedSignal(property):Connect(function()
			if alive then
				apply(instance, record)
			end
		end)
		record.destroying = instance.Destroying:Connect(function()
			record.changed:Disconnect()
			record.destroying:Disconnect()
			records[instance] = nil
		end)
		apply(instance, record)
	end
	local function refresh()
		for instance, record in records do
			apply(instance, record)
		end
	end
	for _, instance in pg:GetDescendants() do
		inspect(instance)
	end
	table.insert(connections, pg.DescendantAdded:Connect(inspect))
	table.insert(connections, pg:GetAttributeChangedSignal("UILocaleOverride"):Connect(refresh))
	table.insert(
		connections,
		LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(refresh)
	)
end
function LocalizationController.destroy()
	alive = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for instance, record in records do
		record.changed:Disconnect()
		record.destroying:Disconnect()
		if instance.Parent then
			(instance :: any)[record.property] =
				Text.original(record.state, (instance :: any)[record.property])
		end
	end
	table.clear(records)
end
return LocalizationController
