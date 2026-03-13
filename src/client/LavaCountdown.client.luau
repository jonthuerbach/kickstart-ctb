local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lavaCountdownRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LavaCountdown") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LavaCountdownGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "CountdownLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.fromScale(0.5, 0.1)
label.BackgroundTransparency = 1
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.FredokaOne
label.Visible = false
label.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
stroke.Thickness = 0.1
stroke.LineJoinMode = Enum.LineJoinMode.Round
stroke.Parent = label

lavaCountdownRemote.OnClientEvent:Connect(function(count: number)
	if count <= 0 then
		label.Visible = false
		return
	end

	label.Text = `Lava rising in {count}`
	label.Visible = true
end)
