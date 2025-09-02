-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ProfileStore/Modules
local ProfileStore = require(ReplicatedStorage.Shared.Data.ProfileStore)
local Template = require(ReplicatedStorage.Shared.Data.DataTemplate)
local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)

local function GetStoreName()
	return RunService:IsStudio() and "Test" or "Live"
end

--Access Profile
local PlayerStore = ProfileStore.New(GetStoreName(), Template)

local function Initialize(player: Player, profile: typeof(PlayerStore:StartSessionAsync()))
	--leaderstats
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	local Gold = Instance.new("NumberValue", leaderstats)
	Gold.Name = "Gold"
	Gold.Value = profile.Data.Gold

	local Gems = Instance.new("NumberValue", leaderstats)
	Gems.Name = "Gems"
	Gems.Value = profile.Data.Gems

	-- Update the UI
	--ReplicatedStorage.Remotes.UpdateGold:FireClient(player, profile.Data.Gold)
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
