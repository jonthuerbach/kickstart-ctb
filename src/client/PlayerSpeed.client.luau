local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local playerInfo = mainGui:WaitForChild("PlayerInfo")
local playerSpeed = playerInfo:WaitForChild("PlayerSpeed")

assert(playerSpeed:IsA("TextLabel"), "[PlayerSpeed] MainGui.PlayerInfo.PlayerSpeed must be a TextLabel")

local leaderstats = player:WaitForChild("leaderstats")
local speedValue = leaderstats:WaitForChild("Speed") :: NumberValue

local function setSpeedText(value: number)
	playerSpeed.Text = `Speed: {math.floor(value)}`
end

setSpeedText(speedValue.Value)
speedValue:GetPropertyChangedSignal("Value"):Connect(function()
	setSpeedText(speedValue.Value)
end)
