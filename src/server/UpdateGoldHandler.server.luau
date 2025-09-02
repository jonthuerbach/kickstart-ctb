local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateGold = remotes:WaitForChild("UpdateGold")

UpdateGold.OnServerEvent:Connect(function(player: Player, amount: number)
	amount = tonumber(amount) or 0
	if amount == 0 then
		return
	end
	amount = math.clamp(amount, -1000, 1000)
	if not DataManager.Profiles[player] then
		return
	end
	DataManager.UpdateGold(player, amount)
end)
