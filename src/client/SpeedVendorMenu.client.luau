local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local upgradePanel = body:WaitForChild("UpgradePanel")
local buyButton = upgradePanel:WaitForChild("BuyButton")
local buyButtonTextLabel = buyButton:WaitForChild("TextLabel")
local upgradeLabel = upgradePanel:WaitForChild("UpgradeLabel")

assert(speedMenu:IsA("GuiObject"), "[SpeedVendorMenu] MainGui.SpeedMenu must be a GuiObject")
assert(closeButton:IsA("GuiButton"), "[SpeedVendorMenu] SpeedMenu.Header.CloseButton must be a GuiButton")
assert(buyButton:IsA("GuiButton"), "[SpeedVendorMenu] SpeedMenu.Body.UpgradePanel.BuyButton must be a GuiButton")
assert(buyButtonTextLabel:IsA("TextLabel"), "[SpeedVendorMenu] BuyButton.TextLabel must be a TextLabel")
assert(upgradeLabel:IsA("TextLabel"), "[SpeedVendorMenu] UpgradeLabel must be a TextLabel")

local function setUpgradePairText(displayCurrentLevel: number, displayNextLevel: number)
	local replacement = `{displayCurrentLevel} > {displayNextLevel}`
	local updatedText, replacementCount = string.gsub(upgradeLabel.Text, "%d+%s*>%s*%d+", replacement, 1)
	if replacementCount == 0 then
		updatedText = `+1 Speed ({replacement})`
	end
	upgradeLabel.Text = updatedText
end

local function formatCost(cost: number): string
	return "$" .. tostring(math.floor(cost))
end

local function applyState(state: { [string]: any })
	local displayCurrentLevel = state.displayCurrentLevel
	local displayNextLevel = state.displayNextLevel
	local nextUpgradeCost = state.nextUpgradeCost
	local canAfford = state.canAfford

	if
		typeof(displayCurrentLevel) ~= "number"
		or typeof(displayNextLevel) ~= "number"
		or typeof(nextUpgradeCost) ~= "number"
		or typeof(canAfford) ~= "boolean"
	then
		return
	end

	setUpgradePairText(displayCurrentLevel, displayNextLevel)
	buyButtonTextLabel.Text = formatCost(nextUpgradeCost)
	buyButton.Active = canAfford
	buyButton.AutoButtonColor = canAfford
	speedMenu.Visible = true
end

closeButton.Activated:Connect(function()
	speedMenu.Visible = false
end)

buyButton.Activated:Connect(function()
	requestSpeedUpgradeRemote:FireServer()
end)

speedVendorStateRemote.OnClientEvent:Connect(function(state: { [string]: any })
	if typeof(state) ~= "table" then
		return
	end

	applyState(state)
end)

speedMenu.Visible = false
