local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local BrainrotBillboard = require(ReplicatedStorage.Shared.Utils.BrainrotBillboard)
local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)

local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")

type PedestalState = {
	plot: any,
	pedestalId: string,
	pedestalModel: Model,
	placePrompt: ProximityPrompt,
	collectButton: BasePart,
	moneyLabel: TextLabel,
	brainrotAttachment: Attachment,
	placedRarity: string?,
	placedModelName: string?,
	ratePerSecond: number,
	bankedMoney: number,
	placedDisplayModel: Model?,
	removePrompt: ProximityPrompt?,
	collectDebounceAt: number,
}

local pedestalByPrompt: { [ProximityPrompt]: PedestalState } = {}
local pedestalByCollectButton: { [BasePart]: PedestalState } = {}
local pedestalsByPlot: { [any]: { [string]: PedestalState } } = {}
local allPedestalStates: { PedestalState } = {}
local savePedestalData: (Player, PedestalState) -> ()

type BrainrotCatalogMetadata = {
	displayName: string,
	baseRatePerSecond: number,
	mutation: string?,
}

local METADATA_LOOKUP: { [string]: BrainrotCatalogMetadata } = {}

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
					displayName = if typeof(entry.name) == "string" and entry.name ~= "" then entry.name else entry.modelName,
					baseRatePerSecond = entry.ratePerSecond,
					mutation = if typeof(entry.mutation) == "string" and entry.mutation ~= "" then entry.mutation else nil,
				}

				METADATA_LOOKUP[`${entry.rarity}/{entry.modelName}`] = metadata
			end
		end
	end
end

local function formatMoney(amount: number): string
	return NumberFormatter.FormatMoney(amount)
end

local function updateMoneyLabel(state: PedestalState)
	local isOccupied = state.placedRarity ~= nil and state.placedModelName ~= nil
	local bankedMoney = math.max(0, state.bankedMoney)

	-- Only hide text when the pedestal is empty and there is no banked payout.
	local displayText = if not isOccupied and bankedMoney <= 0 then "" else formatMoney(bankedMoney)
	state.moneyLabel.Text = displayText

	-- Mirror state for client-side display enforcement.
	state.collectButton:SetAttribute("IsPedestalCollectButton", true)
	state.collectButton:SetAttribute("PedestalOccupied", isOccupied)
	state.collectButton:SetAttribute("PedestalBankedMoney", bankedMoney)
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

	if hasAnyEquippedTool(player) then
		return
	end

	local rarity = state.placedRarity
	local modelName = state.placedModelName
	if not rarity or not modelName then
		return
	end

	BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local updatedCount = BrainrotToolManager.AddOwnedTool(player, rarity, modelName, true)
	if updatedCount <= 0 then
		return
	end

	state.placedRarity = nil
	state.placedModelName = nil
	state.ratePerSecond = 0
	clearPlacedDisplay(state)
	updateMoneyLabel(state)
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

savePedestalData = function(player: Player, state: PedestalState)
	DataManager.SetPedestalData(player, state.pedestalId, {
		rarity = state.placedRarity,
		modelName = state.placedModelName,
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
	state.ratePerSecond = 0
	state.bankedMoney = 0
	clearPlacedDisplay(state)

	if typeof(data) ~= "table" then
		updateMoneyLabel(state)
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
		state.ratePerSecond = getRatePerSecond(rarity, modelName)
		spawnPlacedDisplay(state, rarity, modelName)
	end

	updateMoneyLabel(state)
end

local function onPlacePromptTriggered(state: PedestalState, player: Player)
	if state.plot.ownerUserId ~= player.UserId then
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

	BrainrotToolManager.AssertToolTemplate(placingRarity, placingModelName)
	getBrainrotDisplayTemplate(placingRarity, placingModelName)
	local placingRate = getRatePerSecond(placingRarity, placingModelName)

	local replacedRarity = state.placedRarity
	local replacedModelName = state.placedModelName
	if replacedRarity and replacedModelName then
		BrainrotToolManager.AssertToolTemplate(replacedRarity, replacedModelName)
	end

	local updatedCount = BrainrotToolManager.ConsumeOwnedTool(player, placingRarity, placingModelName)
	if updatedCount < 0 then
		return
	end

	equippedTool:Destroy()

	if replacedRarity and replacedModelName then
		BrainrotToolManager.AddOwnedTool(player, replacedRarity, replacedModelName, false)
	end

	state.placedRarity = placingRarity
	state.placedModelName = placingModelName
	state.ratePerSecond = placingRate
	spawnPlacedDisplay(state, placingRarity, placingModelName)
	updateMoneyLabel(state)

	savePedestalData(player, state)
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
	updateMoneyLabel(state)
	DataManager.UpdateMoney(player, payout)
	savePedestalData(player, state)
end

local function buildPedestalState(plot: any, pedestalId: string, pedestalModel: Model): PedestalState
	local pedestal = pedestalModel:WaitForChild("Pedestal")
	local placeAttachment = pedestal:WaitForChild("PlaceAttachment")
	local placePrompt = placeAttachment:WaitForChild("ProximityPrompt")
	local pedestalTop = pedestal:WaitForChild("PedestalTop")
	local brainrotAttachment = pedestalTop:WaitForChild("BrainrotAttachment")
	local button = pedestalModel:WaitForChild("Button")
	local collectButton = button:WaitForChild("CollectButton")
	local surfaceGui = collectButton:WaitForChild("SurfaceGui")
	local moneyLabel = surfaceGui:WaitForChild("MoneyLabel")

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
		moneyLabel:IsA("TextLabel"),
		`[PedestalInit] {pedestalModel.Name} CollectButton.SurfaceGui.MoneyLabel must be a TextLabel`
	)

	local state: PedestalState = {
		plot = plot,
		pedestalId = pedestalId,
		pedestalModel = pedestalModel,
		placePrompt = placePrompt,
		collectButton = collectButton,
		moneyLabel = moneyLabel,
		brainrotAttachment = brainrotAttachment,
		placedRarity = nil,
		placedModelName = nil,
		ratePerSecond = 0,
		bankedMoney = 0,
		placedDisplayModel = nil,
		removePrompt = nil,
		collectDebounceAt = 0,
	}

	placePrompt:SetAttribute("IsPedestalPlacePrompt", true)
	placePrompt:SetAttribute("PedestalId", pedestalId)

	placePrompt.Triggered:Connect(function(player: Player)
		onPlacePromptTriggered(state, player)
	end)
	collectButton.Touched:Connect(function(hit: BasePart)
		onCollectButtonTouched(state, hit)
	end)
	updateMoneyLabel(state)

	return state
end

local function initializePedestals()
	PlotManager.Initialize()
	for _, plot in PlotManager.GetAllPlots() do
		local byId: { [string]: PedestalState } = {}
		pedestalsByPlot[plot] = byId

		for pedestalId, pedestalModel in plot:GetPedestals() do
			local state = buildPedestalState(plot, pedestalId, pedestalModel)
			byId[pedestalId] = state
			pedestalByPrompt[state.placePrompt] = state
			pedestalByCollectButton[state.collectButton] = state
			table.insert(allPedestalStates, state)
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

for _, player in Players:GetPlayers() do
	task.spawn(restorePedestalsForPlayer, player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(restorePedestalsForPlayer, player)
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
