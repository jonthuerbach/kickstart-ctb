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

function DataManager.AddWins(player: Player, amount: number)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Wins += amount or 1

	local leaderstats = player:WaitForChild("leaderstats")
	if not leaderstats then
		return
	end

	leaderstats:WaitForChild("Wins").Value = profile.Data.Wins
end

return DataManager
