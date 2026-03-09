local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lavaFolder = workspace:WaitForChild("World"):WaitForChild("Lava")
local lavaCountdownRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LavaCountdown") :: RemoteEvent

local SECTION_NAME_PATTERN = "^Section_"
local RISE_MIN_STUDS_ATTRIBUTE = "RiseMinStuds"
local RISE_MAX_STUDS_ATTRIBUTE = "RiseMaxStuds"

local RISE_DURATION = 3
local HOLD_DURATION = 5
local LOWER_DURATION = 0.5
local INTERVAL_BETWEEN_CYCLES = 15

local touchDebounceByCharacter: { [Model]: number } = {}

type LavaSection = {
	folder: Instance,
	name: string,
	lavaPart: BasePart,
	lavaOutline: BasePart,
	restPartCFrame: CFrame,
	restOutlineCFrame: CFrame,
	riseMinStuds: number,
	riseMaxStuds: number,
	outlineHighlight: Highlight?,
	currentPartMoveTween: Tween?,
	currentOutlineMoveTween: Tween?,
	currentOutlineFadeTween: Tween?,
}

type SectionTargets = {
	raisedPartCFrame: CFrame,
	raisedOutlineCFrame: CFrame,
}

local function resolveOutlineHighlight(sectionFolder: Instance, lavaOutline: BasePart): Highlight?
	local direct = lavaOutline:FindFirstChildOfClass("Highlight")
	if direct then
		return direct
	end

	for _, descendant in sectionFolder:GetDescendants() do
		if descendant:IsA("Highlight") and descendant.Adornee == lavaOutline then
			return descendant
		end
	end

	return nil
end

local function stopTween(tween: Tween?)
	if tween then
		tween:Cancel()
	end
end

local function createMoveTween(part: BasePart, target: CFrame, duration: number): Tween
	return TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
end

local function playPartMoveTween(section: LavaSection, target: CFrame, duration: number)
	stopTween(section.currentPartMoveTween)
	local tween = createMoveTween(section.lavaPart, target, duration)
	section.currentPartMoveTween = tween
	tween:Play()
	tween.Completed:Once(function()
		if section.currentPartMoveTween == tween then
			section.currentPartMoveTween = nil
		end
	end)
end

local function playOutlineMoveTween(section: LavaSection, target: CFrame, duration: number)
	stopTween(section.currentOutlineMoveTween)
	local tween = createMoveTween(section.lavaOutline, target, duration)
	section.currentOutlineMoveTween = tween
	tween:Play()
	tween.Completed:Once(function()
		if section.currentOutlineMoveTween == tween then
			section.currentOutlineMoveTween = nil
		end
	end)
end

local function getRiseRange(sectionFolder: Instance): (number?, number?)
	local riseMinStuds = sectionFolder:GetAttribute(RISE_MIN_STUDS_ATTRIBUTE)
	local riseMaxStuds = sectionFolder:GetAttribute(RISE_MAX_STUDS_ATTRIBUTE)

	if typeof(riseMinStuds) ~= "number" or typeof(riseMaxStuds) ~= "number" then
		warn(
			`[LavaInit] Skipping {sectionFolder.Name}: expected numeric attributes "{RISE_MIN_STUDS_ATTRIBUTE}" and "{RISE_MAX_STUDS_ATTRIBUTE}".`
		)
		return nil, nil
	end

	if riseMinStuds < 0 or riseMaxStuds < 0 or riseMinStuds > riseMaxStuds then
		warn(
			`[LavaInit] Skipping {sectionFolder.Name}: invalid rise range ({riseMinStuds}, {riseMaxStuds}). Expected 0 <= min <= max.`
		)
		return nil, nil
	end

	return riseMinStuds, riseMaxStuds
end

