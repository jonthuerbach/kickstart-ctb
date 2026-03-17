local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPedestalUpgradeRemote = remotes:WaitForChild("RequestPedestalUpgrade") :: RemoteEvent

local observedButtons: { [GuiButton]: boolean } = {}

local function observeUpgradeButton(button: GuiButton)
	if observedButtons[button] then
		return
	end
	observedButtons[button] = true

	button.Activated:Connect(function()
		requestPedestalUpgradeRemote:FireServer(button)
	end)

	button.Destroying:Connect(function()
		observedButtons[button] = nil
	end)
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPedestalUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPedestalUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end)
