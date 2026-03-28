local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager = require(ReplicatedStorage.Shared.Utils.MenuManager)
local BrainrotCatalog = require(ReplicatedStorage.Shared.Catalogs.BrainrotCatalog)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestIndexStateRemote = remotes:WaitForChild("RequestIndexState") :: RemoteEvent
local indexStateRemote = remotes:WaitForChild("IndexState") :: RemoteEvent
local brainrotsRoot = ReplicatedStorage:WaitForChild("Brainrots")

local indexMenu = mainGui:WaitForChild("IndexMenu")
local playerButtons = mainGui:WaitForChild("PlayerButtons")
local indexFrame = playerButtons:WaitForChild("IndexFrame")
local indexMenuButton = indexFrame:WaitForChild("IndexMenuButton")
local indexMenuCloseButton = indexMenu:WaitForChild("Header"):WaitForChild("CloseButton")

local body = indexMenu:WaitForChild("Body")
local scrollingFrame = body:WaitForChild("ScrollingFrame")
local titleFrame = scrollingFrame:WaitForChild("TitleFrame")
local titleLabel = titleFrame:WaitForChild("TextLabel") :: TextLabel
local sideMenu = indexMenu:WaitForChild("SideMenu")

assert(indexMenu:IsA("GuiObject"), "[IndexMenu] MainGui.IndexMenu must be a GuiObject")
assert(indexMenuButton:IsA("GuiButton"), "[IndexMenu] IndexFrame.IndexMenuButton must be a GuiButton")
assert(indexMenuCloseButton:IsA("GuiButton"), "[IndexMenu] IndexMenu.Header.CloseButton must be a GuiButton")

local MENU_NAME = "IndexMenu"
local FRAME_COUNT = 9
local DISCOVERED_AMBIENT = Color3.fromRGB(200, 200, 200)
local DISCOVERED_LIGHT_COLOR = Color3.fromRGB(140, 140, 140)
local DISCOVERED_LIGHT_DIRECTION = Vector3.new(-1, -1, -1)
local SILHOUETTE_AMBIENT = Color3.new(0, 0, 0)
local SILHOUETTE_LIGHT_COLOR = Color3.new(0, 0, 0)
local DISCOVERED_GRADIENT_COLOR = ColorSequence.new(Color3.fromRGB(200, 225, 255), Color3.fromRGB(140, 185, 235))
local DISCOVERED_GRADIENT_ROTATION = 90
local UNDISCOVERED_GRADIENT_COLOR = ColorSequence.new(Color3.fromRGB(128, 128, 128), Color3.fromRGB(169, 169, 169))
local UNDISCOVERED_GRADIENT_ROTATION = 90

type SideButtonEntry = {
	rarity: string,
	button: GuiButton,
}

local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local sideButtons: { SideButtonEntry } = {}
for _, rarity in RARITIES do
	local button = sideMenu:WaitForChild(rarity .. "Button")
	assert(button:IsA("GuiButton"), `[IndexMenu] SideMenu.{rarity}Button must be a GuiButton`)
	table.insert(sideButtons, { rarity = rarity, button = button :: GuiButton })
end

local brainrotFrames: { Frame } = {}
for i = 1, FRAME_COUNT do
	local frameName = string.format("BrainrotFrame%02d", i)
	local frame = scrollingFrame:WaitForChild(frameName)
	brainrotFrames[i] = frame
end

local currentRarity: string = "Common"
local indexData: { [string]: { [string]: { discovered: boolean } } }? = nil

local function clearViewportFrame(viewportFrame: ViewportFrame)
	for _, child in viewportFrame:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
end

local function loadBrainrotIntoViewport(
	viewportFrame: ViewportFrame,
	rarity: string,
	modelName: string,
	discovered: boolean
)
	clearViewportFrame(viewportFrame)

	local rarityFolder = brainrotsRoot:FindFirstChild(rarity)
	if not rarityFolder then
		return
	end

	local template = rarityFolder:FindFirstChild(modelName)
	if not template or not template:IsA("Model") then
		return
	end

	local clone = template:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	clone.Parent = viewportFrame

	local cf, size = clone:GetBoundingBox()
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = (maxSize / 2) / math.tan(math.rad(20)) * 1.4

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(distance * 0.5, distance * 0.3, distance * 0.7), cf.Position)
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	if discovered then
		viewportFrame.Ambient = DISCOVERED_AMBIENT
		viewportFrame.LightColor = DISCOVERED_LIGHT_COLOR
		viewportFrame.LightDirection = DISCOVERED_LIGHT_DIRECTION
	else
		viewportFrame.Ambient = SILHOUETTE_AMBIENT
		viewportFrame.LightColor = SILHOUETTE_LIGHT_COLOR
	end
