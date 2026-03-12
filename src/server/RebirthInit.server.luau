local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRebirthRemote = remotes:WaitForChild("RequestRebirth") :: RemoteEvent
local requestRebirthStateRemote = remotes:WaitForChild("RequestRebirthState") :: RemoteEvent
local rebirthStateRemote = remotes:WaitForChild("RebirthState") :: RemoteEvent

local rebirthInFlight: { [Player]: boolean } = {}

local function getDisplayedSpeed(player: Player): number
	return DataManager.GetSpeedLevel(player) + 1
end

local function updateRebirthLeaderstat(player: Player, rebirthCount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local rebirthsValue = leaderstats:FindFirstChild("Rebirths")
	if rebirthsValue and rebirthsValue:IsA("NumberValue") then
		rebirthsValue.Value = math.max(0, math.floor(rebirthCount))
	end
end

local function applyMovementToCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	local rebirthCount = DataManager.GetJumpLevel(player)
	humanoid.WalkSpeed = MovementConfig.GetWalkSpeedForLevel(speedLevel)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = MovementConfig.GetJumpPowerForRebirthCount(rebirthCount)
end

local function buildRebirthState(player: Player): { [string]: any }?
	if not DataManager.Profiles[player] then
		return nil
	end

	local rebirthCount = DataManager.GetJumpLevel(player)
	local requiredDisplayedSpeed = MovementConfig.GetRequiredDisplayedSpeedForRebirthCount(rebirthCount)
	local displayedSpeed = getDisplayedSpeed(player)

	return {
		rebirthCount = rebirthCount,
		requiredDisplayedSpeed = requiredDisplayedSpeed,
		displayedSpeed = displayedSpeed,
		canRebirth = displayedSpeed >= requiredDisplayedSpeed,
	}
end

local function sendRebirthState(player: Player)
	local state = buildRebirthState(player)
	if not state then
		return
	end

	updateRebirthLeaderstat(player, state.rebirthCount)
	player:SetAttribute("SpeedDisplay", state.displayedSpeed)
	rebirthStateRemote:FireClient(player, state)
end

requestRebirthStateRemote.OnServerEvent:Connect(function(player: Player)
	sendRebirthState(player)
end)

requestRebirthRemote.OnServerEvent:Connect(function(player: Player)
	if rebirthInFlight[player] then
		return
	end
	rebirthInFlight[player] = true

	local state = buildRebirthState(player)
	if not state then
		rebirthInFlight[player] = nil
		return
	end

	if state.displayedSpeed < state.requiredDisplayedSpeed then
		sendRebirthState(player)
		rebirthInFlight[player] = nil
		return
	end

	local nextRebirthCount = state.rebirthCount + 1
	DataManager.SetJumpLevel(player, nextRebirthCount)
	DataManager.SetSpeedLevel(player, 0)
	local profile = DataManager.Profiles[player]
	if profile and typeof(profile.Data.Money) == "number" and profile.Data.Money > 0 then
		DataManager.UpdateMoney(player, -profile.Data.Money)
	end
	applyMovementToCharacter(player)
	sendRebirthState(player)

	rebirthInFlight[player] = nil
end)

Players.PlayerRemoving:Connect(function(player: Player)
	rebirthInFlight[player] = nil
end)
