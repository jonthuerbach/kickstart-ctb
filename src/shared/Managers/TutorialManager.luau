local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)

local TutorialManager = {}

local STEP_NONE = 0
local STEP_PICKUP_BRAINROT = 1
local STEP_PLACE_BRAINROT = 2
local STEP_UPGRADE_SPEED = 3
local PLAYER_STEP_ATTRIBUTE = "TutorialStep"
local REFRESH_INTERVAL_SECONDS = 0.2
local READY_TIMEOUT_SECONDS = 20
local STEP_TWO_PEDESTAL_ID = "Pedestal_1"

TutorialManager.STEP_NONE = STEP_NONE
TutorialManager.STEP_PICKUP_BRAINROT = STEP_PICKUP_BRAINROT
TutorialManager.STEP_PLACE_BRAINROT = STEP_PLACE_BRAINROT
TutorialManager.STEP_UPGRADE_SPEED = STEP_UPGRADE_SPEED

local registeredPlayers: { [Player]: boolean } = {}
local started = false
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local elapsedSinceRefresh = 0

local function setPlayerStepAttribute(player: Player, step: number)
	player:SetAttribute(PLAYER_STEP_ATTRIBUTE, step)
end

local function refreshTutorialState(player: Player)
	if player.Parent ~= Players then
		return
	end

	local tutorialCompleted = DataManager.IsTutorialCompleted(player)
	local step = DataManager.GetTutorialStep(player)
	local isActiveStep = step >= STEP_PICKUP_BRAINROT and step <= STEP_UPGRADE_SPEED
	if tutorialCompleted or not isActiveStep then
		setPlayerStepAttribute(player, STEP_NONE)
		return
	end

	setPlayerStepAttribute(player, step)
end

local function countPlacedBrainrots(player: Player): number
	local pedestalsData = DataManager.GetPedestalsData(player)
	if not pedestalsData then
		return 0
	end

	local count = 0
	for _, pedestalData in pedestalsData do
		if typeof(pedestalData) ~= "table" then
			continue
		end

		local rarity = pedestalData.rarity
		local modelName = pedestalData.modelName
		if typeof(rarity) == "string" and typeof(modelName) == "string" and rarity ~= "" and modelName ~= "" then
			count += 1
		end
	end

	return count
end

local function countPersistedOwnedBrainrotTools(player: Player): number
	local brainrotToolsData = DataManager.GetBrainrotToolsData(player)
	if not brainrotToolsData then
		return 0
	end

	local count = 0
	for _, rarityTools in brainrotToolsData do
		if typeof(rarityTools) ~= "table" then
			continue
		end

		for _, ownedCount in rarityTools do
			if typeof(ownedCount) == "number" and ownedCount > 0 then
				count += ownedCount
			end
		end
	end

	return count
end

local function countTaggedBrainrotTools(container: Instance?): number
	if not container then
		return 0
	end

	local count = 0
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			count += 1
		end
	end

	return count
end

local function countLiveOwnedBrainrotTools(player: Player): number
	local backpackCount = countTaggedBrainrotTools(player:FindFirstChild("Backpack"))
	local equippedCount = countTaggedBrainrotTools(player.Character)
	return backpackCount + equippedCount
end

local function shouldStartTutorial(player: Player): boolean
	local placedBrainrotCount = countPlacedBrainrots(player)
	if placedBrainrotCount > 0 then
		return false
	end

	if countPersistedOwnedBrainrotTools(player) > 0 then
		return false
	end

	if countLiveOwnedBrainrotTools(player) > 0 then
		return false
	end

	return true
end

local function waitForPlayerReady(player: Player, timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	while player.Parent == Players and os.clock() < deadline do
		local hasProfile = DataManager.Profiles[player] ~= nil
		local hasPlot = PlotManager.GetPlotForPlayer(player) ~= nil
		if hasProfile and hasPlot then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function setStep(player: Player, step: number)
	DataManager.SetTutorialCompleted(player, false)
	DataManager.SetTutorialStep(player, step)
	refreshTutorialState(player)
end

local function completeTutorial(player: Player)
	DataManager.SetTutorialStep(player, STEP_NONE)
	DataManager.SetTutorialCompleted(player, true)
	refreshTutorialState(player)
end

local function registerPlayer(player: Player)
	registeredPlayers[player] = true

	task.spawn(function()
		if not waitForPlayerReady(player, READY_TIMEOUT_SECONDS) then
			return
		end

		local completed = DataManager.IsTutorialCompleted(player)
		local step = DataManager.GetTutorialStep(player)
		if completed then
			DataManager.SetTutorialStep(player, STEP_NONE)
			refreshTutorialState(player)
			return
		end

		if step >= STEP_PICKUP_BRAINROT and step <= STEP_UPGRADE_SPEED then
			refreshTutorialState(player)
			return
		end

		if shouldStartTutorial(player) then
			setStep(player, STEP_PICKUP_BRAINROT)
			return
		end

		DataManager.SetTutorialStep(player, STEP_NONE)
		refreshTutorialState(player)
	end)
end

local function unregisterPlayer(player: Player)
	registeredPlayers[player] = nil
end

local function ensureStarted()
	if started then
		return
	end

	started = true

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end

	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		registerPlayer(player)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		unregisterPlayer(player)
	end)

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsedSinceRefresh += deltaTime
		if elapsedSinceRefresh < REFRESH_INTERVAL_SECONDS then
			return
		end

		elapsedSinceRefresh = 0
		for player in registeredPlayers do
			refreshTutorialState(player)
		end
	end)
end

function TutorialManager.Start()
	ensureStarted()
end

function TutorialManager.OnBrainrotPickedUp(player: Player)
	ensureStarted()

	if DataManager.IsTutorialCompleted(player) then
		return
	end

	local step = DataManager.GetTutorialStep(player)
	if step == STEP_PICKUP_BRAINROT then
		setStep(player, STEP_PLACE_BRAINROT)
	end
end

function TutorialManager.OnPedestalPlaced(player: Player, pedestalId: string)
	ensureStarted()

	if pedestalId ~= STEP_TWO_PEDESTAL_ID then
		return
	end
	if DataManager.IsTutorialCompleted(player) then
		return
	end

	local step = DataManager.GetTutorialStep(player)
	if step == STEP_PLACE_BRAINROT then
		setStep(player, STEP_UPGRADE_SPEED)
	end
end

function TutorialManager.OnSpeedLevelIncreased(player: Player, previousSpeedLevel: number, newSpeedLevel: number)
	ensureStarted()

	if DataManager.IsTutorialCompleted(player) then
		return
	end
	if newSpeedLevel <= previousSpeedLevel then
		return
	end

	local step = DataManager.GetTutorialStep(player)
	if step == STEP_UPGRADE_SPEED then
		completeTutorial(player)
	end
end

return TutorialManager
