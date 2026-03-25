local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local STEP_ATTRIBUTE = "TutorialStep"
local STEP_NONE = 0
local STEP_PICKUP_BRAINROT = 1
local STEP_PLACE_BRAINROT = 2
local STEP_UPGRADE_SPEED = 3
local STEP_TWO_PEDESTAL_ID = "Pedestal_1"
local BEAM_REFRESH_INTERVAL_SECONDS = 0.2

local STEP_MESSAGES: { [number]: string } = {
	[STEP_PICKUP_BRAINROT] = "Go get a brainrot!",
	[STEP_PLACE_BRAINROT] = "Place the brainrot in your base!",
	[STEP_UPGRADE_SPEED] = "Go upgrade your speed!",
}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local templatesFolder = ReplicatedStorage:WaitForChild("Templates")
local tutorialBeamTemplate = templatesFolder:WaitForChild("TutorialBeam")
assert(tutorialBeamTemplate:IsA("Beam"), "[TutorialStep] ReplicatedStorage.Templates.TutorialBeam must be a Beam")

-- Step label UI

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TutorialStepGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "TutorialStepLabel"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -56)
label.Size = UDim2.fromScale(0.6, 0.07)
label.BackgroundTransparency = 1
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.FredokaOne
label.Visible = false
label.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
stroke.Thickness = 0.1
stroke.LineJoinMode = Enum.LineJoinMode.Round
stroke.Parent = label

local function getCurrentStep(): number
	local stepValue = localPlayer:GetAttribute(STEP_ATTRIBUTE)
	return if typeof(stepValue) == "number" then math.floor(stepValue) else STEP_NONE
end

local function refreshTutorialLabel()
	local step = getCurrentStep()
	local message = STEP_MESSAGES[step]
	if message then
		label.Text = message
		label.Visible = true
		return
	end

	label.Text = ""
	label.Visible = false
end

localPlayer:GetAttributeChangedSignal(STEP_ATTRIBUTE):Connect(refreshTutorialLabel)
refreshTutorialLabel()

-- Beam (client-only so only this player sees it)

local currentBeam: Beam? = nil

local function getRootAttachment(): Attachment?
	local character = localPlayer.Character
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

local function clearBeam()
	if currentBeam then
		currentBeam:Destroy()
		currentBeam = nil
	end
end

local function getOrCreateBeam(): Beam?
	local character = localPlayer.Character
	if not character then
		return nil
	end

	if currentBeam and currentBeam.Parent == character then
		return currentBeam
	end

	clearBeam()

	local beamClone = tutorialBeamTemplate:Clone()
	beamClone.Name = "TutorialBeam"
	beamClone.Parent = character
	currentBeam = beamClone

	return beamClone
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

local function findPlayerPlotModel(): Model?
	for _, child in Workspace:GetChildren() do
		if
			child:IsA("Model")
			and child:GetAttribute("IsPlotModel") == true
			and child:GetAttribute("OwnerUserId") == localPlayer.UserId
		then
			return child
		end
	end
	return nil
end

local function getPedestalOnePlaceAttachment(): Attachment?
	local plotModel = findPlayerPlotModel()
	if not plotModel then
		return nil
	end

	local pedestalOne = plotModel:FindFirstChild(STEP_TWO_PEDESTAL_ID)
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

local function getTargetAttachment(step: number, rootAttachment: Attachment): Attachment?
	if step == STEP_PICKUP_BRAINROT then
		return findClosestSpinnerBrainrotAttachment(rootAttachment)
	end

	if step == STEP_PLACE_BRAINROT then
		return getPedestalOnePlaceAttachment()
	end

	if step == STEP_UPGRADE_SPEED then
		return getSpeedVendorTutorialAttachment()
	end

	return nil
end

local function refreshBeam()
	local step = getCurrentStep()

	if step < STEP_PICKUP_BRAINROT or step > STEP_UPGRADE_SPEED then
		clearBeam()
		return
	end

	local rootAttachment = getRootAttachment()
	if not rootAttachment then
		clearBeam()
		return
	end

	local beam = getOrCreateBeam()
	if not beam then
		return
	end

	beam.Attachment0 = rootAttachment
	local targetAttachment = getTargetAttachment(step, rootAttachment)
	beam.Attachment1 = targetAttachment
	beam.Enabled = targetAttachment ~= nil
end

local beamElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime: number)
	beamElapsed += deltaTime
	if beamElapsed < BEAM_REFRESH_INTERVAL_SECONDS then
		return
	end
	beamElapsed = 0
	refreshBeam()
end)

localPlayer.CharacterRemoving:Connect(function()
	currentBeam = nil
end)
