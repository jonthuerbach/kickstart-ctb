local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Classes.Game)
local currentGame = Game.Start()

local function countdown(seconds, phaseName)
	-- stateValue.Value = phaseName
	if phaseName == "COOLDOWN" then
		currentGame:ResetAll()
		print("Cooldown round started")
	elseif phaseName == "CLICK" then
		-- wallDescription.Text = "Start clicking!"
		print("Click round started")
	elseif phaseName == "COUNTDOWN" then
		-- wallDescription.Text = "Get ready..."
		print("Countdown round started")
	elseif phaseName == "RACE" then
		-- wallDescription.Text = "Go!"
		print("Race round started")
	end
	for t = seconds, 0, -1 do
		-- timerValue.Value = t
		-- wallCountdown.Text = tostring(t)
		task.wait(1)
	end
end

while true do
	countdown(20, "COOLDOWN")
	countdown(10, "CLICK")
	countdown(3, "COUNTDOWN")
	countdown(10, "RACE")
end
