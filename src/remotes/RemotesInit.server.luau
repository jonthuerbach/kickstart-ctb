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

local updateMoney = remotes:FindFirstChild("UpdateMoney")
if not updateMoney then
	updateMoney = Instance.new("RemoteEvent")
	updateMoney.Name = "UpdateMoney"
	updateMoney.Parent = remotes
end

local lavaCountdown = remotes:FindFirstChild("LavaCountdown")
if not lavaCountdown then
	lavaCountdown = Instance.new("RemoteEvent")
	lavaCountdown.Name = "LavaCountdown"
	lavaCountdown.Parent = remotes
end

local speedVendorState = remotes:FindFirstChild("SpeedVendorState")
if not speedVendorState then
	speedVendorState = Instance.new("RemoteEvent")
	speedVendorState.Name = "SpeedVendorState"
	speedVendorState.Parent = remotes
end

local requestSpeedUpgrade = remotes:FindFirstChild("RequestSpeedUpgrade")
if not requestSpeedUpgrade then
	requestSpeedUpgrade = Instance.new("RemoteEvent")
	requestSpeedUpgrade.Name = "RequestSpeedUpgrade"
	requestSpeedUpgrade.Parent = remotes
end

local requestRebirth = remotes:FindFirstChild("RequestRebirth")
if not requestRebirth then
	requestRebirth = Instance.new("RemoteEvent")
	requestRebirth.Name = "RequestRebirth"
	requestRebirth.Parent = remotes
end

local requestRebirthState = remotes:FindFirstChild("RequestRebirthState")
if not requestRebirthState then
	requestRebirthState = Instance.new("RemoteEvent")
	requestRebirthState.Name = "RequestRebirthState"
	requestRebirthState.Parent = remotes
end

local rebirthState = remotes:FindFirstChild("RebirthState")
if not rebirthState then
	rebirthState = Instance.new("RemoteEvent")
	rebirthState.Name = "RebirthState"
	rebirthState.Parent = remotes
end
