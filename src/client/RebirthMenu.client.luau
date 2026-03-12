local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local rebirthMenu = mainGui:FindFirstChild("RebirthMenu")
local playerButtons = mainGui:FindFirstChild("PlayerButtons")
local rebirthFrame = playerButtons:FindFirstChild("RebirthFrame")
local rebirthMenuButton = rebirthFrame:FindFirstChild("RebirthMenuButton")
local rebirthMenuCloseButton = rebirthMenu:FindFirstChild("Header"):FindFirstChild("CloseButton")
local rebirthButton = rebirthMenu:FindFirstChild("Body"):FindFirstChild("Requires"):FindFirstChild("RebirthButton")

assert(rebirthMenu:IsA("GuiObject"), "[RebirthMenu] MainGui.RebirthMenu must be a GuiObject")
assert(rebirthMenuButton:IsA("GuiButton"), "[RebirthMenu] PlayerButtons.RebirthFrame.RebirthButton must be a GuiButton")

rebirthMenu.Visible = false

rebirthMenuButton.Activated:Connect(function()
	if rebirthMenu.Visible then
		rebirthMenu.Visible = false
	else
		rebirthMenu.Visible = true
	end
end)

rebirthMenuCloseButton.Activated:Connect(function()
	rebirthMenu.Visible = false
end)

rebirthButton.Activated:Connect(function()
	-- TODO: Implement rebirth logic
end)
