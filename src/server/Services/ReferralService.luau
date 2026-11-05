--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Community)
local Logic = require(ReplicatedStorage.Shared.Util.Referrals).new(
	Config,
	require(ReplicatedStorage.Shared.Util.RewardGrant).apply
)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local Transaction = require(script.Parent.Parent.Util.PlayerTransaction)
local ReferralService = {}
local joined: { [Player]: number } = {}
local busy = false
function ReferralService.reward(a: Player, b: Player): boolean
	if a == b or a.Parent ~= Players or b.Parent ~= Players then
		return false
	end
	local facts = {
		friends = false,
		secondsA = os.clock() - (joined[a] or os.clock()),
		secondsB = os.clock() - (joined[b] or os.clock()),
		ageA = a.AccountAge,
		ageB = b.AccountAge,
	}
	if
		facts.secondsA < Config.minimumSessionSeconds
		or facts.secondsB < Config.minimumSessionSeconds
		or facts.ageA < Config.minimumAccountDays
		or facts.ageB < Config.minimumAccountDays
	then
		return false
	end
	local p, q = DataService.getProfile(a), DataService.getProfile(b)
	local now = os.time()
	if
		not p
		or not q
		or (p.claims[Logic.key(b.UserId, now)] and q.claims[Logic.key(a.UserId, now)])
	then
		return false
	end
	local ok, friends = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	if not ok or not friends or a.Parent ~= Players or b.Parent ~= Players then
		return false
	end
	facts.friends = true
	local awarded = false
	for _, pair in { { a, b }, { b, a } } do
		local committed = Transaction.run(pair[1], function(profile)
			local accepted = Logic.apply(profile, pair[1].UserId, pair[2].UserId, os.time(), facts)
			return accepted,
				if accepted
					then "Friend join reward delivered!"
					else "Daily friend reward already claimed or capped."
		end, "friend_join")
		awarded = committed or awarded
	end
	return awarded
end
function ReferralService.scan()
	if busy then
		return
	end
	busy = true
	local players = Players:GetPlayers()
	for i, a in players do
		for j = i + 1, #players do
			ReferralService.reward(a, players[j])
		end
	end
	busy = false
end
function ReferralService.init()
	DebugService.register(
		"friends",
		"Check actual friend joins (no eligibility bypass)",
		"friends",
		function()
			ReferralService.scan()
			return true, "Friend scan complete."
		end
	)
end
function ReferralService.start()
	Players.PlayerAdded:Connect(function(player)
		joined[player] = os.clock()
	end)
	for _, player in Players:GetPlayers() do
		joined[player] = os.clock()
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.scanSeconds)
			ReferralService.scan()
		end
	end)
end
return ReferralService
