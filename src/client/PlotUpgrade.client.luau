local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPlotUpgradeRemote = remotes:WaitForChild("RequestPlotUpgrade") :: RemoteEvent
local plotUpgradeRemote = remotes:WaitForChild("PlotUpgrade") :: RemoteEvent

local MAX_PLOT_LEVEL = 10
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
	ownerChangedConnection: RBXScriptConnection?,
	levelChangedConnection: RBXScriptConnection?,
}

local observedButtons: { [GuiButton]: ButtonVisualState } = {}

local function getOwningPlotModel(instance: Instance): Model?
	local current: Instance? = instance
	while current do
		if current:IsA("Model") then
			if current:GetAttribute("IsPlotModel") == true then
				return current
			end
		end
		current = current.Parent
	end

	return nil
end

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

local function normalizePlotLevel(value: any): number
	if typeof(value) ~= "number" then
		return 0
	end

	return math.clamp(math.max(0, math.floor(value)), 0, MAX_PLOT_LEVEL)
end

local function updateLevelLabel(button: GuiButton, plotLevel: number)
	local levelLabel = button:FindFirstChild("Level")
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = `{plotLevel}/{MAX_PLOT_LEVEL}`
	end
end

local function isButtonInteractable(button: GuiButton): boolean
	local plotModel = getOwningPlotModel(button)
	if not plotModel then
		return false
	end

	local ownerUserId = plotModel:GetAttribute("OwnerUserId")
	if ownerUserId ~= localPlayer.UserId then
		return false
	end

	local plotLevel = normalizePlotLevel(button:GetAttribute("PlotLevel"))
	return plotLevel < MAX_PLOT_LEVEL
end

local function refreshButtonInteractability(button: GuiButton, state: ButtonVisualState)
	local canInteract = isButtonInteractable(button)
	button.Active = canInteract
	button.AutoButtonColor = canInteract

	if not canInteract then
		state.isHovered = false
		state.isPressed = false
	end

	updateButtonScale(state)
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
		ownerChangedConnection = nil,
		levelChangedConnection = nil,
	}
	observedButtons[button] = visualState

	local plotModel = getOwningPlotModel(button)
	if plotModel then
		visualState.ownerChangedConnection = plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshButtonInteractability(button, visualState)
		end)
	end

	visualState.levelChangedConnection = button:GetAttributeChangedSignal("PlotLevel"):Connect(function()
		local plotLevel = normalizePlotLevel(button:GetAttribute("PlotLevel"))
		updateLevelLabel(button, plotLevel)
		refreshButtonInteractability(button, visualState)
	end)

	if ENABLE_DESKTOP_MOUSE_ANIMATION then
		button.MouseEnter:Connect(function()
			if not button.Active then
				return
			end

			visualState.isHovered = true
			updateButtonScale(visualState)
		end)

		button.MouseLeave:Connect(function()
			visualState.isHovered = false
			visualState.isPressed = false
			updateButtonScale(visualState)
		end)

		button.MouseButton1Down:Connect(function()
			if not button.Active then
				return
			end

			visualState.isPressed = true
			updateButtonScale(visualState)
		end)

		button.MouseButton1Up:Connect(function()
			visualState.isPressed = false
			updateButtonScale(visualState)
		end)
	end

	button.Activated:Connect(function()
		if not isButtonInteractable(button) then
			refreshButtonInteractability(button, visualState)
			return
		end

		requestPlotUpgradeRemote:FireServer(button)
	end)

	button.Destroying:Connect(function()
		if visualState.activeTween then
			visualState.activeTween:Cancel()
		end
		if visualState.ownerChangedConnection then
			visualState.ownerChangedConnection:Disconnect()
		end
		if visualState.levelChangedConnection then
			visualState.levelChangedConnection:Disconnect()
		end
		observedButtons[button] = nil
	end)

	local initialPlotLevel = normalizePlotLevel(button:GetAttribute("PlotLevel"))
	updateLevelLabel(button, initialPlotLevel)
	refreshButtonInteractability(button, visualState)
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPlotUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("GuiButton") and descendant:GetAttribute("IsPlotUpgradeButton") == true then
		observeUpgradeButton(descendant)
	end
end)

plotUpgradeRemote.OnClientEvent:Connect(function(buttonInstance: Instance?, plotLevel: number)
	local button = if buttonInstance and buttonInstance:IsA("GuiButton") then buttonInstance else nil
	if not button then
		return
	end

	local normalizedPlotLevel = normalizePlotLevel(plotLevel)
	button:SetAttribute("PlotLevel", normalizedPlotLevel)
	updateLevelLabel(button, normalizedPlotLevel)
end)
