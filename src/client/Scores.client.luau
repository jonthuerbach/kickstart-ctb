-- src/client/Timer.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")
local blueTeamFrame = screenGui:WaitForChild("BlueTeamFrame")
local blueTeamText = blueTeamFrame:WaitForChild("BlueTextLabel")
local redTeamFrame = screenGui:WaitForChild("RedTeamFrame")
local redTeamText = redTeamFrame:WaitForChild("RedTextLabel")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateScores = remotes:WaitForChild("UpdateScores")

UpdateScores.OnClientEvent:Connect(function(scores: { [string]: number })
	for team, score in scores do
		if team == GameConfig.Teams[1].name then
			blueTeamText.Text = tostring(score)
		else
			redTeamText.Text = tostring(score)
		end
	end
end)
