local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)

local SHOWCASE_DURATION_SECONDS = 10
local HOVER_AMPLITUDE_STUDS = 0.6
local HOVER_CYCLES_PER_SECOND = 0.2
local SPIN_DEGREES_PER_SECOND = 18
local SHOWCASE_MODEL_NAME = "ShowcaseBrainrot"
local MIN_SCALE = 0.001
local OVERSHOOT_SCALE = 1.1
local INTRO_POP_DURATION_SECONDS = 0.35
local INTRO_SETTLE_DURATION_SECONDS = 0.2
local OUTRO_POP_DURATION_SECONDS = 0.25
local OUTRO_SHRINK_DURATION_SECONDS = 0.3

local world = Workspace:WaitForChild("World")
local brainrotBillboardRoot = world:WaitForChild("BrainrotBillboard")
local billboard = brainrotBillboardRoot:WaitForChild("Billboard")
local billboardModelRoot = billboard:WaitForChild("Model")
local brainrotAttachment = billboardModelRoot:WaitForChild("BrainrotAttachment")
assert(
	brainrotAttachment:IsA("Attachment"),
	"[MythicBillboardShowcaseInit] Workspace.World.BrainrotBillboard.Billboard.Model.BrainrotAttachment must be an Attachment"
)

local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")
local mythicTemplatesFolder = brainrotsRoot:WaitForChild("Mythic")
assert(
	mythicTemplatesFolder:IsA("Folder"),
	"[MythicBillboardShowcaseInit] ReplicatedStorage.Brainrots.Mythic must be a Folder"
)

local mythicEntries = BrainrotCatalog.Names.Mythic
assert(typeof(mythicEntries) == "table" and #mythicEntries > 0, "[MythicBillboardShowcaseInit] Mythic catalog is empty")

local activeModel: Model? = nil
local activeModelStartedAt = 0
local activeModelBaseScale = 1

for _, child in billboardModelRoot:GetChildren() do
	if child:IsA("Model") and child.Name == SHOWCASE_MODEL_NAME then
		child:Destroy()
	end
end

local function clearActiveModel()
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end
	activeModelBaseScale = 1
end

local function tweenModelScale(
	model: Model,
	targetScale: number,
	durationSeconds: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): boolean
	if not model.Parent then
		return false
	end

	local scaleDriver = Instance.new("NumberValue")
	scaleDriver.Value = model:GetScale()
	local scaleChangedConnection = scaleDriver:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:ScaleTo(math.max(MIN_SCALE, scaleDriver.Value))
		end
	end)

	local tween = TweenService:Create(
		scaleDriver,
		TweenInfo.new(durationSeconds, easingStyle, easingDirection),
		{ Value = targetScale }
	)
	tween:Play()
	tween.Completed:Wait()

	scaleChangedConnection:Disconnect()
	scaleDriver:Destroy()

	return model.Parent ~= nil
end

local function playSpawnTweens(model: Model, baseScale: number): boolean
	local collapsedScale = math.max(MIN_SCALE, baseScale * MIN_SCALE)
	local overshootScale = math.max(MIN_SCALE, baseScale * OVERSHOOT_SCALE)

	model:ScaleTo(collapsedScale)
	local didPop = tweenModelScale(
		model,
		overshootScale,
		INTRO_POP_DURATION_SECONDS,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	if not didPop then
		return false
	end

	return tweenModelScale(model, baseScale, INTRO_SETTLE_DURATION_SECONDS, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
end

local function playDespawnTweens(model: Model, baseScale: number): boolean
	local collapsedScale = math.max(MIN_SCALE, baseScale * MIN_SCALE)
	local overshootScale = math.max(MIN_SCALE, baseScale * OVERSHOOT_SCALE)
	local didPop = tweenModelScale(
		model,
		overshootScale,
		OUTRO_POP_DURATION_SECONDS,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	if not didPop then
		return false
	end

	return tweenModelScale(
		model,
		collapsedScale,
		OUTRO_SHRINK_DURATION_SECONDS,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)
end

local function configureShowcaseModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end
end

local function spawnShowcaseModel(entry: any): boolean
	local modelName = entry.modelName
	if typeof(modelName) ~= "string" or modelName == "" then
		warn("[MythicBillboardShowcaseInit] Mythic entry missing modelName")
		return false
	end

	local template = mythicTemplatesFolder:FindFirstChild(modelName)
	if not template or not template:IsA("Model") then
		warn(`[MythicBillboardShowcaseInit] Missing mythic model template: {modelName}`)
		return false
	end

	clearActiveModel()

	local clone = template:Clone()
	local baseScale = math.max(MIN_SCALE, clone:GetScale())
	local collapsedScale = math.max(MIN_SCALE, baseScale * MIN_SCALE)
	clone.Name = SHOWCASE_MODEL_NAME
	configureShowcaseModel(clone)
	clone.Parent = billboardModelRoot
	clone:ScaleTo(collapsedScale)
	clone:PivotTo(brainrotAttachment.WorldCFrame)

	activeModel = clone
	activeModelStartedAt = os.clock()
	activeModelBaseScale = baseScale
	return true
end

RunService.Heartbeat:Connect(function()
	local model = activeModel
	if not model or not model.Parent then
		return
	end

	local elapsedSeconds = os.clock() - activeModelStartedAt
	local hoverOffset = math.sin(elapsedSeconds * math.pi * 2 * HOVER_CYCLES_PER_SECOND) * HOVER_AMPLITUDE_STUDS
	local spinRadians = math.rad(SPIN_DEGREES_PER_SECOND) * elapsedSeconds
	local targetCFrame = brainrotAttachment.WorldCFrame
		* CFrame.new(0, hoverOffset, 0)
		* CFrame.Angles(0, spinRadians, 0)
	model:PivotTo(targetCFrame)
end)

task.spawn(function()
	local currentIndex = 1
	while true do
		local entry = mythicEntries[currentIndex]
		local didSpawn = spawnShowcaseModel(entry)
		if didSpawn then
			local model = activeModel
			local baseScale = activeModelBaseScale
			if model and model.Parent then
				playSpawnTweens(model, baseScale)
				task.wait(SHOWCASE_DURATION_SECONDS)

				-- Only play despawn tween if this is still the active showcase model.
				if activeModel == model and model.Parent then
					playDespawnTweens(model, baseScale)
				end
			end
			clearActiveModel()
		else
			task.wait(1)
		end

		currentIndex += 1
		if currentIndex > #mythicEntries then
			currentIndex = 1
		end
	end
end)
