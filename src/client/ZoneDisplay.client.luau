local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ZONE_CHECK_INTERVAL = 0.2

local ZONE_DEFINITIONS = {
	{ Name = "Common", PartName = "CommonZone", Priority = 1 },
	{ Name = "Rare", PartName = "RareZone", Priority = 2 },
	{ Name = "Epic", PartName = "EpicZone", Priority = 3 },
	{ Name = "Legendary", PartName = "LegendaryZone", Priority = 4 },
	{ Name = "Mythic", PartName = "MythicZone", Priority = 5 },
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Rare = Color3.fromRGB(88, 166, 255),
	Epic = Color3.fromRGB(184, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 80),
	Mythic = Color3.fromRGB(255, 100, 100),
}

local TWEEN_SHOW = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_HIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_SWAP = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local zoneInfo = mainGui:WaitForChild("ZoneInfo")
local textLabel = zoneInfo:WaitForChild("TextLabel")

assert(zoneInfo:IsA("GuiObject"), "[ZoneDisplay] MainGui.ZoneInfo must be a GuiObject")
assert(textLabel:IsA("TextLabel"), "[ZoneDisplay] MainGui.ZoneInfo.TextLabel must be a TextLabel")

textLabel.RichText = true

local zonesFolder = Workspace:WaitForChild("World"):WaitForChild("Zones")

type ZoneEntry = {
	Name: string,
	Part: BasePart,
	Priority: number,
}

local zones: { ZoneEntry } = {}
for _, definition in ZONE_DEFINITIONS do
	local part = zonesFolder:WaitForChild(definition.PartName)
	assert(part:IsA("BasePart"), `[ZoneDisplay] workspace.World.Zones.{definition.PartName} must be a BasePart`)
	table.insert(zones, {
		Name = definition.Name,
		Part = part,
		Priority = definition.Priority,
	})
end

local currentZoneName: string? = nil
local nextCheckAt = 0
local activeTweens: { Tween } = {}

local uiScale = zoneInfo:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = zoneInfo
end

local function isPointInsidePart(point: Vector3, part: BasePart): boolean
	local localPos = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function colorToHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

local function formatZoneText(zoneName: string): string
	local color = RARITY_COLORS[zoneName] or Color3.fromRGB(255, 255, 255)
	return `<font color="{colorToHex(color)}">{zoneName}</font> Zone`
end

local function cancelTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function playTweens(tweens: { Tween })
	cancelTweens()
	for _, tween in tweens do
		tween:Play()
		table.insert(activeTweens, tween)
	end
end

local function showZone(zoneName: string)
	textLabel.Text = formatZoneText(zoneName)
	textLabel.TextTransparency = 1
	uiScale.Scale = 0.5
	zoneInfo.Visible = true

	playTweens({
		TweenService:Create(uiScale, TWEEN_SHOW, { Scale = 1 }),
		TweenService:Create(textLabel, TWEEN_SHOW, { TextTransparency = 0 }),
	})
end

local function hideZone()
	local tweens = {
		TweenService:Create(uiScale, TWEEN_HIDE, { Scale = 0.5 }),
		TweenService:Create(textLabel, TWEEN_HIDE, { TextTransparency = 1 }),
	}
	playTweens(tweens)

	tweens[1].Completed:Once(function()
		if currentZoneName == nil then
			zoneInfo.Visible = false
		end
	end)
end

local function swapZone(zoneName: string)
	textLabel.Text = formatZoneText(zoneName)
	uiScale.Scale = 1.15
	playTweens({
		TweenService:Create(uiScale, TWEEN_SWAP, { Scale = 1 }),
	})
end

local function getRootPart(): BasePart?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getHighestPriorityZone(): string?
	local rootPart = getRootPart()
	if not rootPart then
		return nil
	end

	local position = rootPart.Position
	local bestName: string? = nil
	local bestPriority = -1

	for _, zone in zones do
		if zone.Priority > bestPriority and isPointInsidePart(position, zone.Part) then
			bestName = zone.Name
			bestPriority = zone.Priority
		end
	end

	return bestName
end

local function updateZoneDisplay()
	local newZone = getHighestPriorityZone()
	if newZone == currentZoneName then
		return
	end

	local previousZone = currentZoneName
	currentZoneName = newZone

	if newZone and not previousZone then
		showZone(newZone)
	elseif newZone and previousZone then
		swapZone(newZone)
	else
		hideZone()
	end
end

zoneInfo.Visible = false

localPlayer.CharacterAdded:Connect(function()
	currentZoneName = nil
	cancelTweens()
	zoneInfo.Visible = false
	updateZoneDisplay()
end)

if localPlayer.Character then
	updateZoneDisplay()
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheckAt then
		return
	end
	nextCheckAt = now + ZONE_CHECK_INTERVAL
	updateZoneDisplay()
end)
