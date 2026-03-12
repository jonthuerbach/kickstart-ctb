local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)

local observedButtons: { [BasePart]: boolean } = {}

local function formatMoney(amount: number): string
	return NumberFormatter.FormatMoney(amount)
end

local function computeDisplayText(button: BasePart): string?
	local occupied = button:GetAttribute("PedestalOccupied")
	local bankedMoney = button:GetAttribute("PedestalBankedMoney")

	if typeof(occupied) ~= "boolean" or typeof(bankedMoney) ~= "number" then
		return nil
	end

	local normalizedMoney = math.max(0, bankedMoney)
	if not occupied and normalizedMoney <= 0 then
		return ""
	end

	return formatMoney(normalizedMoney)
end

local function updateLabelFromButton(button: BasePart)
	local surfaceGui = button:FindFirstChild("SurfaceGui")
	local moneyLabel = surfaceGui and surfaceGui:FindFirstChild("MoneyLabel")
	if not moneyLabel or not moneyLabel:IsA("TextLabel") then
		return
	end

	local displayText = computeDisplayText(button)
	if displayText == nil then
		return
	end

	moneyLabel.Text = displayText
end

local function observeButton(button: BasePart)
	if observedButtons[button] then
		return
	end
	observedButtons[button] = true

	button:GetAttributeChangedSignal("PedestalOccupied"):Connect(function()
		updateLabelFromButton(button)
	end)
	button:GetAttributeChangedSignal("PedestalBankedMoney"):Connect(function()
		updateLabelFromButton(button)
	end)

	updateLabelFromButton(button)
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("IsPedestalCollectButton") == true then
		observeButton(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("BasePart") and descendant:GetAttribute("IsPedestalCollectButton") == true then
		observeButton(descendant)
	end
end)
