local GamePassCatalog = {}

GamePassCatalog.Names = {
	VIP = "1502122570",
	-- GOLD_X2 = "1439757298",
}

function GamePassCatalog.GetGamePassId(name: string)
	return GamePassCatalog.Names[name]
end

GamePassCatalog.Functions = {
	["1502122570"] = function(player: Player)
		print("VIP purchased")
	end,

	-- ["1439757298"] = function(player: Player)
	-- 	print("2x Gold purchased")
	-- end,
}

return GamePassCatalog
