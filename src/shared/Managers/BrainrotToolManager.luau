local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local BrainrotToolManager = {}

local brainrotToolsRoot = ReplicatedStorage:WaitForChild("BrainrotTools")

local BRAINROT_TOOL_ATTRIBUTE = "IsBrainrotTool"
local BRAINROT_TOOL_RARITY_ATTRIBUTE = "BrainrotRarity"
local BRAINROT_TOOL_MODEL_ATTRIBUTE = "BrainrotModelName"
local BRAINROT_TOOL_LEVEL_ATTRIBUTE = "BrainrotLevel"

local function tagTool(tool: Tool, rarity: string, modelName: string, level: number?)
	tool:SetAttribute(BRAINROT_TOOL_ATTRIBUTE, true)
	tool:SetAttribute(BRAINROT_TOOL_RARITY_ATTRIBUTE, rarity)
	tool:SetAttribute(BRAINROT_TOOL_MODEL_ATTRIBUTE, modelName)

	if typeof(level) == "number" then
		tool:SetAttribute(BRAINROT_TOOL_LEVEL_ATTRIBUTE, math.max(1, math.floor(level)))
	else
		tool:SetAttribute(BRAINROT_TOOL_LEVEL_ATTRIBUTE, nil)
	end
end

local function isTaggedBrainrotTool(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute(BRAINROT_TOOL_ATTRIBUTE) == true
end

local function removeTaggedTools(parent: Instance?)
	if not parent then
		return
	end

	for _, child in parent:GetChildren() do
		if isTaggedBrainrotTool(child) then
			child:Destroy()
		end
	end
end

local function removeOneMatchingTaggedTool(parent: Instance?, rarity: string, modelName: string, level: number?)
	if not parent then
		return
	end

	local fallbackMatchingTool: Tool? = nil
	local normalizedLevel = if typeof(level) == "number" then math.max(1, math.floor(level)) else nil

	for _, child in parent:GetChildren() do
		if
			child:IsA("Tool")
			and child:GetAttribute(BRAINROT_TOOL_ATTRIBUTE) == true
			and child:GetAttribute(BRAINROT_TOOL_RARITY_ATTRIBUTE) == rarity
			and child:GetAttribute(BRAINROT_TOOL_MODEL_ATTRIBUTE) == modelName
		then
			if normalizedLevel == nil then
				child:Destroy()
				return
			end

			local childLevel = child:GetAttribute(BRAINROT_TOOL_LEVEL_ATTRIBUTE)
			if typeof(childLevel) == "number" and math.max(1, math.floor(childLevel)) == normalizedLevel then
				child:Destroy()
				return
			end

			if fallbackMatchingTool == nil then
				fallbackMatchingTool = child
			end
		end
	end

	if fallbackMatchingTool then
		fallbackMatchingTool:Destroy()
		return
	end
end

function BrainrotToolManager.AssertToolTemplate(rarity: string, modelName: string): Tool
	local rarityFolder = brainrotToolsRoot:FindFirstChild(rarity)
	assert(rarityFolder, `[BrainrotToolManager] Missing tool rarity folder BrainrotTools.{rarity}`)

	local template = rarityFolder:FindFirstChild(modelName)
	assert(template, `[BrainrotToolManager] Missing brainrot tool template BrainrotTools.{rarity}.{modelName}`)
	assert(template:IsA("Tool"), `[BrainrotToolManager] BrainrotTools.{rarity}.{modelName} must be a Tool`)

	return template :: Tool
end

function BrainrotToolManager.GrantToolInstance(
	player: Player,
	rarity: string,
	modelName: string,
	autoEquip: boolean?,
	level: number?
): Tool
	local template = BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local backpack = player:WaitForChild("Backpack")
	local starterGear = player:WaitForChild("StarterGear")

	local backpackTool = template:Clone()
	tagTool(backpackTool, rarity, modelName, level)
	backpackTool.Parent = backpack

	local starterTool = template:Clone()
	tagTool(starterTool, rarity, modelName, level)
	starterTool.Parent = starterGear

	if autoEquip then
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid:EquipTool(backpackTool)
		end
	end

	return backpackTool
end

function BrainrotToolManager.AddOwnedTool(
	player: Player,
	rarity: string,
	modelName: string,
	autoEquip: boolean?,
	level: number?
): number
	BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local updatedCount = DataManager.AddBrainrotTool(player, rarity, modelName, 1, level)
	if updatedCount <= 0 then
		warn(`[BrainrotToolManager] Could not persist tool ownership for {player.Name}: {rarity}/{modelName}`)
		return updatedCount
	end

	DataManager.DiscoverBrainrot(player, rarity, modelName)

	BrainrotToolManager.GrantToolInstance(player, rarity, modelName, autoEquip, level)
	return updatedCount
end

function BrainrotToolManager.ConsumeOwnedTool(player: Player, rarity: string, modelName: string, level: number?): number
	local updatedCount = DataManager.RemoveBrainrotTool(player, rarity, modelName, 1, level)
	if updatedCount < 0 then
		return updatedCount
	end

	removeOneMatchingTaggedTool(player.StarterGear, rarity, modelName, level)
	return updatedCount
end

function BrainrotToolManager.GetToolMetadata(tool: Tool): (string?, string?)
	local rarity = tool:GetAttribute(BRAINROT_TOOL_RARITY_ATTRIBUTE)
	local modelName = tool:GetAttribute(BRAINROT_TOOL_MODEL_ATTRIBUTE)
	if typeof(rarity) ~= "string" or typeof(modelName) ~= "string" then
		return nil, nil
	end

	return rarity, modelName
end

function BrainrotToolManager.GetToolLevel(tool: Tool): number?
	local level = tool:GetAttribute(BRAINROT_TOOL_LEVEL_ATTRIBUTE)
	if typeof(level) ~= "number" then
		return nil
	end

	return math.max(1, math.floor(level))
end

function BrainrotToolManager.RestoreOwnedTools(player: Player)
	local toolsData = DataManager.GetBrainrotToolsData(player)
	if not toolsData then
		return
	end
	local toolLevelsData = DataManager.GetBrainrotToolLevelsData(player)

	local backpack = player:WaitForChild("Backpack")
	local starterGear = player:WaitForChild("StarterGear")

	removeTaggedTools(backpack)
	removeTaggedTools(starterGear)
	removeTaggedTools(player.Character)

	for rarity, rarityTools in toolsData do
		if typeof(rarityTools) ~= "table" then
			continue
		end

		for modelName, count in rarityTools do
			if typeof(modelName) ~= "string" or typeof(count) ~= "number" or count <= 0 then
				continue
			end

			local modelLevels = nil
			if typeof(toolLevelsData) == "table" then
				local rarityLevelInventory = toolLevelsData[rarity]
				if typeof(rarityLevelInventory) == "table" then
					local candidateModelLevels = rarityLevelInventory[modelName]
					if typeof(candidateModelLevels) == "table" then
						modelLevels = candidateModelLevels
					end
				end
			end

			for index = 1, count do
				local level = nil
				if modelLevels and typeof(modelLevels[index]) == "number" then
					level = math.max(1, math.floor(modelLevels[index]))
				end
				BrainrotToolManager.GrantToolInstance(player, rarity, modelName, false, level)
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	removeTaggedTools(player.Character)
end)

return BrainrotToolManager
