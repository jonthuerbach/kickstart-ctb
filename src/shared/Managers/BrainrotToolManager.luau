local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local BrainrotToolManager = {}

local brainrotToolsRoot = ReplicatedStorage:WaitForChild("BrainrotTools")

local BRAINROT_TOOL_ATTRIBUTE = "IsBrainrotTool"
local BRAINROT_TOOL_RARITY_ATTRIBUTE = "BrainrotRarity"
local BRAINROT_TOOL_MODEL_ATTRIBUTE = "BrainrotModelName"

local function tagTool(tool: Tool, rarity: string, modelName: string)
	tool:SetAttribute(BRAINROT_TOOL_ATTRIBUTE, true)
	tool:SetAttribute(BRAINROT_TOOL_RARITY_ATTRIBUTE, rarity)
	tool:SetAttribute(BRAINROT_TOOL_MODEL_ATTRIBUTE, modelName)
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

function BrainrotToolManager.AssertToolTemplate(rarity: string, modelName: string): Tool
	local rarityFolder = brainrotToolsRoot:FindFirstChild(rarity)
	assert(rarityFolder, `[BrainrotToolManager] Missing tool rarity folder BrainrotTools.{rarity}`)

	local template = rarityFolder:FindFirstChild(modelName)
	assert(template, `[BrainrotToolManager] Missing brainrot tool template BrainrotTools.{rarity}.{modelName}`)
	assert(template:IsA("Tool"), `[BrainrotToolManager] BrainrotTools.{rarity}.{modelName} must be a Tool`)

	return template :: Tool
end

function BrainrotToolManager.GrantToolInstance(player: Player, rarity: string, modelName: string, autoEquip: boolean?): Tool
	local template = BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local backpack = player:WaitForChild("Backpack")
	local starterGear = player:WaitForChild("StarterGear")

	local backpackTool = template:Clone()
	tagTool(backpackTool, rarity, modelName)
	backpackTool.Parent = backpack

	local starterTool = template:Clone()
	tagTool(starterTool, rarity, modelName)
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

function BrainrotToolManager.AddOwnedTool(player: Player, rarity: string, modelName: string, autoEquip: boolean?): number
	BrainrotToolManager.AssertToolTemplate(rarity, modelName)

	local updatedCount = DataManager.AddBrainrotTool(player, rarity, modelName, 1)
	if updatedCount <= 0 then
		warn(`[BrainrotToolManager] Could not persist tool ownership for {player.Name}: {rarity}/{modelName}`)
		return updatedCount
	end

	BrainrotToolManager.GrantToolInstance(player, rarity, modelName, autoEquip)
	return updatedCount
end

function BrainrotToolManager.RestoreOwnedTools(player: Player)
	local toolsData = DataManager.GetBrainrotToolsData(player)
	if not toolsData then
		return
	end

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

			for _ = 1, count do
				BrainrotToolManager.GrantToolInstance(player, rarity, modelName, false)
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	removeTaggedTools(player.Character)
end)

return BrainrotToolManager
