local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)
local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local speedVendorStateRemote = remotes:WaitForChild("SpeedVendorState") :: RemoteEvent
local requestSpeedUpgradeRemote = remotes:WaitForChild("RequestSpeedUpgrade") :: RemoteEvent

local mainGui = playerGui:WaitForChild("MainGui")
local speedMenu = mainGui:WaitForChild("SpeedMenu")
local header = speedMenu:WaitForChild("Header")
local closeButton = header:WaitForChild("CloseButton")
local body = speedMenu:WaitForChild("Body")
local upgradePanelX1 = body:WaitForChild("UpgradePanelx1")
local upgradePanelX5 = body:WaitForChild("UpgradePanelx5")
local upgradePanelX10 = body:WaitForChild("UpgradePanelx10")

local buyButtonX1 = upgradePanelX1:WaitForChild("BuyButton")
local buyButtonX1TextLabel = buyButtonX1:WaitForChild("TextLabel")
local upgradeLabelX1 = upgradePanelX1:WaitForChild("UpgradeLabel")

local buyButtonX5 = upgradePanelX5:WaitForChild("BuyButton")
local buyButtonX5TextLabel = buyButtonX5:WaitForChild("TextLabel")
local upgradeLabelX5 = upgradePanelX5:WaitForChild("UpgradeLabel")

local buyButtonX10 = upgradePanelX10:WaitForChild("BuyButton")
local buyButtonX10TextLabel = buyButtonX10:WaitForChild("TextLabel")
local upgradeLabelX10 = upgradePanelX10:WaitForChild("UpgradeLabel")

assert(speedMenu:IsA("GuiObject"), "[SpeedVendorMenu] MainGui.SpeedMenu must be a GuiObject")
assert(closeButton:IsA("GuiButton"), "[SpeedVendorMenu] SpeedMenu.Header.CloseButton must be a GuiButton")
assert(buyButtonX1:IsA("GuiButton"), "[SpeedVendorMenu] SpeedMenu.Body.UpgradePanelx1.BuyButton must be a GuiButton")
assert(
	buyButtonX1TextLabel:IsA("TextLabel"),
	"[SpeedVendorMenu] UpgradePanelx1.BuyButton.TextLabel must be a TextLabel"
)
assert(upgradeLabelX1:IsA("TextLabel"), "[SpeedVendorMenu] UpgradePanelx1.UpgradeLabel must be a TextLabel")
assert(buyButtonX5:IsA("GuiButton"), "[SpeedVendorMenu] SpeedMenu.Body.UpgradePanelx5.BuyButton must be a GuiButton")
assert(
	buyButtonX5TextLabel:IsA("TextLabel"),
	"[SpeedVendorMenu] UpgradePanelx5.BuyButton.TextLabel must be a TextLabel"
)
assert(upgradeLabelX5:IsA("TextLabel"), "[SpeedVendorMenu] UpgradePanelx5.UpgradeLabel must be a TextLabel")
assert(
	buyButtonX10:IsA("GuiButton"),
	"[SpeedVendorMenu] SpeedMenu.Body.UpgradePanelx10.BuyButton must be a GuiButton"
)
assert(
	buyButtonX10TextLabel:IsA("TextLabel"),
	"[SpeedVendorMenu] UpgradePanelx10.BuyButton.TextLabel must be a TextLabel"
)
assert(upgradeLabelX10:IsA("TextLabel"), "[SpeedVendorMenu] UpgradePanelx10.UpgradeLabel must be a TextLabel")

local MENU_NAME = "SpeedMenu"

MenuManager.Register(MENU_NAME, speedMenu)

local function setUpgradeLabelText(label: TextLabel, speedDelta: number, displayCurrentLevel: number)
	local displayTargetLevel = displayCurrentLevel + speedDelta
	local replacement = `{displayCurrentLevel} > {displayTargetLevel}`
	local updatedText, replacementCount = string.gsub(label.Text, "%d+%s*>%s*%d+", replacement, 1)
	if replacementCount == 0 then
		updatedText = `+{speedDelta} Speed ({replacement})`
	end
	label.Text = updatedText
end

local function formatCost(cost: number): string
	return NumberFormatter.FormatMoney(cost)
end

local function applyState(state: { [string]: any })
	local displayCurrentLevel = state.displayCurrentLevel
	local displayNextLevel = state.displayNextLevel
	local costX1 = state.costX1
	local costX5 = state.costX5
	local costX10 = state.costX10
	local canAffordX1 = state.canAffordX1
	local canAffordX5 = state.canAffordX5
	local canAffordX10 = state.canAffordX10

	if
		typeof(displayCurrentLevel) ~= "number"
		or typeof(displayNextLevel) ~= "number"
		or typeof(costX1) ~= "number"
		or typeof(costX5) ~= "number"
		or typeof(costX10) ~= "number"
		or typeof(canAffordX1) ~= "boolean"
		or typeof(canAffordX5) ~= "boolean"
		or typeof(canAffordX10) ~= "boolean"
	then
		return
	end

	setUpgradeLabelText(upgradeLabelX1, 1, displayCurrentLevel)
	setUpgradeLabelText(upgradeLabelX5, 5, displayCurrentLevel)
	setUpgradeLabelText(upgradeLabelX10, 10, displayCurrentLevel)
	buyButtonX1TextLabel.Text = formatCost(costX1)
	buyButtonX5TextLabel.Text = formatCost(costX5)
	buyButtonX10TextLabel.Text = formatCost(costX10)

	buyButtonX1.Active = canAffordX1
	buyButtonX1.AutoButtonColor = canAffordX1
	buyButtonX5.Active = canAffordX5
	buyButtonX5.AutoButtonColor = canAffordX5
	buyButtonX10.Active = canAffordX10
	buyButtonX10.AutoButtonColor = canAffordX10

	if not MenuManager.IsOpen(MENU_NAME) then
		MenuManager.Open(MENU_NAME)
	end
end

closeButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)

buyButtonX1.Activated:Connect(function()
	requestSpeedUpgradeRemote:FireServer(1)
end)

buyButtonX5.Activated:Connect(function()
	requestSpeedUpgradeRemote:FireServer(5)
end)

buyButtonX10.Activated:Connect(function()
	requestSpeedUpgradeRemote:FireServer(10)
end)

speedVendorStateRemote.OnClientEvent:Connect(function(state: { [string]: any })
	if typeof(state) ~= "table" then
		return
	end

	applyState(state)
end)
