local MythicSpawnTimer = {}

MythicSpawnTimer.INTERVAL_SECONDS = 5 * 60

function MythicSpawnTimer.GetSecondsUntilNextWindow(serverNowSeconds: number): number
	local normalizedNow = math.floor(serverNowSeconds)
	local remainder = normalizedNow % MythicSpawnTimer.INTERVAL_SECONDS
	if remainder == 0 then
		return MythicSpawnTimer.INTERVAL_SECONDS
	end

	return MythicSpawnTimer.INTERVAL_SECONDS - remainder
end

function MythicSpawnTimer.FormatAsMmSs(totalSeconds: number): string
	local normalizedSeconds = math.max(0, math.floor(totalSeconds))
	local minutes = math.floor(normalizedSeconds / 60)
	local seconds = normalizedSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

function MythicSpawnTimer.GetFormattedCountdown(serverNowSeconds: number): string
	local remaining = MythicSpawnTimer.GetSecondsUntilNextWindow(serverNowSeconds)
	return MythicSpawnTimer.FormatAsMmSs(remaining)
end

return MythicSpawnTimer
