local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local BrainrotBillboard = require(ReplicatedStorage.Shared.Utils.BrainrotBillboard)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local TutorialManager = require(ReplicatedStorage.Shared.Managers.TutorialManager)

local spinnersFolder = workspace:WaitForChild("Spinners")
local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")
local safeZonePart = workspace:WaitForChild("World"):WaitForChild("SafeZone")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mythicSpawnedRemote = remotes:WaitForChild("MythicSpawned") :: RemoteEvent

local BRAINROT_LIFETIME_SECONDS = 60
local BRAINROT_RESPAWN_DELAY_SECONDS = 5
local MYTHIC_SPAWN_INTERVAL_SECONDS = 5 * 60
local MYTHIC_LIFETIME_SECONDS = 4 * 60
local HELD_BRAINROT_MODEL_ATTRIBUTE = "HeldBrainrotModelName"
local HELD_BRAINROT_RARITY_ATTRIBUTE = "HeldBrainrotRarity"
local rng = Random.new()

local activeHoldTracks: { [Player]: AnimationTrack } = {}
local spinnerStates: { [Model]: { token: number } } = {}
local registeredSpinnerTops: { [Model]: boolean } = {}
local safeZoneDebounceByPlayer: { [Player]: number } = {}
local typeAliases = {
	Comon = "Common",
}

local function stopHoldBrainrotAnimation(player: Player)
	local track = activeHoldTracks[player]
	if track then
		track:Stop()
		track:Destroy()
		activeHoldTracks[player] = nil
	end
end

