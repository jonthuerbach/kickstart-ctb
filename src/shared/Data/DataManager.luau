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

local function ensureBrainrotToolLevelsRoot(profileData: { [string]: any }): { [string]: { [string]: { number } } }
	local brainrotToolLevels = profileData.BrainrotToolLevels
	if typeof(brainrotToolLevels) ~= "table" then
		brainrotToolLevels = {}
		profileData.BrainrotToolLevels = brainrotToolLevels
	end

	return brainrotToolLevels :: { [string]: { [string]: { number } } }
end

local function ensureRarityLevelInventory(
	brainrotToolLevels: { [string]: { [string]: { number } } },
	rarity: string
): { [string]: { number } }
	local rarityLevels = brainrotToolLevels[rarity]
	if typeof(rarityLevels) ~= "table" then
		rarityLevels = {}
		brainrotToolLevels[rarity] = rarityLevels
	end

	return rarityLevels
end

local function ensureModelLevelInventory(
	brainrotToolLevels: { [string]: { [string]: { number } } },
	rarity: string,
	modelName: string
): { number }
	local rarityLevels = ensureRarityLevelInventory(brainrotToolLevels, rarity)
	local modelLevels = rarityLevels[modelName]
	if typeof(modelLevels) ~= "table" then
		modelLevels = {}
		rarityLevels[modelName] = modelLevels
	end

	return modelLevels
end

local function ensurePedestalsRoot(profileData: { [string]: any }): { [string]: any }
	local pedestals = profileData.Pedestals
	if typeof(pedestals) ~= "table" then
		pedestals = {}
		profileData.Pedestals = pedestals
	end

	return pedestals :: { [string]: any }
end

local function ensureMovementRoot(profileData: { [string]: any }): { [string]: any }
	local movement = profileData.Movement
	if typeof(movement) ~= "table" then
		movement = {}
		profileData.Movement = movement
	end

	if typeof(movement.SpeedLevel) ~= "number" then
		movement.SpeedLevel = 0
	end
	if typeof(movement.JumpLevel) ~= "number" then
		movement.JumpLevel = 0
	end

	return movement :: { [string]: any }
end

local function ensureTutorialRoot(profileData: { [string]: any }): { [string]: any }
	local tutorial = profileData.Tutorial
	if typeof(tutorial) ~= "table" then
		tutorial = {}
		profileData.Tutorial = tutorial
	end

	if typeof(tutorial.Step) ~= "number" then
		tutorial.Step = 0
	end
	if typeof(tutorial.Completed) ~= "boolean" then
		tutorial.Completed = false
	end

	return tutorial :: { [string]: any }
end

local function ensureDeveloperProductsRoot(profileData: { [string]: any }): { [string]: any }
	local developerProducts = profileData.DeveloperProducts
	if typeof(developerProducts) ~= "table" then
		developerProducts = {}
		profileData.DeveloperProducts = developerProducts
	end

	local skipLevelCredits = developerProducts.SkipLevelCredits
	if typeof(skipLevelCredits) ~= "number" then
		developerProducts.SkipLevelCredits = 0
	else
		developerProducts.SkipLevelCredits = math.max(0, math.floor(skipLevelCredits))
	end

	return developerProducts :: { [string]: any }
end

local function pushMoneyToClient(player: Player, money: number)
	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		return
	end

	local moneyValue = leaderstats:WaitForChild("Money")
	if moneyValue and moneyValue:IsA("NumberValue") then
		moneyValue.Value = money
	end
	ReplicatedStorage.Remotes.UpdateMoney:FireClient(player, money)
end

function DataManager.UpdateMoney(player: Player, amount: number?)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Money += amount or 1
	pushMoneyToClient(player, profile.Data.Money)
end

