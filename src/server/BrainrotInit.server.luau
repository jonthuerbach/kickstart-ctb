local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)

local spinnersFolder = workspace:WaitForChild("Spinners")
local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")
local safeZonePart = workspace:WaitForChild("World"):WaitForChild("SafeZone")

local BRAINROT_LIFETIME_SECONDS = 60
local BRAINROT_RESPAWN_DELAY_SECONDS = 30
local MYTHIC_SPAWN_INTERVAL_SECONDS = 5 * 60
local MYTHIC_LIFETIME_SECONDS = 4 * 60
local BRAINROT_BILLBOARD_MAX_DISTANCE = 90
local BRAINROT_BILLBOARD_STUDS_OFFSET = Vector3.new(0, 9, 0)
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
local rarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(112, 219, 112),
	Rare = Color3.fromRGB(88, 166, 255),
	Epic = Color3.fromRGB(184, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 80),
	Mythic = Color3.fromRGB(255, 100, 100),
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

local function findBillboardAnchorPart(model: Model): BasePart?
	local root = model:FindFirstChild("RootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getRarityColor(rarity: string): Color3
	return rarityColors[rarity] or Color3.fromRGB(255, 255, 255)
end

local function createBrainrotBillboard(brainrot: Model, lifetimeSeconds: number)
	local anchorPart = findBillboardAnchorPart(brainrot)
	if not anchorPart then
		warn(`[BrainrotInit] Cannot create billboard, no anchor part found for {brainrot.Name}`)
		return
	end

	local displayName = brainrot:GetAttribute("Name")
	local rarity = brainrot:GetAttribute("Rarity")
	local ratePerSecond = brainrot:GetAttribute("RatePerSecond")
	local mutation = brainrot:GetAttribute("Mutation")

	local displayText = typeof(displayName) == "string" and displayName or "Unknown"
	local rarityText = typeof(rarity) == "string" and rarity or "Unknown"
	local rateText = typeof(ratePerSecond) == "number" and tostring(ratePerSecond) or "?"
	local rarityColor = getRarityColor(rarityText)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotBillboard"
	billboard.Adornee = anchorPart
	billboard.Size = UDim2.new(16, 0, 10, 0)
	billboard.StudsOffset = BRAINROT_BILLBOARD_STUDS_OFFSET
	billboard.MaxDistance = BRAINROT_BILLBOARD_MAX_DISTANCE
	billboard.AlwaysOnTop = true
	billboard.Parent = brainrot

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 2)
	layout.Parent = container

	local function buildLabel(name: string, text: string, color: Color3, size: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, size, 0)
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = color
		label.Font = Enum.Font.FredokaOne
		label.Parent = container

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Thickness = 0.02
		stroke.Parent = label

		return label
	end

	local despawnLabel = buildLabel("DespawnCountdown", `${lifetimeSeconds}s`, Color3.fromRGB(255, 255, 0), 0.16)
	buildLabel("DisplayName", displayText, Color3.fromRGB(255, 255, 255), 0.25)
	buildLabel("Rarity", rarityText, rarityColor, 0.16)
	buildLabel("Rate", `${rateText}/s`, Color3.fromRGB(0, 255, 0), 0.25)

	if typeof(mutation) == "string" and mutation ~= "" then
		buildLabel("Mutation", `Mutation: {mutation}`, Color3.fromRGB(255, 240, 130), 0.25)
	end

	task.spawn(function()
		for remaining = lifetimeSeconds - 1, 0, -1 do
			if not brainrot.Parent or not despawnLabel.Parent then
				return
			end

			task.wait(1)

			if not brainrot.Parent or not despawnLabel.Parent then
				return
			end

			despawnLabel.Text = `{remaining}s`
		end
	end)
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
	createBrainrotBillboard(brainrot, lifetimeSeconds)

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
