--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config.BookExtras)
local Spots = require(ReplicatedStorage.Shared.Config.Collectibles).spots
local Logic = require(ReplicatedStorage.Shared.Util.BookExtras)
local Data = require(script.Parent.DataService)
local Customers = require(script.Parent.CustomerService)
local Golden = require(script.Parent.CollectiblesService)
local Debug = require(script.Parent.DebugService)
local Service = {}
function Service.refresh(player: Player)
	local book, golden = Customers.getBook(player), Golden.getState(player)
	if not book or not golden then
		return
	end
	local encoded = HttpService:JSONEncode(Logic.snapshot(book, golden, Spots))
	if player:GetAttribute("BookExtras") ~= encoded then
		player:SetAttribute("BookExtras", encoded)
	end
end
function Service.init()
	Debug.register(
		"bookextras",
		"Read known requests and golden collection clues",
		"bookextras",
		function(player)
			Service.refresh(player)
			return player:GetAttribute("BookExtras") ~= nil,
				tostring(player:GetAttribute("BookExtras"))
		end
	)
end
function Service.start()
	Data.onLoaded(Service.refresh)
	Data.onUpdated(Service.refresh)
	for _, player in Players:GetPlayers() do
		Service.refresh(player)
	end
	task.spawn(function()
		while true do
			task.wait(Config.refreshSeconds)
			for _, player in Players:GetPlayers() do
				Service.refresh(player)
			end
		end
	end)
end
return Service
