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

type PlotUpgradeState = {
	plot: any,
	plotModel: Model,
	upgradeButton: GuiButton,
	levelLabel: TextLabel,
	costLabel: TextLabel,
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

local function applyPlotLevelToState(state: PlotUpgradeState, plotLevel: number)
	local normalizedPlotLevel = normalizePlotLevel(plotLevel)
	local upgradePrice = getUpgradePriceForCurrentLevel(normalizedPlotLevel)
	state.upgradeButton:SetAttribute("PlotLevel", normalizedPlotLevel)
	state.upgradeButton:SetAttribute("PlotUpgradePrice", upgradePrice)
	state.levelLabel.Text = `{normalizedPlotLevel}/{MAX_PLOT_LEVEL}`
	state.costLabel.Text = if upgradePrice then NumberFormatter.FormatMoney(upgradePrice) else "MAX"
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

	local state: PlotUpgradeState = {
		plot = plot,
		plotModel = plotModel,
		upgradeButton = upgradeButton,
		levelLabel = levelLabel,
		costLabel = costLabel,
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
