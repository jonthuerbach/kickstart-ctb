local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local giftOfferIncomingRemote = remotes:WaitForChild("GiftOfferIncoming") :: RemoteEvent
local giftOfferResponseRemote = remotes:WaitForChild("GiftOfferResponse") :: RemoteEvent
local giftOfferClosedRemote = remotes:WaitForChild("GiftOfferClosed") :: RemoteEvent
local giftStatusMessageRemote = remotes:WaitForChild("GiftStatusMessage") :: RemoteEvent

local safeZonePart = Workspace:WaitForChild("World"):WaitForChild("SafeZone")
assert(safeZonePart:IsA("BasePart"), "[GiftInit] workspace.World.SafeZone must be a BasePart")

local REQUEST_TIMEOUT_SECONDS = 30
local REQUEST_COOLDOWN_SECONDS = 30
local GIFT_PROMPT_NAME = "GiftProximityPrompt"
local ALREADY_BEING_GIFTED_MESSAGE = "Player is already being gifted a brainrot. Please try again later."

type PendingGiftRequest = {
	id: string,
	sender: Player,
	recipient: Player,
	rarity: string,
	modelName: string,
	level: number,
	brainrotDisplayName: string,
	resolved: boolean,
}

local promptByPlayer: { [Player]: ProximityPrompt } = {}
local requestBySender: { [Player]: PendingGiftRequest } = {}
local requestByRecipient: { [Player]: PendingGiftRequest } = {}
local cooldownUntilBySender: { [Player]: number } = {}
local brainrotNameLookup: { [string]: string } = {}

local requestCounter = 0

local function buildBrainrotNameLookup()
	for _, entries in BrainrotCatalog.Names do
		if typeof(entries) ~= "table" then
			continue
		end

		for _, entry in entries do
			if typeof(entry) ~= "table" then
				continue
			end

			if
				typeof(entry.rarity) == "string"
				and typeof(entry.modelName) == "string"
				and typeof(entry.name) == "string"
			then
				brainrotNameLookup[`${entry.rarity}/{entry.modelName}`] = entry.name
			end
		end
	end
end

local function getBrainrotDisplayName(rarity: string, modelName: string): string
	return brainrotNameLookup[`${rarity}/{modelName}`] or modelName
end

local function sendStatus(player: Player, message: string)
	giftStatusMessageRemote:FireClient(player, message)
end

local function isPlayerInSafeZone(player: Player): boolean
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

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function arePlayersWithinGiftRange(sender: Player, recipient: Player): boolean
	local senderRoot = getCharacterRoot(sender)
	local recipientRoot = getCharacterRoot(recipient)
	if not senderRoot or not recipientRoot then
		return false
	end

	local recipientPrompt = promptByPlayer[recipient]
	local maxDistance = if recipientPrompt then recipientPrompt.MaxActivationDistance else 10
	return (senderRoot.Position - recipientRoot.Position).Magnitude <= (maxDistance + 1)
end

