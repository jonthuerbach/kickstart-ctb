-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ProfileStore/Modules
local ProfileStore = require(ReplicatedStorage.Shared.Libraries.ProfileStore)
local Template = require(ReplicatedStorage.Shared.Data.DataTemplate)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local GamePassManager = require(ReplicatedStorage.Shared.Data.GamePassManager)
local Game = require(ReplicatedStorage.Shared.Classes.Game)

local function GetStoreName()
	return RunService:IsStudio() and "Test" or "Live"
end

--Access Profile
local PlayerStore = ProfileStore.New(GetStoreName(), Template)

local function Initialize(player: Player, profile: typeof(PlayerStore:StartSessionAsync()))
	--leaderstats
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	local Squares = Instance.new("NumberValue", leaderstats)
	Squares.Name = "Squares"
	Squares.Value = profile.Data.Squares

	local Wins = Instance.new("NumberValue", leaderstats)
	Wins.Name = "Wins"
	Wins.Value = profile.Data.Wins

	-- Update the UI
	--ReplicatedStorage.Remotes.UpdateGold:FireClient(player, profile.Data.Gold)

	GamePassManager.UpdateOwnershipData(player)
end

local function PlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(tostring("Player_" .. player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			DataManager.Profiles[player] = nil
			player:Kick("Data error has occurred. Please rejoin.")
		end)

		if player.Parent == Players then
			DataManager.Profiles[player] = profile
			Initialize(player, profile)
		else
			profile:EndSession()
		end
	else
		player:Kick("Data error has occurred. Please rejoin.")
	end
	player.CharacterAdded:Connect(function(character)
		local g = Game.GetCurrent()
		if g then
			g:PlaceInZone(character)
		end
	end)
end

-- Early Joiners
for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end

-- Adding / Removing
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end
	profile:EndSession()
	DataManager.Profiles[player] = nil
end)
