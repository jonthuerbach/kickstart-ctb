local DataManager = {}

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")

DataManager.Profiles = {}

function DataManager.UpdateSquares(player: Player, amount: number?)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Squares += amount or 1

	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		return
	end

	leaderstats:WaitForChild("Squares").Value = profile.Data.Squares
end

function DataManager.UpdateGold(player: Player, amount: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Gold += amount

	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		return
	end

	leaderstats:WaitForChild("Gold").Value = profile.Data.Gold
	-- ReplicatedStorage.Remotes.UpdateGold:FireClient(player, profile.Data.Gold)
end

function DataManager.AddGems(player: Player, amount: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Gems += amount
	player:WaitForChild("leaderstats"):WaitForChild("Gems"):SetAttribute("Value", profile.Data.Gems)
	--ReplicatedStorage.Remotes.UpdateGems:FireClient(player, profile.Data.Gems)
end

return DataManager
