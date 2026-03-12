local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sellBrainrotActionRemote = remotes:WaitForChild("SellBrainrotAction") :: RemoteEvent
local updateConfirmSellBrainrotActionTextRemote =
	remotes:WaitForChild("UpdateConfirmSellBrainrotActionText") :: RemoteEvent

local toggleSellVendorMenuRemote = remotes:WaitForChild("ToggleSellVendorMenu") :: RemoteEvent
local sellVendorPrompt = Workspace:WaitForChild("World")
	:WaitForChild("Vendors")
	:WaitForChild("SellVendorBooth")
	:WaitForChild("SellVendor")
	:WaitForChild("ProximityPrompt")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local activeSellMenu: BillboardGui? = nil
local buttonsByName: { [string]: TextButton } = {}

local menuOptions = {
	{
		id = "sell_one",
		name = "SellOneButton",
		text = "I wanna sell this brainrot!",
		onClick = function()
			sellBrainrotActionRemote:FireServer("sell_one")
		end,
	},
	{
		id = "sell_all",
		name = "SellAllButton",
		text = "I wanna sell all these brainrots!",
		onClick = function()
			sellBrainrotActionRemote:FireServer("sell_all")
		end,
	},
	{
		id = "check_value",
		name = "CheckValueButton",
		text = "How much is this brainrot worth?",
		onClick = function()
			sellBrainrotActionRemote:FireServer("check_value")
		end,
	},
	{
		id = "close",
		name = "CloseButton",
		text = "Never mind, I am done here. :)",
		onClick = function()
			if activeSellMenu then
				activeSellMenu.Enabled = false
			end
			sellBrainrotActionRemote:FireServer("close")
		end,
	},
}

local DEFAULT_BUTTON_TEXTS = {
	SellOneButton = "I wanna sell this brainrot!",
	SellAllButton = "I wanna sell all these brainrots!",
}

local function isSellVendorPrompt(prompt: ProximityPrompt): boolean
	return prompt == sellVendorPrompt
end

local buildSellMenuButton = function(option, parent: Instance, name: string)
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.Size = UDim2.fromScale(1, 0.2)
	button.Text = ""
	button.Parent = parent

	local sellMenuTextLabel = Instance.new("TextLabel")
	sellMenuTextLabel.Name = "Label"
	sellMenuTextLabel.Size = UDim2.fromScale(1, 1)
	sellMenuTextLabel.BackgroundTransparency = 1
	sellMenuTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellMenuTextLabel.TextScaled = true
	sellMenuTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	sellMenuTextLabel.Font = Enum.Font.FredokaOne
	sellMenuTextLabel.Text = option.text
	sellMenuTextLabel.Parent = button

	local sellMenuTextLabelUiPadding = Instance.new("UIPadding")
	sellMenuTextLabelUiPadding.PaddingLeft = UDim.new(0.05, 0)
	sellMenuTextLabelUiPadding.PaddingRight = UDim.new(0.05, 0)
	sellMenuTextLabelUiPadding.PaddingTop = UDim.new(0.1, 0)
	sellMenuTextLabelUiPadding.PaddingBottom = UDim.new(0.1, 0)
	sellMenuTextLabelUiPadding.Parent = sellMenuTextLabel

	local sellMenuTextLabelStroke = Instance.new("UIStroke")
	sellMenuTextLabelStroke.Color = Color3.fromRGB(0, 0, 0)
	sellMenuTextLabelStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	sellMenuTextLabelStroke.Thickness = 0.08
	sellMenuTextLabelStroke.Parent = sellMenuTextLabel

	button.Activated:Connect(function()
		option.onClick()
	end)

	return button
end

local function setButtonText(buttonName: string, text: string)
	local button = buttonsByName[buttonName]
	if not button then
		return
	end

	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function resetConfirmButtonTexts()
	setButtonText("SellOneButton", DEFAULT_BUTTON_TEXTS.SellOneButton)
	setButtonText("SellAllButton", DEFAULT_BUTTON_TEXTS.SellAllButton)
end

local buildSellMenu = function(head: BasePart): BillboardGui
	local sellMenu = Instance.new("BillboardGui")
	sellMenu.Name = "SellMenu"
	sellMenu.Adornee = head
	sellMenu.Active = true
	sellMenu.Size = UDim2.fromScale(6, 3)
	sellMenu.StudsOffset = Vector3.new(5, 0, 0)
	sellMenu.AlwaysOnTop = true
	sellMenu.ResetOnSpawn = false
	sellMenu.LightInfluence = 0
	sellMenu.Parent = playerGui

	local sellMenuBody = Instance.new("Frame")
	sellMenuBody.Size = UDim2.fromScale(1, 1)
	sellMenuBody.BackgroundTransparency = 1
	sellMenuBody.BorderSizePixel = 0
	sellMenuBody.Active = true
	sellMenuBody.Parent = sellMenu

	local sellMenuUi = Instance.new("UIListLayout")
	sellMenuUi.SortOrder = Enum.SortOrder.LayoutOrder
	sellMenuUi.Padding = UDim.new(0.05, 0)
	sellMenuUi.VerticalAlignment = Enum.VerticalAlignment.Top
	sellMenuUi.HorizontalAlignment = Enum.HorizontalAlignment.Left
	sellMenuUi.Parent = sellMenuBody

	for _, option in ipairs(menuOptions) do
		local button = buildSellMenuButton(option, sellMenuBody, option.name)
		buttonsByName[option.name] = button
	end

	return sellMenu
end

local function bindCharacter(character: Model)
	character:WaitForChild("Humanoid")
	local head = character:WaitForChild("Head")
	assert(head:IsA("BasePart"), "[SellVendorMenu] Character.Head must be a BasePart")

	local existing = playerGui:FindFirstChild("SellMenu")
	if existing and existing:IsA("BillboardGui") then
		local existingMenu = existing :: BillboardGui
		existingMenu.Adornee = head
		activeSellMenu = existingMenu
	else
		activeSellMenu = buildSellMenu(head)
	end

	if activeSellMenu then
		activeSellMenu.Enabled = false
	end
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end

toggleSellVendorMenuRemote.OnClientEvent:Connect(function(visible: boolean)
	print(`[SellVendorMenu] {visible}`)
	if activeSellMenu then
		activeSellMenu.Enabled = visible
	end
	if not visible then
		resetConfirmButtonTexts()
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	if not isSellVendorPrompt(prompt) then
		return
	end

	if activeSellMenu then
		activeSellMenu.Enabled = false
	end
	resetConfirmButtonTexts()
end)

updateConfirmSellBrainrotActionTextRemote.OnClientEvent:Connect(function(name: string, text: string)
	setButtonText(name, text)
end)
