local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

type TutorialRuntimeState = {
	characterAddedConnection: RBXScriptConnection?,
	characterRemovingConnection: RBXScriptConnection?,
	beam: Beam?,
}

local runtimeByPlayer: { [Player]: TutorialRuntimeState } = {}
local started = false
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local elapsedSinceRefresh = 0

local templatesFolder = ReplicatedStorage:WaitForChild("Templates")
local tutorialBeamTemplate = templatesFolder:WaitForChild("TutorialBeam")
assert(tutorialBeamTemplate:IsA("Beam"), "[TutorialManager] ReplicatedStorage.Templates.TutorialBeam must be a Beam")

local function getRuntimeState(player: Player): TutorialRuntimeState
	local state = runtimeByPlayer[player]
	if state then
		return state
	end

	state = {
		characterAddedConnection = nil,
		characterRemovingConnection = nil,
		beam = nil,
	}
	runtimeByPlayer[player] = state
	return state
end

local function getRootAttachment(player: Player): Attachment?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return nil
	end

	local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
	if rootAttachment and rootAttachment:IsA("Attachment") then
		return rootAttachment
	end

	return nil
end

local function clearBeam(player: Player)
	local state = runtimeByPlayer[player]
	if not state then
		return
	end

	local beam = state.beam
	if beam then
		beam:Destroy()
		state.beam = nil
	end
end

local function getOrCreateBeam(player: Player): Beam?
	local character = player.Character
	if not character then
		return nil
	end

	local state = getRuntimeState(player)
	local existingBeam = state.beam
	if existingBeam and existingBeam.Parent == character then
		return existingBeam
	end

	local foundBeam = character:FindFirstChild("TutorialBeam")
	if foundBeam and foundBeam:IsA("Beam") then
		state.beam = foundBeam
		return foundBeam
	end

	local beamClone = tutorialBeamTemplate:Clone()
	beamClone.Name = "TutorialBeam"
	beamClone.Parent = character
	state.beam = beamClone

	return beamClone
end

local function getSpeedVendorTutorialAttachment(): Attachment?
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end

	local vendors = world:FindFirstChild("Vendors")
	if not vendors then
		return nil
	end

	local speedVendorBooth = vendors:FindFirstChild("SpeedVendorBooth")
	if not speedVendorBooth then
		return nil
	end

	local speedVendor = speedVendorBooth:FindFirstChild("SpeedVendor")
	if not speedVendor then
		return nil
	end

	local tutorialAttachment = speedVendor:FindFirstChild("TutorialAttachment")
	if tutorialAttachment and tutorialAttachment:IsA("Attachment") then
		return tutorialAttachment
	end

	return nil
end

local function findClosestSpinnerBrainrotAttachment(rootAttachment: Attachment): Attachment?
	local spinnersFolder = Workspace:FindFirstChild("Spinners")
	if not spinnersFolder then
		return nil
	end

	local closestAttachment: Attachment? = nil
	local closestDistance = math.huge
	local rootPosition = rootAttachment.WorldPosition

	for _, spinnerModel in spinnersFolder:GetChildren() do
		if not spinnerModel:IsA("Model") then
			continue
		end
		if spinnerModel:GetAttribute("IsSpinnerTop") ~= true then
			continue
		end

		local brainrot = spinnerModel:FindFirstChild("Brainrot")
		if not brainrot or not brainrot:IsA("Model") then
			continue
		end

		local tutorialAttachment = brainrot:FindFirstChild("TutorialAttachment", true)
		if not tutorialAttachment or not tutorialAttachment:IsA("Attachment") then
			continue
		end

		local distance = (tutorialAttachment.WorldPosition - rootPosition).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestAttachment = tutorialAttachment
		end
	end

	return closestAttachment
end

