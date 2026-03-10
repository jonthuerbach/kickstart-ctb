local DataManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

DataManager.Profiles = {}

local function ensureBrainrotToolsRoot(profileData: { [string]: any }): { [string]: { [string]: number } }
	local brainrotTools = profileData.BrainrotTools
	if typeof(brainrotTools) ~= "table" then
		brainrotTools = {}
		profileData.BrainrotTools = brainrotTools
	end

	return brainrotTools :: { [string]: { [string]: number } }
end

function DataManager.UpdateMoney(player: Player, amount: number?)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Money += amount or 1

	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		return
	end

	leaderstats:WaitForChild("Money").Value = profile.Data.Money
	ReplicatedStorage.Remotes.UpdateMoney:FireClient(player, profile.Data.Money)
end

function DataManager.AddBrainrotTool(player: Player, rarity: string, modelName: string, amount: number?): number
	local profile = DataManager.Profiles[player]
	if not profile then
		return 0
	end

	local delta = amount or 1
	if delta < 1 then
		return 0
	end

	local brainrotTools = ensureBrainrotToolsRoot(profile.Data)
	local rarityInventory = brainrotTools[rarity]
	if typeof(rarityInventory) ~= "table" then
		rarityInventory = {}
		brainrotTools[rarity] = rarityInventory
	end

	local currentCount = rarityInventory[modelName]
	if typeof(currentCount) ~= "number" then
		currentCount = 0
	end

	local updatedCount = currentCount + delta
	rarityInventory[modelName] = updatedCount
	return updatedCount
end

function DataManager.GetBrainrotToolsData(player: Player): { [string]: { [string]: number } }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureBrainrotToolsRoot(profile.Data)
end

return DataManager
