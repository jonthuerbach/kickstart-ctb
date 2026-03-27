local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MenuManager = {}

export type RegisterOptions = {
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

type MenuEntry = {
	frame: GuiObject,
	restSize: UDim2,
	isAnimating: boolean,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

local OPEN_START_SCALE = 0.4
local OPEN_OVERSHOOT_SCALE = 1.08
local CLOSE_END_SCALE = 0.4
local OPEN_DURATION = 0.15
local CLOSE_DURATION = 0.1
local OPEN_PHASE1_RATIO = 0.57
local EASING_STYLE = Enum.EasingStyle.Quad
local EASING_DIRECTION = Enum.EasingDirection.Out

local BUTTON_HOVER_SCALE = 1.1
local BUTTON_PRESS_SCALE = 0.9
local BUTTON_HOVER_IN_DURATION = 0.09
local BUTTON_RELEASE_DURATION = 0.08
local BUTTON_PRESS_IN_DURATION = 0.06

local menus: { [string]: MenuEntry } = {}
local currentMenu: string? = nil

local function scaleUDim2(udim2: UDim2, factor: number): UDim2
	return UDim2.new(udim2.X.Scale * factor, udim2.X.Offset * factor, udim2.Y.Scale * factor, udim2.Y.Offset * factor)
end

local function forceHide(entry: MenuEntry)
	entry.frame.Visible = false
	entry.frame.Size = entry.restSize
	entry.isAnimating = false
end

local function playOpenAnimation(entry: MenuEntry)
	if entry.isAnimating then
		return
	end
	entry.isAnimating = true

	local frame = entry.frame
	local restSize = entry.restSize

	frame.Size = scaleUDim2(restSize, OPEN_START_SCALE)
	frame.Visible = true

	local phase1Duration = OPEN_DURATION * OPEN_PHASE1_RATIO
	local phase2Duration = OPEN_DURATION * (1 - OPEN_PHASE1_RATIO)
	local tweenInfo1 = TweenInfo.new(phase1Duration, EASING_STYLE, EASING_DIRECTION)
	local tweenInfo2 = TweenInfo.new(phase2Duration, EASING_STYLE, EASING_DIRECTION)

	local tween1 = TweenService:Create(frame, tweenInfo1, {
		Size = scaleUDim2(restSize, OPEN_OVERSHOOT_SCALE),
	})
	local tween2 = TweenService:Create(frame, tweenInfo2, {
		Size = restSize,
	})

	tween1:Play()
	tween1.Completed:Connect(function()
		tween2:Play()
		tween2.Completed:Connect(function()
			entry.isAnimating = false
		end)
	end)
end

local function playCloseAnimation(entry: MenuEntry)
	if entry.isAnimating then
		return
	end
	entry.isAnimating = true

	local frame = entry.frame
	local restSize = entry.restSize

	local tweenInfo = TweenInfo.new(CLOSE_DURATION, EASING_STYLE, EASING_DIRECTION)
	local tween = TweenService:Create(frame, tweenInfo, {
		Size = scaleUDim2(restSize, CLOSE_END_SCALE),
	})

	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
		frame.Size = restSize
		entry.isAnimating = false
	end)
end

function MenuManager.Register(name: string, frame: GuiObject, options: RegisterOptions?)
	assert(frame:IsA("GuiObject"), `[MenuManager] Frame for menu "{name}" must be a GuiObject`)

	frame.Visible = false
	menus[name] = {
		frame = frame,
		restSize = frame.Size,
		isAnimating = false,
		onOpen = if options then options.onOpen else nil,
		onClose = if options then options.onClose else nil,
	}
end

function MenuManager.Open(name: string)
	local entry = menus[name]
	if not entry then
		warn(`[MenuManager] Menu "{name}" is not registered`)
		return
	end

	if currentMenu == name then
		return
	end

	-- Force-hide the currently open menu to avoid animation timing conflicts
	if currentMenu then
		local prevEntry = menus[currentMenu]
		if prevEntry then
			forceHide(prevEntry)
			if prevEntry.onClose then
				prevEntry.onClose()
			end
		end
		currentMenu = nil
	end

	currentMenu = name
	playOpenAnimation(entry)
	if entry.onOpen then
		entry.onOpen()
	end
end

function MenuManager.Close(name: string)
	local entry = menus[name]
	if not entry then
		warn(`[MenuManager] Menu "{name}" is not registered`)
		return
	end

	if currentMenu == name then
		currentMenu = nil
	end

	if not entry.frame.Visible then
		return
	end

	playCloseAnimation(entry)
	if entry.onClose then
		entry.onClose()
	end
end

function MenuManager.Toggle(name: string)
	if currentMenu == name then
		MenuManager.Close(name)
	else
		MenuManager.Open(name)
	end
end

function MenuManager.IsOpen(name: string): boolean
	return currentMenu == name
end

function MenuManager.AttachHoverPressEffect(button: GuiButton)
	local function getOrCreateScale(): UIScale
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

	local scale = getOrCreateScale()
	local baseScale = scale.Scale
	local isHovered = false
	local isPressed = false
	local activeTween: Tween? = nil
	local activePressInput: InputObject? = nil

	local function isPressInput(userInputType: Enum.UserInputType): boolean
		return userInputType == Enum.UserInputType.MouseButton1 or userInputType == Enum.UserInputType.Touch
	end

	local function tweenScale(targetScale: number, duration: number, easingStyle: Enum.EasingStyle)
		if activeTween then
			activeTween:Cancel()
		end
		local newTween = TweenService:Create(
			scale,
			TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out),
			{ Scale = targetScale }
		)
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

return MenuManager
