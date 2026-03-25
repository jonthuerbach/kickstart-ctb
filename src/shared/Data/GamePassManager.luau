local GamePassManager = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local GamePassCatalog = require(ReplicatedStorage.Shared.Catalogs.GamePassCatalog)

local function syncOwnershipAttributes(player: Player, profile: { Data: { GamePasses: { [string]: { owned: boolean, awarded: boolean } } } })
	for passId, attributeName in GamePassCatalog.Attributes do
		local passData = profile.Data.GamePasses[passId]
		local owned = passData and passData.owned == true
		player:SetAttribute(attributeName, owned)
	end
end

function GamePassManager.PromptPurchase(player: Player, name: string)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local passId: string? = GamePassCatalog.GetGamePassId(name)
	if not passId then
		return
	end

	local hasPass = profile.Data.GamePasses[passId].owned
	if hasPass == false then
		local success, message = pcall(function()
			hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
		end)

		if not success then
			warn("Error while checking if player owns pass: " .. message)
			return
		end

		if hasPass == false then
			MarketplaceService:PromptGamePassPurchase(player, tonumber(passId))
		elseif hasPass == true then
			GamePassManager.UpdateOwnershipData(player)
		end
	end
end

function GamePassManager.OnPromptPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if wasPurchased == false then
		return
	end

	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local passIdStr = tostring(gamePassId)
	local passData = profile.Data.GamePasses[passIdStr]
	if not passData then
		warn("[GamePassManager] No profile data for game pass id: " .. passIdStr)
		return
	end

	passData.owned = true

	local awardFunction = GamePassCatalog.Functions[passIdStr]
	if awardFunction then
		awardFunction(player)
		passData.awarded = true
	else
		warn("[GamePassManager] No award function for game pass id: " .. passIdStr)
	end

	syncOwnershipAttributes(player, profile)
end

function GamePassManager.UpdateOwnershipData(player: Player)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	for passId: string, awardFunction in GamePassCatalog.Functions do
		local passData = profile.Data.GamePasses[passId]
		if not passData then
			continue
		end

		if passData.owned == false then
			local hasPass = false
			local success, message = pcall(function()
				hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
			end)

			if not success then
				warn("Error while checking if player owns pass: " .. message)
				continue
			end

			if hasPass then
				passData.owned = true
				awardFunction(player)
				passData.awarded = true
			end
		end
	end

	syncOwnershipAttributes(player, profile)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(...)
	GamePassManager.OnPromptPurchaseFinished(...)
end)

ReplicatedStorage:WaitForChild("Remotes")
	:WaitForChild("RequestGamePass").OnServerEvent
	:Connect(function(player: Player, name: string)
		GamePassManager.PromptPurchase(player, name)
	end)

return GamePassManager
