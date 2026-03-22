local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local PEDESTAL_COLLECT_SOUND_ID = "rbxassetid://607665037"
local LIFT_STUDS = 1.5
local LIFT_DURATION_SECONDS = 0.12
local DROP_DURATION_SECONDS = 0.12
local LIFT_EASING_STYLE = Enum.EasingStyle.Quad
local LIFT_EASING_DIRECTION = Enum.EasingDirection.Out
local DROP_EASING_STYLE = Enum.EasingStyle.Quad
local DROP_EASING_DIRECTION = Enum.EasingDirection.In

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pedestalCollectSfxRemote = remotes:WaitForChild("PedestalCollectSfx") :: RemoteEvent

local collectSound = Instance.new("Sound")
collectSound.Name = "PedestalCollectSfx"
collectSound.SoundId = PEDESTAL_COLLECT_SOUND_ID
collectSound.Volume = 1
collectSound.PlaybackSpeed = 1
collectSound.Looped = false
collectSound.Parent = SoundService

type ActiveModelAnimation = {
	liftTween: Tween?,
	dropTween: Tween?,
	pivotValue: CFrameValue,
	changedConnection: RBXScriptConnection?,
}

local activeAnimationsByModel: { [Model]: ActiveModelAnimation } = {}

local function cleanupAnimation(model: Model, snapToRestPivot: boolean, restPivot: CFrame)
	local activeAnimation = activeAnimationsByModel[model]
	if not activeAnimation then
		return
	end

	if activeAnimation.liftTween then
		activeAnimation.liftTween:Cancel()
	end
	if activeAnimation.dropTween then
		activeAnimation.dropTween:Cancel()
	end
	if activeAnimation.changedConnection then
		activeAnimation.changedConnection:Disconnect()
	end
	activeAnimation.pivotValue:Destroy()
	activeAnimationsByModel[model] = nil

	if snapToRestPivot and model.Parent then
		model:PivotTo(restPivot)
	end
end

local function playCollectAnimation(displayModel: Model, restPivot: CFrame)
	cleanupAnimation(displayModel, true, restPivot)

	local pivotValue = Instance.new("CFrameValue")
	pivotValue.Value = restPivot

	local changedConnection = pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
		if displayModel.Parent then
			displayModel:PivotTo(pivotValue.Value)
		end
	end)

	local liftedPivot = restPivot * CFrame.new(0, LIFT_STUDS, 0)
	local liftTween = TweenService:Create(
		pivotValue,
		TweenInfo.new(LIFT_DURATION_SECONDS, LIFT_EASING_STYLE, LIFT_EASING_DIRECTION),
		{ Value = liftedPivot }
	)
	local dropTween = TweenService:Create(
		pivotValue,
		TweenInfo.new(DROP_DURATION_SECONDS, DROP_EASING_STYLE, DROP_EASING_DIRECTION),
		{ Value = restPivot }
	)

	activeAnimationsByModel[displayModel] = {
		liftTween = liftTween,
		dropTween = dropTween,
		pivotValue = pivotValue,
		changedConnection = changedConnection,
	}

	liftTween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if activeAnimationsByModel[displayModel] == nil then
			return
		end
		if playbackState ~= Enum.PlaybackState.Completed then
			cleanupAnimation(displayModel, true, restPivot)
			return
		end

		dropTween:Play()
	end)

	dropTween.Completed:Connect(function()
		cleanupAnimation(displayModel, true, restPivot)
	end)

	liftTween:Play()
end

pedestalCollectSfxRemote.OnClientEvent:Connect(function(displayModel: Instance?, restPivot: CFrame?)
	if collectSound.IsPlaying then
		collectSound:Stop()
	end

	collectSound:Play()

	if displayModel and displayModel:IsA("Model") then
		local resolvedRestPivot = if typeof(restPivot) == "CFrame" then restPivot else displayModel:GetPivot()
		playCollectAnimation(displayModel, resolvedRestPivot)
	end
end)
