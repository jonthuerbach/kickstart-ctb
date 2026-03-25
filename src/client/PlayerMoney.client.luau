local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)
local updateMoneyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateMoney") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local playerInfo = mainGui:WaitForChild("PlayerInfo")
local playerMoney = playerInfo:WaitForChild("PlayerMoney")

local leaderstats = player:WaitForChild("leaderstats")
local moneyValue = leaderstats:WaitForChild("Money") :: NumberValue

local function setMoneyText(value: number)
	playerMoney.Text = NumberFormatter.FormatMoney(value)
end

setMoneyText(moneyValue.Value)

updateMoneyRemote.OnClientEvent:Connect(function(money: number)
	setMoneyText(money)
end)
