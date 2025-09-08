local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer

-- Tuning
local BASE_SPEED = 32
local MULTIPLIER = 1.5 -- sprint = BASE_SPEED * MULTIPLIER
local MAX_STAMINA = 4.0 -- seconds of full sprint
local DRAIN_PER_SEC = 1.0
local REGEN_PER_SEC = 0.25

local bar: Frame?

-- UI
local function ensureGui()
	local pg = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("SprintGui") :: ScreenGui?
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "SprintGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = pg
	end

	local frame = gui:FindFirstChild("SprintFrame") :: Frame?
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "SprintFrame"
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.fromScale(0.5, 0.95)
		frame.Size = UDim2.fromScale(0.3, 0.025)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = gui
	end

	local sprintStroke = frame:FindFirstChild("SprintStroke") :: Frame?
	if not sprintStroke then
		sprintStroke = Instance.new("UIStroke")
		sprintStroke.Name = "SprintStroke"
		sprintStroke.Color = Color3.fromRGB(30, 60, 0)
		sprintStroke.Thickness = 3
		sprintStroke.Parent = frame
	end

	bar = frame:FindFirstChild("Bar") :: Frame?
	if not bar then
		bar = Instance.new("Frame")
		if bar then
			bar.Name = "Bar"
			bar.AnchorPoint = Vector2.new(0, 0.5)
			bar.Position = UDim2.fromScale(0, 0.5)
			bar.Size = UDim2.fromScale(1, 1)
			bar.BackgroundColor3 = Color3.fromRGB(128, 255, 0)
			bar.BorderSizePixel = 0
			bar.Parent = frame
		end
	end

	return gui, frame, bar
end

local function setBar(bar: Frame, pct: number)
	pct = math.clamp(pct, 0, 1)
	bar.Size = UDim2.fromScale(pct, 1)
end

local sprintHeld = false
local stamina = MAX_STAMINA
local humanoid: Humanoid? = nil

local function bindInputs()
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprintHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprintHeld = false
		end
	end)
end

local function attachToCharacter(char: Model)
	local h = char:WaitForChild("Humanoid") :: Humanoid
	humanoid = h
	h.WalkSpeed = BASE_SPEED
end

local function mainLoop()
	local _, _, b = ensureGui()
	bar = b

	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now

		if not humanoid then
			return
		end

		local sprinting = sprintHeld and stamina > 0
		if sprinting then
			stamina -= DRAIN_PER_SEC * dt
			if stamina <= 0 then
				stamina = 0
				sprinting = false
			end
		else
			stamina += REGEN_PER_SEC * dt
			if stamina > MAX_STAMINA then
				stamina = MAX_STAMINA
			end
		end

		if stamina < 1 then
			_, _, bar = ensureGui()
			if bar then
				bar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			end
		else
			if bar then
				bar.BackgroundColor3 = Color3.fromRGB(128, 255, 0)
			end
		end

		local target = sprinting and (BASE_SPEED * MULTIPLIER) or BASE_SPEED
		if humanoid.WalkSpeed ~= target then
			humanoid.WalkSpeed = target
		end

		setBar(bar :: Frame, stamina / MAX_STAMINA)
	end)
end

local function init()
	bindInputs()
	LOCAL_PLAYER.CharacterAdded:Connect(attachToCharacter)
	if LOCAL_PLAYER.Character then
		attachToCharacter(LOCAL_PLAYER.Character)
	end
	mainLoop()
end

init()
