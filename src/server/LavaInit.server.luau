local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lavaFolder = workspace:WaitForChild("World"):WaitForChild("Lava")
local lavaPart = lavaFolder:WaitForChild("LavaPart") :: BasePart
local lavaOutline = lavaFolder:WaitForChild("LavaOutline") :: BasePart
local lavaCountdownRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LavaCountdown") :: RemoteEvent

local RISE_MIN_STUDS = 8
local RISE_MAX_STUDS = 32
local RISE_DURATION = 3
local HOLD_DURATION = 5
local LOWER_DURATION = 0.5
local INTERVAL_BETWEEN_CYCLES = 15

local restCFrame = lavaPart.CFrame
local currentMoveTween: Tween? = nil
local currentOutlineFadeTween: Tween? = nil
local touchDebounceByCharacter: { [Model]: number } = {}

local function resolveOutlineHighlight(): Highlight?
	local direct = lavaOutline:FindFirstChildOfClass("Highlight")
	if direct then
		return direct
	end

	for _, descendant in lavaFolder:GetDescendants() do
		if descendant:IsA("Highlight") and descendant.Adornee == lavaOutline then
			return descendant
		end
	end

	return nil
end

local lavaOutlineHighlight = resolveOutlineHighlight()
if not lavaOutlineHighlight then
	warn("[LavaInit] Could not find a Highlight for LavaOutline")
end

local function stopCurrentMoveTween()
	if currentMoveTween then
		currentMoveTween:Cancel()
		currentMoveTween = nil
	end
end

local function tweenToCFrame(target: CFrame, duration: number, part: BasePart)
	if not part then
		part = lavaPart
	end

	stopCurrentMoveTween()

	local tween = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = target }
	)

	currentMoveTween = tween
	tween:Play()
	tween.Completed:Wait()
end

local function tweenOutlineFade(
	duration: number,
	targetOutlineTransparency: number,
	targetFillTransparency: number,
	onCompleted: (() -> ())?
)
	if not lavaOutlineHighlight then
		return
	end

	if currentOutlineFadeTween then
		currentOutlineFadeTween:Cancel()
		currentOutlineFadeTween = nil
	end

	local tween = TweenService:Create(
		lavaOutlineHighlight,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			OutlineTransparency = targetOutlineTransparency,
			FillTransparency = targetFillTransparency,
		}
	)
	currentOutlineFadeTween = tween
	if onCompleted then
		tween.Completed:Once(function(playbackState: Enum.PlaybackState)
			if playbackState == Enum.PlaybackState.Completed then
				onCompleted()
			end
		end)
	end
	tween:Play()
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

local COUNTDOWN_SECONDS = 5

task.spawn(function()
	while true do
		local riseDistance = math.random(RISE_MIN_STUDS, RISE_MAX_STUDS)
		local raisedCFrame = restCFrame + Vector3.new(0, riseDistance, 0)

		tweenToCFrame(raisedCFrame, 0.2, lavaOutline)
		tweenOutlineFade(0, 0, 0.75)

		-- Countdown before rising
		for t = COUNTDOWN_SECONDS, 1, -1 do
			lavaCountdownRemote:FireAllClients(t)
			task.wait(1)
		end
		lavaCountdownRemote:FireAllClients(0) -- tells clients to hide the label

		task.spawn(function()
			tweenOutlineFade(1, 1, 1, function()
				lavaOutline.CFrame = restCFrame
			end)
			lavaOutline.Material = Enum.Material.SmoothPlastic
		end)

		tweenToCFrame(raisedCFrame, RISE_DURATION, lavaPart)
		task.wait(HOLD_DURATION)
		tweenToCFrame(restCFrame, LOWER_DURATION, lavaPart)
		lavaOutline.Material = Enum.Material.Glass
		task.wait(INTERVAL_BETWEEN_CYCLES)
	end
end)
