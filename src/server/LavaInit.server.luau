local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local lavaPart = workspace:WaitForChild("World"):WaitForChild("Lava"):WaitForChild("LavaPart") :: BasePart

local RISE_MIN_STUDS = 8
local RISE_MAX_STUDS = 32
local RISE_DURATION = 5
local HOLD_DURATION = 10
local LOWER_DURATION = 2
local INTERVAL_BETWEEN_CYCLES = 30

local restCFrame = lavaPart.CFrame
local currentTween: Tween? = nil
local touchDebounceByCharacter: { [Model]: number } = {}

local function stopCurrentTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

local function tweenToCFrame(target: CFrame, duration: number)
	stopCurrentTween()

	local tween = TweenService:Create(
		lavaPart,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = target }
	)

	currentTween = tween
	tween:Play()
	tween.Completed:Wait()
end

local function tryKillPlayerFromHit(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Prevent repeated work while a character continuously touches lava.
	local now = os.clock()
	local lastHit = touchDebounceByCharacter[character]
	if lastHit and (now - lastHit) < 0.2 then
		return
	end
	touchDebounceByCharacter[character] = now

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

lavaPart.Touched:Connect(tryKillPlayerFromHit)

task.spawn(function()
	while true do
		local riseDistance = math.random(RISE_MIN_STUDS, RISE_MAX_STUDS)
		local raisedCFrame = restCFrame + Vector3.new(0, riseDistance, 0)

		tweenToCFrame(raisedCFrame, RISE_DURATION)
		task.wait(HOLD_DURATION)
		tweenToCFrame(restCFrame, LOWER_DURATION)
		task.wait(INTERVAL_BETWEEN_CYCLES)
	end
end)
