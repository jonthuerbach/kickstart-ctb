local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
assert(progressBar:IsA("GuiObject"), "[RebirthMenu] RebirthMenu.Requires.ProgressBarOutline.ProgressBar must be a GuiObject")
assert(progressValue:IsA("TextLabel"), "[RebirthMenu] RebirthMenu.Requires.ProgressBarOutline.Value must be a TextLabel")

-- Animation config (matches SpeedMenu)
local OPEN_START_SCALE = 0.4
local OPEN_OVERSHOOT_SCALE = 1.08
local CLOSE_END_SCALE = 0.4
local OPEN_DURATION = 0.15
local CLOSE_DURATION = 0.1
local OPEN_PHASE1_RATIO = 0.57
local EASING_UP = Enum.EasingStyle.Quad
local EASING_DIRECTION_OUT = Enum.EasingDirection.Out
local BUTTON_HOVER_SCALE = 1.1
local BUTTON_PRESS_SCALE = 0.8
local BUTTON_HOVER_IN_DURATION = 0.09
local BUTTON_RELEASE_DURATION = 0.08
local BUTTON_PRESS_IN_DURATION = 0.06

local rebirthMenuRestSize = rebirthMenu.Size
local isAnimating = false

local function scaleUDim2(udim2: UDim2, factor: number): UDim2
	return UDim2.new(
		udim2.X.Scale * factor,
		udim2.X.Offset * factor,
		udim2.Y.Scale * factor,
		udim2.Y.Offset * factor
	)
end

local function getOrCreateHoverPressScale(button: GuiButton): UIScale
	local namedScale = button:FindFirstChild("HoverPressScale")
	if namedScale and namedScale:IsA("UIScale") then
		return namedScale
	end

	for _, child in button:GetChildren() do
		if child:IsA("UIScale") then
			return child
		end
	end

	local scale = Instance.new("UIScale")
	scale.Name = "HoverPressScale"
	scale.Scale = 1
	scale.Parent = button
	return scale
end

local function attachSnappyHoverPressEffect(button: GuiButton)
	local scale = getOrCreateHoverPressScale(button)
	local baseScale = scale.Scale
	local isHovered = false
	local isPressed = false
	local activeTween: Tween? = nil
	local activePressInput: InputObject? = nil

	local function isPressInput(userInputType: Enum.UserInputType): boolean
		return userInputType == Enum.UserInputType.MouseButton1 or userInputType == Enum.UserInputType.Touch
	end

	local function tweenScale(targetScale: number, duration: number, easingStyle: Enum.EasingStyle)
		local currentTween = activeTween
		if currentTween then
			currentTween:Cancel()
		end
		local newTween =
			TweenService:Create(scale, TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out), { Scale = targetScale })
		activeTween = newTween
		newTween:Play()
	end

	local function updateButtonScale()
		if isPressed then
			tweenScale(baseScale * BUTTON_PRESS_SCALE, BUTTON_PRESS_IN_DURATION, Enum.EasingStyle.Quad)
			return
		end

		if isHovered then
			tweenScale(baseScale * BUTTON_HOVER_SCALE, BUTTON_HOVER_IN_DURATION, Enum.EasingStyle.Back)
			return
		end

		tweenScale(baseScale, BUTTON_RELEASE_DURATION, Enum.EasingStyle.Quad)
	end

	button.MouseEnter:Connect(function()
		isHovered = true
		updateButtonScale()
	end)

	button.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		updateButtonScale()
	end)

	button.MouseButton1Down:Connect(function()
		-- Mouse fallback for environments where InputBegan may not fire on the button.
		isPressed = true
		activePressInput = nil
		updateButtonScale()
	end)

	button.MouseButton1Up:Connect(function()
		isPressed = false
		activePressInput = nil
		updateButtonScale()
	end)

	button.InputBegan:Connect(function(input: InputObject)
		if not isPressInput(input.UserInputType) then
			return
		end

		isPressed = true
		activePressInput = input
		updateButtonScale()
	end)

	button.InputEnded:Connect(function(input: InputObject)
		if not isPressInput(input.UserInputType) then
			return
		end

		if activePressInput and input ~= activePressInput and input.UserInputType ~= activePressInput.UserInputType then
			return
		end

		isPressed = false
		activePressInput = nil
		updateButtonScale()
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not activePressInput then
			return
		end

		if input == activePressInput then
			isPressed = false
			activePressInput = nil
			updateButtonScale()
		end
	end)

	button.Activated:Connect(function()
		isPressed = false
		activePressInput = nil
		updateButtonScale()
	end)
end

rebirthMenu.Visible = false
attachSnappyHoverPressEffect(rebirthMenuButton)

local requiredDisplayedSpeed = MovementConfig.GetRequiredDisplayedSpeedForRebirthCount(0)

local function getDisplayedSpeed(): number
	local speedDisplay = player:GetAttribute("SpeedDisplay")
	if typeof(speedDisplay) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(speedDisplay))
end

local function updateProgressUi(displayedSpeed: number, requiredSpeed: number)
	local clampedRequired = math.max(1, math.floor(requiredSpeed))
	local ratio = math.clamp(displayedSpeed / clampedRequired, 0, 1)
	progressBar.Size = UDim2.new(ratio, 0, progressBar.Size.Y.Scale, progressBar.Size.Y.Offset)
	progressValue.Text = `{displayedSpeed}/{clampedRequired} Speed`

	local canRebirth = displayedSpeed >= clampedRequired
	rebirthButton.Active = canRebirth
	rebirthButton.AutoButtonColor = canRebirth
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

local function playOpenAnimation()
	if isAnimating then
		return
	end
	isAnimating = true

	rebirthMenu.Size = scaleUDim2(rebirthMenuRestSize, OPEN_START_SCALE)
	rebirthMenu.Visible = true

	local phase1Duration = OPEN_DURATION * OPEN_PHASE1_RATIO
	local phase2Duration = OPEN_DURATION * (1 - OPEN_PHASE1_RATIO)
	local tweenInfo1 = TweenInfo.new(phase1Duration, EASING_UP, EASING_DIRECTION_OUT)
	local tweenInfo2 = TweenInfo.new(phase2Duration, EASING_UP, EASING_DIRECTION_OUT)

	local tween1 = TweenService:Create(rebirthMenu, tweenInfo1, {
		Size = scaleUDim2(rebirthMenuRestSize, OPEN_OVERSHOOT_SCALE),
	})
	local tween2 = TweenService:Create(rebirthMenu, tweenInfo2, {
		Size = rebirthMenuRestSize,
	})

	tween1:Play()
	tween1.Completed:Connect(function()
		tween2:Play()
		tween2.Completed:Connect(function()
			isAnimating = false
		end)
	end)
end

local function playCloseAnimation()
	if isAnimating then
		return
	end
	isAnimating = true

	local tweenInfo = TweenInfo.new(CLOSE_DURATION, EASING_UP, EASING_DIRECTION_OUT)
	local tween = TweenService:Create(rebirthMenu, tweenInfo, {
		Size = scaleUDim2(rebirthMenuRestSize, CLOSE_END_SCALE),
	})

	tween:Play()
	tween.Completed:Connect(function()
		rebirthMenu.Visible = false
		rebirthMenu.Size = rebirthMenuRestSize
		isAnimating = false
	end)
end

rebirthMenuButton.Activated:Connect(function()
	if rebirthMenu.Visible then
		playCloseAnimation()
	else
		playOpenAnimation()
		requestRebirthStateRemote:FireServer()
	end
end)

rebirthMenuCloseButton.Activated:Connect(function()
	playCloseAnimation()
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

refreshProgressFromSpeedAttribute()
