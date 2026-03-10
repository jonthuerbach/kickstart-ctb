local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spinnerTemplate = ReplicatedStorage:FindFirstChild("Templates"):WaitForChild("SpinnerTemplate")
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
	local stacks = spinnerAttachment:GetAttribute("Stacks")
	local minSpeed = spinnerAttachment:GetAttribute("MinSpeed")
	local maxSpeed = spinnerAttachment:GetAttribute("MaxSpeed")
	local spawnType = spinnerAttachment:GetAttribute("Type")
	local scale = spinnerAttachment:GetAttribute("Scale")

	if typeof(stacks) ~= "number" or stacks < 1 then
		warn(`[SpinnerInit] {spinnerAttachment.Name} has invalid Stacks attribute`)
		continue
	end

	if typeof(minSpeed) ~= "number" or typeof(maxSpeed) ~= "number" or minSpeed > maxSpeed then
		warn(`[SpinnerInit] {spinnerAttachment.Name} has invalid MinSpeed/MaxSpeed attributes`)
		continue
	end

	if typeof(spawnType) ~= "string" then
		warn(`[SpinnerInit] {spinnerAttachment.Name} is missing Type attribute`)
		spawnType = ""
	end

	if typeof(scale) ~= "number" or scale <= 0 then
		warn(`[SpinnerInit] {spinnerAttachment.Name} has invalid Scale attribute; defaulting to 1`)
		scale = 1
	end

	for i = 1, stacks do
		local spinnerClone = spinnerTemplate:Clone()
		spinnerClone:ScaleTo(scale)
		local trunk = spinnerClone:WaitForChild("SpinnerTrunk")
		local primaryPart = spinnerClone.PrimaryPart

		local randomSpeed = math.random(minSpeed, maxSpeed) -- degrees/sec
		local directionMultiplier = (i % 2 == 1) and 1 or -1 -- bottom layer (i=1) stays current direction, then alternates
		local signedSpeed = randomSpeed * directionMultiplier

		spinnerClone.Name = `Spinner_{attachmentIndex}_{i}`
		spinnerClone:SetAttribute("Speed", randomSpeed)
		spinnerClone:SetAttribute("SignedSpeed", signedSpeed)
		spinnerClone:SetAttribute("IsSpinnerTop", false)
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
		angularVelocity.AngularVelocity = Vector3.new(math.rad(signedSpeed), 0, 0)
		angularVelocity.MaxTorque = math.huge
		angularVelocity.Parent = primaryPart

		if i == stacks then
			if attachmentIndex == 1 then
				spinnerClone.Name = "SpinnerTop"
			else
				spinnerClone.Name = `SpinnerTop_{attachmentIndex}`
			end

			spinnerClone:SetAttribute("IsSpinnerTop", true)
			spinnerClone:SetAttribute("BrainrotType", spawnType)
			spinnerClone:SetAttribute("SpinnerAttachmentName", spinnerAttachment.Name)
		end
	end
end
