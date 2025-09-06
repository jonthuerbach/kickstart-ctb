local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local Square = {}
Square.__index = Square

export type Square = typeof(setmetatable({} :: { cf: CFrame, hits: { [Player]: boolean }, part: BasePart }, Square))

function Square.New(cf: CFrame)
	local self = setmetatable({
		cf = cf,
		hits = {},
	}, Square)

	local part = Instance.new("Part")
	part.Anchored = true
	part.CFrame = cf
	part.Size = Vector3.new(8, 1, 8)
	part.BrickColor = BrickColor.new("White")
	part.Parent = workspace
	part.Touched:Connect(function(hit: BasePart)
		self:partTouched(hit)
	end)
	self.part = part

	return self
end

function Square.partTouched(self: Square, hit: BasePart): ()
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or self.hits[player] then
		return
	end

	for p in pairs(self.hits) do
		self.hits[p] = nil
	end
	self.hits[player] = true

	-- self.part.BrickColor = player.Team.TeamColor
	self.part.BrickColor = BrickColor.new("Bright blue")
	self.part.Material = Enum.Material.Neon
	DataManager.UpdateSquares(player, 1)
end

function Square.GetSize(self: Square): Vector3
	return self.part.Size
end

function Square.Reset(self: Square): ()
	self.hits = {}
	self.part.BrickColor = BrickColor.new("White")
end

function Square.Destroy(self: Square): ()
	self.part:Destroy()
end

return Square
