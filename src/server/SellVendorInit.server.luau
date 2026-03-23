local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sellBrainrotActionRemote = remotes:WaitForChild("SellBrainrotAction") :: RemoteEvent
local updateConfirmSellBrainrotActionText = remotes:WaitForChild("UpdateConfirmSellBrainrotActionText") :: RemoteEvent

local toggleSellVendorMenuRemote = remotes:WaitForChild("ToggleSellVendorMenu") :: RemoteEvent
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)
local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local pendingSellConfirmAction: { [Player]: string? } = {}
local RATE_LOOKUP: { [string]: number } = {}

local SELL_RATE_MULTIPLIER = 100

local DEFAULT_SELL_ONE_TEXT = "I wanna sell this brainrot!"
local DEFAULT_SELL_ALL_TEXT = "I wanna sell all these brainrots!"
local CONFIRM_SELL_ONE_TEXT = "Are you sure you want to sell this?"
local CONFIRM_SELL_ALL_TEXT = "Are you sure you want to sell all?"

local function buildRateLookup()
	for _, entries in BrainrotCatalog.Names do
		if typeof(entries) ~= "table" then
			continue
		end

		for _, entry in entries do
			if
				typeof(entry) == "table"
				and typeof(entry.rarity) == "string"
				and typeof(entry.modelName) == "string"
				and typeof(entry.ratePerSecond) == "number"
			then
				RATE_LOOKUP[`${entry.rarity}/{entry.modelName}`] = entry.ratePerSecond
			end
		end
	end
end

local function getRatePerSecond(rarity: string, modelName: string): number?
	return RATE_LOOKUP[`${rarity}/{modelName}`]
end

local function getPayoutForTool(rarity: string, modelName: string): number
	local ratePerSecond = getRatePerSecond(rarity, modelName)
	if not ratePerSecond then
		warn(`[SellVendorInit] Missing ratePerSecond in BrainrotCatalog for {rarity}/{modelName}`)
		return 0
	end

	return ratePerSecond * SELL_RATE_MULTIPLIER
end

local function destroyBrainrotToolsInContainer(container: Instance?)
	if not container then
		return
	end

	for _, child in container:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end

		local rarity, modelName = BrainrotToolManager.GetToolMetadata(child)
		if rarity and modelName then
			child:Destroy()
		end
	end
end

local function payoutAndSellOne(player: Player)
	local character = player.Character
	if not character then
		print(`[SellVendorInit] {player.Name} has no character to sell from`)
		return
	end

	local heldBrainrot: Tool? = nil
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local rarity, modelName = BrainrotToolManager.GetToolMetadata(child)
			if rarity and modelName then
				heldBrainrot = child
				break
			end
		end
	end

	if not heldBrainrot then
		print(`[SellVendorInit] {player.Name} has no brainrot to sell`)
		return
	end

	local rarity, modelName = BrainrotToolManager.GetToolMetadata(heldBrainrot)
	if not rarity or not modelName then
		warn(`[SellVendorInit] Could not resolve metadata for equipped tool {heldBrainrot.Name}`)
		return
	end
	local heldLevel = BrainrotToolManager.GetToolLevel(heldBrainrot)
	local resolvedHeldLevel = if typeof(heldLevel) == "number" then math.max(1, math.floor(heldLevel)) else 1

	local updatedCount = DataManager.RemoveBrainrotTool(player, rarity, modelName, 1, resolvedHeldLevel)
	if updatedCount < 0 then
		warn(`[SellVendorInit] Could not persist sell_one for {player.Name}: {rarity}/{modelName}`)
		return
	end

	local payout = getPayoutForTool(rarity, modelName)
	if payout > 0 then
		DataManager.UpdateMoney(player, payout)
	end
	heldBrainrot:Destroy()
	print(`[SellVendorInit] {player.Name} sold one brainrot ({rarity}/{modelName}) for {payout}`)
end

