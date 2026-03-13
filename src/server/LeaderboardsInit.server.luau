local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataManager = require(ReplicatedStorage.Shared.Data.DataManager)
local NumberFormatter = require(ReplicatedStorage.Shared.Utils.NumberFormatter)

type LeaderboardSpec = {
	modelName: string,
	dataStoreName: string,
	getValue: (Player) -> number,
	formatValue: (number) -> string,
}

type LeaderboardView = {
	modelName: string,
	entryTemplate: GuiObject,
	entryContainer: Instance,
	orderedStore: OrderedDataStore,
	formatValue: (number) -> string,
}

local DISPLAY_REFRESH_INTERVAL_SECONDS = 45
local WRITE_FLUSH_INTERVAL_SECONDS = 30
local LEADERBOARD_PAGE_SIZE = 25

local GENERATED_ENTRY_ATTRIBUTE = "GeneratedLeaderboardEntry"
local FALLBACK_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"

local leaderboardSpecs: { LeaderboardSpec } = {
	{
		modelName = "SpeedLeaderboard",
		dataStoreName = "GlobalLeaderboard_Speed_v1",
		getValue = function(player: Player): number
			if DataManager.Profiles[player] then
				return DataManager.GetSpeedLevel(player)
			end

			local speedDisplay = player:GetAttribute("SpeedDisplay")
			if typeof(speedDisplay) == "number" then
				return speedDisplay
			end

			return 0
		end,
		formatValue = function(value: number): string
			return NumberFormatter.FormatCompact(value)
		end,
	},
	{
		modelName = "MoneyLeaderboard",
		dataStoreName = "GlobalLeaderboard_Money_v1",
		getValue = function(player: Player): number
			local profile = DataManager.Profiles[player]
			if profile then
				local money = profile.Data.Money
				if typeof(money) == "number" then
					return math.max(0, money)
				end
			end

			local leaderstats = player:FindFirstChild("leaderstats")
			local moneyValue = leaderstats and leaderstats:FindFirstChild("Money")
			if moneyValue and moneyValue:IsA("NumberValue") then
				return math.max(0, moneyValue.Value)
			end

			return 0
		end,
		formatValue = function(value: number): string
			return NumberFormatter.FormatMoney(value)
		end,
	},
	{
		modelName = "RebirthLeaderboard",
		dataStoreName = "GlobalLeaderboard_Rebirth_v1",
		getValue = function(player: Player): number
			if DataManager.Profiles[player] then
				return DataManager.GetJumpLevel(player)
			end

			local leaderstats = player:FindFirstChild("leaderstats")
			local rebirthValue = leaderstats and leaderstats:FindFirstChild("Rebirths")
			if rebirthValue and rebirthValue:IsA("NumberValue") then
				return rebirthValue.Value
			end

			return 0
		end,
		formatValue = function(value: number): string
			return NumberFormatter.FormatCompact(value)
		end,
	},
}

local orderedStoresByName: { [string]: OrderedDataStore } = {}
local leaderboardViews: { LeaderboardView } = {}
local leaderboardSpecsByStoreName: { [string]: LeaderboardSpec } = {}

local pendingWrites: { [number]: { [string]: number } } = {}
local lastWrittenValues: { [number]: { [string]: number } } = {}

local thumbnailCache: { [number]: string } = {}
local nameCache: { [number]: string } = {}

local refreshPending = false

local function sanitizeValue(value: number): number
	if typeof(value) ~= "number" then
		return 0
	end

	local floored = math.floor(value)
	if floored < 0 then
		return 0
	end

	return floored
end

local function getDisplayRoot(leaderboardModel: Instance): Instance
	local nestedRoot = leaderboardModel:FindFirstChild("leaderboardModel")
	if nestedRoot then
		return nestedRoot
	end

	return leaderboardModel
end

