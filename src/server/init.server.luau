-- print("Hello world, from server!")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spike = require(ReplicatedStorage.Shared.Classes.Spike)

local spikes = {}

for i = 1, 10 do
	local spike = Spike.New(CFrame.new(math.random(-20, 20), 0, math.random(-20, 20)))
	spikes[i] = spike
end
