local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local function waitForMovementData(player: Player, timeoutSeconds: number): (number, number)
	local deadline = os.clock() + timeoutSeconds
	while player.Parent == Players and os.clock() < deadline do
		if DataManager.Profiles[player] then
			return DataManager.GetSpeedLevel(player), DataManager.GetJumpLevel(player)
		end
		task.wait(0.1)
	end

	return 0, 0
end

local function applyPlayerDefaults(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local speedLevel, rebirthCount = waitForMovementData(player, 15)

	humanoid.UseJumpPower = true
	humanoid.JumpPower = MovementConfig.GetJumpPowerForRebirthCount(rebirthCount)
	humanoid.WalkSpeed = MovementConfig.GetWalkSpeedForLevel(speedLevel)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		applyPlayerDefaults(player, character)
	end)

	if player.Character then
		task.spawn(applyPlayerDefaults, player, player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		task.spawn(applyPlayerDefaults, player, player.Character)
	end
end
