local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local observedPlots: { [Model]: boolean } = {}

local function isBrainrotTool(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute("IsBrainrotTool") == true
end

local function hasEquippedBrainrotTool(): boolean
	local character = localPlayer.Character
	if not character then
		return false
	end

	for _, child in character:GetChildren() do
		if isBrainrotTool(child) then
			return true
		end
	end

	return false
end

local function getOwningPlotModel(instance: Instance): Model?
	local current: Instance? = instance
	while current do
		if current:IsA("Model") then
			if current:GetAttribute("IsPlotModel") == true then
				return current
			end
		end
		current = current.Parent
	end

	return nil
end

local function shouldEnablePrompt(prompt: ProximityPrompt): boolean
	if prompt:GetAttribute("IsPedestalPlacePrompt") ~= true then
		return prompt.Enabled
	end

	local plotModel = getOwningPlotModel(prompt)
	if not plotModel then
		return false
	end

	local ownerUserId = plotModel:GetAttribute("OwnerUserId")
	if ownerUserId ~= localPlayer.UserId then
		return false
	end

	return hasEquippedBrainrotTool()
end

local function refreshPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("IsPedestalPlacePrompt") ~= true then
		return
	end

	prompt.Enabled = shouldEnablePrompt(prompt)
end

local function refreshAllPrompts()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("IsPedestalPlacePrompt") == true then
			refreshPrompt(descendant)
		end
	end
end

local function observePlot(plotModel: Model)
	if observedPlots[plotModel] then
		return
	end

	observedPlots[plotModel] = true
	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshAllPrompts()
	end)
	plotModel.Destroying:Connect(function()
		observedPlots[plotModel] = nil
	end)
end

local function observePrompt(plotPrompt: ProximityPrompt)
	local plotModel = getOwningPlotModel(plotPrompt)
	if plotModel then
		observePlot(plotModel)
	end
end

local function bindCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			refreshAllPrompts()
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			refreshAllPrompts()
		end
	end)

	refreshAllPrompts()
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("IsPedestalPlacePrompt") == true then
		observePrompt(descendant)
		refreshPrompt(descendant)
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	if descendant:IsA("Tool") and descendant.Parent == localPlayer.Character then
		task.defer(refreshAllPrompts)
	end
end)

localPlayer.CharacterAdded:Connect(bindCharacter)

if localPlayer.Character then
	bindCharacter(localPlayer.Character)
else
	refreshAllPrompts()
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("IsPedestalPlacePrompt") == true then
		observePrompt(descendant)
	end
end
