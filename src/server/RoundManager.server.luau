local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateTimer = Remotes:WaitForChild("UpdateTimer")

local Game = require(ReplicatedStorage.Shared.Classes.Game)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local currentGame = Game.Start()

local StartingFloor = workspace:WaitForChild("StartingFloor")

local function ensureTeams()
	for _, def in ipairs(GameConfig.Teams) do
		local t = Teams:FindFirstChild(def.name)
		if not t then
			t = Instance.new("Team")
			t.Name = def.name
			t.TeamColor = def.color
			t.AutoAssignable = false
			t.Parent = Teams
		end
	end
end

local function showStartingFloor(isShowing: boolean)
	print("showStartingFloor", isShowing)
	if isShowing then
		StartingFloor.Transparency = 0.5
		StartingFloor.CanCollide = true
		StartingFloor.CanTouch = true
	else
		StartingFloor.Transparency = 1
		StartingFloor.CanCollide = false
		StartingFloor.CanTouch = false
	end
end

local function assignTeams()
	ensureTeams()
	local blueName = GameConfig.Teams[1].name
	local redName = GameConfig.Teams[2].name
	local blueTeam = Teams:FindFirstChild(blueName) :: Team?
	local redTeam = Teams:FindFirstChild(redName) :: Team?
	if not (blueTeam and redTeam) then
		return
	end

	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)

	for i, p in ipairs(players) do
		local team = (i % 2 == 1) and blueTeam or redTeam
		p.Team = team
		local ls = p:FindFirstChild("leaderstats")
		local teamStat = ls and ls:FindFirstChild("Team")
		if teamStat then
			print(team.Name)
			teamStat.Value = team.Name
		end
	end
end

local function clearTeams()
	for _, p in ipairs(Players:GetPlayers()) do
		p.Team = nil
		local ls = p:FindFirstChild("leaderstats")
		local teamStat = ls and ls:FindFirstChild("Team")
		if teamStat then
			teamStat.Value = ""
		end
	end

	for _, def in ipairs(GameConfig.Teams) do
		local t = Teams:FindFirstChild(def.name)
		if t then
			t:Destroy()
		end
	end
end

local function placeAllInZone()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			currentGame:PlaceInZone(character)
		end
	end
end

local function countdown(seconds: number, phaseId: string, phaseLabel: string)
	-- stateValue.Value = phaseId
	if phaseId == "INTERMISSION" then
		showStartingFloor(true)
		placeAllInZone()
		clearTeams()
		currentGame:ResetScores()
		currentGame:ResetAll()
		print("Intermission round started")
	elseif phaseId == "TEAM_SELECTION" then
		assignTeams()
		print("Team selection round started")
	elseif phaseId == "COUNTDOWN" then
		-- wallDescription.Text = "Get ready..."
		print("Countdown started")
	elseif phaseId == "ROUND_START" then
		showStartingFloor(false)
		-- wallDescription.Text = "Go!"a
		print("Start the round!")
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
