local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spinnerTemplatesFolder = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("Spinners")
local defaultSpinnerTemplateName = "SpinnerTemplate_1"
local spinnerAttachmentsFolder = workspace:WaitForChild("World"):WaitForChild("Spinners")

local fixedRotation = CFrame.Angles(0, 0, math.rad(90))

local spinnerFolder = Instance.new("Folder")
spinnerFolder.Name = "Spinners"
spinnerFolder.Parent = workspace

local function isValidSpinnerTemplate(template: Instance?): boolean
	if not template or not template:IsA("Model") then
		return false
	end

	local asModel = template :: Model
	if not asModel.PrimaryPart then
		return false
	end

	local trunk = asModel:FindFirstChild("SpinnerTrunk")
	if not trunk or not trunk:IsA("BasePart") then
		return false
	end

	if not asModel:FindFirstChildWhichIsA("HingeConstraint", true) then
		return false
	end

	return true
end

local defaultSpinnerTemplate = spinnerTemplatesFolder:FindFirstChild(defaultSpinnerTemplateName)
if not isValidSpinnerTemplate(defaultSpinnerTemplate) then
	warn(
		`[SpinnerInit] Missing or invalid default template "{defaultSpinnerTemplateName}" in ReplicatedStorage.Templates.Spinners`
	)
	return
end

local function resolveSpinnerTemplate(spinnerAttachment: Attachment): Model?
	local templateName = spinnerAttachment:GetAttribute("SpinnerTemplate")
	if typeof(templateName) ~= "string" or templateName == "" then
		warn(
			`[SpinnerInit] {spinnerAttachment.Name} is missing SpinnerTemplate attribute; falling back to {defaultSpinnerTemplateName}`
		)
		return defaultSpinnerTemplate :: Model
	end

	local template = spinnerTemplatesFolder:FindFirstChild(templateName)
	if not isValidSpinnerTemplate(template) then
		warn(
			`[SpinnerInit] {spinnerAttachment.Name} references missing/invalid template "{templateName}"; falling back to {defaultSpinnerTemplateName}`
		)
		return defaultSpinnerTemplate :: Model
	end

	return template :: Model
end

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
	local spinnerTemplate = resolveSpinnerTemplate(spinnerAttachment)
	if not spinnerTemplate then
		warn(`[SpinnerInit] {spinnerAttachment.Name} could not resolve a spinner template`)
		continue
	end

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

	for i = 1, stacks do
		local spinnerClone = spinnerTemplate:Clone()
		local trunk = spinnerClone:WaitForChild("SpinnerTrunk")

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

		local hinge = spinnerClone:FindFirstChildWhichIsA("HingeConstraint", true)
		if not hinge then
			warn(`[SpinnerInit] {spinnerClone.Name} is missing a HingeConstraint`)
			continue
		end

		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.AngularVelocity = math.rad(signedSpeed)
		hinge.MotorMaxTorque = 50000

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
