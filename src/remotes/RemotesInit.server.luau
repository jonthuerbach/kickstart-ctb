local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local updateGold = remotes:FindFirstChild("UpdateGold")
if not updateGold then
	updateGold = Instance.new("RemoteEvent")
	updateGold.Name = "UpdateGold"
	updateGold.Parent = remotes
end

local updateGems = remotes:FindFirstChild("UpdateGems")
if not updateGems then
	updateGems = Instance.new("RemoteEvent")
	updateGems.Name = "UpdateGems"
	updateGems.Parent = remotes
end

local requestGamePass = remotes:FindFirstChild("RequestGamePass")
if not requestGamePass then
	requestGamePass = Instance.new("RemoteEvent")
	requestGamePass.Name = "RequestGamePass"
	requestGamePass.Parent = remotes
end
