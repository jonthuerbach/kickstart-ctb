local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPlotUpgradeRemote = remotes:WaitForChild("RequestPlotUpgrade") :: RemoteEvent
local plotUpgradeRemote = remotes:WaitForChild("PlotUpgrade") :: RemoteEvent
local pedestalUpgradeSfxRemote = remotes:WaitForChild("PedestalUpgradeSfx") :: RemoteEvent

local MAX_PLOT_LEVEL = 10
local PLOT_UPGRADE_INITIAL_PRICE = 10000000
local PLOT_UPGRADE_PRICE_MULTIPLIER = 2
local FIRST_SECOND_FLOOR_PEDESTAL_NUMBER = 11
local LAST_SECOND_FLOOR_PEDESTAL_NUMBER = 20

local ATTR_DEFAULT_TRANSPARENCY = "PlotRevealDefaultTransparency"
local ATTR_DEFAULT_CAN_COLLIDE = "PlotRevealDefaultCanCollide"
local ATTR_DEFAULT_CAN_TOUCH = "PlotRevealDefaultCanTouch"
local ATTR_DEFAULT_CAN_QUERY = "PlotRevealDefaultCanQuery"
local ATTR_DEFAULT_ENABLED = "PlotRevealDefaultEnabled"
local ATTR_PLOT_REVEAL_VISIBLE = "PlotRevealVisible"

type PlotUpgradeState = {
	plot: any,
	plotModel: Model,
	upgradeButton: GuiButton,
	levelLabel: TextLabel,
	costLabel: TextLabel,
	level02Folder: Instance?,
	ceilingNoHoleModel: Instance?,
	ceilingWithHoleModel: Instance?,
	ladderModel: Instance?,
}

local stateByButton: { [GuiButton]: PlotUpgradeState } = {}
local stateByPlot: { [any]: PlotUpgradeState } = {}

local function normalizePlotLevel(plotLevel: number): number
	return math.clamp(math.max(0, math.floor(plotLevel)), 0, MAX_PLOT_LEVEL)
end

local function getUpgradePriceForCurrentLevel(currentPlotLevel: number): number?
	local normalizedCurrentPlotLevel = normalizePlotLevel(currentPlotLevel)
	if normalizedCurrentPlotLevel >= MAX_PLOT_LEVEL then
		return nil
	end

	local price = PLOT_UPGRADE_INITIAL_PRICE * (PLOT_UPGRADE_PRICE_MULTIPLIER ^ normalizedCurrentPlotLevel)
	return math.max(0, math.floor(price))
end

local function rememberDefaultTransparency(instance: Instance, transparency: number)
	if instance:GetAttribute(ATTR_DEFAULT_TRANSPARENCY) == nil then
		instance:SetAttribute(ATTR_DEFAULT_TRANSPARENCY, transparency)
	end
end

local function rememberDefaultEnabled(instance: Instance, enabled: boolean)
	if instance:GetAttribute(ATTR_DEFAULT_ENABLED) == nil then
		instance:SetAttribute(ATTR_DEFAULT_ENABLED, enabled)
	end
end

local function rememberDefaultPartPhysics(part: BasePart)
	if part:GetAttribute(ATTR_DEFAULT_CAN_COLLIDE) == nil then
		part:SetAttribute(ATTR_DEFAULT_CAN_COLLIDE, part.CanCollide)
	end
	if part:GetAttribute(ATTR_DEFAULT_CAN_TOUCH) == nil then
		part:SetAttribute(ATTR_DEFAULT_CAN_TOUCH, part.CanTouch)
	end
	if part:GetAttribute(ATTR_DEFAULT_CAN_QUERY) == nil then
		part:SetAttribute(ATTR_DEFAULT_CAN_QUERY, part.CanQuery)
	end
end

