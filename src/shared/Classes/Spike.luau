local Players = game:GetService("Players")

local Spike = {}
Spike.__index = Spike

export type Spike = typeof(setmetatable({} :: { cf: CFrame, hits: { [Player]: boolean }, part: BasePart }, Spike))

function Spike.New(cf: CFrame)
	local self = setmetatable({
		cf = cf,
		hits = {},
	}, Spike)

	local part = Instance.new("Part")
	part.Anchored = true
	part.CFrame = cf
	part.Parent = workspace
	part.Touched:Connect(function(hit: BasePart)
		self:partTouched(hit)
	end)
	self.part = part

	return self
end

function Spike.partTouched(self: Spike, hit: BasePart): ()
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or self.hits[player] then
		return
	end

	self.hits[player] = true
	player.Character.Humanoid.Health -= 25
end

function Spike.Destroy(self: Spike): ()
	self.part:Destroy()
end

return Spike
