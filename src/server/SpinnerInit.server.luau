local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spinnerTemplate = ReplicatedStorage:WaitForChild("SpinnerTemplate")
local spinnerAttachment =
	workspace:FindFirstChild("Attachments"):FindFirstChild("Spinners"):WaitForChild("SpinnerAttachment_1")

local STACK_COUNT = 5
local MIN_SPEED = 20
local MAX_SPEED = 50

local currentPosition = spinnerAttachment.WorldPosition
local fixedRotation = CFrame.Angles(0, 0, math.rad(90))

local spinnerFolder = Instance.new("Folder")
spinnerFolder.Name = "Spinners"
spinnerFolder.Parent = workspace

for i = 1, STACK_COUNT do
	local spinnerClone = spinnerTemplate:Clone()
	local trunk = spinnerClone:WaitForChild("SpinnerTrunk")
	local primaryPart = spinnerClone.PrimaryPart

	local randomSpeed = math.random(MIN_SPEED, MAX_SPEED) -- degrees/sec

	local randomColor = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))

	spinnerClone.Name = "Spinner_" .. i
	spinnerClone:SetAttribute("Speed", randomSpeed)
	spinnerClone.SpinnerTrunk.Color = randomColor
	spinnerClone.SpinnerBranch.Color = randomColor
	spinnerClone:PivotTo(CFrame.new(currentPosition) * fixedRotation)

	spinnerClone.Parent = spinnerFolder

	currentPosition = currentPosition + Vector3.new(0, trunk.Size.X, 0)

	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinAttachment"
	attachment.Parent = primaryPart

	local angularVelocity = Instance.new("AngularVelocity")
	angularVelocity.Attachment0 = attachment
	angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	angularVelocity.AngularVelocity = Vector3.new(math.rad(randomSpeed), 0, 0)
	angularVelocity.MaxTorque = math.huge
	angularVelocity.Parent = primaryPart

	if i == STACK_COUNT then
		local brainrot =
			ReplicatedStorage:FindFirstChild("Brainrots"):FindFirstChild("Common"):WaitForChild("Matteo"):Clone()
		local brainrotPosition = spinnerClone.SpinnerTrunk.Position
			+ Vector3.new(0, spinnerClone.SpinnerTrunk.Size.X / 2, 0)
		local brainrotRotation = CFrame.Angles(0, math.rad(180), 0)

		spinnerClone.Name = "SpinnerTop"

		brainrot.Name = "Brainrot"
		brainrot:PivotTo(CFrame.new(brainrotPosition) * brainrotRotation)
		brainrot:SetAttribute("Name", "Matteo")
		brainrot:SetAttribute("Rarity", "Common")
		brainrot.Parent = spinnerClone
	end
end
