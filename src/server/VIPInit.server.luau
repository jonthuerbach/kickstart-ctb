local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local VIP_PLAYERS_GROUP = "VIPPlayers"
local VIP_BARRIER_GROUP = "VIPBarrier"
local VIP_ATTRIBUTE = "GamePassVIP"
local PROFILE_WAIT_TIMEOUT = 15

PhysicsService:RegisterCollisionGroup(VIP_PLAYERS_GROUP)
PhysicsService:RegisterCollisionGroup(VIP_BARRIER_GROUP)
PhysicsService:CollisionGroupSetCollidable(VIP_PLAYERS_GROUP, VIP_BARRIER_GROUP, false)

-- Assign all existing and future barrier parts in the VIP folder
local vipFolder = workspace:WaitForChild("World"):WaitForChild("VIP")

for _, descendant in vipFolder:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = VIP_BARRIER_GROUP
	end
end

vipFolder.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = VIP_BARRIER_GROUP
	end
end)

local function isVIP(player: Player): boolean
	return player:GetAttribute(VIP_ATTRIBUTE) == true
end

local function getCollisionGroup(player: Player): string
	return if isVIP(player) then VIP_PLAYERS_GROUP else "Default"
end

local function applyCollisionGroup(character: Model, groupName: string)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

local function waitForProfile(player: Player): boolean
	local deadline = os.clock() + PROFILE_WAIT_TIMEOUT
	while player.Parent == Players and os.clock() < deadline do
		if DataManager.Profiles[player] then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function onCharacterAdded(player: Player, character: Model)
	if not waitForProfile(player) then
		return
	end

	applyCollisionGroup(character, getCollisionGroup(player))

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = getCollisionGroup(player)
		end
	end)
end

local function onVIPStatusChanged(player: Player)
	local character = player.Character
	if not character then
		return
	end
	applyCollisionGroup(character, getCollisionGroup(player))
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	player:GetAttributeChangedSignal(VIP_ATTRIBUTE):Connect(function()
		onVIPStatusChanged(player)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
