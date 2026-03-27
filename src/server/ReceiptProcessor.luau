local MarketplaceService = game:GetService("MarketplaceService")

local ReceiptProcessor = {}

type ReceiptHandler = (receiptInfo: any) -> Enum.ProductPurchaseDecision

local handlers: { [number]: ReceiptHandler } = {}

function ReceiptProcessor.RegisterHandler(productId: number, handler: ReceiptHandler)
	assert(
		handlers[productId] == nil,
		`[ReceiptProcessor] Handler already registered for product {productId}`
	)
	handlers[productId] = handler
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local handler = handlers[receiptInfo.ProductId]
	if handler then
		return handler(receiptInfo)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return ReceiptProcessor
