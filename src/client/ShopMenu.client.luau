local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestGamePassRemote = remotes:WaitForChild("RequestGamePass") :: RemoteEvent

local shopMenu = mainGui:WaitForChild("ShopMenu")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local shopFrame = playerButtons:WaitForChild("ShopFrame")
local shopMenuButton = shopFrame:WaitForChild("ShopMenuButton")
local shopMenuCloseButton = shopMenu:WaitForChild("Header"):WaitForChild("CloseButton")

local gamepassFrame = shopMenu
	:WaitForChild("Body")
	:WaitForChild("ScrollingFrame")
	:WaitForChild("GamepassFrame")

local vipButton = gamepassFrame
	:WaitForChild("VIPFrame")
	:WaitForChild("CanvasGroup")
	:WaitForChild("ButtonFrame")
	:WaitForChild("VIPGamepassButton")

local twoXMoneyButton = gamepassFrame
	:WaitForChild("2XFrame")
	:WaitForChild("CanvasGroup")
	:WaitForChild("ButtonFrame")
	:WaitForChild("2XGamepassButton")

assert(shopMenu:IsA("GuiObject"), "[ShopMenu] MainGui.ShopMenu must be a GuiObject")
assert(shopMenuButton:IsA("GuiButton"), "[ShopMenu] PlayerButtons.ShopFrame.ShopMenuButton must be a GuiButton")
assert(shopMenuCloseButton:IsA("GuiButton"), "[ShopMenu] ShopMenu.Header.CloseButton must be a GuiButton")
assert(vipButton:IsA("GuiButton"), "[ShopMenu] VIPGamepassButton must be a GuiButton")
assert(twoXMoneyButton:IsA("GuiButton"), "[ShopMenu] 2XGamepassButton must be a GuiButton")

local MENU_NAME = "ShopMenu"
local OWNED_GRADIENT_LIGHT = Color3.fromRGB(180, 180, 180)
local OWNED_GRADIENT_DARK = Color3.fromRGB(120, 120, 120)
local OWNED_GRADIENT_ROTATION = 90

type GamepassEntry = {
	button: GuiButton,
	passName: string,
	attributeName: string,
}

local gamepassEntries: { GamepassEntry } = {
	{ button = vipButton, passName = "VIP", attributeName = "GamePassVIP" },
	{ button = twoXMoneyButton, passName = "2XMoney", attributeName = "GamePass2XMoney" },
}

local function applyOwnedState(button: GuiButton)
	button.Active = false
	button.AutoButtonColor = false

	if button:FindFirstChild("OwnedGradient") then
		return
	end

	local gradient = Instance.new("UIGradient")
	gradient.Name = "OwnedGradient"
	gradient.Rotation = OWNED_GRADIENT_ROTATION
	gradient.Color = ColorSequence.new(OWNED_GRADIENT_LIGHT, OWNED_GRADIENT_DARK)
	gradient.Parent = button
end

local function refreshButtonState(entry: GamepassEntry)
	if player:GetAttribute(entry.attributeName) == true then
		applyOwnedState(entry.button)
	end
end

MenuManager.Register(MENU_NAME, shopMenu)
MenuManager.AttachHoverPressEffect(shopMenuButton)

for _, entry in gamepassEntries do
	refreshButtonState(entry)

	player:GetAttributeChangedSignal(entry.attributeName):Connect(function()
		refreshButtonState(entry)
	end)

	entry.button.Activated:Connect(function()
		if player:GetAttribute(entry.attributeName) == true then
			return
		end
		requestGamePassRemote:FireServer(entry.passName)
	end)
end

shopMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

shopMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)
