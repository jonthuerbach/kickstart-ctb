local DeveloperProductCatalog = {}

DeveloperProductCatalog.Ids = {
	SkipLevel = 3561788298,
}

function DeveloperProductCatalog.GetProductId(name: string): number?
	return DeveloperProductCatalog.Ids[name]
end

return DeveloperProductCatalog
