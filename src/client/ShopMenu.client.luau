local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)
local DeveloperProductCatalog = require(ReplicatedStorage.Shared.Catalogs.DeveloperProductCatalog)

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

local scrollingFrame = shopMenu:WaitForChild("Body"):WaitForChild("ScrollingFrame")

local gamepassFrame = scrollingFrame:WaitForChild("GamepassFrame")
local gameMoneyFrame = scrollingFrame:WaitForChild("GameMoneyFrame")

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

local cash25KButton = gameMoneyFrame
	:WaitForChild("25KCashFrame")
	:WaitForChild("CanvasGroup")
	:WaitForChild("ButtonFrame")
	:WaitForChild("25KButton")

local cash1MButton = gameMoneyFrame
	:WaitForChild("1MCashFrame")
	:WaitForChild("CanvasGroup")
	:WaitForChild("ButtonFrame")
	:WaitForChild("1MButton")

local cash1BButton = gameMoneyFrame
	:WaitForChild("1BCashFrame")
	:WaitForChild("CanvasGroup")
	:WaitForChild("ButtonFrame")
	:WaitForChild("1BButton")

assert(shopMenu:IsA("GuiObject"), "[ShopMenu] MainGui.ShopMenu must be a GuiObject")
assert(shopMenuButton:IsA("GuiButton"), "[ShopMenu] PlayerButtons.ShopFrame.ShopMenuButton must be a GuiButton")
assert(shopMenuCloseButton:IsA("GuiButton"), "[ShopMenu] ShopMenu.Header.CloseButton must be a GuiButton")
assert(vipButton:IsA("GuiButton"), "[ShopMenu] VIPGamepassButton must be a GuiButton")
assert(twoXMoneyButton:IsA("GuiButton"), "[ShopMenu] 2XGamepassButton must be a GuiButton")
assert(cash25KButton:IsA("GuiButton"), "[ShopMenu] 25KButton must be a GuiButton")
assert(cash1MButton:IsA("GuiButton"), "[ShopMenu] 1MButton must be a GuiButton")
assert(cash1BButton:IsA("GuiButton"), "[ShopMenu] 1BButton must be a GuiButton")

local MENU_NAME = "ShopMenu"
local OWNED_GRADIENT_LIGHT = Color3.fromRGB(180, 180, 180)
local OWNED_GRADIENT_DARK = Color3.fromRGB(120, 120, 120)
local OWNED_GRADIENT_ROTATION = 90

-- Gamepass buttons (one-time purchases, disable when owned)

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

local function refreshGamepassButton(entry: GamepassEntry)
	if player:GetAttribute(entry.attributeName) == true then
		applyOwnedState(entry.button)
	end
end

for _, entry in gamepassEntries do
	refreshGamepassButton(entry)

	player:GetAttributeChangedSignal(entry.attributeName):Connect(function()
		refreshGamepassButton(entry)
	end)

	entry.button.Activated:Connect(function()
		if player:GetAttribute(entry.attributeName) == true then
			return
		end
		requestGamePassRemote:FireServer(entry.passName)
	end)
end

-- Cash buttons (repeatable developer products)

type CashEntry = {
	button: GuiButton,
	productId: number,
}

local cashEntries: { CashEntry } = {
	{ button = cash25KButton, productId = DeveloperProductCatalog.Ids.Cash25K },
	{ button = cash1MButton, productId = DeveloperProductCatalog.Ids.Cash1M },
	{ button = cash1BButton, productId = DeveloperProductCatalog.Ids.Cash1B },
}

for _, entry in cashEntries do
	entry.button.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, entry.productId)
	end)
end

-- Menu open/close

MenuManager.Register(MENU_NAME, shopMenu)
MenuManager.AttachHoverPressEffect(shopMenuButton)

shopMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

shopMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)
