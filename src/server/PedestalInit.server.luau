local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local DeveloperProductCatalog = require(ReplicatedStorage.Shared.Catalogs.DeveloperProductCatalog)
local BrainrotBillboard = require(ReplicatedStorage.Shared.Utils.BrainrotBillboard)
local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)
local TutorialManager = require(ReplicatedStorage.Shared.Managers.TutorialManager)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPedestalUpgradeRemote = remotes:WaitForChild("RequestPedestalUpgrade") :: RemoteEvent
local pedestalCollectSfxRemote = remotes:WaitForChild("PedestalCollectSfx") :: RemoteEvent
local pedestalUpgradeSfxRemote = remotes:WaitForChild("PedestalUpgradeSfx") :: RemoteEvent

local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")
local MAX_BRAINROT_LEVEL = 100
local SKIP_LEVEL_PRODUCT_ID = DeveloperProductCatalog.GetProductId("SkipLevel")
local BRAINROT_RATE_PER_SECOND_MULTIPLIER = 1.2

assert(typeof(SKIP_LEVEL_PRODUCT_ID) == "number", "[PedestalInit] Missing SkipLevel developer product id")

type PedestalState = {
	plot: any,
	pedestalId: string,
	pedestalModel: Model,
	placePrompt: ProximityPrompt,
	collectButton: BasePart,
	upgradeSurfaceGui: SurfaceGui,
	upgradeButton: GuiButton,
	upgradeCostLabel: TextLabel,
	upgradeLevelLabel: TextLabel,
	brainrotAttachment: Attachment,
	placedRarity: string?,
	placedModelName: string?,
	brainrotLevel: number,
	ratePerSecond: number,
	upgradePrice: number,
	bankedMoney: number,
	placedDisplayModel: Model?,
	removePrompt: ProximityPrompt?,
	collectDebounceAt: number,
	suppressUnoccupiedMoneyDisplay: boolean,
}

local pedestalByPrompt: { [ProximityPrompt]: PedestalState } = {}
local pedestalByCollectButton: { [BasePart]: PedestalState } = {}
local pedestalByUpgradeButton: { [GuiButton]: PedestalState } = {}
local pedestalsByPlot: { [any]: { [string]: PedestalState } } = {}
local allPedestalStates: { PedestalState } = {}
local savePedestalData: (Player, PedestalState) -> ()
local lastOwnerUserIdByPlot: { [any]: number? } = {}
local observedPlotModels: { [Model]: boolean } = {}
local upgradeInFlightByPlayer: { [Player]: boolean } = {}
type PendingSkipLevelRequest = {
	pedestalId: string,
	upgradeButton: GuiButton,
}
local pendingSkipLevelRequestByPlayer: { [Player]: PendingSkipLevelRequest } = {}

type BrainrotCatalogMetadata = {
	displayName: string,
	baseRatePerSecond: number,
	mutation: string?,
}

local METADATA_LOOKUP: { [string]: BrainrotCatalogMetadata } = {}

local function isPedestalModelUnlocked(pedestalModel: Model): boolean
	return pedestalModel:GetAttribute("PlotPedestalUnlocked") ~= false
end

local function buildMetadataLookup()
	for _, entries in BrainrotCatalog.Names do
		if typeof(entries) ~= "table" then
			continue
		end

		for _, entry in entries do
			if
				typeof(entry) == "table"
				and typeof(entry.rarity) == "string"
				and typeof(entry.modelName) == "string"
				and typeof(entry.ratePerSecond) == "number"
			then
				local metadata: BrainrotCatalogMetadata = {
					displayName = if typeof(entry.name) == "string" and entry.name ~= ""
						then entry.name
						else entry.modelName,
					baseRatePerSecond = entry.ratePerSecond,
					mutation = if typeof(entry.mutation) == "string" and entry.mutation ~= ""
						then entry.mutation
						else nil,
				}

				METADATA_LOOKUP[`${entry.rarity}/{entry.modelName}`] = metadata
			end
		end
	end
end

local function formatMoney(amount: number): string
	return NumberFormatter.FormatMoney(amount)
