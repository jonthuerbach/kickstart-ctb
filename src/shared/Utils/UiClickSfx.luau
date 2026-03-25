local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")

local UiClickSfx = {}

UiClickSfx.TAG_NAME = "UiClickSfx"
UiClickSfx.SOUND_ID = "rbxassetid://140494750798924"
UiClickSfx.DEFAULT_VOLUME = 0.85
UiClickSfx.DEFAULT_PLAYBACK_SPEED = 1

type ButtonConnections = {
	mouseDownConnection: RBXScriptConnection,
	inputBeganConnection: RBXScriptConnection,
	destroyingConnection: RBXScriptConnection,
}

local trackedButtons: { [GuiButton]: ButtonConnections } = {}
local tagAddedConnection: RBXScriptConnection? = nil
local tagRemovedConnection: RBXScriptConnection? = nil
local clickSound: Sound? = nil
local isStarted = false

local function ensureClickSound(): Sound
	local existingSound = SoundService:FindFirstChild("UiClickSfx")
	if existingSound and existingSound:IsA("Sound") then
		clickSound = existingSound
		if clickSound then
			clickSound.SoundId = UiClickSfx.SOUND_ID
			clickSound.Volume = UiClickSfx.DEFAULT_VOLUME
			clickSound.PlaybackSpeed = UiClickSfx.DEFAULT_PLAYBACK_SPEED
			clickSound.Looped = false
		end
		return existingSound
	end

	local newSound = Instance.new("Sound")
	newSound.Name = "UiClickSfx"
	newSound.SoundId = UiClickSfx.SOUND_ID
	newSound.Volume = UiClickSfx.DEFAULT_VOLUME
	newSound.PlaybackSpeed = UiClickSfx.DEFAULT_PLAYBACK_SPEED
	newSound.Looped = false
	newSound.Parent = SoundService

	clickSound = newSound
	return newSound
end

local function isClickable(button: GuiButton): boolean
	return button.Active and button.Visible
end

local function playClickIfInteractable(button: GuiButton)
	if not isClickable(button) then
		return
	end

	local sound = ensureClickSound()
	if sound.IsPlaying then
		sound:Stop()
	end
	sound:Play()
end

local function disconnectButton(button: GuiButton)
	local existingConnections = trackedButtons[button]
	if not existingConnections then
		return
	end

	existingConnections.mouseDownConnection:Disconnect()
	existingConnections.inputBeganConnection:Disconnect()
	existingConnections.destroyingConnection:Disconnect()
	trackedButtons[button] = nil
end

local function observeButton(button: GuiButton)
	if trackedButtons[button] then
		return
	end

	local connections: ButtonConnections = {
		mouseDownConnection = button.MouseButton1Down:Connect(function()
			playClickIfInteractable(button)
		end),
		inputBeganConnection = button.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			playClickIfInteractable(button)
		end),
		destroyingConnection = button.Destroying:Connect(function()
			disconnectButton(button)
		end),
	}

	trackedButtons[button] = connections
end

local function onTagAdded(instance: Instance)
	if not instance:IsA("GuiButton") then
		return
	end
	observeButton(instance)
end

local function onTagRemoved(instance: Instance)
	if not instance:IsA("GuiButton") then
		return
	end
	disconnectButton(instance)
end

function UiClickSfx.Start()
	if isStarted then
		return
	end
	isStarted = true

	ensureClickSound()

	for _, instance in ipairs(CollectionService:GetTagged(UiClickSfx.TAG_NAME)) do
		onTagAdded(instance)
	end

	tagAddedConnection = CollectionService:GetInstanceAddedSignal(UiClickSfx.TAG_NAME):Connect(onTagAdded)
	tagRemovedConnection = CollectionService:GetInstanceRemovedSignal(UiClickSfx.TAG_NAME):Connect(onTagRemoved)
end

function UiClickSfx.Stop()
	if not isStarted then
		return
	end
	isStarted = false

	for button in trackedButtons do
		disconnectButton(button)
	end

	if tagAddedConnection then
		tagAddedConnection:Disconnect()
		tagAddedConnection = nil
	end
	if tagRemovedConnection then
		tagRemovedConnection:Disconnect()
		tagRemovedConnection = nil
	end
end

return UiClickSfx
