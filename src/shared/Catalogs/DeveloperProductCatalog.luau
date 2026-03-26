local DeveloperProductCatalog = {}

DeveloperProductCatalog.Ids = {
	SkipLevel = 3561788298,
	Cash25K = 3563541174,
	Cash1M = 3563541377,
	Cash1B = 3563541559,
}

DeveloperProductCatalog.CashProducts = {
	[3563541174] = 25_000,
	[3563541377] = 1_000_000,
	[3563541559] = 1_000_000_000,
}

function DeveloperProductCatalog.GetProductId(name: string): number?
	return DeveloperProductCatalog.Ids[name]
end

return DeveloperProductCatalog