local function setBasePartVisibility(part: BasePart, isVisible: boolean)
	rememberDefaultTransparency(part, part.Transparency)
	rememberDefaultPartPhysics(part)

	if isVisible then
		local defaultTransparency = part:GetAttribute(ATTR_DEFAULT_TRANSPARENCY)
		local defaultCanCollide = part:GetAttribute(ATTR_DEFAULT_CAN_COLLIDE)
		local defaultCanTouch = part:GetAttribute(ATTR_DEFAULT_CAN_TOUCH)
		local defaultCanQuery = part:GetAttribute(ATTR_DEFAULT_CAN_QUERY)
		part.Transparency = if typeof(defaultTransparency) == "number" then defaultTransparency else 0
		part.CanCollide = defaultCanCollide == true
		part.CanTouch = defaultCanTouch == true
		part.CanQuery = defaultCanQuery == true
		return
	end

	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function setDecalVisibility(decal: Decal, isVisible: boolean)
	rememberDefaultTransparency(decal, decal.Transparency)
	if isVisible then
		local defaultTransparency = decal:GetAttribute(ATTR_DEFAULT_TRANSPARENCY)
		decal.Transparency = if typeof(defaultTransparency) == "number" then defaultTransparency else 0
		return
	end

	decal.Transparency = 1
end

local function setTextureVisibility(texture: Texture, isVisible: boolean)
	rememberDefaultTransparency(texture, texture.Transparency)
	if isVisible then
		local defaultTransparency = texture:GetAttribute(ATTR_DEFAULT_TRANSPARENCY)
		texture.Transparency = if typeof(defaultTransparency) == "number" then defaultTransparency else 0
		return
	end

	texture.Transparency = 1
end

local function setGuiVisibility(gui: LayerCollector, isVisible: boolean)
	rememberDefaultEnabled(gui, gui.Enabled)
	if isVisible then
		local defaultEnabled = gui:GetAttribute(ATTR_DEFAULT_ENABLED)
		gui.Enabled = defaultEnabled == true
		return
	end

	gui.Enabled = false
end

local function setPromptVisibility(prompt: ProximityPrompt, isVisible: boolean)
	rememberDefaultEnabled(prompt, prompt.Enabled)
	prompt:SetAttribute(ATTR_PLOT_REVEAL_VISIBLE, isVisible)

	if isVisible then
		local defaultEnabled = prompt:GetAttribute(ATTR_DEFAULT_ENABLED)
		prompt.Enabled = defaultEnabled == true
		return
	end

	prompt.Enabled = false
end

local function applyVisibilityToSingleInstance(instance: Instance, isVisible: boolean)
	if instance:IsA("BasePart") then
		setBasePartVisibility(instance, isVisible)
		return
	end

	if instance:IsA("Decal") or instance:IsA("Texture") then
		if instance:IsA("Decal") then
			setDecalVisibility(instance, isVisible)
		else
			setTextureVisibility(instance, isVisible)
		end
		return
	end

	if instance:IsA("SurfaceGui") or instance:IsA("BillboardGui") then
		setGuiVisibility(instance, isVisible)
		return
	end

	if instance:IsA("ProximityPrompt") then
		setPromptVisibility(instance, isVisible)
	end
end

local function setInstanceVisibility(root: Instance, isVisible: boolean)
	applyVisibilityToSingleInstance(root, isVisible)
	for _, descendant in root:GetDescendants() do
		applyVisibilityToSingleInstance(descendant, isVisible)
	end
end

-- Pedestal visibility is special: we can force-disable UI/prompts while hidden,
-- but must not force-enable them while visible because PedestalInit owns that state.
local function applyPedestalVisibilityToSingleInstance(instance: Instance, isVisible: boolean)
	if instance:IsA("BasePart") then
		setBasePartVisibility(instance, isVisible)
		return
	end

	if instance:IsA("Decal") then
		setDecalVisibility(instance, isVisible)
		return
	end
	if instance:IsA("Texture") then
		setTextureVisibility(instance, isVisible)
		return
	end

	if instance:IsA("ProximityPrompt") then
		instance:SetAttribute(ATTR_PLOT_REVEAL_VISIBLE, isVisible)
		if not isVisible then
			instance.Enabled = false
		end
		return
	end

	if instance:IsA("SurfaceGui") then
		if not isVisible then
			instance.Enabled = false
		end
		return
	end

	if instance:IsA("BillboardGui") then
		if not isVisible then
			instance.Enabled = false
		end
	end
end

local function setPedestalModelVisibility(pedestalModel: Model, isVisible: boolean)
	applyPedestalVisibilityToSingleInstance(pedestalModel, isVisible)
	for _, descendant in pedestalModel:GetDescendants() do
		applyPedestalVisibilityToSingleInstance(descendant, isVisible)
	end
end

