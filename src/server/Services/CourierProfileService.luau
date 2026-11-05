--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local Summary = require(ReplicatedStorage.Shared.Util.CourierProfile).new(
	require(ReplicatedStorage.Shared.Config.Customers),
	require(ReplicatedStorage.Shared.Config.Rarities),
	require(script.Parent.EconomyService).getProgression().levelFromXp
)
local Likes = require(ReplicatedStorage.Shared.Util.PizzeriaLikes).new(
	require(ReplicatedStorage.Shared.Config.PizzeriaLikes)
)
local CourierProfileService = {}
local connections: { [Player]: RBXScriptConnection } = {}
function CourierProfileService.refresh(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local title = player:GetAttribute("CourierTitle")
	local dto = Summary(
		profile,
		Likes.count(profile.likes, os.time()),
		if type(title) == "string" then title else nil
	)
	dto.userId, dto.name = player.UserId, player.DisplayName
	player:SetAttribute("CourierProfile", HttpService:JSONEncode(dto))
end
function CourierProfileService.init()
	DebugService.register(
		"courierprofile",
		"Publish your read-only courier profile",
		"courierprofile",
		function(player)
			CourierProfileService.refresh(player)
			return true, tostring(player:GetAttribute("CourierProfile"))
		end
	)
end
function CourierProfileService.start()
	DataService.onLoaded(CourierProfileService.refresh)
	DataService.onUpdated(CourierProfileService.refresh)
	local function attach(player: Player)
		connections[player] = player:GetAttributeChangedSignal("CourierTitle"):Connect(function()
			CourierProfileService.refresh(player)
		end)
		CourierProfileService.refresh(player)
	end
	Players.PlayerAdded:Connect(attach)
	for _, player in Players:GetPlayers() do
		attach(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local c = connections[player]
		if c then
			c:Disconnect()
		end
		connections[player] = nil
	end)
end
return CourierProfileService
