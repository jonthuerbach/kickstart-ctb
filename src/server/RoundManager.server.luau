local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateTimer = Remotes:WaitForChild("UpdateTimer")

local Game = require(ReplicatedStorage.Shared.Classes.Game)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local currentGame = Game.Start()

local function countdown(seconds: number, phaseId: string, phaseLabel: string)
	-- stateValue.Value = phaseId
	if phaseId == "INTERMISSION" then
		currentGame:ResetAll()
		print("Intermission round started")
	elseif phaseId == "TEAM_SELECTION" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				print(p.Name)
			end
		end
		print("Click round started")
	elseif phaseId == "COUNTDOWN" then
		-- wallDescription.Text = "Get ready..."
		print("Countdown round started")
	elseif phaseId == "START" then
		-- wallDescription.Text = "Go!"a
		print("Race round started")
	end
	for t = seconds, 0, -1 do
		UpdateTimer:FireAllClients(t, phaseLabel)
		task.wait(1)
	end
end

while true do
	countdown(
		GameConfig.PhaseConfig.INTERMISSION.duration,
		GameConfig.PhaseConfig.INTERMISSION.id,
		GameConfig.PhaseConfig.INTERMISSION.label
	)
	countdown(
		GameConfig.PhaseConfig.TEAM_SELECTION.duration,
		GameConfig.PhaseConfig.TEAM_SELECTION.id,
		GameConfig.PhaseConfig.TEAM_SELECTION.label
	)
	countdown(
		GameConfig.PhaseConfig.COUNTDOWN.duration,
		GameConfig.PhaseConfig.COUNTDOWN.id,
		GameConfig.PhaseConfig.COUNTDOWN.label
	)
	countdown(
		GameConfig.PhaseConfig.ROUND_START.duration,
		GameConfig.PhaseConfig.ROUND_START.id,
		GameConfig.PhaseConfig.ROUND_START.label
	)
end
