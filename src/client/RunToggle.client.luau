local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local runToggleFrame = playerButtons:WaitForChild("RunToggleFrame")
local runButton = runToggleFrame:WaitForChild("RunButton")
local gradient = runButton:WaitForChild("StudsTexture"):WaitForChild("UIGradient")

assert(runButton:IsA("GuiButton"), "[RunToggle] RunButton must be a GuiButton")
assert(gradient:IsA("UIGradient"), "[RunToggle] RunButton.StudsTexture.UIGradient must be a UIGradient")

local WALK_GRADIENT_LIGHT = Color3.fromRGB(180, 180, 180)
local WALK_GRADIENT_DARK = Color3.fromRGB(120, 120, 120)

local originalGradientColor = gradient.Color
local isWalking = false
local walkSpeedConnection: RBXScriptConnection? = nil

local function getRunSpeed(): number
	local speedLevel = player:GetAttribute("SpeedDisplay")
	if typeof(speedLevel) ~= "number" then
		return MovementConfig.BASE_WALK_SPEED
	end
	return MovementConfig.GetWalkSpeedForLevel(speedLevel)
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function applyWalkMode()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = MovementConfig.BASE_WALK_SPEED
	end
	gradient.Color = ColorSequence.new(WALK_GRADIENT_LIGHT, WALK_GRADIENT_DARK)
end

local function applyRunMode()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = getRunSpeed()
	end
	gradient.Color = originalGradientColor
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	if walkSpeedConnection then
		walkSpeedConnection:Disconnect()
	end

	if isWalking then
		humanoid.WalkSpeed = MovementConfig.BASE_WALK_SPEED
	end

	walkSpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if isWalking and humanoid.WalkSpeed ~= MovementConfig.BASE_WALK_SPEED then
			humanoid.WalkSpeed = MovementConfig.BASE_WALK_SPEED
		end
	end)
end

runButton.Activated:Connect(function()
	isWalking = not isWalking
	if isWalking then
		applyWalkMode()
	else
		applyRunMode()
	end
end)

player.CharacterAdded:Connect(function(character)
	task.spawn(bindCharacter, character)
end)

if player.Character then
	task.spawn(bindCharacter, player.Character)
end