local function getSelfAndDescendants(root: Instance): { Instance }
	local allInstances = { root }
	for _, descendant in root:GetDescendants() do
		table.insert(allInstances, descendant)
	end
	return allInstances
end

local function ensureVisibleGeometryFallback(root: Instance)
	local allInstances = getSelfAndDescendants(root)
	local hasVisibleGeometry = false

	for _, instance in allInstances do
		if instance:IsA("BasePart") and instance.Transparency < 1 then
			hasVisibleGeometry = true
			break
		end

		if (instance:IsA("Decal") or instance:IsA("Texture")) and instance.Transparency < 1 then
			hasVisibleGeometry = true
			break
		end
	end

	if hasVisibleGeometry then
		return
	end

	for _, instance in allInstances do
		if instance:IsA("BasePart") then
			rememberDefaultPartPhysics(instance)
			instance.Transparency = 0
			local defaultCanCollide = instance:GetAttribute(ATTR_DEFAULT_CAN_COLLIDE)
			local defaultCanTouch = instance:GetAttribute(ATTR_DEFAULT_CAN_TOUCH)
			local defaultCanQuery = instance:GetAttribute(ATTR_DEFAULT_CAN_QUERY)
			instance.CanCollide = if typeof(defaultCanCollide) == "boolean" then defaultCanCollide else true
			instance.CanTouch = if typeof(defaultCanTouch) == "boolean" then defaultCanTouch else true
			instance.CanQuery = if typeof(defaultCanQuery) == "boolean" then defaultCanQuery else true
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			instance.Transparency = 0
		end
	end
end

local function getPedestalNumberFromId(pedestalId: string): number?
	local pedestalNumberText = pedestalId:match("(%d+)$")
	if not pedestalNumberText then
		return nil
	end

	return tonumber(pedestalNumberText)
end

local function isSecondFloorPedestalNumber(pedestalNumber: number): boolean
	return pedestalNumber >= FIRST_SECOND_FLOOR_PEDESTAL_NUMBER and pedestalNumber <= LAST_SECOND_FLOOR_PEDESTAL_NUMBER
end

local function isPedestalUnlockedForPlotLevel(pedestalNumber: number, plotLevel: number): boolean
	if not isSecondFloorPedestalNumber(pedestalNumber) then
		return true
	end

	local requiredPlotLevel = pedestalNumber - 10
	return plotLevel >= requiredPlotLevel
end

local function resolvePlotOwnerUserId(plot: any): number?
	local model = plot._model
	if model and model:IsA("Model") then
		local ownerFromAttribute = model:GetAttribute("OwnerUserId")
		if typeof(ownerFromAttribute) == "number" then
			return ownerFromAttribute
		end
	end

	local ownerUserId = plot.ownerUserId
	if typeof(ownerUserId) == "number" then
		return ownerUserId
	end

	return nil
end

local function applySecondFloorVisibility(state: PlotUpgradeState, isVisible: boolean)
	if not state.level02Folder then
		return
	end

	setInstanceVisibility(state.level02Folder, isVisible)
end

local function applyCeilingSwap(state: PlotUpgradeState, showCeilingWithHole: boolean)
	if state.ceilingNoHoleModel then
		setInstanceVisibility(state.ceilingNoHoleModel, not showCeilingWithHole)
		if not showCeilingWithHole then
			ensureVisibleGeometryFallback(state.ceilingNoHoleModel)
		end
	end
	if state.ceilingWithHoleModel then
		setInstanceVisibility(state.ceilingWithHoleModel, showCeilingWithHole)
		if showCeilingWithHole then
			ensureVisibleGeometryFallback(state.ceilingWithHoleModel)
		end
	end
end

local function applyLadderVisibility(state: PlotUpgradeState, isVisible: boolean)
	if not state.ladderModel then
		return
	end

	setInstanceVisibility(state.ladderModel, isVisible)
end

local function applySecondFloorPedestalUnlocks(state: PlotUpgradeState, plotLevel: number)
	for pedestalId, pedestalModel in state.plot:GetPedestals() do
		if not pedestalModel or not pedestalModel:IsA("Model") then
			continue
		end

		local pedestalNumber = getPedestalNumberFromId(pedestalId)
		local isUnlocked = true
		if pedestalNumber then
			isUnlocked = isPedestalUnlockedForPlotLevel(pedestalNumber, plotLevel)
		end

		pedestalModel:SetAttribute("PlotPedestalUnlocked", isUnlocked)
		setPedestalModelVisibility(pedestalModel, isUnlocked)
	end