end

local function getDiscoveredCount(rarity: string, catalogEntries: { any }): (number, number)
	local total = #catalogEntries
	local discovered = 0

	if indexData then
		local rarityIndex = indexData[rarity]
		if typeof(rarityIndex) == "table" then
			for _, entry in catalogEntries do
				local entryData = rarityIndex[entry.modelName]
				if typeof(entryData) == "table" and entryData.discovered == true then
					discovered += 1
				end
			end
		end
	end

	return discovered, total
end

local function loadRarityCategory(rarity: string)
	currentRarity = rarity

	local catalogEntries = BrainrotCatalog.Names[rarity]
	if catalogEntries then
		local discovered, total = getDiscoveredCount(rarity, catalogEntries)
		titleLabel.Text = `{rarity} Brainrots ({discovered}/{total})`
	else
		titleLabel.Text = rarity .. " Brainrots"
	end
	if not catalogEntries then
		for i = 1, FRAME_COUNT do
			brainrotFrames[i].Visible = false
		end
		return
	end

	for i = 1, FRAME_COUNT do
		local frame = brainrotFrames[i]
		local viewportFrame = frame:FindFirstChild("ViewportFrame") :: ViewportFrame?
		local nameLabel = frame:FindFirstChild("NameLabel") :: TextLabel?
		local rarityLabel = frame:FindFirstChild("RarityLabel") :: TextLabel?

		local entry = catalogEntries[i]
		if entry and viewportFrame then
			local modelName: string = entry.modelName
			local discovered = false

			if indexData then
				local rarityIndex = indexData[rarity]
				if typeof(rarityIndex) == "table" then
					local entryData = rarityIndex[modelName]
					if typeof(entryData) == "table" and entryData.discovered == true then
						discovered = true
					end
				end
			end

			loadBrainrotIntoViewport(viewportFrame, rarity, modelName, discovered)

			if nameLabel then
				nameLabel.Text = if discovered then entry.name else "???"
			end
			if rarityLabel then
				rarityLabel.Text = rarity
			end

			local studsTexture = frame:FindFirstChild("StudsTexture")
			local uiGradient = if studsTexture then studsTexture:FindFirstChild("UIGradient") :: UIGradient? else nil
			if uiGradient then
				if discovered then
					uiGradient.Color = DISCOVERED_GRADIENT_COLOR
					uiGradient.Rotation = DISCOVERED_GRADIENT_ROTATION
				else
					uiGradient.Color = UNDISCOVERED_GRADIENT_COLOR
					uiGradient.Rotation = UNDISCOVERED_GRADIENT_ROTATION
				end
			end

			frame.Visible = true
		else
			if viewportFrame then
				clearViewportFrame(viewportFrame)
			end
			if nameLabel then
				nameLabel.Text = ""
			end
			if rarityLabel then
				rarityLabel.Text = ""
			end
			frame.Visible = false
		end
	end
end

local function onIndexStateReceived(data: any)
	if typeof(data) ~= "table" then
		return
	end

	indexData = data :: { [string]: { [string]: { discovered: boolean } } }

	if MenuManager.IsOpen(MENU_NAME) then
		loadRarityCategory(currentRarity)
	end
end

indexStateRemote.OnClientEvent:Connect(onIndexStateReceived)

MenuManager.Register(MENU_NAME, indexMenu, {
	onOpen = function()
		requestIndexStateRemote:FireServer()
		loadRarityCategory(currentRarity)
	end,
	onClose = function()
		for i = 1, FRAME_COUNT do
			local viewportFrame = brainrotFrames[i]:FindFirstChild("ViewportFrame") :: ViewportFrame?
			if viewportFrame then
				clearViewportFrame(viewportFrame)
			end
		end
	end,
})

MenuManager.AttachHoverPressEffect(indexMenuButton)

indexMenuButton.Activated:Connect(function()
	MenuManager.Toggle(MENU_NAME)
end)

indexMenuCloseButton.Activated:Connect(function()
	MenuManager.Close(MENU_NAME)
end)

for _, entry in sideButtons do
	MenuManager.AttachHoverPressEffect(entry.button)

	entry.button.Activated:Connect(function()
		if currentRarity == entry.rarity then
			return
		end
		loadRarityCategory(entry.rarity)
	end)
end