local function payoutAndSellAll(player: Player)
	local toolsData = DataManager.GetBrainrotToolsData(player)
	if not toolsData then
		print(`[SellVendorInit] {player.Name} has no persisted brainrot inventory`)
		return
	end

	local totalPayout = 0
	local totalSold = 0
	local ownedEntriesToSell = {}

	for rarity, rarityTools in toolsData do
		if typeof(rarity) ~= "string" or typeof(rarityTools) ~= "table" then
			continue
		end

		for modelName, count in rarityTools do
			if typeof(modelName) == "string" and typeof(count) == "number" and count > 0 then
				table.insert(ownedEntriesToSell, {
					rarity = rarity,
					modelName = modelName,
					count = count,
				})
			end
		end
	end

	for _, entry in ownedEntriesToSell do
		local removedCount = DataManager.RemoveBrainrotTool(player, entry.rarity, entry.modelName, entry.count)
		if removedCount < 0 then
			warn(
				`[SellVendorInit] Failed removing {entry.count} owned tools for {player.Name}: {entry.rarity}/{entry.modelName}`
			)
			continue
		end

		totalSold += entry.count
		local payoutEach = getPayoutForTool(entry.rarity, entry.modelName)
		totalPayout += (payoutEach * entry.count)
	end

	destroyBrainrotToolsInContainer(player.Character)
	destroyBrainrotToolsInContainer(player:FindFirstChild("Backpack"))
	destroyBrainrotToolsInContainer(player:FindFirstChild("StarterGear"))

	if totalPayout > 0 then
		DataManager.UpdateMoney(player, totalPayout)
	end
	print(`[SellVendorInit] {player.Name} sold all brainrots ({totalSold}) for {totalPayout}`)
end

local function resetConfirmTexts(player: Player)
	updateConfirmSellBrainrotActionText:FireClient(player, "SellOneButton", DEFAULT_SELL_ONE_TEXT)
	updateConfirmSellBrainrotActionText:FireClient(player, "SellAllButton", DEFAULT_SELL_ALL_TEXT)
end

local sellVendor =
	Workspace:WaitForChild("World"):WaitForChild("Vendors"):WaitForChild("SellVendorBooth"):WaitForChild("SellVendor")
local sellVendorHumanoid = sellVendor:WaitForChild("Humanoid")
local sellVendorPrompt = sellVendor:WaitForChild("ProximityPrompt")

sellVendorHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

assert(sellVendorPrompt:IsA("ProximityPrompt"), "[SellVendorInit] Expected SellVendor ProximityPrompt.")

sellVendorPrompt.Triggered:Connect(function(player: Player)
	print(`[SellVendorInit] {player.Name} triggered sell vendor prompt`)
	pendingSellConfirmAction[player] = nil
	resetConfirmTexts(player)
	toggleSellVendorMenuRemote:FireClient(player, true)
end)

sellBrainrotActionRemote.OnServerEvent:Connect(function(player: Player, action: string)
	if action == "sell_one" then
		if pendingSellConfirmAction[player] ~= "sell_one" then
			pendingSellConfirmAction[player] = "sell_one"
			updateConfirmSellBrainrotActionText:FireClient(player, "SellOneButton", CONFIRM_SELL_ONE_TEXT)
			updateConfirmSellBrainrotActionText:FireClient(player, "SellAllButton", DEFAULT_SELL_ALL_TEXT)
			return
		end

		pendingSellConfirmAction[player] = nil
		resetConfirmTexts(player)
		payoutAndSellOne(player)
	elseif action == "sell_all" then
		if pendingSellConfirmAction[player] ~= "sell_all" then
			pendingSellConfirmAction[player] = "sell_all"
			updateConfirmSellBrainrotActionText:FireClient(player, "SellAllButton", CONFIRM_SELL_ALL_TEXT)
			updateConfirmSellBrainrotActionText:FireClient(player, "SellOneButton", DEFAULT_SELL_ONE_TEXT)
			return
		end

		pendingSellConfirmAction[player] = nil
		resetConfirmTexts(player)
		payoutAndSellAll(player)
	elseif action == "check_value" then
		pendingSellConfirmAction[player] = nil
		resetConfirmTexts(player)
		if player.Character then
			local heldBrainrot = player.Character:FindFirstChildOfClass("Tool")
			if heldBrainrot then
				print(`[SellVendorInit] {player.Name} checked value on one brainrot`)
			else
				print(`[SellVendorInit] {player.Name} has no brainrot to check value on`)
			end
		end
	elseif action == "close" then
		pendingSellConfirmAction[player] = nil
		resetConfirmTexts(player)
		print("closing sell menu")
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	pendingSellConfirmAction[player] = nil
end)

buildRateLookup()