local function playHoldBrainrotAnimation(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	stopHoldBrainrotAnimation(player)

	local raiseAnimation = Instance.new("Animation")
	raiseAnimation.AnimationId = "rbxassetid://102754426367947"

	local holdAnimation = Instance.new("Animation")
	holdAnimation.AnimationId = "rbxassetid://101131966990892"

	local raiseTrack = animator:LoadAnimation(raiseAnimation)
	raiseTrack.Priority = Enum.AnimationPriority.Action
	raiseTrack.Looped = false

	local holdTrack = animator:LoadAnimation(holdAnimation)
	holdTrack.Priority = Enum.AnimationPriority.Action
	holdTrack.Looped = true

	raiseTrack:Play()
	raiseTrack.Stopped:Connect(function()
		if activeHoldTracks[player] ~= nil then
			return
		end

		holdTrack:Play()
		activeHoldTracks[player] = holdTrack
	end)
end

local function setHeldBrainrotState(player: Player, modelName: string?, rarity: string?)
	if modelName == nil then
		player:SetAttribute(HELD_BRAINROT_MODEL_ATTRIBUTE, nil)
	else
		player:SetAttribute(HELD_BRAINROT_MODEL_ATTRIBUTE, modelName)
	end

	if rarity == nil then
		player:SetAttribute(HELD_BRAINROT_RARITY_ATTRIBUTE, nil)
	else
		player:SetAttribute(HELD_BRAINROT_RARITY_ATTRIBUTE, rarity)
	end
end

local function clearHeldBrainrot(player: Player)
	local character = player.Character
	if character then
		local overheadBrainrot = character:FindFirstChild("OverheadBrainrot")
		if overheadBrainrot then
			overheadBrainrot:Destroy()
		end
	end

	stopHoldBrainrotAnimation(player)
	setHeldBrainrotState(player, nil, nil)
end

local function attachBrainrotAboveHead(player: Player, modelName: string, rarity: string)
	playHoldBrainrotAnimation(player)

	local character = player.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local rarityFolder = brainrotsRoot:FindFirstChild(rarity)
	if not rarityFolder then
		warn(`[BrainrotInit] Missing rarity folder {rarity} for carried brainrot {modelName}`)
		return
	end

	local modelTemplate = rarityFolder:FindFirstChild(modelName)
	if not modelTemplate or not modelTemplate:IsA("Model") then
		warn(`[BrainrotInit] Missing carried model {rarity}/{modelName}`)
		return
	end

	local existing = character:FindFirstChild("OverheadBrainrot")
	if existing then
		existing:Destroy()
	end

	local displayBrainrot = modelTemplate:Clone()
	displayBrainrot.Name = "OverheadBrainrot"
	displayBrainrot.Parent = character

	local primaryPart = displayBrainrot.PrimaryPart
	if not primaryPart then
		warn(`[BrainrotInit] Carried model {rarity}/{modelName} is missing PrimaryPart`)
		displayBrainrot:Destroy()
		return
	end

	for _, descendant in displayBrainrot:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end

	local offset = CFrame.new(0, 1, 1)
	task.wait(0.35)
	displayBrainrot:PivotTo(head.CFrame * offset)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = primaryPart
	weld.Parent = primaryPart

	setHeldBrainrotState(player, modelName, rarity)
end

local function getSpinnerState(spinnerTop: Model): { token: number }
	local state = spinnerStates[spinnerTop]
	if not state then
		state = { token = 0 }
		spinnerStates[spinnerTop] = state
	end
	return state
end

local function incrementSpinnerToken(spinnerTop: Model): number
	local state = getSpinnerState(spinnerTop)
	state.token += 1
	return state.token
end

local function normalizeSpawnType(rawType: any): string?
	if typeof(rawType) ~= "string" or rawType == "" then
		return nil
	end

	return typeAliases[rawType] or rawType
end

local function isMythicSpawnType(spawnType: string?): boolean
	return spawnType == "Mythic"
end

local function isMythicSpinnerTop(spinnerTop: Model): boolean
	local spawnType = normalizeSpawnType(spinnerTop:GetAttribute("BrainrotType"))
	return isMythicSpawnType(spawnType)
end

local function secondsUntilNextMythicWindow(nowEpochSeconds: number): number
	local remainder = nowEpochSeconds % MYTHIC_SPAWN_INTERVAL_SECONDS
	if remainder == 0 then
		return MYTHIC_SPAWN_INTERVAL_SECONDS
	end

	return MYTHIC_SPAWN_INTERVAL_SECONDS - remainder
end

local function selectWeightedBrainrot(spawnType: string): any?
	local category = BrainrotCatalog.Names[spawnType]
	if typeof(category) ~= "table" then
		warn(`[BrainrotInit] No catalog category found for type {spawnType}`)
		return nil
	end

	local totalWeight = 0
	for _, entry in category do
		if typeof(entry.chance) == "number" and entry.chance > 0 then
			totalWeight += entry.chance
		end
	end

	if totalWeight <= 0 then
		warn(`[BrainrotInit] Catalog category {spawnType} has no valid chance values`)
		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0
	for _, entry in category do
		local chance = entry.chance
		if typeof(chance) == "number" and chance > 0 then
			cumulative += chance
			if roll <= cumulative then
				return entry
			end
		end
	end

	return category[#category]
end

local function getBrainrotTemplate(entry: any): Model?
	local rarity = entry.rarity
	local modelName = entry.modelName

	if typeof(rarity) ~= "string" or typeof(modelName) ~= "string" then
		warn("[BrainrotInit] Invalid catalog entry: missing rarity/modelName")
		return nil
	end

	local rarityFolder = brainrotsRoot:FindFirstChild(rarity)
	if not rarityFolder then
		warn(`[BrainrotInit] Missing rarity folder {rarity} for model {modelName}`)
		return nil
	end

	local template = rarityFolder:FindFirstChild(modelName)
	if not template or not template:IsA("Model") then
		warn(`[BrainrotInit] Missing model {rarity}/{modelName}`)
		return nil
	end

	return template
end

local function scheduleRespawn(spinnerTop: Model, delaySeconds: number, expectedToken: number, spawnFn: (Model) -> ())
	task.delay(delaySeconds, function()
		if not spinnerTop.Parent then
			return
		end

		local state = spinnerStates[spinnerTop]
		if not state or state.token ~= expectedToken then
			return
		end

		spawnFn(spinnerTop)
	end)
end

local function spawnBrainrotForSpinnerTop(spinnerTop: Model)
	if not spinnerTop.Parent then
		return
	end

	local spawnType = normalizeSpawnType(spinnerTop:GetAttribute("BrainrotType"))
	if not spawnType then
		warn(`[BrainrotInit] Spinner {spinnerTop.Name} is missing a valid BrainrotType`)
		return
	end
	local isMythic = isMythicSpawnType(spawnType)

	local selected = selectWeightedBrainrot(spawnType)
	if not selected then
		return
	end

	local template = getBrainrotTemplate(selected)
	if not template then
		return
	end

	local brainrotAttachment = spinnerTop:FindFirstChild("BrainrotAttachment")
	if not brainrotAttachment or not brainrotAttachment:IsA("Attachment") then
		warn(`[BrainrotInit] Spinner {spinnerTop.Name} is missing BrainrotAttachment`)
		return
	end

	local current = spinnerTop:FindFirstChild("Brainrot")
	if current then
		current:Destroy()
	end

	local brainrot = template:Clone()
	brainrot.Name = "Brainrot"
	brainrot:SetAttribute("Name", selected.name)
	brainrot:SetAttribute("ModelName", selected.modelName)
	brainrot:SetAttribute("Rarity", selected.rarity)
	brainrot:SetAttribute("RatePerSecond", selected.ratePerSecond)
	brainrot:SetAttribute("Chance", selected.chance)
	if typeof(selected.mutation) == "string" then
		brainrot:SetAttribute("Mutation", selected.mutation)
	end
	brainrot.Parent = spinnerTop

	brainrot:PivotTo(brainrotAttachment.WorldCFrame)
	local lifetimeSeconds = if isMythic then MYTHIC_LIFETIME_SECONDS else BRAINROT_LIFETIME_SECONDS
	BrainrotBillboard.CreateFromAttributes(brainrot, {
		variant = "Spinner",
		showDespawnCountdown = true,
		lifetimeSeconds = lifetimeSeconds,
	})

	if isMythic then
		mythicSpawnedRemote:FireAllClients()
	end

	local spawnToken = incrementSpinnerToken(spinnerTop)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = selected.name
	prompt.HoldDuration = 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = brainrot

	if not prompt then
		warn(`[BrainrotInit] Spawned brainrot {selected.modelName} has no ProximityPrompt`)
	else
		prompt.Triggered:Connect(function(player: Player)
			if not brainrot.Parent then
				return
			end

			prompt.Enabled = false
			local pickedModelName = brainrot:GetAttribute("ModelName")
			local pickedRarity = brainrot:GetAttribute("Rarity")
			brainrot:Destroy()

			if typeof(pickedModelName) == "string" and typeof(pickedRarity) == "string" then
				attachBrainrotAboveHead(player, pickedModelName, pickedRarity)
				TutorialManager.OnBrainrotPickedUp(player)
			else
				warn("[BrainrotInit] Picked brainrot was missing model metadata")
			end

			if not isMythic then
				local respawnToken = incrementSpinnerToken(spinnerTop)
				scheduleRespawn(spinnerTop, BRAINROT_RESPAWN_DELAY_SECONDS, respawnToken, spawnBrainrotForSpinnerTop)
			end
		end)
	end

	task.delay(lifetimeSeconds, function()
		if not spinnerTop.Parent then
			return
		end

		local state = spinnerStates[spinnerTop]
		if not state or state.token ~= spawnToken then
			return
		end

		local currentBrainrot = spinnerTop:FindFirstChild("Brainrot")
		if currentBrainrot then
			currentBrainrot:Destroy()
		end

		if not isMythic then
			local respawnToken = incrementSpinnerToken(spinnerTop)
			scheduleRespawn(spinnerTop, BRAINROT_RESPAWN_DELAY_SECONDS, respawnToken, spawnBrainrotForSpinnerTop)
		end
	end)
end

local function scheduleMythicSpawns(spinnerTop: Model)
	local now = os.time()
	if now % MYTHIC_SPAWN_INTERVAL_SECONDS == 0 and spinnerTop:FindFirstChild("Brainrot") == nil then
		spawnBrainrotForSpinnerTop(spinnerTop)
	end

	local function scheduleNext()
		if not spinnerTop.Parent then
			return
		end

		local delaySeconds = secondsUntilNextMythicWindow(os.time())
		task.delay(delaySeconds, function()
			if not spinnerTop.Parent then
				return
			end

			if spinnerTop:FindFirstChild("Brainrot") == nil then
				spawnBrainrotForSpinnerTop(spinnerTop)
			end

			scheduleNext()
		end)
	end

	scheduleNext()
end

local function isSpinnerTop(instance: Instance): boolean
	if not instance:IsA("Model") then
		return false
	end

	if instance:GetAttribute("IsSpinnerTop") == true then
		return true
	end

	return instance.Name:match("^SpinnerTop") ~= nil
end

local function registerSpinnerTop(spinnerTop: Model)
	if registeredSpinnerTops[spinnerTop] then
		return
	end

	registeredSpinnerTops[spinnerTop] = true
	if isMythicSpinnerTop(spinnerTop) then
		scheduleMythicSpawns(spinnerTop)
	else
		spawnBrainrotForSpinnerTop(spinnerTop)
	end

	spinnerTop.Destroying:Connect(function()
		registeredSpinnerTops[spinnerTop] = nil
		spinnerStates[spinnerTop] = nil
	end)
end

for _, child in spinnersFolder:GetChildren() do
	if isSpinnerTop(child) then
		registerSpinnerTop(child :: Model)
	end
end

spinnersFolder.ChildAdded:Connect(function(child)
	if isSpinnerTop(child) then
		registerSpinnerTop(child :: Model)
	end
end)

safeZonePart.Touched:Connect(function(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local modelName = player:GetAttribute(HELD_BRAINROT_MODEL_ATTRIBUTE)
	local rarity = player:GetAttribute(HELD_BRAINROT_RARITY_ATTRIBUTE)
	if typeof(modelName) ~= "string" or typeof(rarity) ~= "string" then
		return
	end

	local now = os.clock()
	local lastTouch = safeZoneDebounceByPlayer[player]
	if lastTouch and (now - lastTouch) < 0.2 then
		return
	end
	safeZoneDebounceByPlayer[player] = now

	BrainrotToolManager.AssertToolTemplate(rarity, modelName)
	local updatedCount = BrainrotToolManager.AddOwnedTool(player, rarity, modelName, true)
	if updatedCount <= 0 then
		return
	end

	clearHeldBrainrot(player)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		clearHeldBrainrot(player)
	end)
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(function()
		clearHeldBrainrot(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	safeZoneDebounceByPlayer[player] = nil
	stopHoldBrainrotAnimation(player)
	setHeldBrainrotState(player, nil, nil)
end)