function DataManager.SetMoney(player: Player, money: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local normalizedMoney = math.max(0, money)
	profile.Data.Money = normalizedMoney
	pushMoneyToClient(player, normalizedMoney)
end

function DataManager.AddBrainrotTool(
	player: Player,
	rarity: string,
	modelName: string,
	amount: number?,
	level: number?
): number
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

	local brainrotToolLevels = ensureBrainrotToolLevelsRoot(profile.Data)
	local modelLevels = ensureModelLevelInventory(brainrotToolLevels, rarity, modelName)
	local normalizedLevel = if typeof(level) == "number" then math.max(1, math.floor(level)) else 1
	for _ = 1, delta do
		table.insert(modelLevels, normalizedLevel)
	end

	return updatedCount
end

function DataManager.RemoveBrainrotTool(
	player: Player,
	rarity: string,
	modelName: string,
	amount: number?,
	preferredLevel: number?
): number
	local profile = DataManager.Profiles[player]
	if not profile then
		return -1
	end

	local delta = amount or 1
	if delta < 1 then
		return -1
	end

	local brainrotTools = ensureBrainrotToolsRoot(profile.Data)
	local rarityInventory = brainrotTools[rarity]
	if typeof(rarityInventory) ~= "table" then
		return -1
	end

	local currentCount = rarityInventory[modelName]
	if typeof(currentCount) ~= "number" or currentCount < delta then
		return -1
	end

	local updatedCount = currentCount - delta
	if updatedCount <= 0 then
		rarityInventory[modelName] = nil
		if next(rarityInventory) == nil then
			brainrotTools[rarity] = nil
		end
	else
		rarityInventory[modelName] = updatedCount
	end

	local brainrotToolLevels = ensureBrainrotToolLevelsRoot(profile.Data)
	local rarityLevels = brainrotToolLevels[rarity]
	local modelLevels = if typeof(rarityLevels) == "table" then rarityLevels[modelName] else nil
	if typeof(modelLevels) == "table" then
		local removalsRemaining = delta
		local normalizedPreferredLevel = if typeof(preferredLevel) == "number"
			then math.max(1, math.floor(preferredLevel))
			else nil

		if normalizedPreferredLevel ~= nil then
			for index = #modelLevels, 1, -1 do
				if removalsRemaining <= 0 then
					break
				end

				local candidateLevel = modelLevels[index]
				if
					typeof(candidateLevel) == "number"
					and math.max(1, math.floor(candidateLevel)) == normalizedPreferredLevel
				then
					table.remove(modelLevels, index)
					removalsRemaining -= 1
				end
			end
		end

		while removalsRemaining > 0 and #modelLevels > 0 do
			table.remove(modelLevels, #modelLevels)
			removalsRemaining -= 1
		end

		if #modelLevels == 0 then
			rarityLevels[modelName] = nil
			if next(rarityLevels) == nil then
				brainrotToolLevels[rarity] = nil
			end
		end
	end

	return updatedCount
end

function DataManager.GetBrainrotToolsData(player: Player): { [string]: { [string]: number } }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureBrainrotToolsRoot(profile.Data)
end

function DataManager.GetBrainrotToolLevelsData(player: Player): { [string]: { [string]: { number } } }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureBrainrotToolLevelsRoot(profile.Data)
end

function DataManager.GetPedestalsData(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensurePedestalsRoot(profile.Data)
end

function DataManager.SetPedestalData(player: Player, pedestalId: string, data: any)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local pedestals = ensurePedestalsRoot(profile.Data)
	pedestals[pedestalId] = data
end

function DataManager.GetMovementData(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureMovementRoot(profile.Data)
end

function DataManager.GetSpeedLevel(player: Player): number
	local movement = DataManager.GetMovementData(player)
	if not movement then
		return 0
	end

	local speedLevel = movement.SpeedLevel
	if typeof(speedLevel) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(speedLevel))
end

function DataManager.SetSpeedLevel(player: Player, speedLevel: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local movement = ensureMovementRoot(profile.Data)
	movement.SpeedLevel = math.max(0, math.floor(speedLevel))
end

function DataManager.GetJumpLevel(player: Player): number
	local movement = DataManager.GetMovementData(player)
	if not movement then
		return 0
	end

	local jumpLevel = movement.JumpLevel
	if typeof(jumpLevel) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(jumpLevel))
end

function DataManager.SetJumpLevel(player: Player, jumpLevel: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local movement = ensureMovementRoot(profile.Data)
	movement.JumpLevel = math.max(0, math.floor(jumpLevel))
end

function DataManager.GetTutorialData(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureTutorialRoot(profile.Data)
end

function DataManager.GetDeveloperProductsData(player: Player): { [string]: any }?
	local profile = DataManager.Profiles[player]
	if not profile then
		return nil
	end

	return ensureDeveloperProductsRoot(profile.Data)
end

function DataManager.GetSkipLevelCredits(player: Player): number
	local developerProducts = DataManager.GetDeveloperProductsData(player)
	if not developerProducts then
		return 0
	end

	local skipLevelCredits = developerProducts.SkipLevelCredits
	if typeof(skipLevelCredits) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(skipLevelCredits))
end

function DataManager.AddSkipLevelCredits(player: Player, amount: number?): number
	local profile = DataManager.Profiles[player]
	if not profile then
		return 0
	end

	local delta = if typeof(amount) == "number" then math.floor(amount) else 1
	if delta <= 0 then
		return DataManager.GetSkipLevelCredits(player)
	end

	local developerProducts = ensureDeveloperProductsRoot(profile.Data)
	local currentSkipLevelCredits = developerProducts.SkipLevelCredits
	local updatedSkipLevelCredits = currentSkipLevelCredits + delta
	developerProducts.SkipLevelCredits = updatedSkipLevelCredits

	return updatedSkipLevelCredits
end

function DataManager.ConsumeSkipLevelCredit(player: Player): boolean
	local profile = DataManager.Profiles[player]
	if not profile then
		return false
	end

	local developerProducts = ensureDeveloperProductsRoot(profile.Data)
	local currentSkipLevelCredits = developerProducts.SkipLevelCredits
	if currentSkipLevelCredits <= 0 then
		return false
	end

	developerProducts.SkipLevelCredits = currentSkipLevelCredits - 1
	return true
end

function DataManager.GetTutorialStep(player: Player): number
	local tutorial = DataManager.GetTutorialData(player)
	if not tutorial then
		return 0
	end

	local step = tutorial.Step
	if typeof(step) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(step))
end

function DataManager.SetTutorialStep(player: Player, step: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local tutorial = ensureTutorialRoot(profile.Data)
	tutorial.Step = math.max(0, math.floor(step))
end

function DataManager.IsTutorialCompleted(player: Player): boolean
	local tutorial = DataManager.GetTutorialData(player)
	if not tutorial then
		return false
	end

	return tutorial.Completed == true
end

function DataManager.SetTutorialCompleted(player: Player, completed: boolean)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local tutorial = ensureTutorialRoot(profile.Data)
	tutorial.Completed = completed == true
end

function DataManager.GetPlotLevel(player: Player): number
	local profile = DataManager.Profiles[player]
	if not profile then
		return 0
	end

	return profile.Data.PlotLevel
end

function DataManager.SetPlotLevel(player: Player, plotLevel: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.PlotLevel = math.max(0, math.floor(plotLevel))
end
return DataManager
