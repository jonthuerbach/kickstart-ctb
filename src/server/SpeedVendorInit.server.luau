local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local speedVendorStateRemote = remotes:WaitForChild("SpeedVendorState") :: RemoteEvent
local requestSpeedUpgradeRemote = remotes:WaitForChild("RequestSpeedUpgrade") :: RemoteEvent

local speedVendorPrompt = Workspace:WaitForChild("World")
	:WaitForChild("Vendors")
	:WaitForChild("SpeedVendorBooth")
	:WaitForChild("SpeedVendor")
	:WaitForChild("ProximityPrompt")

assert(speedVendorPrompt:IsA("ProximityPrompt"), "[SpeedVendorInit] Expected SpeedVendor ProximityPrompt.")

local purchaseInFlight: { [Player]: boolean } = {}

local function updateSpeedDisplay(player: Player, speedLevel: number)
	player:SetAttribute("SpeedDisplay", speedLevel + 1)
end

local function getSpeedVendorState(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	local nextUpgradeCost = MovementConfig.GetSpeedUpgradeCost(speedLevel)
	local money = profile.Data.Money
	local canAfford = typeof(money) == "number" and money >= nextUpgradeCost

	return {
		speedLevel = speedLevel,
		displayCurrentLevel = speedLevel + 1,
		displayNextLevel = speedLevel + 2,
		nextUpgradeCost = nextUpgradeCost,
		canAfford = canAfford,
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

requestSpeedUpgradeRemote.OnServerEvent:Connect(function(player: Player)
	if purchaseInFlight[player] then
		return
	end
	purchaseInFlight[player] = true

	local profile = DataManager.Profiles[player]
	if not profile then
		purchaseInFlight[player] = nil
		return
	end

	local speedLevel = DataManager.GetSpeedLevel(player)
	local nextUpgradeCost = MovementConfig.GetSpeedUpgradeCost(speedLevel)
	local money = profile.Data.Money

	if typeof(money) ~= "number" or money < nextUpgradeCost then
		sendState(player)
		purchaseInFlight[player] = nil
		return
	end

	DataManager.UpdateMoney(player, -nextUpgradeCost)
	local upgradedSpeedLevel = speedLevel + 1
	DataManager.SetSpeedLevel(player, upgradedSpeedLevel)
	updateSpeedDisplay(player, upgradedSpeedLevel)
	applyCurrentSpeedToCharacter(player)
	sendState(player)

	purchaseInFlight[player] = nil
end)

Players.PlayerRemoving:Connect(function(player: Player)
	purchaseInFlight[player] = nil
end)