end

local function getInitialUpgradePrice(ratePerSecond: number): number
	return math.ceil(math.max(0, ratePerSecond) * 1.45)
end

local function getUpgradeStatsForLevel(baseRatePerSecond: number, level: number): (number, number)
	local targetLevel = math.clamp(math.max(1, math.floor(level)), 1, MAX_BRAINROT_LEVEL)
	local currentRatePerSecond = math.max(1, math.floor(baseRatePerSecond))
	local currentUpgradePrice = getInitialUpgradePrice(currentRatePerSecond)
	for _ = 2, targetLevel do
		currentRatePerSecond = math.ceil(currentRatePerSecond * BRAINROT_RATE_PER_SECOND_MULTIPLIER)
		currentUpgradePrice = math.ceil(currentUpgradePrice * 1.45)
	end

	return currentRatePerSecond, currentUpgradePrice
end

local function updateUpgradeDisplay(state: PedestalState)
	local isUnlocked = isPedestalModelUnlocked(state.pedestalModel)
	if not isUnlocked then
		state.upgradeSurfaceGui.Enabled = false
		state.upgradeButton.Active = false
		state.upgradeButton.AutoButtonColor = false
		state.upgradeCostLabel.Text = ""
		state.upgradeLevelLabel.Text = ""
		return
	end

	local isOccupied = state.placedRarity ~= nil and state.placedModelName ~= nil
	state.upgradeSurfaceGui.Enabled = isOccupied
	state.upgradeButton.Active = isOccupied
	state.upgradeButton.AutoButtonColor = isOccupied
	if not isOccupied then
		state.upgradeCostLabel.Text = ""
		state.upgradeLevelLabel.Text = ""
		return
	end

	local currentLevel = math.clamp(math.max(1, state.brainrotLevel), 1, MAX_BRAINROT_LEVEL)
	local isMaxLevel = currentLevel >= MAX_BRAINROT_LEVEL
	state.upgradeButton.Active = not isMaxLevel
	state.upgradeButton.AutoButtonColor = not isMaxLevel
	if isMaxLevel then
		state.upgradeCostLabel.Text = ""
		state.upgradeLevelLabel.Text = `Level {MAX_BRAINROT_LEVEL}`
		return
	end

	local nextLevel = currentLevel + 1
	state.upgradeCostLabel.Text = formatMoney(state.upgradePrice)
	state.upgradeLevelLabel.Text = `Level {currentLevel} > Level {nextLevel}`
end

local function updateMoneyLabel(state: PedestalState)
	local isUnlocked = isPedestalModelUnlocked(state.pedestalModel)
	if not isUnlocked then
		state.collectButton:SetAttribute("IsPedestalCollectButton", true)
		state.collectButton:SetAttribute("PedestalOccupied", false)
		state.collectButton:SetAttribute("PedestalBankedMoney", 0)
		state.collectButton:SetAttribute("PedestalSuppressUnoccupiedMoney", true)
		return
	end

	local isOccupied = state.placedRarity ~= nil and state.placedModelName ~= nil
	local bankedMoney = math.max(0, state.bankedMoney)
	local suppressUnoccupiedMoneyDisplay = state.suppressUnoccupiedMoneyDisplay == true

	state.collectButton:SetAttribute("IsPedestalCollectButton", true)
	state.collectButton:SetAttribute("PedestalOccupied", isOccupied)
	state.collectButton:SetAttribute("PedestalBankedMoney", bankedMoney)
	state.collectButton:SetAttribute("PedestalSuppressUnoccupiedMoney", suppressUnoccupiedMoneyDisplay)
end

local function getRatePerSecond(rarity: string, modelName: string): number
	local metadata = METADATA_LOOKUP[`${rarity}/{modelName}`]
	assert(metadata, `[PedestalInit] Missing metadata in BrainrotCatalog for {rarity}/{modelName}`)
	return metadata.baseRatePerSecond
end

