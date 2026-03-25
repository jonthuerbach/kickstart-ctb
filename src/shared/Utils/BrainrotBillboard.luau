local DEFAULT_RARITY_COLOR = Color3.fromRGB(255, 255, 255)
local NumberFormatter = require(script.Parent.NumberFormatter)

local rarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(112, 219, 112),
	Rare = Color3.fromRGB(88, 166, 255),
	Epic = Color3.fromRGB(184, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 80),
	Mythic = Color3.fromRGB(255, 100, 100),
}

local styleProfiles = {
	Spinner = {
		size = UDim2.new(16, 0, 10, 0),
		studsOffset = Vector3.new(0, 9, 0),
		maxDistance = 96,
		alwaysOnTop = true,
	},
	Pedestal = {
		size = UDim2.new(10, 0, 6, 0),
		studsOffset = Vector3.new(0, 9, 0),
		maxDistance = 64,
		alwaysOnTop = false,
	},
}

export type BillboardVariant = "Spinner" | "Pedestal"

export type CreateOptions = {
	variant: BillboardVariant?,
	showDespawnCountdown: boolean?,
	lifetimeSeconds: number?,
	size: UDim2?,
	studsOffset: Vector3?,
	maxDistance: number?,
	alwaysOnTop: boolean?,
}

local function findAnchorPart(model: Model): BasePart?
	local root = model:FindFirstChild("RootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function buildLabel(container: Instance, name: string, text: string, color: Color3, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, size, 0)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Bevel
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	stroke.Thickness = 3
	stroke.Parent = label

	return label
end

local function getRarityColor(rarity: string): Color3
	return rarityColors[rarity] or DEFAULT_RARITY_COLOR
end

local function destroyExistingBillboard(model: Model)
	local existing = model:FindFirstChild("BrainrotBillboard")
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end
end

local BrainrotBillboard = {}

function BrainrotBillboard.CreateFromAttributes(model: Model, options: CreateOptions?): BillboardGui?
	local anchorPart = findAnchorPart(model)
	if not anchorPart then
		warn(`[BrainrotBillboard] Cannot create billboard, no anchor part found for {model.Name}`)
		return nil
	end

	local variant = if options and options.variant then options.variant else "Spinner"
	local profile = styleProfiles[variant]

	local displayNameAttr = model:GetAttribute("Name")
	local rarityAttr = model:GetAttribute("Rarity")
	local ratePerSecondAttr = model:GetAttribute("RatePerSecond")
	local mutationAttr = model:GetAttribute("Mutation")

	local displayText = if typeof(displayNameAttr) == "string" then displayNameAttr else "Unknown"
	local rarityText = if typeof(rarityAttr) == "string" then rarityAttr else "Unknown"
	local rateText = if typeof(ratePerSecondAttr) == "number"
		then NumberFormatter.FormatCompact(ratePerSecondAttr)
		else "?"
	local rarityColor = getRarityColor(rarityText)

	local size = if options and options.size then options.size else profile.size
	local studsOffset = if options and options.studsOffset then options.studsOffset else profile.studsOffset
	local maxDistance = if options and options.maxDistance then options.maxDistance else profile.maxDistance
	local alwaysOnTop = if options and options.alwaysOnTop ~= nil then options.alwaysOnTop else profile.alwaysOnTop

	destroyExistingBillboard(model)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotBillboard"
	billboard.Adornee = anchorPart
	billboard.Size = size
	billboard.StudsOffset = studsOffset
	billboard.MaxDistance = maxDistance
	billboard.AlwaysOnTop = alwaysOnTop
	billboard.Parent = model

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = billboard

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 2)
	layout.Parent = container

	local countdownLabel: TextLabel? = nil
	local shouldShowCountdown = options ~= nil and options.showDespawnCountdown == true
	local lifetimeSeconds = if options then options.lifetimeSeconds else nil
	if shouldShowCountdown and typeof(lifetimeSeconds) == "number" and lifetimeSeconds > 0 then
		countdownLabel =
			buildLabel(container, "DespawnCountdown", `${lifetimeSeconds}s`, Color3.fromRGB(255, 255, 0), 0.16)
	end

	if variant == "Pedestal" then
		local levelAttr = model:GetAttribute("Level")
		local levelText = if typeof(levelAttr) == "number" then `Level: {levelAttr}` else "?"
		buildLabel(container, "Level", levelText, Color3.fromRGB(255, 255, 0), 0.16)
	end

	buildLabel(container, "DisplayName", displayText, Color3.fromRGB(255, 255, 255), 0.25)
	buildLabel(container, "Rarity", rarityText, rarityColor, 0.16)
	buildLabel(container, "Rate", `${rateText}/s`, Color3.fromRGB(0, 255, 0), 0.25)

	if typeof(mutationAttr) == "string" and mutationAttr ~= "" then
		buildLabel(container, "Mutation", `Mutation: {mutationAttr}`, Color3.fromRGB(255, 240, 130), 0.25)
	end

	if countdownLabel and typeof(lifetimeSeconds) == "number" then
		task.spawn(function()
			for remaining = lifetimeSeconds - 1, 0, -1 do
				if not model.Parent or not countdownLabel.Parent then
					return
				end

				task.wait(1)

				if not model.Parent or not countdownLabel.Parent then
					return
				end

				countdownLabel.Text = `{remaining}s`
			end
		end)
	end

	return billboard
end

return BrainrotBillboard
