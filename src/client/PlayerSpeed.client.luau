local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local playerInfo = mainGui:WaitForChild("PlayerInfo")
local playerSpeed = playerInfo:WaitForChild("PlayerSpeed")

assert(playerSpeed:IsA("TextLabel"), "[PlayerSpeed] MainGui.PlayerInfo.PlayerSpeed must be a TextLabel")

local function setSpeedText(value: number)
	playerSpeed.Text = `Speed: {math.floor(value)}`
end

local function refreshFromAttribute()
	local speedDisplay = player:GetAttribute("SpeedDisplay")
	if typeof(speedDisplay) ~= "number" then
		return
	end

	setSpeedText(speedDisplay)
end

refreshFromAttribute()
player:GetAttributeChangedSignal("SpeedDisplay"):Connect(function()
	refreshFromAttribute()
end)