local function getBrainrotCatalogMetadata(rarity: string, modelName: string): BrainrotCatalogMetadata
	local metadata = METADATA_LOOKUP[`${rarity}/{modelName}`]
	assert(metadata, `[PedestalInit] Missing metadata in BrainrotCatalog for {rarity}/{modelName}`)
	return metadata
end

local function getBrainrotDisplayTemplate(rarity: string, modelName: string): Model
	local rarityFolder = brainrotsRoot:FindFirstChild(rarity)
	assert(rarityFolder, `[PedestalInit] Missing Brainrots rarity folder: {rarity}`)

	local template = rarityFolder:FindFirstChild(modelName)
	assert(template, `[PedestalInit] Missing Brainrots model: {rarity}/{modelName}`)
	assert(template:IsA("Model"), `[PedestalInit] Brainrots.{rarity}.{modelName} must be a Model`)

	return template :: Model
end

local function findPromptAnchorPart(model: Model): BasePart?
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

local function clearPlacedDisplay(state: PedestalState)
	if state.removePrompt then
		state.removePrompt:Destroy()
		state.removePrompt = nil
	end

	if state.placedDisplayModel then
		state.placedDisplayModel:Destroy()
		state.placedDisplayModel = nil
	end
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

local function hasAnyEquippedTool(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			return true
		end
	end

	return false
end

local function onRemovePromptTriggered(state: PedestalState, player: Player)
	if state.plot.ownerUserId ~= player.UserId then
		return
	end

	if not isPedestalModelUnlocked(state.pedestalModel) then
		return
	end

	if hasAnyEquippedTool(player) then
		return
	end

	local rarity = state.placedRarity
	local modelName = state.placedModelName
	if not rarity or not modelName then
		return
	end

	BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local updatedCount = BrainrotToolManager.AddOwnedTool(player, rarity, modelName, true, state.brainrotLevel)
	if updatedCount <= 0 then
		return
	end

	state.placedRarity = nil
	state.placedModelName = nil
	state.brainrotLevel = 1
	state.ratePerSecond = 0
	state.upgradePrice = 0
	state.suppressUnoccupiedMoneyDisplay = false
	clearPlacedDisplay(state)
	updateMoneyLabel(state)
	updateUpgradeDisplay(state)
	savePedestalData(player, state)
end

local function spawnPlacedDisplay(state: PedestalState, rarity: string, modelName: string)
	clearPlacedDisplay(state)
	local metadata = getBrainrotCatalogMetadata(rarity, modelName)
	local template = getBrainrotDisplayTemplate(rarity, modelName)
	local display = template:Clone()
	display.Name = "PlacedBrainrot"
	display.Parent = state.pedestalModel

	for _, descendant in display:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end

	display:PivotTo(state.brainrotAttachment.WorldCFrame)
	display:SetAttribute("Name", metadata.displayName)
	display:SetAttribute("ModelName", modelName)
	display:SetAttribute("Rarity", rarity)
	display:SetAttribute("RatePerSecond", state.ratePerSecond)
	display:SetAttribute("Level", state.brainrotLevel)
	display:SetAttribute("Mutation", metadata.mutation)
	BrainrotBillboard.CreateFromAttributes(display, {
		variant = "Pedestal",
		showDespawnCountdown = false,
	})
	state.placedDisplayModel = display

	local anchorPart = findPromptAnchorPart(display)
	assert(anchorPart, `[PedestalInit] PlacedBrainrot {rarity}/{modelName} has no BasePart for remove prompt`)

	local removePrompt = Instance.new("ProximityPrompt")
	removePrompt.ActionText = "Remove"
	removePrompt.ObjectText = metadata.displayName
	removePrompt.HoldDuration = 0
	removePrompt.RequiresLineOfSight = false
	removePrompt:SetAttribute("IsPedestalRemovePrompt", true)
	removePrompt.Parent = anchorPart
	removePrompt.Triggered:Connect(function(player: Player)
		onRemovePromptTriggered(state, player)
	end)

	state.removePrompt = removePrompt
end

local function refreshPlacedDisplayStats(state: PedestalState)
	local display = state.placedDisplayModel
	if not display then
		return
	end

	display:SetAttribute("RatePerSecond", state.ratePerSecond)
	display:SetAttribute("Level", state.brainrotLevel)
	BrainrotBillboard.CreateFromAttributes(display, {
		variant = "Pedestal",
		showDespawnCountdown = false,
	})
end

savePedestalData = function(player: Player, state: PedestalState)
	DataManager.SetPedestalData(player, state.pedestalId, {
		rarity = state.placedRarity,
		modelName = state.placedModelName,
		level = state.brainrotLevel,
		ratePerSecond = state.ratePerSecond,
		upgradePrice = state.upgradePrice,
		bankedMoney = state.bankedMoney,
	})
end

local function getOwnerPlayer(state: PedestalState): Player?
	local ownerUserId = state.plot.ownerUserId
	if typeof(ownerUserId) ~= "number" then
		return nil
	end

	return Players:GetPlayerByUserId(ownerUserId)
end

local function savePedestalDataForOwner(state: PedestalState)
	local ownerPlayer = getOwnerPlayer(state)
	if ownerPlayer then
		savePedestalData(ownerPlayer, state)
	end
end

local function applyPedestalData(state: PedestalState, data: any)
	state.placedRarity = nil
	state.placedModelName = nil
	state.brainrotLevel = 1
	state.ratePerSecond = 0
	state.upgradePrice = 0
	state.bankedMoney = 0
	state.suppressUnoccupiedMoneyDisplay = false
	clearPlacedDisplay(state)

	if typeof(data) ~= "table" then
		updateMoneyLabel(state)
		updateUpgradeDisplay(state)
		return
	end

	local bankedMoney = data.bankedMoney
	if typeof(bankedMoney) == "number" and bankedMoney > 0 then
		state.bankedMoney = bankedMoney
	end

	local rarity = data.rarity
	local modelName = data.modelName
	if typeof(rarity) == "string" and typeof(modelName) == "string" then
		state.placedRarity = rarity
		state.placedModelName = modelName
		local savedLevel = data.level
		if typeof(savedLevel) == "number" and savedLevel >= 1 then
			state.brainrotLevel = math.clamp(math.floor(savedLevel), 1, MAX_BRAINROT_LEVEL)
		else
			state.brainrotLevel = 1
		end

		local savedRate = data.ratePerSecond
		if typeof(savedRate) == "number" and savedRate > 0 then
			state.ratePerSecond = math.floor(savedRate)
		else
			state.ratePerSecond = getRatePerSecond(rarity, modelName)
		end

		local savedUpgradePrice = data.upgradePrice
		if typeof(savedUpgradePrice) == "number" and savedUpgradePrice > 0 then
			state.upgradePrice = math.floor(savedUpgradePrice)
		else
			state.upgradePrice = getInitialUpgradePrice(state.ratePerSecond)
		end

		spawnPlacedDisplay(state, rarity, modelName)
	end

	updateMoneyLabel(state)
	updateUpgradeDisplay(state)
end

local function clearPedestalOccupancyForPlot(plot: any)
	local plotPedestals = pedestalsByPlot[plot]
	if not plotPedestals then
		return
	end

	for _, state in plotPedestals do
		state.suppressUnoccupiedMoneyDisplay = true
		if
			state.placedRarity ~= nil
			or state.placedModelName ~= nil
			or state.placedDisplayModel ~= nil
			or state.removePrompt ~= nil
		then
			state.placedRarity = nil
			state.placedModelName = nil
			state.brainrotLevel = 1
			state.ratePerSecond = 0
			state.upgradePrice = 0
			clearPlacedDisplay(state)
		end

		updateMoneyLabel(state)
		updateUpgradeDisplay(state)
	end
end

local function getPlotModel(plot: any): Model?
	local model = plot._model
	if model and model:IsA("Model") then
		return model
	end

	return nil
end

local function resolvePlotOwnerUserId(plot: any): number?
	local model = getPlotModel(plot)
	local attributeOwner = if model then model:GetAttribute("OwnerUserId") else nil
	if typeof(attributeOwner) == "number" then
		return attributeOwner
	end

	local ownerUserId = plot.ownerUserId
	if typeof(ownerUserId) == "number" then
		return ownerUserId
	end

	return nil
end

local function handlePlotOwnerChange(plot: any)
	local previousOwnerUserId = lastOwnerUserIdByPlot[plot]
	local currentOwnerUserId = resolvePlotOwnerUserId(plot)

	if previousOwnerUserId ~= currentOwnerUserId then
		-- Best-effort immediate world cleanup whenever ownership transitions.
		clearPedestalOccupancyForPlot(plot)
		lastOwnerUserIdByPlot[plot] = currentOwnerUserId
	end
end

local function onPlacePromptTriggered(state: PedestalState, player: Player)
	if state.plot.ownerUserId ~= player.UserId then
		return
	end

	if not isPedestalModelUnlocked(state.pedestalModel) then
		return
	end

	local equippedTool = getEquippedBrainrotTool(player)
	if not equippedTool then
		return
	end

	local placingRarity, placingModelName = BrainrotToolManager.GetToolMetadata(equippedTool)
	if not placingRarity or not placingModelName then
		return
	end
	local placingLevel = BrainrotToolManager.GetToolLevel(equippedTool)
	local resolvedPlacingLevel = if typeof(placingLevel) == "number"
		then math.clamp(math.floor(placingLevel), 1, MAX_BRAINROT_LEVEL)
		else 1

	BrainrotToolManager.AssertToolTemplate(placingRarity, placingModelName)
	getBrainrotDisplayTemplate(placingRarity, placingModelName)
	local basePlacingRate = getRatePerSecond(placingRarity, placingModelName)
	local placingRate, placingUpgradePrice = getUpgradeStatsForLevel(basePlacingRate, resolvedPlacingLevel)

	local replacedRarity = state.placedRarity
	local replacedModelName = state.placedModelName
	local replacedLevel = state.brainrotLevel
	if replacedRarity and replacedModelName then
		BrainrotToolManager.AssertToolTemplate(replacedRarity, replacedModelName)
	end

	local updatedCount =
		BrainrotToolManager.ConsumeOwnedTool(player, placingRarity, placingModelName, resolvedPlacingLevel)
	if updatedCount < 0 then
		return
	end

	equippedTool:Destroy()

	if replacedRarity and replacedModelName then
		BrainrotToolManager.AddOwnedTool(player, replacedRarity, replacedModelName, false, replacedLevel)
	end

	state.placedRarity = placingRarity
	state.placedModelName = placingModelName
	state.brainrotLevel = resolvedPlacingLevel
	state.ratePerSecond = placingRate
	state.upgradePrice = placingUpgradePrice
	state.suppressUnoccupiedMoneyDisplay = false
	spawnPlacedDisplay(state, placingRarity, placingModelName)
	updateMoneyLabel(state)
	updateUpgradeDisplay(state)

	savePedestalData(player, state)
	TutorialManager.OnPedestalPlaced(player, state.pedestalId)
end

local function onCollectButtonTouched(state: PedestalState, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	if state.plot.ownerUserId ~= player.UserId then
		return
	end

	if not isPedestalModelUnlocked(state.pedestalModel) then
		return
	end

	local now = os.clock()
	if (now - state.collectDebounceAt) < 1 then
		return
	end
	state.collectDebounceAt = now

	if state.bankedMoney <= 0 then
		return
	end

	local payout = state.bankedMoney
	state.bankedMoney = 0
	state.suppressUnoccupiedMoneyDisplay = false
	updateMoneyLabel(state)
	DataManager.UpdateMoney(player, payout)
	savePedestalData(player, state)
	pedestalCollectSfxRemote:FireClient(player, state.placedDisplayModel, state.brainrotAttachment.WorldCFrame)
end

local function isStateUpgradeableForPlayer(state: PedestalState, player: Player): boolean
	if state.plot.ownerUserId ~= player.UserId then
		return false
	end

	if not isPedestalModelUnlocked(state.pedestalModel) then
		return false
	end

	if state.placedRarity == nil or state.placedModelName == nil or state.ratePerSecond <= 0 then
		return false
	end

	local currentLevel = math.max(1, state.brainrotLevel)
	if currentLevel >= MAX_BRAINROT_LEVEL then
		return false
	end

	return state.upgradePrice > 0
end

local function applySingleLevelUpgrade(state: PedestalState, player: Player): boolean
	if not isStateUpgradeableForPlayer(state, player) then
		updateUpgradeDisplay(state)
		return false
	end

	local currentUpgradePrice = state.upgradePrice
	state.ratePerSecond = math.ceil(state.ratePerSecond * BRAINROT_RATE_PER_SECOND_MULTIPLIER)
	state.upgradePrice = math.ceil(currentUpgradePrice * 1.45)
	state.brainrotLevel = math.min(MAX_BRAINROT_LEVEL, math.max(1, state.brainrotLevel) + 1)
	refreshPlacedDisplayStats(state)
	updateUpgradeDisplay(state)
	savePedestalData(player, state)
	pedestalUpgradeSfxRemote:FireClient(player)
	return true
end

local function resolvePendingSkipLevelState(player: Player): PedestalState?
	local pendingRequest = pendingSkipLevelRequestByPlayer[player]
	if not pendingRequest then
		return nil
	end

	local state = pedestalByUpgradeButton[pendingRequest.upgradeButton]
	if not state then
		return nil
	end

	if state.pedestalId ~= pendingRequest.pedestalId then
		return nil
	end

	return state
end

local function onUpgradeButtonRequested(player: Player, upgradeButtonInstance: Instance?)
	if upgradeInFlightByPlayer[player] then
		return
	end
	upgradeInFlightByPlayer[player] = true

	local upgradeButton = if upgradeButtonInstance and upgradeButtonInstance:IsA("GuiButton")
		then upgradeButtonInstance
		else nil
	if not upgradeButton then
		upgradeInFlightByPlayer[player] = nil
		return
	end

	local state = pedestalByUpgradeButton[upgradeButton]
	if not state then
		upgradeInFlightByPlayer[player] = nil
		return
	end

	if not isStateUpgradeableForPlayer(state, player) then
		updateUpgradeDisplay(state)
		upgradeInFlightByPlayer[player] = nil
		return
	end

	local profile = DataManager.Profiles[player]
	if not profile then
		upgradeInFlightByPlayer[player] = nil
		return
	end

	local currentMoney = profile.Data.Money
	local upgradeCost = state.upgradePrice
	if typeof(currentMoney) ~= "number" or upgradeCost <= 0 then
		updateUpgradeDisplay(state)
		upgradeInFlightByPlayer[player] = nil
		return
	end

	if currentMoney < upgradeCost then
		if DataManager.ConsumeSkipLevelCredit(player) then
			local didApplySkipLevelUpgrade = applySingleLevelUpgrade(state, player)
			if not didApplySkipLevelUpgrade then
				DataManager.AddSkipLevelCredits(player, 1)
			end
			pendingSkipLevelRequestByPlayer[player] = nil
			upgradeInFlightByPlayer[player] = nil
			return
		end

		pendingSkipLevelRequestByPlayer[player] = {
			pedestalId = state.pedestalId,
			upgradeButton = state.upgradeButton,
		}
		local didPromptSkipLevelPurchase, promptError = pcall(function()
			MarketplaceService:PromptProductPurchase(player, SKIP_LEVEL_PRODUCT_ID)
		end)
		if not didPromptSkipLevelPurchase then
			warn(`[PedestalInit] Failed to prompt SkipLevel product for {player.Name}: {promptError}`)
			pendingSkipLevelRequestByPlayer[player] = nil
		end

		updateUpgradeDisplay(state)
		upgradeInFlightByPlayer[player] = nil
		return
	end

	DataManager.UpdateMoney(player, -upgradeCost)
	local didApplyMoneyUpgrade = applySingleLevelUpgrade(state, player)
	if not didApplyMoneyUpgrade then
		DataManager.UpdateMoney(player, upgradeCost)
	end
	pendingSkipLevelRequestByPlayer[player] = nil

	upgradeInFlightByPlayer[player] = nil
end

local function processSkipLevelReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not DataManager.Profiles[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local hadPendingRequest = pendingSkipLevelRequestByPlayer[player] ~= nil
	local pendingState = resolvePendingSkipLevelState(player)
	pendingSkipLevelRequestByPlayer[player] = nil

	-- Off-flow purchases are intentionally not granted for this product.
	if not hadPendingRequest then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if pendingState and applySingleLevelUpgrade(pendingState, player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local updatedSkipLevelCredits = DataManager.AddSkipLevelCredits(player, 1)
	if updatedSkipLevelCredits <= 0 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function buildPedestalState(plot: any, pedestalId: string, pedestalModel: Model): PedestalState
	local pedestal = pedestalModel:WaitForChild("Pedestal")
	local placeAttachment = pedestal:WaitForChild("PlaceAttachment")
	local placePrompt = placeAttachment:WaitForChild("ProximityPrompt")
	local pedestalTop = pedestal:WaitForChild("PedestalTop")
	local brainrotAttachment = pedestalTop:WaitForChild("BrainrotAttachment")
	local button = pedestalModel:WaitForChild("Button")
	local collectButton = button:WaitForChild("CollectButton")
	local upgradeButtonRoot = pedestalModel:WaitForChild("UpgradeButton")
	local upgradeButtonBase = upgradeButtonRoot:WaitForChild("UpgradeButtonBase")
	local upgradeSurfaceGui = upgradeButtonBase:WaitForChild("SurfaceGui")
	local upgradeButton = upgradeSurfaceGui:WaitForChild("UpgradeButton")
	local upgradeCostLabel = upgradeButton:WaitForChild("Cost")
	local upgradeLevelLabel = upgradeButton:WaitForChild("Level")

	assert(
		placePrompt:IsA("ProximityPrompt"),
		`[PedestalInit] {pedestalModel.Name} PlaceAttachment.ProximityPrompt is invalid`
	)
	assert(
		brainrotAttachment:IsA("Attachment"),
		`[PedestalInit] {pedestalModel.Name} PedestalTop.BrainrotAttachment is invalid`
	)
	assert(collectButton:IsA("BasePart"), `[PedestalInit] {pedestalModel.Name} Button.CollectButton must be a BasePart`)
	assert(
		upgradeSurfaceGui:IsA("SurfaceGui"),
		`[PedestalInit] {pedestalModel.Name} UpgradeButtonBase.SurfaceGui must be a SurfaceGui`
	)
	assert(upgradeButton:IsA("GuiButton"), `[PedestalInit] {pedestalModel.Name} UpgradeButton must be a GuiButton`)
	assert(
		upgradeCostLabel:IsA("TextLabel"),
		`[PedestalInit] {pedestalModel.Name} UpgradeButton.Cost must be a TextLabel`
	)
	assert(
		upgradeLevelLabel:IsA("TextLabel"),
		`[PedestalInit] {pedestalModel.Name} UpgradeButton.Level must be a TextLabel`
	)

	local state: PedestalState = {
		plot = plot,
		pedestalId = pedestalId,
		pedestalModel = pedestalModel,
		placePrompt = placePrompt,
		collectButton = collectButton,
		upgradeSurfaceGui = upgradeSurfaceGui :: SurfaceGui,
		upgradeButton = upgradeButton :: GuiButton,
		upgradeCostLabel = upgradeCostLabel :: TextLabel,
		upgradeLevelLabel = upgradeLevelLabel :: TextLabel,
		brainrotAttachment = brainrotAttachment,
		placedRarity = nil,
		placedModelName = nil,
		brainrotLevel = 1,
		ratePerSecond = 0,
		upgradePrice = 0,
		bankedMoney = 0,
		placedDisplayModel = nil,
		removePrompt = nil,
		collectDebounceAt = 0,
		suppressUnoccupiedMoneyDisplay = false,
	}

	placePrompt:SetAttribute("IsPedestalPlacePrompt", true)
	placePrompt:SetAttribute("PedestalId", pedestalId)
	state.upgradeButton:SetAttribute("IsPedestalUpgradeButton", true)
	state.upgradeButton:SetAttribute("PedestalId", pedestalId)

	placePrompt.Triggered:Connect(function(player: Player)
		onPlacePromptTriggered(state, player)
	end)
	collectButton.Touched:Connect(function(hit: BasePart)
		onCollectButtonTouched(state, hit)
	end)
	updateMoneyLabel(state)
	updateUpgradeDisplay(state)

	return state
end

local function initializePedestals()
	PlotManager.Initialize()
	for _, plot in PlotManager.GetAllPlots() do
		local byId: { [string]: PedestalState } = {}
		pedestalsByPlot[plot] = byId
		lastOwnerUserIdByPlot[plot] = resolvePlotOwnerUserId(plot)

		for pedestalId, pedestalModel in plot:GetPedestals() do
			local state = buildPedestalState(plot, pedestalId, pedestalModel)
			byId[pedestalId] = state
			pedestalByPrompt[state.placePrompt] = state
			pedestalByCollectButton[state.collectButton] = state
			pedestalByUpgradeButton[state.upgradeButton] = state
			table.insert(allPedestalStates, state)
		end

		local plotModel = getPlotModel(plot)
		if plotModel and not observedPlotModels[plotModel] then
			observedPlotModels[plotModel] = true
			plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				handlePlotOwnerChange(plot)
			end)
			plotModel.Destroying:Connect(function()
				observedPlotModels[plotModel] = nil
				lastOwnerUserIdByPlot[plot] = nil
				pedestalsByPlot[plot] = nil
			end)
		end
	end
end

local function waitForPlayerDataAndPlot(player: Player, timeoutSeconds: number): any?
	local deadline = os.clock() + timeoutSeconds
	while player.Parent == Players and os.clock() < deadline do
		local profile = DataManager.Profiles[player]
		local plot = PlotManager.GetPlotForPlayer(player)
		if profile and plot then
			return plot
		end
		task.wait(0.1)
	end

	return nil
end

local function restorePedestalsForPlayer(player: Player)
	local plot = waitForPlayerDataAndPlot(player, 20)
	if not plot then
		return
	end

	local pedestalsData = DataManager.GetPedestalsData(player)
	if not pedestalsData then
		return
	end

	local plotPedestals = pedestalsByPlot[plot]
	if not plotPedestals then
		return
	end

	for pedestalId, state in plotPedestals do
		applyPedestalData(state, pedestalsData[pedestalId])
		savePedestalData(player, state)
	end
end

buildMetadataLookup()
initializePedestals()

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local cashAmount = DeveloperProductCatalog.CashProducts[receiptInfo.ProductId]
	if cashAmount then
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player or not DataManager.Profiles[player] then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		DataManager.UpdateMoney(player, cashAmount)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if receiptInfo.ProductId == SKIP_LEVEL_PRODUCT_ID then
		return processSkipLevelReceipt(receiptInfo)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

requestPedestalUpgradeRemote.OnServerEvent:Connect(onUpgradeButtonRequested)

for _, player in Players:GetPlayers() do
	task.spawn(restorePedestalsForPlayer, player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(restorePedestalsForPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	upgradeInFlightByPlayer[player] = nil
	pendingSkipLevelRequestByPlayer[player] = nil
	local targetUserId = player.UserId
	for plot in pedestalsByPlot do
		local ownerUserId = resolvePlotOwnerUserId(plot)
		local lastOwnerUserId = lastOwnerUserIdByPlot[plot]
		if ownerUserId == targetUserId or lastOwnerUserId == targetUserId then
			-- Best-effort immediate clear even if owner flip happened first.
			clearPedestalOccupancyForPlot(plot)
			lastOwnerUserIdByPlot[plot] = nil
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for _, state in allPedestalStates do
			if state.placedRarity ~= nil and state.placedModelName ~= nil and state.ratePerSecond > 0 then
				state.bankedMoney += state.ratePerSecond
				updateMoneyLabel(state)
				savePedestalDataForOwner(state)
			end
		end
	end
end)