local function getEquippedBrainrotTool(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			return child
		end
	end

	return nil
end

local function clearActiveRequest(request: PendingGiftRequest)
	requestBySender[request.sender] = nil
	requestByRecipient[request.recipient] = nil
end

local function restoreGiftToSenderOwnership(sender: Player, rarity: string, modelName: string, level: number)
	if sender.Parent == Players then
		local updatedCount = BrainrotToolManager.AddOwnedTool(sender, rarity, modelName, false, level)
		if updatedCount > 0 then
			return
		end
	end

	local updatedCount = DataManager.AddBrainrotTool(sender, rarity, modelName, 1, level)
	if updatedCount <= 0 then
		warn(`[GiftInit] Failed to restore gift ownership for {sender.Name}: {rarity}/{modelName}`)
	end
end

local function closeGiftMenu(player: Player, requestId: string)
	giftOfferClosedRemote:FireClient(player, requestId)
end

local function resolveGiftRequest(request: PendingGiftRequest, outcome: string)
	if request.resolved then
		return
	end
	request.resolved = true
	clearActiveRequest(request)

	local sender = request.sender
	local recipient = request.recipient

	if outcome == "accepted" then
		local updatedCount = BrainrotToolManager.AddOwnedTool(recipient, request.rarity, request.modelName, false, request.level)
		if updatedCount <= 0 then
			restoreGiftToSenderOwnership(sender, request.rarity, request.modelName, request.level)
			sendStatus(sender, "Gift failed because the receiver could not receive the brainrot. It has been returned to you.")
			sendStatus(recipient, "Gift failed. Please try again.")
			closeGiftMenu(recipient, request.id)
			return
		end

		sendStatus(sender, "You sent a gift!")
		sendStatus(recipient, "You received a gift!")
		closeGiftMenu(recipient, request.id)
		print(
			`[GiftInit] Gift completed: {sender.Name} -> {recipient.Name} ({request.rarity}/{request.modelName} - {request.brainrotDisplayName})`
		)
		return
	end

	restoreGiftToSenderOwnership(sender, request.rarity, request.modelName, request.level)
	closeGiftMenu(recipient, request.id)

	if outcome == "cancelled" then
		sendStatus(sender, `${recipient.DisplayName} canceled your gift offer. Your brainrot was returned.`)
		sendStatus(recipient, "You canceled the gift offer.")
	elseif outcome == "timed_out" then
		sendStatus(sender, "Your gift request timed out after 30 seconds. Your brainrot was returned.")
		sendStatus(recipient, "Gift request timed out.")
	elseif outcome == "sender_left" then
		sendStatus(recipient, "Gift failed because the sender left the game.")
	elseif outcome == "recipient_left" then
		sendStatus(sender, "Gift canceled because the recipient left the game. Your brainrot was returned.")
	elseif outcome == "moved_away" then
		sendStatus(sender, "Gift canceled because one of you moved too far away. Your brainrot was returned.")
		sendStatus(recipient, "Gift canceled because one of you moved too far away.")
	elseif outcome == "invalid_sender_state" then
		sendStatus(sender, "Gift canceled because the offered brainrot is no longer available. Your brainrot was returned.")
		sendStatus(recipient, "Gift canceled because the offered brainrot is no longer available.")
	else
		sendStatus(sender, "Gift canceled. Your brainrot was returned.")
		sendStatus(recipient, "Gift canceled.")
	end

	print(
		`[GiftInit] Gift canceled ({outcome}): {sender.Name} -> {recipient.Name} ({request.rarity}/{request.modelName} - {request.brainrotDisplayName})`
	)
end

local function beginGiftRequest(sender: Player, recipient: Player)
	if sender == recipient then
		return
	end

	local senderProfile = DataManager.Profiles[sender]
	local recipientProfile = DataManager.Profiles[recipient]
	if not senderProfile or not recipientProfile then
		sendStatus(sender, "Gift failed because player data is not ready. Please try again.")
		return
	end

	if requestBySender[sender] or requestByRecipient[sender] then
		sendStatus(sender, "You already have a gift request in progress.")
		return
	end

	if requestBySender[recipient] or requestByRecipient[recipient] then
		sendStatus(sender, ALREADY_BEING_GIFTED_MESSAGE)
		return
	end

	local now = os.clock()
	local cooldownUntil = cooldownUntilBySender[sender]
	if cooldownUntil and now < cooldownUntil then
		local remaining = math.max(1, math.ceil(cooldownUntil - now))
		sendStatus(sender, `Please wait {remaining}s before sending another gift request.`)
		return
	end

	if not isPlayerInSafeZone(sender) or not isPlayerInSafeZone(recipient) then
		sendStatus(sender, "Both players must be inside the safe zone to gift brainrots.")
		return
	end

	local equippedTool = getEquippedBrainrotTool(sender)
	if not equippedTool then
		sendStatus(sender, "Equip a brainrot tool before gifting.")
		return
	end

	local rarity, modelName = BrainrotToolManager.GetToolMetadata(equippedTool)
	if not rarity or not modelName then
		sendStatus(sender, "Equipped tool is not a valid brainrot gift.")
		return
	end
	local equippedLevel = BrainrotToolManager.GetToolLevel(equippedTool)
	local resolvedEquippedLevel = if typeof(equippedLevel) == "number" then math.max(1, math.floor(equippedLevel)) else 1

	local updatedCount = BrainrotToolManager.ConsumeOwnedTool(sender, rarity, modelName, resolvedEquippedLevel)
	if updatedCount < 0 then
		sendStatus(sender, "Gift failed because you no longer own that brainrot.")
		return
	end
	equippedTool:Destroy()

	requestCounter += 1
	local requestId = `{sender.UserId}:{recipient.UserId}:{requestCounter}`
	local brainrotDisplayName = getBrainrotDisplayName(rarity, modelName)
	local request: PendingGiftRequest = {
		id = requestId,
		sender = sender,
		recipient = recipient,
		rarity = rarity,
		modelName = modelName,
		level = resolvedEquippedLevel,
		brainrotDisplayName = brainrotDisplayName,
		resolved = false,
	}

	requestBySender[sender] = request
	requestByRecipient[recipient] = request
	cooldownUntilBySender[sender] = now + REQUEST_COOLDOWN_SECONDS

	giftOfferIncomingRemote:FireClient(recipient, {
		requestId = requestId,
		senderDisplayName = sender.DisplayName,
		brainrotName = brainrotDisplayName,
		timeoutSeconds = REQUEST_TIMEOUT_SECONDS,
	})
	sendStatus(sender, `Gift offer sent to {recipient.DisplayName}.`)

	task.delay(REQUEST_TIMEOUT_SECONDS, function()
		if request.resolved then
			return
		end
		resolveGiftRequest(request, "timed_out")
	end)
end

local function bindPrompt(prompt: ProximityPrompt, recipient: Player)
	prompt.Triggered:Connect(function(sender: Player)
		beginGiftRequest(sender, recipient)
	end)
end

local function clearPromptForPlayer(player: Player)
	local prompt = promptByPlayer[player]
	if not prompt then
		return
	end

	promptByPlayer[player] = nil
	prompt:Destroy()
end

local function attachPromptToCharacter(player: Player, character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		rootPart = character:WaitForChild("HumanoidRootPart", 10)
	end
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	clearPromptForPlayer(player)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = GIFT_PROMPT_NAME
	prompt.ActionText = "Gift"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = rootPart

	promptByPlayer[player] = prompt
	bindPrompt(prompt, player)
end

local function connectPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		attachPromptToCharacter(player, character)
	end)

	player:GetPropertyChangedSignal("DisplayName"):Connect(function()
		local prompt = promptByPlayer[player]
		if prompt then
			prompt.ObjectText = player.DisplayName
		end
	end)

	if player.Character then
		attachPromptToCharacter(player, player.Character)
	end
end

giftOfferResponseRemote.OnServerEvent:Connect(function(recipient: Player, requestId: string, responseAction: string)
	if typeof(requestId) ~= "string" or typeof(responseAction) ~= "string" then
		return
	end

	local request = requestByRecipient[recipient]
	if not request or request.id ~= requestId then
		sendStatus(recipient, "That gift request is no longer available.")
		closeGiftMenu(recipient, requestId)
		return
	end

	if request.resolved then
		closeGiftMenu(recipient, request.id)
		return
	end

	if responseAction == "cancel" then
		resolveGiftRequest(request, "cancelled")
		return
	end

	if responseAction ~= "accept" then
		return
	end

	local sender = request.sender
	if sender.Parent ~= Players then
		resolveGiftRequest(request, "sender_left")
		return
	end

	if not DataManager.Profiles[sender] or not DataManager.Profiles[recipient] then
		resolveGiftRequest(request, "invalid_sender_state")
		return
	end

	if not isPlayerInSafeZone(sender) or not isPlayerInSafeZone(recipient) or not arePlayersWithinGiftRange(sender, recipient) then
		resolveGiftRequest(request, "moved_away")
		return
	end

	resolveGiftRequest(request, "accepted")
end)

Players.PlayerAdded:Connect(connectPlayer)

for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	clearPromptForPlayer(player)
	cooldownUntilBySender[player] = nil

	local outboundRequest = requestBySender[player]
	if outboundRequest then
		resolveGiftRequest(outboundRequest, "sender_left")
	end

	local inboundRequest = requestByRecipient[player]
	if inboundRequest then
		resolveGiftRequest(inboundRequest, "recipient_left")
	end
end)

buildBrainrotNameLookup()
