local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(ReplicatedStorage.Shared.Managers.PlotManager)

local function moveCharacterToAssignedPlot(player: Player, character: Model)
	local plot = PlotManager.GetPlotForPlayer(player)
	if not plot then
		warn(`[PlotInit] Cannot move {player.Name}; no assigned plot`)
		return
	end

	character:PivotTo(plot:GetSpawnCFrame())
end

local function assignPlayer(player: Player)
	local plot = PlotManager.AssignNextAvailable(player)
	if not plot then
		warn(`[PlotInit] Could not assign a plot to {player.Name}`)
		return
	end

	if player.Character then
		moveCharacterToAssignedPlot(player, player.Character)
	end
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		moveCharacterToAssignedPlot(player, character)
	end)

	assignPlayer(player)
end

PlotManager.Initialize()

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	PlotManager.UnassignPlayer(player)
end)
