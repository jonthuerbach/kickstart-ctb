local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")

local shopMenu = mainGui:WaitForChild("ShopMenu")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local shopFrame = playerButtons:WaitForChild("ShopFrame")
local shopMenuButton = shopFrame:WaitForChild("ShopMenuButton")
local shopMenuCloseButton = shopMenu:WaitForChild("Header"):WaitForChild("CloseButton")

assert(shopMenu:IsA("GuiObject"), "[ShopMenu] MainGui.ShopMenu must be a GuiObject")
assert(shopMenuButton:IsA("GuiButton"), "[ShopMenu] PlayerButtons.ShopFrame.ShopMenuButton must be a GuiButton")
assert(shopMenuCloseButton:IsA("GuiButton"), "[ShopMenu] ShopMenu.Header.CloseButton must be a GuiButton")

local MENU_NAME = "ShopMenu"

MenuManager.Register(MENU_NAME, shopMenu)
MenuManager.AttachHoverPressEffect(shopMenuButton)

shopMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

shopMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)
