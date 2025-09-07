-- src/client/Timer.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")
local timerFrame = screenGui:WaitForChild("TimerFrame")
local timerText = timerFrame:WaitForChild("TimerTextLabel")
local phaseFrame = screenGui:WaitForChild("PhaseFrame")
local phaseText = phaseFrame:WaitForChild("PhaseTextLabel")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateTimer = remotes:WaitForChild("UpdateTimer")

UpdateTimer.OnClientEvent:Connect(function(t: number, phaseName: string)
	timerText.Text = tostring(t)
	phaseText.Text = phaseName
end)
