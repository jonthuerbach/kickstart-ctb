local MovementConfig = {}

MovementConfig.BASE_WALK_SPEED = 32
MovementConfig.BASE_JUMP_POWER = 50
MovementConfig.REBIRTH_JUMP_POWER_INCREMENT = 20
MovementConfig.REBIRTH_BASE_REQUIRED_SPEED = 20
MovementConfig.REBIRTH_REQUIRED_SPEED_MULTIPLIER = 1.5

MovementConfig.SPEED_UPGRADE_INCREMENT = 0.75
MovementConfig.SPEED_UPGRADE_BASE_PRICE = 200
MovementConfig.SPEED_UPGRADE_PRICE_MULTIPLIER = 1.15

function MovementConfig.GetWalkSpeedForLevel(level: number): number
	local normalizedLevel = math.max(0, math.floor(level))
	return MovementConfig.BASE_WALK_SPEED + (normalizedLevel * MovementConfig.SPEED_UPGRADE_INCREMENT)
end

function MovementConfig.GetSpeedUpgradeCost(speedLevel: number): number
	local normalizedLevel = math.max(0, math.floor(speedLevel))
	local rawCost = MovementConfig.SPEED_UPGRADE_BASE_PRICE
		* (MovementConfig.SPEED_UPGRADE_PRICE_MULTIPLIER ^ normalizedLevel)
	return math.ceil(rawCost)
end

function MovementConfig.GetSpeedUpgradeBundleCost(currentSpeedLevel: number, upgradeCount: number): number
	local normalizedLevel = math.max(0, math.floor(currentSpeedLevel))
	local normalizedCount = math.max(1, math.floor(upgradeCount))
	local total = 0

	for i = 0, normalizedCount - 1 do
		total += MovementConfig.GetSpeedUpgradeCost(normalizedLevel + i)
	end

	return total
end

function MovementConfig.GetJumpPowerForRebirthCount(rebirthCount: number): number
	local normalizedCount = math.max(0, math.floor(rebirthCount))
	return MovementConfig.BASE_JUMP_POWER + (normalizedCount * MovementConfig.REBIRTH_JUMP_POWER_INCREMENT)
end

function MovementConfig.GetRequiredDisplayedSpeedForRebirthCount(rebirthCount: number): number
	local normalizedCount = math.max(0, math.floor(rebirthCount))
	local rawRequired = MovementConfig.REBIRTH_BASE_REQUIRED_SPEED
		* (MovementConfig.REBIRTH_REQUIRED_SPEED_MULTIPLIER ^ normalizedCount)
	return math.ceil(rawRequired)
end

return MovementConfig
