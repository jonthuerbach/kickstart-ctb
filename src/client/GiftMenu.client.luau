local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local GIFT_PROMPT_NAME = "GiftProximityPrompt"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")

local giftMenu = mainGui:WaitForChild("GiftMenu")
local section = giftMenu:WaitForChild("Body"):WaitForChild("Section")
local upgradeLabel = section:WaitForChild("UpgradeLabel")
local acceptButton = section:WaitForChild("AcceptButton")
local cancelButton = section:WaitForChild("CancelButton")

assert(giftMenu:IsA("GuiObject"), "[GiftMenu] MainGui.GiftMenu must be a GuiObject")
assert(upgradeLabel:IsA("TextLabel"), "[GiftMenu] GiftMenu.Body.Section.UpgradeLabel must be a TextLabel")
assert(acceptButton:IsA("GuiButton"), "[GiftMenu] GiftMenu.Body.Section.AcceptButton must be a GuiButton")
assert(cancelButton:IsA("GuiButton"), "[GiftMenu] GiftMenu.Body.Section.CancelButton must be a GuiButton")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local giftOfferIncomingRemote = remotes:WaitForChild("GiftOfferIncoming") :: RemoteEvent
local giftOfferResponseRemote = remotes:WaitForChild("GiftOfferResponse") :: RemoteEvent
local giftOfferClosedRemote = remotes:WaitForChild("GiftOfferClosed") :: RemoteEvent
local giftStatusMessageRemote = remotes:WaitForChild("GiftStatusMessage") :: RemoteEvent

local safeZonePart = Workspace:WaitForChild("World"):WaitForChild("SafeZone")
assert(safeZonePart:IsA("BasePart"), "[GiftMenu] workspace.World.SafeZone must be a BasePart")

local trackedGiftPrompts: { [ProximityPrompt]: boolean } = {}
local currentRequestId: string? = nil
local hasEquippedBrainrot = false
local isInSafeZone = false
local nextSafeZoneCheckAt = 0

local function showStatusMessage(message: string)
	local textChannels = TextChatService:FindFirstChild("TextChannels")
	if textChannels then
		local systemChannel = textChannels:FindFirstChild("RBXSystem") or textChannels:FindFirstChild("RBXGeneral")
		if systemChannel and systemChannel:IsA("TextChannel") then
			systemChannel:DisplaySystemMessage(message)
			return
		end
	end

	warn(`[GiftMenu] {message}`)
end

local function setMenuPromptText(senderDisplayName: string, brainrotName: string)
	upgradeLabel.Text = `{senderDisplayName} wants to give you a {brainrotName} as a gift! Do you accept?`
end

local function setGiftMenuVisible(visible: boolean)
	giftMenu.Visible = visible
end

local function isPromptOnLocalCharacter(prompt: ProximityPrompt): boolean
	local character = player.Character
	if not character then
		return false
	end

	return prompt:IsDescendantOf(character)
end

local function shouldEnableGiftPrompt(prompt: ProximityPrompt): boolean
	if not hasEquippedBrainrot then
		return false
	end

	if not isInSafeZone then
		return false
	end

	if isPromptOnLocalCharacter(prompt) then
		return false
	end

	return true
end

local function refreshPromptVisibility()
	for prompt in trackedGiftPrompts do
		if prompt.Parent == nil then
			trackedGiftPrompts[prompt] = nil
			continue
		end

		prompt.Enabled = shouldEnableGiftPrompt(prompt)
	end
end

local function isPlayerInSafeZone(): boolean
	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local localPosition = safeZonePart.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = safeZonePart.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function recomputeEquippedBrainrot(character: Model?)
	hasEquippedBrainrot = false
	if not character then
		refreshPromptVisibility()
		return
	end

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			hasEquippedBrainrot = true
			break
		end
	end

	refreshPromptVisibility()
end

local function bindCharacter(character: Model)
	recomputeEquippedBrainrot(character)

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			recomputeEquippedBrainrot(character)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			recomputeEquippedBrainrot(character)
		end
	end)
end

local function trackPrompt(prompt: ProximityPrompt)
	if prompt.Name ~= GIFT_PROMPT_NAME then
		return
	end

	trackedGiftPrompts[prompt] = true
	prompt.Enabled = shouldEnableGiftPrompt(prompt)
end

giftMenu.Visible = false

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("ProximityPrompt") then
		trackPrompt(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("ProximityPrompt") then
		trackPrompt(descendant)
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant: Instance)
	if descendant:IsA("ProximityPrompt") then
		trackedGiftPrompts[descendant] = nil
	end
end)

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextSafeZoneCheckAt then
		return
	end
	nextSafeZoneCheckAt = now + 0.2

	local inSafeZoneNow = isPlayerInSafeZone()
	if inSafeZoneNow ~= isInSafeZone then
		isInSafeZone = inSafeZoneNow
		refreshPromptVisibility()
	end
end)

acceptButton.Activated:Connect(function()
	if not currentRequestId then
		return
	end

	giftOfferResponseRemote:FireServer(currentRequestId, "accept")
	setGiftMenuVisible(false)
end)

cancelButton.Activated:Connect(function()
	if not currentRequestId then
		return
	end

	giftOfferResponseRemote:FireServer(currentRequestId, "cancel")
	setGiftMenuVisible(false)
	currentRequestId = nil
end)

giftOfferIncomingRemote.OnClientEvent:Connect(function(payload: { [string]: any })
	if typeof(payload) ~= "table" then
		return
	end

	local requestId = payload.requestId
	local senderDisplayName = payload.senderDisplayName
	local brainrotName = payload.brainrotName
	if typeof(requestId) ~= "string" or typeof(senderDisplayName) ~= "string" or typeof(brainrotName) ~= "string" then
		return
	end

	currentRequestId = requestId
	setMenuPromptText(senderDisplayName, brainrotName)
	setGiftMenuVisible(true)
end)

giftOfferClosedRemote.OnClientEvent:Connect(function(requestId: string)
	if typeof(requestId) ~= "string" then
		return
	end

	if currentRequestId ~= requestId then
		return
	end

	currentRequestId = nil
	setGiftMenuVisible(false)
end)

giftStatusMessageRemote.OnClientEvent:Connect(function(message: string)
	if typeof(message) ~= "string" or message == "" then
		return
	end

	showStatusMessage(message)
end)