local function resolveLeaderboardView(spec: LeaderboardSpec): LeaderboardView?
	local world = Workspace:FindFirstChild("World")
	if not world then
		warn("[LeaderboardsInit] Missing workspace.World")
		return nil
	end

	local leaderboards = world:FindFirstChild("Leaderboards")
	if not leaderboards then
		warn("[LeaderboardsInit] Missing workspace.World.Leaderboards")
		return nil
	end

	local leaderboardModel = leaderboards:FindFirstChild(spec.modelName)
	if not leaderboardModel then
		warn(`[LeaderboardsInit] Missing workspace.World.Leaderboards.{spec.modelName}`)
		return nil
	end

	local displayRoot = getDisplayRoot(leaderboardModel)
	local display = displayRoot:FindFirstChild("Display")
	local screen = display and display:FindFirstChild("Screen")
	local screenGui = screen and screen:FindFirstChild("ScreenGui")
	local screenFrame = screenGui and screenGui:FindFirstChild("ScreenFrame")
	local playerFrame = screenFrame and screenFrame:FindFirstChild("PlayerFrame")

	if
		not display
		or not screen
		or not screenGui
		or not screenFrame
		or not playerFrame
		or not playerFrame:IsA("GuiObject")
	then
		warn(
			`[LeaderboardsInit] Invalid UI hierarchy for {spec.modelName}. Expected Display.Screen.ScreenGui.ScreenFrame.PlayerFrame`
		)
		return nil
	end

	local orderedStore = orderedStoresByName[spec.dataStoreName]
	if not orderedStore then
		warn(`[LeaderboardsInit] Missing OrderedDataStore for {spec.dataStoreName}`)
		return nil
	end

	playerFrame.Visible = false

	return {
		modelName = spec.modelName,
		entryTemplate = playerFrame,
		entryContainer = screenFrame,
		orderedStore = orderedStore,
		formatValue = spec.formatValue,
	}
end

local function setTextValue(instance: Instance?, value: string)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") then
		instance.Text = value
		return
	end

	if instance:IsA("TextButton") then
		instance.Text = value
	end
end

local function setImageValue(instance: Instance?, value: string)
	if not instance then
		return
	end

	if instance:IsA("ImageLabel") then
		instance.Image = value
		return
	end

	if instance:IsA("ImageButton") then
		instance.Image = value
	end
end

local function getPlayerImage(userId: number): string
	local cachedImage = thumbnailCache[userId]
	if cachedImage then
		return cachedImage
	end

	local image = FALLBACK_IMAGE
	local success, content = pcall(function()
		local thumbnail, _isReady =
			Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		return thumbnail
	end)

	if success and typeof(content) == "string" and content ~= "" then
		image = content
	end

	thumbnailCache[userId] = image
	return image
end

local function getPlayerName(userId: number): string
	local cachedName = nameCache[userId]
	if cachedName then
		return cachedName
	end

	local fallbackName = `User {userId}`
	local success, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	local resolvedName = if success and typeof(username) == "string" and username ~= "" then username else fallbackName
	nameCache[userId] = resolvedName
	return resolvedName
end

