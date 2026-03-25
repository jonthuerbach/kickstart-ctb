local GamePassCatalog = {}

GamePassCatalog.Names = {
	VIP = "1764317066",
	["2XMoney"] = "1767395214",
}

GamePassCatalog.Attributes = {
	["1764317066"] = "GamePassVIP",
	["1767395214"] = "GamePass2XMoney",
}

function GamePassCatalog.GetGamePassId(name: string): string?
	return GamePassCatalog.Names[name]
end

function GamePassCatalog.GetAttributeName(passId: string): string?
	return GamePassCatalog.Attributes[passId]
end

GamePassCatalog.Functions = {
	["1764317066"] = function(_player: Player)
		-- VIP benefits applied elsewhere
	end,
	["1767395214"] = function(_player: Player)
		-- 2x Money: doubles brainrot ratePerSecond (wired up later)
	end,
}

return GamePassCatalog
