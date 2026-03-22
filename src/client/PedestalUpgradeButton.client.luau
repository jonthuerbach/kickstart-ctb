local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPedestalUpgradeRemote = remotes:WaitForChild("RequestPedestalUpgrade") :: RemoteEvent
local pedestalUpgradeSfxRemote = remotes:WaitForChild("PedestalUpgradeSfx") :: RemoteEvent

local PEDESTAL_UPGRADE_SOUND_ID = "rbxassetid://120891770644830"

local HOVER_SCALE_MULTIPLIER = 1.1
local PRESSED_SCALE_MULTIPLIER = 0.9
local SCALE_TWEEN_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ENABLE_DESKTOP_MOUSE_ANIMATION = UserInputService.MouseEnabled

type ButtonVisualState = {
	uiScale: UIScale,
	baseScale: number,
	isHovered: boolean,
	isPressed: boolean,
	activeTween: Tween?,
}

local observedButtons: { [GuiButton]: ButtonVisualState } = {}

local upgradeSound = Instance.new("Sound")
upgradeSound.Name = "PedestalUpgradeSfx"
upgradeSound.SoundId = PEDESTAL_UPGRADE_SOUND_ID
upgradeSound.Volume = 1
upgradeSound.PlaybackSpeed = 1
upgradeSound.Looped = false
upgradeSound.Parent = SoundService

local function getOrCreateButtonScale(button: GuiButton): UIScale
	local existingScale = button:FindFirstChildOfClass("UIScale")
	if existingScale then
		return existingScale
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = button
	return uiScale
end

local function getTargetScale(state: ButtonVisualState): number
	if state.isPressed then
		return state.baseScale * PRESSED_SCALE_MULTIPLIER
	end
	if state.isHovered then
		return state.baseScale * HOVER_SCALE_MULTIPLIER
	end
	return state.baseScale
end

local function tweenScaleTo(state: ButtonVisualState, targetScale: number)
	if state.activeTween then
		state.activeTween:Cancel()
		state.activeTween = nil
	end

	local tween = TweenService:Create(state.uiScale, SCALE_TWEEN_INFO, { Scale = targetScale })
	state.activeTween = tween
	tween:Play()
end

local function updateButtonScale(state: ButtonVisualState)
	tweenScaleTo(state, getTargetScale(state))
end

local function observeUpgradeButton(button: GuiButton)
	if observedButtons[button] then
		return
	end

	local uiScale = getOrCreateButtonScale(button)
	local visualState: ButtonVisualState = {
		uiScale = uiScale,
		baseScale = uiScale.Scale,
		isHovered = false,
		isPressed = false,
		activeTween = nil,
	}
	observedButtons[button] = visualState

	if ENABLE_DESKTOP_MOUSE_ANIMATION then
		button.MouseEnter:Connect(function()
			visualState.isHovered = true
			updateButtonScale(visualState)
		end)

		button.MouseLeave:Connect(function()
			visualState.isHovered = false
			visualState.isPressed = false
			updateButtonScale(visualState)
		end)

		button.MouseButton1Down:Connect(function()
			visualState.isPressed = true
			updateButtonScale(visualState)
		end)

		button.MouseButton1Up:Connect(function()
			visualState.isPressed = false
			updateButtonScale(visualState)
		end)
	end

	button.Activated:Connect(function()
		requestPedestalUpgradeRemote:FireServer(button)
	end)

	button.Destroying:Connect(function()
		if visualState.activeTween then
			visualState.activeTween:Cancel()
		end
		observedButtons[button] = nil
	end)
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPedestalUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPedestalUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end)

pedestalUpgradeSfxRemote.OnClientEvent:Connect(function()
	if upgradeSound.IsPlaying then
		upgradeSound:Stop()
	end

	upgradeSound:Play()
end)
