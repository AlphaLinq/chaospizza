--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.Codes)
local View = require(script.Parent.ShopView)
local CodesWidget = {}
function CodesWidget.mount(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "Codes"
	frame.LayoutOrder = 10
	frame.Size = UDim2.new(1, 0, 0, 190)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local title = View.label(frame, "Title", "Promotion codes", 20)
	title.Size = UDim2.new(1, 0, 0, 32)
	local input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.PlaceholderText = "Enter a code"
	input.Text = ""
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.GothamMedium
	input.TextSize = 18
	input.TextColor3 = View.colors.cream
	input.PlaceholderColor3 = View.colors.muted
	input.BackgroundColor3 = View.colors.row
	input.Size = UDim2.new(1, 0, 0, 44)
	input.Position = UDim2.fromOffset(0, 36)
	input.Parent = frame
	View.round(input)
	local redeem = Instance.new("TextButton")
	redeem.Name = "Redeem"
	redeem.Text = "Redeem code"
	redeem.Font = Enum.Font.GothamBold
	redeem.TextSize = 17
	redeem.TextColor3 = View.colors.panel
	redeem.BackgroundColor3 = View.colors.cheese
	redeem.Size = UDim2.new(1, 0, 0, 44)
	redeem.Position = UDim2.fromOffset(0, 88)
	redeem.Parent = frame
	View.round(redeem)
	local result = View.label(frame, "Result", "Codes are free. Each code works once.", 14)
	result.Position = UDim2.fromOffset(0, 140)
	result.Size = UDim2.new(1, 0, 0, 48)
	local pending: string? = nil
	local token = 0
	local function submit()
		if pending then
			return
		end
		if #input.Text == 0 or #input.Text > Config.maxLength then
			result.Text = "Enter a valid code."
			return
		end
		local key = `code:{input.Text}`
		pending = key
		token += 1
		local generation = token
		redeem.Active = false
		result.Text = "Checking your code…"
		Net.event("RequestPurchase"):FireServer(key)
		task.delay(Config.requestTimeoutSeconds, function()
			if frame.Parent and pending and generation == token then
				pending = nil
				redeem.Active = true
				result.Text = "No reply yet. Please try again."
			end
		end)
	end
	redeem.Activated:Connect(submit)
	input.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	local connection = Net.event("PurchaseResult").OnClientEvent
		:Connect(function(_, reason: any, key: any)
			if pending and key == pending then
				pending = nil
				token += 1
				redeem.Active = true
				result.Text = tostring(reason)
			end
		end)
	frame.Destroying:Connect(function()
		connection:Disconnect()
	end)
end
return CodesWidget
