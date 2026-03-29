local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local RewardsCatalog = require(ReplicatedStorage.Shared.Catalogs.RewardsCatalog)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRewardsStateRemote = remotes:WaitForChild("RequestRewardsState") :: RemoteEvent
local rewardsStateRemote = remotes:WaitForChild("RewardsState") :: RemoteEvent
local requestCollectRewardRemote = remotes:WaitForChild("RequestCollectReward") :: RemoteEvent

local FLUSH_INTERVAL = 60

local joinTimestamps: { [Player]: number } = {}
local collectInFlight: { [Player]: boolean } = {}

local function getElapsedSeconds(player: Player): number?
	local rewards = DataManager.GetRewardsData(player)
	if not rewards then
		return nil
	end

	local savedElapsed = rewards.ElapsedSeconds
	if typeof(savedElapsed) ~= "number" then
		savedElapsed = 0
	end

	local joinedAt = joinTimestamps[player]
	if not joinedAt then
		return savedElapsed
	end

	return savedElapsed + (os.time() - joinedAt)
end

local function flushElapsed(player: Player)
	local elapsed = getElapsedSeconds(player)
	if elapsed == nil then
		return
	end

	DataManager.SetRewardsElapsed(player, elapsed)
	joinTimestamps[player] = os.time()
end

local function initRewardsCycle(player: Player)
	local rewards = DataManager.GetRewardsData(player)
	if not rewards then
		return
	end

	local now = os.time()
	local cycleStart = rewards.CycleStart
	if typeof(cycleStart) ~= "number" or cycleStart <= 0 then
		DataManager.ResetRewardsCycle(player, now)
	elseif (now - cycleStart) >= RewardsCatalog.CYCLE_DURATION_SECONDS then
		DataManager.ResetRewardsCycle(player, now)
	end

	joinTimestamps[player] = now
end

local function buildRewardsState(player: Player): { [string]: any }?
	local elapsed = getElapsedSeconds(player)
	if elapsed == nil then
		return nil
	end

	local rewards = DataManager.GetRewardsData(player)
	if not rewards then
		return nil
	end

	local collected = rewards.Collected
	local collectedCopy = {}
	for i = 1, RewardsCatalog.REWARD_COUNT do
		collectedCopy[i] = if typeof(collected) == "table" and collected[i] == true then true else false
	end

	return {
		elapsedSeconds = elapsed,
		collected = collectedCopy,
	}
end

local function sendRewardsState(player: Player)
	local state = buildRewardsState(player)
	if not state then
		return
	end

	rewardsStateRemote:FireClient(player, state)
end

local function pickRandomBrainrot(rarity: string): string?
	local entries = BrainrotCatalog.Names[rarity]
	if not entries or #entries == 0 then
		return nil
	end

	local entry = entries[math.random(1, #entries)]
	return entry.modelName
end

local function grantReward(player: Player, slotIndex: number): boolean
	local entry = RewardsCatalog.Rewards[slotIndex]
	if not entry then
		return false
	end

	if entry.rewardType == "Money" then
		DataManager.UpdateMoney(player, entry.amount)
		return true
	elseif entry.rewardType == "Brainrot" then
		local modelName = pickRandomBrainrot(entry.rarity)
		if not modelName then
			return false
		end

		local count = BrainrotToolManager.AddOwnedTool(player, entry.rarity, modelName, false)
		return count > 0
	end

	return false
end

requestRewardsStateRemote.OnServerEvent:Connect(function(player: Player)
	flushElapsed(player)
	sendRewardsState(player)
end)

requestCollectRewardRemote.OnServerEvent:Connect(function(player: Player, slotIndex: unknown)
	if typeof(slotIndex) ~= "number" then
		return
	end

	local slotInt = math.floor(slotIndex)
	if slotInt < 1 or slotInt > RewardsCatalog.REWARD_COUNT then
		return
	end

	if collectInFlight[player] then
		return
	end
	collectInFlight[player] = true

	local profile = DataManager.Profiles[player]
	if not profile then
		collectInFlight[player] = nil
		return
	end

	if DataManager.IsRewardCollected(player, slotInt) then
		sendRewardsState(player)
		collectInFlight[player] = nil
		return
	end

	flushElapsed(player)

	local elapsed = getElapsedSeconds(player)
	if elapsed == nil then
		collectInFlight[player] = nil
		return
	end

	local entry = RewardsCatalog.Rewards[slotInt]
	if not entry then
		collectInFlight[player] = nil
		return
	end

	local requiredSeconds = entry.timeMinutes * 60
	if elapsed < requiredSeconds then
		sendRewardsState(player)
		collectInFlight[player] = nil
		return
	end

	local granted = grantReward(player, slotInt)
	if granted then
		DataManager.SetRewardCollected(player, slotInt)
	end

	sendRewardsState(player)
	collectInFlight[player] = nil
end)

local function onPlayerReady(player: Player)
	while player.Parent == Players and not DataManager.Profiles[player] do
		task.wait(0.2)
	end

	if not DataManager.Profiles[player] then
		return
	end

	initRewardsCycle(player)
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerReady, player)
end

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(onPlayerReady, player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if DataManager.Profiles[player] and joinTimestamps[player] then
		flushElapsed(player)
	end

	joinTimestamps[player] = nil
	collectInFlight[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		for _, player in Players:GetPlayers() do
			if DataManager.Profiles[player] and joinTimestamps[player] then
				flushElapsed(player)
			end
		end
	end
end)
