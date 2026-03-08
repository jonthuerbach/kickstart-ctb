local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plot = require(ReplicatedStorage.Shared.Classes.Plot)

local PlotManager = {}

local _plots: { [string]: Plot.Plot } = {}
local _initialized = false

local function toPlotId(attachmentName: string): string
	local plotNumber = attachmentName:match("(%d+)$")
	if plotNumber then
		return `Plot_{plotNumber}`
	end

	return attachmentName
end

-- Scans Workspace.World.Plots for Attachment children and spawns a PlotTemplate clone
-- at each one. Safe to call once at server startup.
function PlotManager.Initialize()
	if _initialized then
		return
	end

	local worldFolder = workspace:WaitForChild("World")
	local plotsFolder = worldFolder:WaitForChild("Plots")

	for _, child in plotsFolder:GetChildren() do
		if not child:IsA("Attachment") then
			continue
		end

		local plotId = toPlotId(child.Name)
		local plot = Plot.new(plotId, child :: Attachment, workspace)
		_plots[plotId] = plot
		print(`[PlotManager] Initialized plot: {plotId}`)
	end

	_initialized = true
end

-- Assigns the player to the first available plot (sorted ascending by name
-- so Plot01 is always preferred over Plot02, etc.).
function PlotManager.AssignNextAvailable(player: Player): Plot.Plot?
	local current = PlotManager.GetPlotForPlayer(player)
	if current then
		return current
	end

	local sortedIds = {}
	for plotId in _plots do
		table.insert(sortedIds, plotId)
	end
	table.sort(sortedIds, function(a, b)
		local aNum = tonumber(a:match("(%d+)$"))
		local bNum = tonumber(b:match("(%d+)$"))

		if aNum and bNum then
			return aNum < bNum
		end

		return a < b
	end)

	for _, plotId in sortedIds do
		local plot = _plots[plotId]
		if plot:IsAvailable() then
			plot:Assign(player)
			print(`[PlotManager] Assigned {player.Name} to {plotId}`)
			return plot
		end
	end

	warn(`[PlotManager] No available plots for {player.Name}`)
	return nil
end

-- Releases whichever plot the player currently owns, if any.
function PlotManager.UnassignPlayer(player: Player)
	for plotId, plot in _plots do
		if plot.ownerUserId == player.UserId then
			plot:Unassign()
			print(`[PlotManager] Released {plotId} from {player.Name}`)
			return
		end
	end
end

-- Returns the plot owned by the given player, or nil.
function PlotManager.GetPlotForPlayer(player: Player): Plot.Plot?
	for _, plot in _plots do
		if plot.ownerUserId == player.UserId then
			return plot
		end
	end
	return nil
end

-- Returns the plot with the given id, or nil.
function PlotManager.GetPlot(plotId: string): Plot.Plot?
	return _plots[plotId]
end

return PlotManager
