-- src/client/Timer.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")
local phaseFrame = screenGui:WaitForChild("PhaseFrame")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local IsShowingPhase = remotes:WaitForChild("IsShowingPhase")

IsShowingPhase.OnClientEvent:Connect(function(isShowing: boolean)
	phaseFrame.Visible = isShowing
end)
