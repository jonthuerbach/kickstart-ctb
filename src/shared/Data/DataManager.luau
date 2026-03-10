local DataManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

DataManager.Profiles = {}

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

return DataManager
