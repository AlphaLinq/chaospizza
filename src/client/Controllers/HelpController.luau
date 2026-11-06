--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Help)
local Panel = require(script.Parent.Parent.Util.CommunityPanel)
local View = require(script.Parent.Parent.Util.ShopView)
local Diagram = require(script.Parent.Parent.Util.HelpIllustration)
local HelpController = {}
local screen: ScreenGui? = nil
function HelpController.start()
	local ui = Panel.new("Help", Config.title)
	screen = ui.screen
	ui.status.Text = Config.summary
	for index, page in Config.pages do
		local card = Instance.new("Frame")
		card.Name, card.LayoutOrder = page.id, index
		card.Size = UDim2.new(1, -8, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = View.colors.row
		card.Parent = ui.scroll
		View.round(card)
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0, 12)
		padding.Parent = card
		Diagram.mount(card, page.id)
		local title = View.label(card, "Heading", page.title, 20)
		title.Font = Enum.Font.FredokaOne
		title.Position, title.Size = UDim2.fromOffset(88, 12), UDim2.new(1, -100, 0, 64)
		local body = View.label(card, "Instruction", page.body, 17)
		body.Position, body.Size = UDim2.fromOffset(12, 88), UDim2.new(1, -24, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.TextYAlignment = Enum.TextYAlignment.Top
	end
end
function HelpController.destroy()
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return HelpController
