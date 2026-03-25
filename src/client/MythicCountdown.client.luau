local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MythicSpawnTimer = require(ReplicatedStorage.Shared.Utils.MythicSpawnTimer)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MythicCountdownGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "CountdownFrame"
frame.AnchorPoint = Vector2.new(1, 1)
frame.Position = UDim2.new(1, -12, 1, -12)
frame.Size = UDim2.fromScale(0.5, 0.10)
frame.BackgroundTransparency = 1
frame.Parent = screenGui

local label = Instance.new("TextLabel")
label.Name = "MythicCountdownLabel"
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, 0, 1, 0)
label.Size = UDim2.fromScale(1, 0.5)
label.BackgroundTransparency = 1
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.FredokaOne
label.TextXAlignment = Enum.TextXAlignment.Right
label.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
stroke.Thickness = 0.1
stroke.LineJoinMode = Enum.LineJoinMode.Round
stroke.Parent = label

local world = Workspace:WaitForChild("World")
local brainrotBillboard = world:WaitForChild("BrainrotBillboard")
local billboardPart = brainrotBillboard:WaitForChild("Billboard")
local display = billboardPart:WaitForChild("Display")
local screen = display:WaitForChild("Screen")
local billboardScreenGui = screen:WaitForChild("ScreenGui")
local billboardFrame = billboardScreenGui:WaitForChild("Frame")
local billboardTimeLabel = billboardFrame:WaitForChild("TimeLabel")
assert(billboardTimeLabel:IsA("TextLabel"), "[MythicCountdown] TimeLabel must be a TextLabel")

task.spawn(function()
	while true do
		local formattedCountdown = MythicSpawnTimer.GetFormattedCountdown(Workspace:GetServerTimeNow())
		label.Text = `Mythic Spawns In: {formattedCountdown}`
		billboardTimeLabel.Text = formattedCountdown
		task.wait(1)
	end
end)
