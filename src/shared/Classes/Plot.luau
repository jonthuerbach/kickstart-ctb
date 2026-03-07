local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plot = {}
Plot.__index = Plot

export type Plot = typeof(setmetatable(
	{} :: {
		plotId: string,
		ownerUserId: number?,
		claimedAt: number?,
		_model: Model,
		_badgeGui: BillboardGui?,
	},
	Plot
))

-- The attachment can be any Attachment in Workspace.Plots.
-- The PlotTemplate model must have a PrimaryPart set for PivotTo to work correctly.
-- The PlotTemplate model must contain an OwnerBadge part with a child Attachment.
function Plot.new(plotId: string, attachment: Attachment): Plot
	local template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("PlotTemplate") :: Model
	local model = template:Clone()
	model.Name = plotId
	model:PivotTo(attachment.WorldCFrame)
	model.Parent = workspace:FindFirstChild("Plots")

	local self = setmetatable({
		plotId = plotId,
		ownerUserId = nil,
		claimedAt = nil,
		_model = model,
		_badgeGui = nil,
	}, Plot)

	self:_setupVendor()

	return self
end

function Plot.IsAvailable(self: Plot): boolean
	return self.ownerUserId == nil
end

function Plot.Assign(self: Plot, player: Player)
	self.ownerUserId = player.UserId
	self.claimedAt = os.time()
	self:_buildOwnerBadge(player)
end

function Plot.Unassign(self: Plot)
	self.ownerUserId = nil
	self.claimedAt = nil

	if self._badgeGui then
		self._badgeGui:Destroy()
		self._badgeGui = nil
	end
end

function Plot._buildOwnerBadge(self: Plot, player: Player)
	local ownerBadgePart = self._model:FindFirstChild("OwnerBadge")
	if not ownerBadgePart then
		warn(`[Plot] PlotTemplate is missing OwnerBadge part on plot {self.plotId}`)
		return
	end

	local attachment = ownerBadgePart:FindFirstChildOfClass("Attachment")
	if not attachment then
		warn(`[Plot] OwnerBadge is missing an Attachment on plot {self.plotId}`)
		return
	end

	if self._badgeGui then
		self._badgeGui:Destroy()
		self._badgeGui = nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerBadgeGui"
	billboard.Size = UDim2.fromScale(48, 24)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.LightInfluence = 0

	local imageFrame = Instance.new("Frame")
	imageFrame.Name = "ImageFrame"
	imageFrame.AnchorPoint = Vector2.new(0.5, 0)
	imageFrame.Size = UDim2.fromScale(1, 0.66)
	imageFrame.Position = UDim2.new(0.5, 0, 0, 0)
	imageFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	imageFrame.BorderSizePixel = 0
	imageFrame.Parent = billboard

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(1, 0)
	frameCorner.Parent = imageFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(0, 0, 0)
	frameStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	frameStroke.Thickness = 0.05
	frameStroke.LineJoinMode = Enum.LineJoinMode.Round
	frameStroke.Parent = imageFrame

	local profileImage = Instance.new("ImageLabel")
	profileImage.Name = "ProfileImage"
	profileImage.Size = UDim2.fromScale(1, 1)
	profileImage.BackgroundTransparency = 1
	profileImage.ScaleType = Enum.ScaleType.Crop
	profileImage.Parent = imageFrame

	local frameUiAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	frameUiAspectRatioConstraint.AspectRatio = 1
	frameUiAspectRatioConstraint.Parent = imageFrame

	local imageCorner = Instance.new("UICorner")
	imageCorner.CornerRadius = UDim.new(1, 0)
	imageCorner.Parent = profileImage

	local nameFrame = Instance.new("Frame")
	nameFrame.Name = "NameFrame"
	nameFrame.AnchorPoint = Vector2.new(0.5, 0)
	nameFrame.Position = UDim2.new(0.5, 0, 0.66, 0)
	nameFrame.Size = UDim2.fromScale(1, 0.33)
	nameFrame.BackgroundTransparency = 1
	nameFrame.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DisplayName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Parent = nameFrame

	local nameLabelUiPadding = Instance.new("UIPadding")
	nameLabelUiPadding.PaddingLeft = UDim.new(0.0, 0)
	nameLabelUiPadding.PaddingRight = UDim.new(0.0, 0)
	nameLabelUiPadding.PaddingTop = UDim.new(0.1, 0)
	nameLabelUiPadding.PaddingBottom = UDim.new(0.1, 0)
	nameLabelUiPadding.Parent = nameLabel

	local nameLabelStroke = Instance.new("UIStroke")
	nameLabelStroke.Color = Color3.fromRGB(0, 0, 0)
	nameLabelStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	nameLabelStroke.Thickness = 0.1
	nameLabelStroke.LineJoinMode = Enum.LineJoinMode.Round
	nameLabelStroke.Parent = nameLabel

	billboard.Parent = attachment
	self._badgeGui = billboard

	-- Thumbnail fetch is async; fire and forget
	task.spawn(function()
		local ok, thumbnail = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)

		-- Guard against unassignment occurring while the request was in flight
		if ok and thumbnail and profileImage.Parent then
			profileImage.Image = thumbnail
		end
	end)
end

function Plot._setupPedestals(self: Plot) end

return Plot
