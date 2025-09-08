local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local requestGamePass = remotes:FindFirstChild("RequestGamePass")
if not requestGamePass then
	requestGamePass = Instance.new("RemoteEvent")
	requestGamePass.Name = "RequestGamePass"
	requestGamePass.Parent = remotes
end

local updateTimer = remotes:FindFirstChild("UpdateTimer")
if not updateTimer then
	updateTimer = Instance.new("RemoteEvent")
	updateTimer.Name = "UpdateTimer"
	updateTimer.Parent = remotes
end

local updateScores = remotes:FindFirstChild("UpdateScores")
if not updateScores then
	updateScores = Instance.new("RemoteEvent")
	updateScores.Name = "UpdateScores"
	updateScores.Parent = remotes
end
