local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestIndexStateRemote = remotes:WaitForChild("RequestIndexState") :: RemoteEvent
local indexStateRemote = remotes:WaitForChild("IndexState") :: RemoteEvent

requestIndexStateRemote.OnServerEvent:Connect(function(player: Player)
	local indexData = DataManager.GetBrainrotIndexData(player)
	if not indexData then
		return
	end

	indexStateRemote:FireClient(player, indexData)
end)
