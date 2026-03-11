local MovementConfig = {}

MovementConfig.BASE_WALK_SPEED = 16
MovementConfig.BASE_JUMP_POWER = 50

MovementConfig.SPEED_UPGRADE_INCREMENT = 1
MovementConfig.SPEED_UPGRADE_BASE_PRICE = 50
MovementConfig.SPEED_UPGRADE_PRICE_MULTIPLIER = 1.25

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

return MovementConfig
