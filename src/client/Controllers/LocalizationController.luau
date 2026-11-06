--!strict
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Localize = require(ReplicatedStorage.Shared.Util.Localize)
local translate = Localize.new(require(ReplicatedStorage.Shared.Config.Strings))
local LocalizationController = {}
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
local records: { [Instance]: any } = {}
local connections: { RBXScriptConnection } = {}
function LocalizationController.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function locale(): string
		return Localize.locale(
			pg:GetAttribute("UILocaleOverride") or LocalizationService.RobloxLocaleId
		)
	end
	local function apply(instance: any, record: any)
		record.writing = true
		instance[record.property] = translate(record.source, locale())
		record.writing = false
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
		if not screen or not own[screen.Name] then
			return
		end
		local property = if instance:IsA("TextBox") then "PlaceholderText" else "Text"
		local record: any =
			{ property = property, source = (instance :: any)[property], writing = false }
		records[instance] = record
		record.changed = instance:GetPropertyChangedSignal(property):Connect(function()
			if not record.writing then
				record.source = (instance :: any)[property]
				apply(instance, record)
			end
		end)
		instance.Destroying:Connect(function()
			record.changed:Disconnect()
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
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for instance, record in records do
		record.changed:Disconnect();
		(instance :: any)[record.property] = record.source
	end
	table.clear(records)
end
return LocalizationController
