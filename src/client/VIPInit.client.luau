local Players = game:GetService("Players")

local player = Players.LocalPlayer

local VIP_PLAYERS_GROUP = "VIPPlayers"
local VIP_ATTRIBUTE = "GamePassVIP"

local function isVIP(): boolean
	return player:GetAttribute(VIP_ATTRIBUTE) == true
end

local function getCollisionGroup(): string
	return if isVIP() then VIP_PLAYERS_GROUP else "Default"
end

local function applyCollisionGroup(character: Model, groupName: string)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

local function onCharacterAdded(character: Model)
	applyCollisionGroup(character, getCollisionGroup())

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = getCollisionGroup()
		end
	end)
end

local function onVIPStatusChanged()
	local character = player.Character
	if not character then
		return
	end
	applyCollisionGroup(character, getCollisionGroup())
end

player.CharacterAdded:Connect(onCharacterAdded)
player:GetAttributeChangedSignal(VIP_ATTRIBUTE):Connect(onVIPStatusChanged)

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
