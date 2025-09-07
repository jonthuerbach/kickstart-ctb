local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Square = require(ReplicatedStorage.Shared.Classes.Square)

local Game = {}
Game.__index = Game

local rng = Random.new()
local current: Game?

type Square = Square.Square
export type Game = typeof(setmetatable({} :: { Squares: { [number]: Square } }, Game))

function generateSquareGrid(): { [number]: Square }
	local squares = {}
	local index = 1
	for i = 1, GameConfig.GridSize do
		for j = 1, GameConfig.GridSize do
			squares[index] = Square.New(CFrame.new((i - 1) * 8, 0, (j - 1) * 8))
			index += 1
		end
	end
	return squares
end

function generateStartingFloor(): ()
	local part = Instance.new("Part")
	part.Name = "StartingFloor"
	part.CFrame = CFrame.new(0, 20.5, 0)
	part.Size =
		Vector3.new(GameConfig.GridSize * GameConfig.SquareSize.X, 1, GameConfig.GridSize * GameConfig.SquareSize.Z)
	part.Position = Vector3.new(124, 24, 124)
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
		Squares = generateSquareGrid(),
		StartingFloor = generateStartingFloor(),
	}, Game)

	return self
end

function Game.Start()
	local self = Game.New()
	self:ResetAll()
	current = self
	return self
end

function Game.ResetAll(self: Game): ()
	for _, square in self.Squares do
		square:Destroy()
	end
	self.Squares = generateSquareGrid()
end

function Game.PlaceInZone(self: Game, character: Model): ()
	local pos = randomPointInZone(self.StartingFloor)
	character:PivotTo(CFrame.new(pos))
end

function Game.GetCurrent(): Game?
	return current
end

return Game
