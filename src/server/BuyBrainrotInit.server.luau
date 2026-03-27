local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotToolManager = require(ReplicatedStorage.Shared.Managers.BrainrotToolManager)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local ReceiptProcessor = require(script.Parent.ReceiptProcessor)

local RARITY = "Godly"
local BUY_BRAINROTS_FOLDER = workspace:WaitForChild("World"):WaitForChild("BuyBrainrots")

local function setupBuyableBrainrot(brainrotFolder: Instance)
	local brainrotModel: Model? = nil
	for _, child in brainrotFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("DevProductId") ~= nil then
			brainrotModel = child :: Model
			break
		end
	end

	assert(brainrotModel, `[BuyBrainrotInit] No model with DevProductId found in {brainrotFolder:GetFullName()}`)

	local devProductId = brainrotModel:GetAttribute("DevProductId")
	local brainrotName = brainrotModel:GetAttribute("Name")
	local cost = brainrotModel:GetAttribute("Cost")

	assert(
		typeof(devProductId) == "number",
		`[BuyBrainrotInit] DevProductId must be a number on {brainrotModel:GetFullName()}`
	)
	assert(typeof(brainrotName) == "string", `[BuyBrainrotInit] Name must be a string on {brainrotModel:GetFullName()}`)
	assert(typeof(cost) == "number", `[BuyBrainrotInit] Cost must be a number on {brainrotModel:GetFullName()}`)

	BrainrotToolManager.AssertToolTemplate(RARITY, brainrotName)

	local prompt = brainrotModel:FindFirstChild("BuyProximityPrompt")
	assert(
		prompt and prompt:IsA("ProximityPrompt"),
		`[BuyBrainrotInit] Missing BuyProximityPrompt in {brainrotModel:GetFullName()}`
	)

	prompt.ObjectText = brainrotName
	prompt.ActionText = `Buy for {cost}`

	prompt.Triggered:Connect(function(player: Player)
		MarketplaceService:PromptProductPurchase(player, devProductId)
	end)

	ReceiptProcessor.RegisterHandler(devProductId, function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player or not DataManager.Profiles[player] then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local count = BrainrotToolManager.AddOwnedTool(player, RARITY, brainrotName, true)
		if count <= 0 then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end)
end

for _, brainrotFolder in BUY_BRAINROTS_FOLDER:GetChildren() do
	setupBuyableBrainrot(brainrotFolder)
end