end

local function applyPlotRevealStateForLevel(state: PlotUpgradeState, plotLevel: number)
	local normalizedPlotLevel = normalizePlotLevel(plotLevel)
	local hasSecondFloorAccess = normalizedPlotLevel > 0

	applySecondFloorVisibility(state, hasSecondFloorAccess)
	applyCeilingSwap(state, hasSecondFloorAccess)
	applyLadderVisibility(state, hasSecondFloorAccess)
	applySecondFloorPedestalUnlocks(state, normalizedPlotLevel)
end

local function applyPlotLevelToState(state: PlotUpgradeState, plotLevel: number)
	local normalizedPlotLevel = normalizePlotLevel(plotLevel)
	local upgradePrice = getUpgradePriceForCurrentLevel(normalizedPlotLevel)

	state.upgradeButton:SetAttribute("PlotLevel", normalizedPlotLevel)
	state.upgradeButton:SetAttribute("PlotUpgradePrice", upgradePrice)
	state.levelLabel.Text = `{normalizedPlotLevel}/{MAX_PLOT_LEVEL}`
	state.costLabel.Text = if upgradePrice then NumberFormatter.FormatMoney(upgradePrice) else "MAX"

	applyPlotRevealStateForLevel(state, normalizedPlotLevel)
end

local function syncStateToCurrentOwner(state: PlotUpgradeState)
	local ownerUserId = resolvePlotOwnerUserId(state.plot)
	if typeof(ownerUserId) ~= "number" then
		applyPlotLevelToState(state, 0)
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if not ownerPlayer then
		applyPlotLevelToState(state, 0)
		return
	end

	applyPlotLevelToState(state, DataManager.GetPlotLevel(ownerPlayer))
end

local function buildPlotUpgradeState(plot: any): PlotUpgradeState?
	local plotModel = plot._model
	if not plotModel or not plotModel:IsA("Model") then
		return nil
	end

	local upgradeRoot = plotModel:FindFirstChild("Upgrade")
	if not upgradeRoot then
		warn(`[PlotUpgradeInit] Missing Upgrade folder on plot model {plotModel.Name}`)
		return nil
	end

	local upgradeMain = upgradeRoot:FindFirstChild("Main")
	local surfaceGui = if upgradeMain then upgradeMain:FindFirstChild("SurfaceGui") else nil
	local upgradeButtonFrame = if surfaceGui then surfaceGui:FindFirstChild("UpgradeButtonFrame") else nil
	local upgradeButton = if upgradeButtonFrame then upgradeButtonFrame:FindFirstChild("UpgradeBaseButton") else nil
	local levelLabel = if upgradeButton then upgradeButton:FindFirstChild("Level") else nil
	local costLabel = if upgradeButton then upgradeButton:FindFirstChild("Cost") else nil

	if not upgradeButton or not upgradeButton:IsA("GuiButton") then
		warn(
			`[PlotUpgradeInit] Missing GuiButton at Upgrade.Main.SurfaceGui.UpgradeButtonFrame.UpgradeBaseButton on plot {plotModel.Name}`
		)
		return nil
	end

	if not levelLabel or not levelLabel:IsA("TextLabel") then
		warn(`[PlotUpgradeInit] Missing TextLabel at UpgradeBaseButton.Level on plot {plotModel.Name}`)
		return nil
	end

	if not costLabel or not costLabel:IsA("TextLabel") then
		warn(`[PlotUpgradeInit] Missing TextLabel at UpgradeBaseButton.Cost on plot {plotModel.Name}`)
		return nil
	end

	local levelsFolder = plotModel:FindFirstChild("Levels")
	local level01Folder = if levelsFolder then levelsFolder:FindFirstChild("Level01") else nil
	local level02Folder = if levelsFolder then levelsFolder:FindFirstChild("Level02") else nil
	local level01CeilingFolder = if level01Folder then level01Folder:FindFirstChild("Ceiling") else nil
	local ceilingNoHoleModel = if level01CeilingFolder then level01CeilingFolder:FindFirstChild("CeilingNoHole") else nil
	local ceilingWithHoleModel = if level01CeilingFolder then level01CeilingFolder:FindFirstChild("CeilingWithHole") else nil
	local level01LadderFolder = if level01Folder then level01Folder:FindFirstChild("Ladder") else nil
	local ladderModel = if level01LadderFolder then level01LadderFolder:FindFirstChild("Ladder") else nil

	if not levelsFolder then
		warn(`[PlotUpgradeInit] Missing Levels folder on plot {plotModel.Name}`)
	end
	if not level01Folder then
		warn(`[PlotUpgradeInit] Missing Levels.Level01 on plot {plotModel.Name}`)
	end
	if not level02Folder then
		warn(`[PlotUpgradeInit] Missing Levels.Level02 on plot {plotModel.Name}`)
	end
	if not ceilingNoHoleModel then
		warn(`[PlotUpgradeInit] Missing Levels.Level01.Ceiling.CeilingNoHole on plot {plotModel.Name}`)
	end
	if not ceilingWithHoleModel then
		warn(`[PlotUpgradeInit] Missing Levels.Level01.Ceiling.CeilingWithHole on plot {plotModel.Name}`)
	end
	if not ladderModel then
		warn(`[PlotUpgradeInit] Missing Levels.Level01.Ladder.Ladder on plot {plotModel.Name}`)
	end

	local state: PlotUpgradeState = {
		plot = plot,
		plotModel = plotModel,
		upgradeButton = upgradeButton,
		levelLabel = levelLabel,
		costLabel = costLabel,
		level02Folder = level02Folder,
		ceilingNoHoleModel = ceilingNoHoleModel,
		ceilingWithHoleModel = ceilingWithHoleModel,
		ladderModel = ladderModel,
	}

	upgradeButton:SetAttribute("IsPlotUpgradeButton", true)
	upgradeButton:SetAttribute("PlotMaxLevel", MAX_PLOT_LEVEL)
	applyPlotLevelToState(state, 0)

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		syncStateToCurrentOwner(state)
	end)

	return state
