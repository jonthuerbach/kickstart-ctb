local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)

local function assignPlayer(player: Player)
	local plot = PlotManager.AssignNextAvailable(player)
	if not plot then
		warn(`[PlotInit] Could not assign a plot to {player.Name}`)
	end
end

PlotManager.Initialize()

for _, player in Players:GetPlayers() do
	task.spawn(assignPlayer, player)
end

Players.PlayerAdded:Connect(assignPlayer)
Players.PlayerRemoving:Connect(function(player)
	PlotManager.UnassignPlayer(player)
end)
