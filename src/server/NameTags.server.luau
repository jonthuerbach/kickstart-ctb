-- ServerScriptService/NameTags.server.luau
local Players = game:GetService("Players")

local function applyNameTag(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart

	-- Hide Roblox defaults
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	-- Remove any existing custom tag
	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end

	-- Create custom tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Adornee = head
	tag.AlwaysOnTop = true
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.Size = UDim2.fromScale(6, 1.5)
	tag.Parent = head

	local tagFrame = Instance.new("Frame")
	tagFrame.Size = UDim2.fromScale(1, 1)
	tagFrame.BackgroundTransparency = 1
	tagFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	tagFrame.Parent = tag

	local tagFrameStroke = Instance.new("UIStroke")
	tagFrameStroke.Thickness = 4
	tagFrameStroke.Color = Color3.new(0, 0, 0)
	tagFrameStroke.Parent = tagFrame

	local tagFrameUICorner = Instance.new("UICorner")
	tagFrameUICorner.CornerRadius = UDim.new(0, 8)
	tagFrameUICorner.Parent = tagFrame

	local tagFrameUIPadding = Instance.new("UIPadding")
	tagFrameUIPadding.PaddingLeft = UDim.new(0.1, 0)
	tagFrameUIPadding.PaddingRight = UDim.new(0.1, 0)
	tagFrameUIPadding.PaddingTop = UDim.new(0.1, 0)
	tagFrameUIPadding.PaddingBottom = UDim.new(0.1, 0)
	tagFrameUIPadding.Parent = tagFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
	label.Parent = tagFrame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	local function updateColor()
		local team = player.Team
		if team then
			local uiGradient = Instance.new("UIGradient")
			uiGradient.Color = ColorSequence.new({
				team.Name == "Blue" and ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 128, 255))
					or ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 128, 128)),
				team.Name == "Blue" and ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255))
					or ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			})
			uiGradient.Rotation = 90
			uiGradient.Parent = tagFrame
			-- tagFrame.BackgroundColor3 = team.Name == "Blue" and Color3.new(0, 0, 1) or Color3.new(1, 0, 0)
			tagFrame.BackgroundTransparency = 0
			tagFrameStroke.Enabled = true
		else
			tagFrame.BackgroundTransparency = 1
			tagFrameStroke.Enabled = false
		end
	end
	updateColor()
	player:GetPropertyChangedSignal("Team"):Connect(updateColor)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		applyNameTag(player, character)
	end)
	if player.Character then
		applyNameTag(player, player.Character)
	end
end)
