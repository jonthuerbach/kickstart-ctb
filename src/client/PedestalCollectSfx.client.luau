local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local PEDESTAL_COLLECT_SOUND_ID = "rbxassetid://607665037"

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pedestalCollectSfxRemote = remotes:WaitForChild("PedestalCollectSfx") :: RemoteEvent

local collectSound = Instance.new("Sound")
collectSound.Name = "PedestalCollectSfx"
collectSound.SoundId = PEDESTAL_COLLECT_SOUND_ID
collectSound.Volume = 1
collectSound.PlaybackSpeed = 1
collectSound.Looped = false
collectSound.Parent = SoundService

pedestalCollectSfxRemote.OnClientEvent:Connect(function()
	if collectSound.IsPlaying then
		collectSound:Stop()
	end

	collectSound:Play()
end)
