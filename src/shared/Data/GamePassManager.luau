local GamePassManager = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local GamePassCatalog = require(ReplicatedStorage.Shared.Catalogs.GamePassCatalog)

function GamePassManager.PromptPurchase(player: Player, name: string)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local passId: string = GamePassCatalog.GetGamePassId(name)
	if not passId then
		return
	end

	-- check if player owns pass from profile (gifted gamepasses)
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
			-- prompt user for purchase HERE!
			MarketplaceService:PromptGamePassPurchase(player, tonumber(passId))
		elseif hasPass == true then
			-- re-sync all gamepass data because something went out of sync
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

	local awardFunction = GamePassCatalog.Functions[gamePassId]
	if awardFunction then
		awardFunction(player)
		profile.Data.GamePasses[gamePassId].awarded = true
	else
		warn("No award function found for game pass id: " .. gamePassId)
	end
end

function GamePassManager.UpdateOwnershipData(player: Player)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	for passId: string, awardFunction in GamePassCatalog.Functions do
		local hasPass = profile.Data.GamePasses[passId].owned
		if hasPass == false then
			local success, message = pcall(function()
				hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
			end)

			if not success then
				warn("Error while checking if player owns pass: " .. message)
				continue
			end

			if hasPass then
				profile.Data.GamePasses[passId].owned = true

				awardFunction(player)
				profile.Data.GamePasses[passId].awarded = true
			end
		end
	end
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
