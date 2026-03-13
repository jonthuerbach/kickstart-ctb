local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SAFE_ZONE_SOUND_ID = "rbxassetid://131911681104322"
local OUTSIDE_ZONE_SOUND_ID = "rbxassetid://1840434705"
local SAFE_ZONE_CHECK_INTERVAL_SECONDS = 0.2

local localPlayer = Players.LocalPlayer
local safeZonePart = Workspace:WaitForChild("World"):WaitForChild("SafeZone")
assert(safeZonePart:IsA("BasePart"), "[ZoneMusic] workspace.World.SafeZone must be a BasePart")

local safeZoneMusic = Instance.new("Sound")
safeZoneMusic.Name = "SafeZoneMusic"
safeZoneMusic.SoundId = SAFE_ZONE_SOUND_ID
safeZoneMusic.Looped = true
safeZoneMusic.Parent = SoundService

local outsideZoneMusic = Instance.new("Sound")
outsideZoneMusic.Name = "OutsideZoneMusic"
outsideZoneMusic.SoundId = OUTSIDE_ZONE_SOUND_ID
outsideZoneMusic.Looped = true
outsideZoneMusic.Parent = SoundService

local isInSafeZone = false
local nextZoneCheckAt = 0
local currentTrack: Sound? = nil

local function isPlayerInSafeZone(): boolean
	local character = localPlayer.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local localPosition = safeZonePart.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = safeZonePart.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function playTrack(track: Sound)
	if currentTrack == track and track.IsPlaying then
		return
	end

	if currentTrack and currentTrack.IsPlaying then
		currentTrack:Stop()
	end

	currentTrack = track
	if not track.IsPlaying then
		track:Play()
	end
end

local function updateMusicForZone()
	local inSafeZoneNow = isPlayerInSafeZone()
	if inSafeZoneNow ~= isInSafeZone then
		isInSafeZone = inSafeZoneNow
	end

	if isInSafeZone then
		playTrack(safeZoneMusic)
	else
		playTrack(outsideZoneMusic)
	end
end

local function onCharacterAdded()
	-- Start correct music as soon as the character spawns.
	updateMusicForZone()
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded()
else
	playTrack(outsideZoneMusic)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextZoneCheckAt then
		return
	end

	nextZoneCheckAt = now + SAFE_ZONE_CHECK_INTERVAL_SECONDS
	updateMusicForZone()
end)
