local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MYTHIC_SPAWN_INTERVAL_SECONDS = 5 * 60

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MythicCountdownGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "MythicCountdownLabel"
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -24, 1, -24)
label.Size = UDim2.fromOffset(360, 44)
label.BackgroundTransparency = 1
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.FredokaOne
label.TextXAlignment = Enum.TextXAlignment.Right
label.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
stroke.Thickness = 0.06
stroke.LineJoinMode = Enum.LineJoinMode.Round
stroke.Parent = label

local function getSecondsUntilNextMythicWindow(serverNowSeconds: number): number
	local remainder = serverNowSeconds % MYTHIC_SPAWN_INTERVAL_SECONDS
	if remainder == 0 then
		return 0
	end

	return MYTHIC_SPAWN_INTERVAL_SECONDS - remainder
end

local function formatAsMmSs(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

task.spawn(function()
	while true do
		local serverNow = math.floor(Workspace:GetServerTimeNow())
		local remaining = getSecondsUntilNextMythicWindow(serverNow)
		label.Text = `Mythic Spawns In: {formatAsMmSs(remaining)}`
		task.wait(1)
	end
end)
