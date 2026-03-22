local Players = game:GetService("Players")

local STEP_ATTRIBUTE = "TutorialStep"
local STEP_NONE = 0
local STEP_MESSAGES: { [number]: string } = {
	[1] = "Go get a brainrot!",
	[2] = "Place the brainrot in your base!",
	[3] = "Go upgrade your speed!",
}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TutorialStepGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "TutorialStepLabel"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -56)
label.Size = UDim2.fromScale(0.6, 0.07)
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

local function refreshTutorialLabel()
	local stepValue = localPlayer:GetAttribute(STEP_ATTRIBUTE)
	local step = if typeof(stepValue) == "number" then math.floor(stepValue) else STEP_NONE
	local message = STEP_MESSAGES[step]
	if message then
		label.Text = message
		label.Visible = true
		return
	end

	label.Text = ""
	label.Visible = false
end

localPlayer:GetAttributeChangedSignal(STEP_ATTRIBUTE):Connect(refreshTutorialLabel)
refreshTutorialLabel()
