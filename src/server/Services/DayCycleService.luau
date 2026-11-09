--!strict
-- Day/night cycle (#217), server side. The clock itself is pure
-- (Util/DayCycle, from server time), so this only owns the debug offset
-- (CityState "DayOffset", seconds) and answers "is it night?" for the
-- Night shift tip bonus (OrderService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DayCycle = require(ReplicatedStorage.Shared.Util.DayCycle)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DebugService = require(script.Parent.DebugService)

local DayCycleService = {}

local cfg = Tuning.DayCycle
local offset = 0

local function fraction(): number
	return DayCycle.fraction(Workspace:GetServerTimeNow(), offset, cfg :: any)
end

function DayCycleService.getPhase(): DayCycle.Phase
	return (DayCycle.phase(fraction(), cfg :: any))
end

function DayCycleService.isNight(): boolean
	return DayCycleService.getPhase() == "night"
end

local function setOffset(seconds: number)
	offset = seconds
	local state = ReplicatedStorage:FindFirstChild("CityState")
	if state then
		state:SetAttribute("DayOffset", if offset ~= 0 then offset else nil)
	end
end

function DayCycleService.init()
	DebugService.register(
		"daytime",
		"Day/night: jump to a phase, or back to the normal clock",
		"daytime [day|dusk|night|dawn|cycle]",
		function(_, args)
			local phase = args[1] or "cycle"
			if phase == "cycle" then
				setOffset(0)
				return true, `normal clock ({DayCycleService.getPhase()})`
			end
			if phase ~= "day" and phase ~= "dusk" and phase ~= "night" and phase ~= "dawn" then
				return false, "usage: daytime [day|dusk|night|dawn|cycle]"
			end
			setOffset(DayCycle.offsetFor(phase :: any, Workspace:GetServerTimeNow(), cfg :: any))
			return true, `now {DayCycleService.getPhase()}`
		end
	)
end

return DayCycleService