end

local function initializePlotUpgradeButtons()
	PlotManager.Initialize()

	for _, plot in PlotManager.GetAllPlots() do
		local state = buildPlotUpgradeState(plot)
		if not state then
			continue
		end

		stateByButton[state.upgradeButton] = state
		stateByPlot[plot] = state
		syncStateToCurrentOwner(state)
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

local function restorePlotUpgradeForPlayer(player: Player)
	local plot = waitForPlayerDataAndPlot(player, 20)
	if not plot then
		return
	end

	local state = stateByPlot[plot]
	if not state then
		return
	end

	applyPlotLevelToState(state, DataManager.GetPlotLevel(player))
end

local function onRequestPlotUpgrade(player: Player, upgradeButtonInstance: Instance?)
	local upgradeButton = if upgradeButtonInstance and upgradeButtonInstance:IsA("GuiButton")
		then upgradeButtonInstance
		else nil
	if not upgradeButton then
		return
	end

	local state = stateByButton[upgradeButton]
	if not state then
		return
	end

	local ownerUserId = resolvePlotOwnerUserId(state.plot)
	if ownerUserId ~= player.UserId then
		return
	end

	local currentPlotLevel = normalizePlotLevel(DataManager.GetPlotLevel(player))
	if currentPlotLevel >= MAX_PLOT_LEVEL then
		applyPlotLevelToState(state, currentPlotLevel)
		return
	end

	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local upgradePrice = getUpgradePriceForCurrentLevel(currentPlotLevel)
	if not upgradePrice or upgradePrice <= 0 then
		return
	end

	local currentMoney = profile.Data.Money
	if typeof(currentMoney) ~= "number" or currentMoney < upgradePrice then
		applyPlotLevelToState(state, currentPlotLevel)
		return
	end

	DataManager.UpdateMoney(player, -upgradePrice)

	local nextPlotLevel = currentPlotLevel + 1
	DataManager.SetPlotLevel(player, nextPlotLevel)
	applyPlotLevelToState(state, nextPlotLevel)
	pedestalUpgradeSfxRemote:FireClient(player)
	plotUpgradeRemote:FireClient(player, upgradeButton, nextPlotLevel)
end

initializePlotUpgradeButtons()

requestPlotUpgradeRemote.OnServerEvent:Connect(onRequestPlotUpgrade)

for _, player in Players:GetPlayers() do
	task.spawn(restorePlotUpgradeForPlayer, player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(restorePlotUpgradeForPlayer, player)
end)
