local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spinnerTemplate = ReplicatedStorage:WaitForChild("SpinnerTemplate")
local spinnerAttachmentsFolder = workspace:WaitForChild("World"):WaitForChild("Spinners")

local fixedRotation = CFrame.Angles(0, 0, math.rad(90))

local spinnerFolder = Instance.new("Folder")
spinnerFolder.Name = "Spinners"
spinnerFolder.Parent = workspace

local spinnerAttachments = {}
for _, child in ipairs(spinnerAttachmentsFolder:GetChildren()) do
	if child:IsA("Attachment") and child.Name:match("^SpinnerAttachment_%d+$") then
		table.insert(spinnerAttachments, child)
	end
end

table.sort(spinnerAttachments, function(a, b)
	local aNum = tonumber(a.Name:match("(%d+)$")) or math.huge
	local bNum = tonumber(b.Name:match("(%d+)$")) or math.huge
	return aNum < bNum
end)

if #spinnerAttachments == 0 then
	warn("[SpinnerInit] No SpinnerAttachment_<n> attachments found in workspace.World.Spinners")
	return
end

for attachmentIndex, spinnerAttachment in ipairs(spinnerAttachments) do
	local currentPosition = spinnerAttachment.WorldPosition

	for i = 1, spinnerAttachment:GetAttribute("Stacks") do
		local spinnerClone = spinnerTemplate:Clone()
		local trunk = spinnerClone:WaitForChild("SpinnerTrunk")
		local primaryPart = spinnerClone.PrimaryPart

		local randomSpeed =
			math.random(spinnerAttachment:GetAttribute("MinSpeed"), spinnerAttachment:GetAttribute("MaxSpeed")) -- degrees/sec

		spinnerClone.Name = `Spinner_{attachmentIndex}_{i}`
		spinnerClone:SetAttribute("Speed", randomSpeed)
		spinnerClone.SpinnerTrunk.Color = i % 2 == 0 and Color3.fromRGB(255, 255, 255)
			or BrickColor.new("Bright red").Color
		spinnerClone.SpinnerBranch.Color = i % 2 == 0 and Color3.fromRGB(255, 255, 255)
			or BrickColor.new("Bright red").Color
		spinnerClone:PivotTo(CFrame.new(currentPosition) * fixedRotation)

		spinnerClone.Parent = spinnerFolder

		currentPosition = currentPosition + Vector3.new(0, trunk.Size.X, 0)

		local spinAttachment = Instance.new("Attachment")
		spinAttachment.Name = "SpinAttachment"
		spinAttachment.Parent = primaryPart

		local angularVelocity = Instance.new("AngularVelocity")
		angularVelocity.Attachment0 = spinAttachment
		angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		angularVelocity.AngularVelocity = Vector3.new(math.rad(randomSpeed), 0, 0)
		angularVelocity.MaxTorque = math.huge
		angularVelocity.Parent = primaryPart

		if i == spinnerAttachment:GetAttribute("Stacks") then
			local brainrot =
				ReplicatedStorage:FindFirstChild("Brainrots"):FindFirstChild("Common"):WaitForChild("Matteo"):Clone()
			local brainrotPosition = spinnerClone.SpinnerTrunk.Position
				+ Vector3.new(0, spinnerClone.SpinnerTrunk.Size.X / 2, 0)
			local brainrotRotation = CFrame.Angles(0, math.rad(180), 0)

			if attachmentIndex == 1 then
				spinnerClone.Name = "SpinnerTop"
			else
				spinnerClone.Name = `SpinnerTop_{attachmentIndex}`
			end

			brainrot.Name = "Brainrot"
			brainrot:PivotTo(CFrame.new(brainrotPosition) * brainrotRotation)
			brainrot:SetAttribute("Name", "Matteo")
			brainrot:SetAttribute("Rarity", "Common")
			brainrot.Parent = spinnerClone
		end
	end
end