local function getPedestalOnePlaceAttachment(player: Player): Attachment?
	local plot = PlotManager.GetPlotForPlayer(player)
	if not plot then
		return nil
	end

	local pedestals = plot:GetPedestals()
	local pedestalOne = pedestals[STEP_TWO_PEDESTAL_ID]
	if not pedestalOne or not pedestalOne:IsA("Model") then
		return nil
	end

	local pedestal = pedestalOne:FindFirstChild("Pedestal")
	if not pedestal then
		return nil
	end

	local placeAttachment = pedestal:FindFirstChild("PlaceAttachment")
	if placeAttachment and placeAttachment:IsA("Attachment") then
		return placeAttachment
	end

	return nil
end

local function setPlayerStepAttribute(player: Player, step: number)
	player:SetAttribute(PLAYER_STEP_ATTRIBUTE, step)
end

local function getTargetAttachment(player: Player, step: number, rootAttachment: Attachment): Attachment?
	if step == STEP_PICKUP_BRAINROT then
		return findClosestSpinnerBrainrotAttachment(rootAttachment)
	end

	if step == STEP_PLACE_BRAINROT then
		return getPedestalOnePlaceAttachment(player)
	end

	if step == STEP_UPGRADE_SPEED then
		return getSpeedVendorTutorialAttachment()
	end

	return nil
end

local function refreshBeam(player: Player)
	if player.Parent ~= Players then
		clearBeam(player)
		return
	end

	local tutorialCompleted = DataManager.IsTutorialCompleted(player)
	local step = DataManager.GetTutorialStep(player)
	local isActiveStep = step >= STEP_PICKUP_BRAINROT and step <= STEP_UPGRADE_SPEED
	if tutorialCompleted or not isActiveStep then
		setPlayerStepAttribute(player, STEP_NONE)
		clearBeam(player)
		return
	end

	setPlayerStepAttribute(player, step)

	local rootAttachment = getRootAttachment(player)
	if not rootAttachment then
		clearBeam(player)
		return
	end

	local beam = getOrCreateBeam(player)
	if not beam then
		return
	end

	beam.Attachment0 = rootAttachment
	local targetAttachment = getTargetAttachment(player, step, rootAttachment)
	beam.Attachment1 = targetAttachment
	beam.Enabled = targetAttachment ~= nil
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
	refreshBeam(player)
end

local function completeTutorial(player: Player)
	DataManager.SetTutorialStep(player, STEP_NONE)
	DataManager.SetTutorialCompleted(player, true)
	refreshBeam(player)
end

local function registerPlayer(player: Player)
	local state = getRuntimeState(player)
	if not state.characterAddedConnection then
		state.characterAddedConnection = player.CharacterAdded:Connect(function()
			task.defer(refreshBeam, player)
		end)
	end
	if not state.characterRemovingConnection then
		state.characterRemovingConnection = player.CharacterRemoving:Connect(function()
			clearBeam(player)
		end)
	end

	task.spawn(function()
		if not waitForPlayerReady(player, READY_TIMEOUT_SECONDS) then
			return
		end

		local completed = DataManager.IsTutorialCompleted(player)
		local step = DataManager.GetTutorialStep(player)
		if completed then
			DataManager.SetTutorialStep(player, STEP_NONE)
			refreshBeam(player)
			return
		end

		if step >= STEP_PICKUP_BRAINROT and step <= STEP_UPGRADE_SPEED then
			refreshBeam(player)
			return
		end

		if shouldStartTutorial(player) then
			setStep(player, STEP_PICKUP_BRAINROT)
			return
		end

		DataManager.SetTutorialStep(player, STEP_NONE)
		refreshBeam(player)
	end)
end

local function unregisterPlayer(player: Player)
	local state = runtimeByPlayer[player]
	if not state then
		return
	end

	clearBeam(player)

	if state.characterAddedConnection then
		state.characterAddedConnection:Disconnect()
		state.characterAddedConnection = nil
	end
	if state.characterRemovingConnection then
		state.characterRemovingConnection:Disconnect()
		state.characterRemovingConnection = nil
	end

	runtimeByPlayer[player] = nil
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
		for player in runtimeByPlayer do
			refreshBeam(player)
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
