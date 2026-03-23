local GamePassCatalog = {}

GamePassCatalog.Names = {
	VIP = "1764317066",
}

function GamePassCatalog.GetGamePassId(name: string)
	return GamePassCatalog.Names[name]
end

GamePassCatalog.Functions = {
	["1764317066"] = function(player: Player)
		print("VIP purchased")
	end,
}

return GamePassCatalog
