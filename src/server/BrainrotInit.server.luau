local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spinnersFolder = workspace:WaitForChild("Spinners")
local brainrot = spinnersFolder:FindFirstChild("SpinnerTop"):FindFirstChild("Brainrot")
local brainrotProximityPrompt = brainrot:WaitForChild("ProximityPrompt")

local activeHoldTracks = {}

local function stopHoldBrainrotAnimation(player)
	local track = activeHoldTracks[player]
	if track then
		track:Stop()
		track:Destroy()
		activeHoldTracks[player] = nil
	end
end

local function playHoldBrainrotAnimation(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	stopHoldBrainrotAnimation(player)

	local raiseAnimation = Instance.new("Animation")
	raiseAnimation.AnimationId = "rbxassetid://102754426367947"

	local holdAnimation = Instance.new("Animation")
	holdAnimation.AnimationId = "rbxassetid://101131966990892"

	local raiseTrack = animator:LoadAnimation(raiseAnimation)
	raiseTrack.Priority = Enum.AnimationPriority.Action
	raiseTrack.Looped = false

	local holdTrack = animator:LoadAnimation(holdAnimation)
	holdTrack.Priority = Enum.AnimationPriority.Action
	holdTrack.Looped = true

	raiseTrack:Play()

	raiseTrack.Stopped:Connect(function()
		-- If something else already replaced the active track, do nothing
		if activeHoldTracks[player] ~= nil then
			return
		end

		holdTrack:Play()
		activeHoldTracks[player] = holdTrack
	end)
end

local function attachBrainrotAboveHead(player)
	playHoldBrainrotAnimation(player)

	local character = player.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	-- Remove existing overhead brainrot if there is one
	local existing = character:FindFirstChild("OverheadBrainrot")
	if existing then
		existing:Destroy()
	end

	local displayBrainrot =
		ReplicatedStorage:WaitForChild("Brainrots"):WaitForChild("Common"):WaitForChild("Matteo"):Clone()

	displayBrainrot.Name = "OverheadBrainrot"
	displayBrainrot.Parent = character

	-- Make sure the model has a PrimaryPart set in Studio
	local primaryPart = displayBrainrot.PrimaryPart
	if not primaryPart then
		warn("Matteo model is missing a PrimaryPart")
		displayBrainrot:Destroy()
		return
	end

	-- Optional but strongly recommended for carried/display items
	for _, descendant in ipairs(displayBrainrot:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	-- Position it above the head
	local offset = CFrame.new(0, 1, 1) * CFrame.Angles(0, 0, 0)
	task.wait(0.35)
	displayBrainrot:PivotTo(head.CFrame * offset)
	displayBrainrot:FindFirstChild("ProximityPrompt").Enabled = false

	-- Weld the display model to the player's head
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = primaryPart
	weld.Parent = primaryPart
end

brainrotProximityPrompt.Triggered:Connect(function(player)
	-- local backpack = player:WaitForChild("Backpack")
	-- local starterGear = player:WaitForChild("StarterGear")
	-- local brainrotTool = ReplicatedStorage:WaitForChild("BrainrotTools"):WaitForChild("Matteo"):Clone()

	brainrot:Destroy()

	attachBrainrotAboveHead(player)
end)
