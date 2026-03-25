local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)

local SHOWCASE_DURATION_SECONDS = 10
local HOVER_AMPLITUDE_STUDS = 0.6
local HOVER_CYCLES_PER_SECOND = 0.2
local SPIN_DEGREES_PER_SECOND = 18
local SHOWCASE_MODEL_NAME = "ShowcaseBrainrot"

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
	clone.Name = SHOWCASE_MODEL_NAME
	configureShowcaseModel(clone)
	clone.Parent = billboardModelRoot
	clone:PivotTo(brainrotAttachment.WorldCFrame)

	activeModel = clone
	activeModelStartedAt = os.clock()
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
		spawnShowcaseModel(entry)

		task.wait(SHOWCASE_DURATION_SECONDS)

		currentIndex += 1
		if currentIndex > #mythicEntries then
			currentIndex = 1
		end
	end
end)
