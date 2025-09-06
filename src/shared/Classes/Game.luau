local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Square = require(ReplicatedStorage.Shared.Classes.Square)

local Game = {}
Game.__index = Game

type Square = Square.Square
export type Game = typeof(setmetatable({} :: { squares: { [number]: Square } }, Game))

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

function Game.New()
	local self = setmetatable({
		squares = generateSquareGrid(),
	}, Game)

	return self
end

function Game.Start()
	local self = Game.New()
	self:ResetAll()
	return self
end

function Game.ResetAll(self: Game): ()
	for _, square in self.squares do
		square:Destroy()
	end
	self.squares = generateSquareGrid()
end

return Game
