local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local speedVendorStateRemote = remotes:WaitForChild("SpeedVendorState") :: RemoteEvent
local requestSpeedUpgradeRemote = remotes:WaitForChild("RequestSpeedUpgrade") :: RemoteEvent

local speedVendor =
	Workspace:WaitForChild("World"):WaitForChild("Vendors"):WaitForChild("SpeedVendorBooth"):WaitForChild("SpeedVendor")
local speedVendorHumanoid = speedVendor:WaitForChild("Humanoid")
local speedVendorPrompt = speedVendor:WaitForChild("ProximityPrompt")

speedVendorHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

assert(speedVendorPrompt:IsA("ProximityPrompt"), "[SpeedVendorInit] Expected SpeedVendor ProximityPrompt.")

local purchaseInFlight: { [Player]: boolean } = {}
local VALID_UPGRADE_COUNTS = {
	[1] = true,
	[5] = true,
	[10] = true,
}

local function updateSpeedDisplay(player: Player, speedLevel: number)
	player:SetAttribute("SpeedDisplay", speedLevel + 1)
end

local function getSpeedVendorState(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	local money = profile.Data.Money
	local costX1 = MovementConfig.GetSpeedUpgradeBundleCost(speedLevel, 1)
	local costX5 = MovementConfig.GetSpeedUpgradeBundleCost(speedLevel, 5)
	local costX10 = MovementConfig.GetSpeedUpgradeBundleCost(speedLevel, 10)
	local numericMoney = if typeof(money) == "number" then money else 0

	return {
		speedLevel = speedLevel,
		displayCurrentLevel = speedLevel + 1,
		displayNextLevel = speedLevel + 2,
		costX1 = costX1,
		costX5 = costX5,
		costX10 = costX10,
		canAffordX1 = numericMoney >= costX1,
		canAffordX5 = numericMoney >= costX5,
		canAffordX10 = numericMoney >= costX10,
	}
end

local function applyCurrentSpeedToCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	humanoid.WalkSpeed = MovementConfig.GetWalkSpeedForLevel(speedLevel)
end

local function sendState(player: Player)
	local state = getSpeedVendorState(player)
	if not state then
		return
	end

	updateSpeedDisplay(player, state.speedLevel)
	speedVendorStateRemote:FireClient(player, state)
end

speedVendorPrompt.Triggered:Connect(function(player: Player)
	sendState(player)
end)

requestSpeedUpgradeRemote.OnServerEvent:Connect(function(player: Player, requestedCount: number?)
	if purchaseInFlight[player] then
		return
	end
	purchaseInFlight[player] = true

	local profile = DataManager.Profiles[player]
	if not profile then
		purchaseInFlight[player] = nil
		return
	end

	local upgradeCount = if typeof(requestedCount) == "number" then math.floor(requestedCount) else 1
	if not VALID_UPGRADE_COUNTS[upgradeCount] then
		sendState(player)
		purchaseInFlight[player] = nil
		return
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	local totalUpgradeCost = MovementConfig.GetSpeedUpgradeBundleCost(speedLevel, upgradeCount)
	local money = profile.Data.Money

	if typeof(money) ~= "number" or money < totalUpgradeCost then
		sendState(player)
		purchaseInFlight[player] = nil
		return
	end

	DataManager.UpdateMoney(player, -totalUpgradeCost)
	local upgradedSpeedLevel = speedLevel + upgradeCount
	DataManager.SetSpeedLevel(player, upgradedSpeedLevel)
	updateSpeedDisplay(player, upgradedSpeedLevel)
	applyCurrentSpeedToCharacter(player)
	sendState(player)

	purchaseInFlight[player] = nil
end)

Players.PlayerRemoving:Connect(function(player: Player)
	purchaseInFlight[player] = nil
end)
