local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)
local RewardsCatalog = require(ReplicatedStorage.Shared.Catalogs.RewardsCatalog)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRewardsStateRemote = remotes:WaitForChild("RequestRewardsState") :: RemoteEvent
local rewardsStateRemote = remotes:WaitForChild("RewardsState") :: RemoteEvent
local requestCollectRewardRemote = remotes:WaitForChild("RequestCollectReward") :: RemoteEvent

local rewardsMenu = mainGui:WaitForChild("RewardsMenu")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local rewardsFrame = playerButtons:WaitForChild("RewardsFrame")
local rewardsMenuButton = rewardsFrame:WaitForChild("RewardsMenuButton")
local indicator = rewardsFrame:WaitForChild("Indicator") :: TextLabel
local rewardsMenuCloseButton = rewardsMenu:WaitForChild("Header"):WaitForChild("CloseButton")
local body = rewardsMenu:WaitForChild("Body")

assert(rewardsMenu:IsA("GuiObject"), "[RewardsMenu] MainGui.RewardsMenu must be a GuiObject")
assert(rewardsMenuButton:IsA("GuiButton"), "[RewardsMenu] RewardsFrame.RewardsMenuButton must be a GuiButton")
assert(rewardsMenuCloseButton:IsA("GuiButton"), "[RewardsMenu] RewardsMenu.Header.CloseButton must be a GuiButton")

local MENU_NAME = "RewardsMenu"
local REWARD_COUNT = RewardsCatalog.REWARD_COUNT
local TIMER_UPDATE_INTERVAL = 0.5
local WIGGLE_INTERVAL = 5
local WIGGLE_AMPLITUDES = { 10, -7, 4, -2 }
local WIGGLE_STEP_DURATION = 0.08
local WIGGLE_RETURN_DURATION = 0.1

local COLOR_COLLECT = Color3.fromRGB(50, 255, 50)
local COLOR_COLLECTED = Color3.fromRGB(150, 150, 150)
local COLOR_TIMER = Color3.fromRGB(255, 255, 255)

type RewardFrameEntry = {
	frame: Frame,
	button: GuiButton,
	label: TextLabel,
	collectedIcon: GuiObject,
}

local rewardFrames: { RewardFrameEntry } = {}
for i = 1, REWARD_COUNT do
	local frameName = string.format("RewardFrame%02d", i)
	local frame = body:WaitForChild(frameName)
	local button = frame:WaitForChild("RewardButton")
	local label = button:WaitForChild("TextLabel") :: TextLabel
	local collectedIcon = button:WaitForChild("CollectedIcon")

	assert(button:IsA("GuiButton"), `[RewardsMenu] {frameName}.RewardButton must be a GuiButton`)
	assert(label:IsA("TextLabel"), `[RewardsMenu] {frameName}.RewardButton.TextLabel must be a TextLabel`)

	rewardFrames[i] = {
		frame = frame,
		button = button :: GuiButton,
		label = label,
		collectedIcon = collectedIcon,
	}
end

local serverElapsed: number = 0
local receivedAt: number = os.clock()
local collectedSlots: { boolean } = {}
for i = 1, REWARD_COUNT do
	collectedSlots[i] = false
end

local function getCurrentElapsed(): number
	return serverElapsed + (os.clock() - receivedAt)
end

local function formatTime(seconds: number): string
	local totalSeconds = math.max(0, math.ceil(seconds))
	local minutes = math.floor(totalSeconds / 60)
	local secs = totalSeconds % 60
	return string.format("%d:%02d", minutes, secs)
end

local function updateFrameUi(index: number)
	local entry = rewardFrames[index]
	if not entry then
		return
	end

	local reward = RewardsCatalog.Rewards[index]
	if not reward then
		return
	end

	local requiredSeconds = reward.timeMinutes * 60
	local elapsed = getCurrentElapsed()
	local collected = collectedSlots[index] == true

	if collected then
		entry.label.Text = "Collected"
		entry.label.TextColor3 = COLOR_COLLECTED
		entry.collectedIcon.Visible = true
		entry.button.Active = false
		entry.button.AutoButtonColor = false
	elseif elapsed >= requiredSeconds then
		entry.label.Text = "Collect"
		entry.label.TextColor3 = COLOR_COLLECT
		entry.collectedIcon.Visible = false
		entry.button.Active = true
		entry.button.AutoButtonColor = true
	else
		local remaining = requiredSeconds - elapsed
		entry.label.Text = formatTime(remaining)
		entry.label.TextColor3 = COLOR_TIMER
		entry.collectedIcon.Visible = false
		entry.button.Active = false
		entry.button.AutoButtonColor = false
	end
end

local function updateAllFrames()
	for i = 1, REWARD_COUNT do
		updateFrameUi(i)
	end
end

local function hasCollectableReward(): boolean
	local elapsed = getCurrentElapsed()
	for i = 1, REWARD_COUNT do
		if collectedSlots[i] ~= true then
			local reward = RewardsCatalog.Rewards[i]
			if reward and elapsed >= reward.timeMinutes * 60 then
				return true
			end
		end
	end
	return false
end

local function updateIndicator()
	indicator.Visible = hasCollectableReward()
end

local function applyRewardsState(state: { [string]: any })
	local elapsed = state.elapsedSeconds
	local collected = state.collected

	if typeof(elapsed) ~= "number" then
		return
	end
	if typeof(collected) ~= "table" then
		return
	end

	serverElapsed = elapsed
	receivedAt = os.clock()

	for i = 1, REWARD_COUNT do
		collectedSlots[i] = collected[i] == true
	end

	updateAllFrames()
	updateIndicator()
end

local function playWiggle()
	local tweenInfo = TweenInfo.new(WIGGLE_STEP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, angle in WIGGLE_AMPLITUDES do
		local tween = TweenService:Create(indicator, tweenInfo, { Rotation = angle })
		tween:Play()
		tween.Completed:Wait()
	end
	local returnTween = TweenService:Create(
		indicator,
		TweenInfo.new(WIGGLE_RETURN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
	returnTween:Play()
	returnTween.Completed:Wait()
end

MenuManager.Register(MENU_NAME, rewardsMenu, {
	onOpen = function()
		requestRewardsStateRemote:FireServer()
		updateAllFrames()
	end,
})

MenuManager.AttachHoverPressEffect(rewardsMenuButton)

rewardsMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

rewardsMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)

for i = 1, REWARD_COUNT do
	local entry = rewardFrames[i]
	entry.button.Activated:Connect(function()
		if collectedSlots[i] == true then
			return
		end

		local reward = RewardsCatalog.Rewards[i]
		if not reward then
			return
		end

		if getCurrentElapsed() < reward.timeMinutes * 60 then
			return
		end

		requestCollectRewardRemote:FireServer(i)
	end)
end

rewardsStateRemote.OnClientEvent:Connect(function(state: { [string]: any })
	if typeof(state) ~= "table" then
		return
	end
	applyRewardsState(state)
end)

task.spawn(function()
	while true do
		if MenuManager.IsOpen(MENU_NAME) then
			updateAllFrames()
		end
		updateIndicator()
		task.wait(TIMER_UPDATE_INTERVAL)
	end
end)

task.spawn(function()
	while true do
		if indicator.Visible then
			playWiggle()
		end
		task.wait(WIGGLE_INTERVAL)
	end
end)

requestRewardsStateRemote:FireServer()
