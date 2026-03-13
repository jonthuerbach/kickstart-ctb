local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local MYTHIC_SPAWN_SOUND_ID = "rbxassetid://122324955203867"
local MYTHIC_SPAWN_BANNER_DURATION_SECONDS = 4

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mythicSpawnedRemote = remotes:WaitForChild("MythicSpawned") :: RemoteEvent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MythicSpawnBannerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local bannerLabel = Instance.new("TextLabel")
bannerLabel.Name = "MythicSpawnLabel"
bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
bannerLabel.Position = UDim2.new(0.5, 0, 0, 100)
bannerLabel.Size = UDim2.fromScale(0.5, 0.08)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Text = "A mythic brainrot has spawned!"
bannerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bannerLabel.TextScaled = true
bannerLabel.Font = Enum.Font.FredokaOne
bannerLabel.Visible = false
bannerLabel.Parent = screenGui

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(0, 0, 0)
bannerStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
bannerStroke.Thickness = 0.1
bannerStroke.LineJoinMode = Enum.LineJoinMode.Round
bannerStroke.Parent = bannerLabel

local mythicSpawnSound = Instance.new("Sound")
mythicSpawnSound.Name = "MythicSpawnSfx"
mythicSpawnSound.SoundId = MYTHIC_SPAWN_SOUND_ID
mythicSpawnSound.Looped = false
mythicSpawnSound.Parent = SoundService

local latestBannerToken = 0

mythicSpawnedRemote.OnClientEvent:Connect(function()
	if mythicSpawnSound.IsPlaying then
		mythicSpawnSound:Stop()
	end

	mythicSpawnSound:Play()

	latestBannerToken += 1
	local bannerToken = latestBannerToken
	bannerLabel.Visible = true

	task.delay(MYTHIC_SPAWN_BANNER_DURATION_SECONDS, function()
		if latestBannerToken ~= bannerToken then
			return
		end

		bannerLabel.Visible = false
	end)
end)
