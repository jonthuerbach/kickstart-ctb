local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRebirthRemote = remotes:WaitForChild("RequestRebirth") :: RemoteEvent
local requestRebirthStateRemote = remotes:WaitForChild("RequestRebirthState") :: RemoteEvent
local rebirthStateRemote = remotes:WaitForChild("RebirthState") :: RemoteEvent

local rebirthMenu = mainGui:WaitForChild("RebirthMenu")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local rebirthFrame = playerButtons:WaitForChild("RebirthFrame")
local rebirthMenuButton = rebirthFrame:WaitForChild("RebirthMenuButton")
local indicator = rebirthFrame:WaitForChild("Indicator") :: TextLabel
local rebirthMenuCloseButton = rebirthMenu:WaitForChild("Header"):WaitForChild("CloseButton")
local requiresFrame = rebirthMenu:WaitForChild("Body"):WaitForChild("Requires")
local rebirthButton = requiresFrame:WaitForChild("RebirthButton")
local progressBarOutline = requiresFrame:WaitForChild("ProgressBarOutline")
local progressBar = progressBarOutline:WaitForChild("ProgressBar")
local progressValue = progressBarOutline:WaitForChild("Value")

assert(rebirthMenu:IsA("GuiObject"), "[RebirthMenu] MainGui.RebirthMenu must be a GuiObject")
assert(rebirthMenuButton:IsA("GuiButton"), "[RebirthMenu] PlayerButtons.RebirthFrame.RebirthButton must be a GuiButton")
assert(rebirthMenuCloseButton:IsA("GuiButton"), "[RebirthMenu] RebirthMenu.Header.CloseButton must be a GuiButton")
assert(rebirthButton:IsA("GuiButton"), "[RebirthMenu] RebirthMenu.Body.Requires.RebirthButton must be a GuiButton")
assert(
	progressBar:IsA("GuiObject"),
	"[RebirthMenu] RebirthMenu.Requires.ProgressBarOutline.ProgressBar must be a GuiObject"
)
assert(
	progressValue:IsA("TextLabel"),
	"[RebirthMenu] RebirthMenu.Requires.ProgressBarOutline.Value must be a TextLabel"
)

local MENU_NAME = "RebirthMenu"
local WIGGLE_INTERVAL = 5
local WIGGLE_AMPLITUDES = { 10, -7, 4, -2 }
local WIGGLE_STEP_DURATION = 0.08
local WIGGLE_RETURN_DURATION = 0.1

MenuManager.Register(MENU_NAME, rebirthMenu, {
	onOpen = function()
		requestRebirthStateRemote:FireServer()
	end,
})
MenuManager.AttachHoverPressEffect(rebirthMenuButton)

local requiredDisplayedSpeed = MovementConfig.GetRequiredDisplayedSpeedForRebirthCount(0)

local function getDisplayedSpeed(): number
	local speedDisplay = player:GetAttribute("SpeedDisplay")
	if typeof(speedDisplay) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(speedDisplay))
end

local function updateIndicator(canRebirth: boolean)
	indicator.Visible = canRebirth
end

local function updateProgressUi(displayedSpeed: number, requiredSpeed: number)
	local clampedRequired = math.max(1, math.floor(requiredSpeed))
	local ratio = math.clamp(displayedSpeed / clampedRequired, 0, 1)
	progressBar.Size = UDim2.new(ratio, 0, progressBar.Size.Y.Scale, progressBar.Size.Y.Offset)
	progressValue.Text = `{displayedSpeed}/{clampedRequired} Speed`

	local canRebirth = displayedSpeed >= clampedRequired
	rebirthButton.Active = canRebirth
	rebirthButton.AutoButtonColor = canRebirth
	updateIndicator(canRebirth)
end

local function refreshProgressFromSpeedAttribute()
	updateProgressUi(getDisplayedSpeed(), requiredDisplayedSpeed)
end

local function applyRebirthState(state: { [string]: any })
	local serverRequiredDisplayedSpeed = state.requiredDisplayedSpeed
	local serverDisplayedSpeed = state.displayedSpeed
	if typeof(serverRequiredDisplayedSpeed) ~= "number" or typeof(serverDisplayedSpeed) ~= "number" then
		return
	end

	requiredDisplayedSpeed = math.max(1, math.floor(serverRequiredDisplayedSpeed))
	updateProgressUi(math.max(0, math.floor(serverDisplayedSpeed)), requiredDisplayedSpeed)
end

local function playWiggle()
	local tweenInfo = TweenInfo.new(WIGGLE_STEP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, angle in WIGGLE_AMPLITUDES do
		local tween = TweenService:Create(indicator, tweenInfo, { Rotation = angle })
		tween:Play()
		tween.Completed:Wait()
	end
	local returnTween = TweenService:Create(
		indicator,
		TweenInfo.new(WIGGLE_RETURN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
	returnTween:Play()
	returnTween.Completed:Wait()
end

task.spawn(function()
	while true do
		if indicator.Visible then
			playWiggle()
		end
		task.wait(WIGGLE_INTERVAL)
	end
end)

rebirthMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

rebirthMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)

rebirthButton.Activated:Connect(function()
	requestRebirthRemote:FireServer()
end)

rebirthStateRemote.OnClientEvent:Connect(function(state: { [string]: any })
	if typeof(state) ~= "table" then
		return
	end
	applyRebirthState(state)
end)

player:GetAttributeChangedSignal("SpeedDisplay"):Connect(function()
	refreshProgressFromSpeedAttribute()
end)

requestRebirthStateRemote:FireServer()
refreshProgressFromSpeedAttribute()
