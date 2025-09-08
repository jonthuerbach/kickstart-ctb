local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Square = require(ReplicatedStorage.Shared.Classes.Square)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateScores = Remotes:WaitForChild("UpdateScores")

local Game = {}
Game.__index = Game

local rng = Random.new()
local current: Game?

type Square = Square.Square
export type Game = typeof(setmetatable({} :: { Squares: { [number]: Square }, ScoringEnabled: boolean }, Game))

function generateSquareGrid(onTouch: (Square, Player) -> ()): { [number]: Square }
	local squares = {}
	local index = 1
	for i = 1, GameConfig.GridSize do
		for j = 1, GameConfig.GridSize do
			squares[index] = Square.New(CFrame.new((i - 1) * 8, 0, (j - 1) * 8), onTouch)
			index += 1
		end
	end
	return squares
end

function generateStartingFloor(): ()
	local positionAmount = ((GameConfig.GridSize * GameConfig.SquareSize.X) / 2) - (GameConfig.SquareSize.X / 2)

	local part = Instance.new("Part")
	part.Name = "StartingFloor"
	part.CFrame = CFrame.new(0, 20.5, 0)
	part.Size =
		Vector3.new(GameConfig.GridSize * GameConfig.SquareSize.X, 1, GameConfig.GridSize * GameConfig.SquareSize.Z)
	part.Position = Vector3.new(positionAmount, 24, positionAmount)
	part.BrickColor = BrickColor.new("White")
	part.Material = Enum.Material.Glass
	part.Transparency = 0.5
	part.Anchored = true
	part.Parent = workspace
	return part
end

local function randomPointInZone(part: BasePart): Vector3
	local half = part.Size * 0.5
	local x = rng:NextNumber(-half.X, half.X)
	local z = rng:NextNumber(-half.Z, half.Z)
	local offset = Vector3.new(x, half.Y + 4, z)
	return (part.CFrame * CFrame.new(offset)).Position
end

function Game.New()
	local self = setmetatable({
		Squares = {},
		StartingFloor = generateStartingFloor(),
		Scores = {
			Blue = 0,
			Red = 0,
		},
		ScoringEnabled = false,
	}, Game)

	self.Squares = generateSquareGrid(function(square, player)
		self:OnSquareTouched(square, player)
		-- UpdateScores:FireAllClients(self.Scores)
	end)

	return self
end

function Game.Start()
	local game = Game.New()
	game:ResetAll()
	current = game
	return game
end

function Game.ResetAll(self: Game): ()
	for _, square in self.Squares do
		square:Destroy()
	end
	self.Squares = generateSquareGrid(function(square, player)
		self:OnSquareTouched(square, player)
		-- UpdateScores:FireAllClients(self.Scores)
	end)
end

function Game.PlaceInZone(self: Game, character: Model): ()
	local pos = randomPointInZone(self.StartingFloor)
	character:PivotTo(CFrame.new(pos))
end

function Game.PlaceAllInZone(self: Game, characters: { Model }): ()
	for _, character in characters do
		self:PlaceInZone(character)
	end
end

function Game.GetCurrent(): Game?
	return current
end

function Game.ResetScores(self: Game): ()
	for k in pairs(self.Scores) do
		self.Scores[k] = 0
	end
	UpdateScores:FireAllClients(self.Scores)
end

function Game.OnSquareTouched(self: Game, square, player: Player): ()
	if not self.ScoringEnabled then
		return
	end

	local team = player.Team
	if not team then
		return
	end
	local newTeam = team.Name
	local prevTeam = square.ownerTeam
	if prevTeam == newTeam then
		return
	end

	if prevTeam == nil then
		if self.Scores[newTeam] ~= nil then
			self.Scores[newTeam] += 1
		end
	else
		if self.Scores[prevTeam] ~= nil then
			self.Scores[prevTeam] -= 1
		end
		if self.Scores[newTeam] ~= nil then
			self.Scores[newTeam] += 1
		end
	end

	square.ownerTeam = newTeam
	square.part.BrickColor = team.TeamColor
	square.part.Material = Enum.Material.Neon

	UpdateScores:FireAllClients(self.Scores)
end

function Game.SetScoringEnabled(self: Game, enabled: boolean): ()
	self.ScoringEnabled = enabled
end

return Game