local function buildSections(): { LavaSection }
	local sections = {}

	for _, child in lavaFolder:GetChildren() do
		if child:IsA("Folder") and string.match(child.Name, SECTION_NAME_PATTERN) then
			local lavaPart = child:FindFirstChild("LavaPart")
			local lavaOutline = child:FindFirstChild("LavaOutline")
			if not lavaPart or not lavaPart:IsA("BasePart") then
				warn(`[LavaInit] Skipping {child.Name}: missing BasePart named "LavaPart".`)
				continue
			end
			if not lavaOutline or not lavaOutline:IsA("BasePart") then
				warn(`[LavaInit] Skipping {child.Name}: missing BasePart named "LavaOutline".`)
				continue
			end

			local riseMinStuds, riseMaxStuds = getRiseRange(child)
			if not riseMinStuds or not riseMaxStuds then
				continue
			end

			local outlineHighlight = resolveOutlineHighlight(child, lavaOutline)
			if not outlineHighlight then
				warn(`[LavaInit] {child.Name}: could not find a Highlight for LavaOutline; fade will be skipped.`)
			end

			table.insert(sections, {
				folder = child,
				name = child.Name,
				lavaPart = lavaPart,
				lavaOutline = lavaOutline,
				restPartCFrame = lavaPart.CFrame,
				restOutlineCFrame = lavaOutline.CFrame,
				riseMinStuds = riseMinStuds,
				riseMaxStuds = riseMaxStuds,
				outlineHighlight = outlineHighlight,
				currentPartMoveTween = nil,
				currentOutlineMoveTween = nil,
				currentOutlineFadeTween = nil,
			})
		end
	end

	return sections
end

local function tweenOutlineFade(
	section: LavaSection,
	duration: number,
	targetOutlineTransparency: number,
	targetFillTransparency: number,
	onCompleted: (() -> ())?
)
	if not section.outlineHighlight then
		return
	end

	stopTween(section.currentOutlineFadeTween)

	local tween = TweenService:Create(
		section.outlineHighlight,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			OutlineTransparency = targetOutlineTransparency,
			FillTransparency = targetFillTransparency,
		}
	)
	section.currentOutlineFadeTween = tween
	if onCompleted then
		tween.Completed:Once(function(playbackState: Enum.PlaybackState)
			if playbackState == Enum.PlaybackState.Completed then
				onCompleted()
			end
		end)
	end
	tween.Completed:Once(function()
		if section.currentOutlineFadeTween == tween then
			section.currentOutlineFadeTween = nil
		end
	end)
	tween:Play()
end

local function tryKillPlayerFromHit(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Prevent repeated work while a character continuously touches lava.
	local now = os.clock()
	local lastHit = touchDebounceByCharacter[character]
	if lastHit and (now - lastHit) < 0.2 then
		return
	end
	touchDebounceByCharacter[character] = now

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local lavaSections = buildSections()
if #lavaSections == 0 then
	warn("[LavaInit] No valid lava sections found under workspace.World.Lava (expected folders named Section_*).")
	return
end

for _, section in lavaSections do
	section.lavaPart.Touched:Connect(tryKillPlayerFromHit)
end

local COUNTDOWN_SECONDS = 5

task.spawn(function()
	while true do
		local cycleTargetsBySection: { [LavaSection]: SectionTargets } = {}

		for _, section in lavaSections do
			local riseDistance = math.random(section.riseMinStuds, section.riseMaxStuds)
			local riseOffset = Vector3.new(0, riseDistance, 0)
			local sectionTargets = {
				raisedPartCFrame = section.restPartCFrame + riseOffset,
				raisedOutlineCFrame = section.restOutlineCFrame + riseOffset,
			}
			cycleTargetsBySection[section] = sectionTargets

			playOutlineMoveTween(section, sectionTargets.raisedOutlineCFrame, 0.2)
			tweenOutlineFade(section, 0, 0, 0.75)
		end

		-- Countdown before rising
		for t = COUNTDOWN_SECONDS, 1, -1 do
			lavaCountdownRemote:FireAllClients(t)
			task.wait(1)
		end
		lavaCountdownRemote:FireAllClients(0) -- tells clients to hide the label

		for _, section in lavaSections do
			task.spawn(function()
				tweenOutlineFade(section, 1, 1, 1, function()
					section.lavaOutline.CFrame = section.restOutlineCFrame
				end)
				section.lavaOutline.Material = Enum.Material.SmoothPlastic
			end)
		end

		for _, section in lavaSections do
			local sectionTargets = cycleTargetsBySection[section]
			if sectionTargets then
				playPartMoveTween(section, sectionTargets.raisedPartCFrame, RISE_DURATION)
			end
		end
		task.wait(RISE_DURATION)
		task.wait(HOLD_DURATION)

		for _, section in lavaSections do
			playPartMoveTween(section, section.restPartCFrame, LOWER_DURATION)
			section.lavaOutline.Material = Enum.Material.Glass
		end
		task.wait(LOWER_DURATION)
		task.wait(INTERVAL_BETWEEN_CYCLES)
	end
end)
