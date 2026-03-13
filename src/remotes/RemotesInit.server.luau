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

local toggleSellVendorMenu = remotes:FindFirstChild("ToggleSellVendorMenu")
if not toggleSellVendorMenu then
	toggleSellVendorMenu = Instance.new("RemoteEvent")
	toggleSellVendorMenu.Name = "ToggleSellVendorMenu"
	toggleSellVendorMenu.Parent = remotes
end

local sellBrainrotAction = remotes:FindFirstChild("SellBrainrotAction")
if not sellBrainrotAction then
	sellBrainrotAction = Instance.new("RemoteEvent")
	sellBrainrotAction.Name = "SellBrainrotAction"
	sellBrainrotAction.Parent = remotes
end

local updateConfirmSellBrainrotActionText = remotes:FindFirstChild("UpdateConfirmSellBrainrotActionText")
if not updateConfirmSellBrainrotActionText then
	updateConfirmSellBrainrotActionText = Instance.new("RemoteEvent")
	updateConfirmSellBrainrotActionText.Name = "UpdateConfirmSellBrainrotActionText"
	updateConfirmSellBrainrotActionText.Parent = remotes
end

local confirmSellBrainrotAction = remotes:FindFirstChild("ConfirmSellBrainrotAction")
if not confirmSellBrainrotAction then
	confirmSellBrainrotAction = Instance.new("RemoteEvent")
	confirmSellBrainrotAction.Name = "ConfirmSellBrainrotAction"
	confirmSellBrainrotAction.Parent = remotes
end

local giftOfferIncoming = remotes:FindFirstChild("GiftOfferIncoming")
if not giftOfferIncoming then
	giftOfferIncoming = Instance.new("RemoteEvent")
	giftOfferIncoming.Name = "GiftOfferIncoming"
	giftOfferIncoming.Parent = remotes
end

local giftOfferResponse = remotes:FindFirstChild("GiftOfferResponse")
if not giftOfferResponse then
	giftOfferResponse = Instance.new("RemoteEvent")
	giftOfferResponse.Name = "GiftOfferResponse"
	giftOfferResponse.Parent = remotes
end

local giftOfferClosed = remotes:FindFirstChild("GiftOfferClosed")
if not giftOfferClosed then
	giftOfferClosed = Instance.new("RemoteEvent")
	giftOfferClosed.Name = "GiftOfferClosed"
	giftOfferClosed.Parent = remotes
end

local giftStatusMessage = remotes:FindFirstChild("GiftStatusMessage")
if not giftStatusMessage then
	giftStatusMessage = Instance.new("RemoteEvent")
	giftStatusMessage.Name = "GiftStatusMessage"
	giftStatusMessage.Parent = remotes
end

local mythicSpawned = remotes:FindFirstChild("MythicSpawned")
if not mythicSpawned then
	mythicSpawned = Instance.new("RemoteEvent")
	mythicSpawned.Name = "MythicSpawned"
	mythicSpawned.Parent = remotes
end
