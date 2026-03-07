local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plotTemplate = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("PlotTemplate")
local pedestalTemplate = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("PedestalTemplate")

local plotsFolder = workspace:WaitForChild("World"):WaitForChild("Plots")

for _, plotAttachment in ipairs(plotsFolder:GetChildren()) do
	if plotAttachment:IsA("Attachment") then
		local plotClone = plotTemplate:Clone()
		plotClone.Parent = workspace
		plotClone:PivotTo(plotAttachment.WorldCFrame)

		local plotNumber = plotAttachment.Name:match("(%d+)$")
		if plotNumber then
			plotClone.Name = "Plot_" .. plotNumber
		else
			plotClone.Name = "Plot"
		end

		local pedestalsFolder = plotClone:WaitForChild("Level01"):WaitForChild("Pedestals")

		for _, pedestalAttachment in ipairs(pedestalsFolder:GetChildren()) do
			if pedestalAttachment:IsA("Attachment") then
				local pedestalClone = pedestalTemplate:Clone()
				pedestalClone.Name = pedestalAttachment.Name:gsub("Attachment", "")
				pedestalClone.Parent = plotClone
				pedestalClone:PivotTo(pedestalAttachment.WorldCFrame)
			end
		end
	end
end