local function clearGeneratedEntries(container: Instance, template: GuiObject)
	for _, child in container:GetChildren() do
		if child == template then
			continue
		end

		if child:GetAttribute(GENERATED_ENTRY_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
end

local function queueWrite(userId: number, dataStoreName: string, value: number)
	local normalizedValue = sanitizeValue(value)
	local userWrites = pendingWrites[userId]
	if not userWrites then
		userWrites = {}
		pendingWrites[userId] = userWrites
	end

	local alreadyPendingValue = userWrites[dataStoreName]
	if alreadyPendingValue == normalizedValue then
		return
	end

	userWrites[dataStoreName] = normalizedValue
end

local function queuePlayerStatWrites(player: Player)
	for _, spec in leaderboardSpecs do
		queueWrite(player.UserId, spec.dataStoreName, spec.getValue(player))
	end
end

local function queueSingleStatWrite(player: Player, dataStoreName: string)
	local spec = leaderboardSpecsByStoreName[dataStoreName]
	if not spec then
		return
	end

	queueWrite(player.UserId, spec.dataStoreName, spec.getValue(player))
end

local function flushPendingWrites()
	for userId, userWrites in pendingWrites do
		local lastWritesForUser = lastWrittenValues[userId]
		if not lastWritesForUser then
			lastWritesForUser = {}
			lastWrittenValues[userId] = lastWritesForUser
		end

		for dataStoreName, value in userWrites do
			local alreadyWritten = lastWritesForUser[dataStoreName]
			if alreadyWritten == value then
				userWrites[dataStoreName] = nil
				continue
			end

			local store = orderedStoresByName[dataStoreName]
			if not store then
				warn(`[LeaderboardsInit] Missing OrderedDataStore for pending write: {dataStoreName}`)
				continue
			end

			local success, err = pcall(function()
				store:SetAsync(tostring(userId), value)
			end)

			if success then
				lastWritesForUser[dataStoreName] = value
				userWrites[dataStoreName] = nil
			else
				warn(`[LeaderboardsInit] Failed SetAsync for {dataStoreName} user {userId}: {err}`)
			end
		end

		if next(userWrites) == nil then
			pendingWrites[userId] = nil
		end
	end
end

local function populateView(view: LeaderboardView)
	local success, result = pcall(function()
		return view.orderedStore:GetSortedAsync(false, LEADERBOARD_PAGE_SIZE)
	end)

	if not success then
		warn(`[LeaderboardsInit] GetSortedAsync failed for {view.modelName}: {result}`)
		return
	end

	local pages = result :: DataStorePages
	local entries = pages:GetCurrentPage()

	clearGeneratedEntries(view.entryContainer, view.entryTemplate)

	for rank, entry in entries do
		local key = entry.key or entry.Key
		local value = entry.value or entry.Value
		local userId = tonumber(tostring(key))
		local numericValue = if typeof(value) == "number" then sanitizeValue(value) else 0

		if not userId then
			continue
		end

		local row = view.entryTemplate:Clone()
		row.Name = `PlayerFrame_{rank}`
		row.Visible = true
		row.LayoutOrder = rank
		row:SetAttribute(GENERATED_ENTRY_ATTRIBUTE, true)

		local userDetails = row:FindFirstChild("UserDetails")
		local valueDetails = row:FindFirstChild("ValueDetails")
		local imageLabel = userDetails and userDetails:FindFirstChild("ImageLabel")
		local nameText = userDetails and userDetails:FindFirstChild("TextLabel")
		local valueText = valueDetails and valueDetails:FindFirstChild("TextLabel")

		setImageValue(imageLabel, getPlayerImage(userId))
		setTextValue(nameText, getPlayerName(userId))
		setTextValue(valueText, view.formatValue(numericValue))

		row.Parent = view.entryContainer
	end
end

local function refreshAllLeaderboards()
	for _, view in leaderboardViews do
		populateView(view)
	end
end

local function requestRefresh()
	if refreshPending then
		return
	end

	refreshPending = true
	task.defer(function()
		refreshPending = false
		refreshAllLeaderboards()
	end)
end

local function connectPlayerSignals(player: Player)
	player:GetAttributeChangedSignal("SpeedDisplay"):Connect(function()
		queueSingleStatWrite(player, "GlobalLeaderboard_Speed_v1")
	end)

	task.defer(function()
		local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 20)
		if not leaderstats then
			return
		end

		local moneyValue = leaderstats:FindFirstChild("Money") or leaderstats:WaitForChild("Money", 20)
		local rebirthValue = leaderstats:FindFirstChild("Rebirths") or leaderstats:WaitForChild("Rebirths", 20)

		if moneyValue and moneyValue:IsA("NumberValue") then
			moneyValue.Changed:Connect(function()
				queueSingleStatWrite(player, "GlobalLeaderboard_Money_v1")
			end)
		end

		if rebirthValue and rebirthValue:IsA("NumberValue") then
			rebirthValue.Changed:Connect(function()
				queueSingleStatWrite(player, "GlobalLeaderboard_Rebirth_v1")
			end)
		end

		queuePlayerStatWrites(player)
	end)
end

for _, spec in leaderboardSpecs do
	orderedStoresByName[spec.dataStoreName] = DataStoreService:GetOrderedDataStore(spec.dataStoreName)
	leaderboardSpecsByStoreName[spec.dataStoreName] = spec
end

for _, spec in leaderboardSpecs do
	local view = resolveLeaderboardView(spec)
	if view then
		table.insert(leaderboardViews, view)
	end
end

if #leaderboardViews == 0 then
	warn("[LeaderboardsInit] No valid leaderboard views found; script will idle.")
	return
end

for _, player in Players:GetPlayers() do
	connectPlayerSignals(player)
	queuePlayerStatWrites(player)
end

Players.PlayerAdded:Connect(function(player: Player)
	connectPlayerSignals(player)
	queuePlayerStatWrites(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	queuePlayerStatWrites(player)
	flushPendingWrites()
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		queuePlayerStatWrites(player)
	end
	flushPendingWrites()
end)

task.spawn(function()
	while true do
		flushPendingWrites()
		task.wait(WRITE_FLUSH_INTERVAL_SECONDS)
	end
end)

task.spawn(function()
	while true do
		requestRefresh()
		task.wait(DISPLAY_REFRESH_INTERVAL_SECONDS)
	end
end)

requestRefresh()
