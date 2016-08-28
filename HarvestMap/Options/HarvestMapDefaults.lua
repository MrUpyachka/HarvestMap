if not Harvest then
	Harvest = {}
end

Harvest.dataDefault = {
	data = {},
	--dataVersion = Harvest.dataVersion
}

Harvest.defaultGlobalSettings = {
	accountWideSettings = false,
	maxTimeDifference = 0
}

Harvest.defaultSettings = {
	-- which pins are displayed on the map/compass
	isPinTypeVisible = {
		[Harvest.GetPinType(Harvest.BLACKSMITH)]  = true,
		[Harvest.GetPinType(Harvest.CLOTHING)]    = true,
		[Harvest.GetPinType(Harvest.ENCHANTING)]  = true,
		[Harvest.GetPinType(Harvest.ALCHEMY)]     = true,
		[Harvest.GetPinType(Harvest.WOODWORKING)] = true,
		[Harvest.GetPinType(Harvest.CHESTS)]      = true,
		[Harvest.GetPinType(Harvest.WATER)]       = true,
		[Harvest.GetPinType(Harvest.FISHING)]     = true,
		[Harvest.GetPinType(Harvest.HEAVYSACK)]	  = true,
		[Harvest.GetPinType(Harvest.TROVE)]       = true,
		[Harvest.GetPinType(Harvest.OLDTROVE)]	      = true,
		[Harvest.GetPinType(Harvest.JUSTICE)]	      = true,
		[Harvest.GetPinType(Harvest.TOUR)]	      = true,
		[Harvest.GetPinType( "Debug" )]           = false
	},
	-- which pin types are skipped while importing
	isPinTypeSavedOnImport = {
		[Harvest.BLACKSMITH]  = true,
		[Harvest.CLOTHING]    = true,
		[Harvest.ENCHANTING]  = true,
		[Harvest.ALCHEMY]     = true,
		[Harvest.WOODWORKING] = true,
		[Harvest.CHESTS]      = true,
		[Harvest.WATER]       = true,
		[Harvest.FISHING]     = true,
		[Harvest.HEAVYSACK]	  = true,
		[Harvest.TROVE]	      = true,
		[Harvest.OLDTROVE]	      = true,
		[Harvest.JUSTICE]	      = true,
	},
	-- which pin types are skipped when gathered
	isPinTypeSavedOnGather = {
		[Harvest.BLACKSMITH]  = true,
		[Harvest.CLOTHING]    = true,
		[Harvest.ENCHANTING]  = true,
		[Harvest.ALCHEMY]     = true,
		[Harvest.WOODWORKING] = true,
		[Harvest.CHESTS]      = true,
		[Harvest.WATER]       = true,
		[Harvest.FISHING]     = true,
		[Harvest.HEAVYSACK]	  = true,
		[Harvest.TROVE]	      = true,
		[Harvest.OLDTROVE]         = true,
		[Harvest.JUSTICE]         = true,
	},

	isZoneSavedOnImport = {
		["alikr"]        = true,     --Alik'r Desert
		["auridon"]      = true,     --Auridon, Khenarthi's Roost
		["bangkorai"]    = true,     --Bangkorai
		["coldharbor"]   = true,     --Coldharbour
		["craglorn"]     = true,     --Craglorn
		["cyrodiil"]     = true,     --Cyrodiil
		["deshaan"]      = true,     --"Deshaan"
		["eastmarch"]    = true,     --Eastmarch
		["glenumbra"]    = true,     --Glenumbra, Betnikh, Stros M'Kai
		["grahtwood"]    = true,     --Grahtwood
		["greenshade"]   = true,     --Greenshade
		["malabaltor"]   = true,     --Malabal Tor
		["reapersmarch"] = true,     --Reaper's March
		["rivenspire"]   = true,     --Rivenspire
		["shadowfen"]    = true,     --Shadowfen
		["stonefalls"]   = true,     --Stonefalls, Bal Foyen, Bleakrock Isle
		["stormhaven"]   = true,     --Stormhaven
		["therift"]      = true,     --The Rift
		["wrothgar"]     = true,
		["thievesguild"] = true, --hew's bane
		["darkbrotherhood"] = true,
	},

	mapLayouts = {
		[Harvest.BLACKSMITH]  = { level = 20, texture = "HarvestMap/Textures/Map/mining.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.CLOTHING] 	  = { level = 20, texture = "HarvestMap/Textures/Map/clothing.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.ENCHANTING]  = { level = 20, texture = "HarvestMap/Textures/Map/enchanting.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.ALCHEMY] 	  = { level = 20, texture = "HarvestMap/Textures/Map/alchemy.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.WOODWORKING] = { level = 20, texture = "HarvestMap/Textures/Map/wood.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.CHESTS]      = { level = 20, texture = "HarvestMap/Textures/Map/chest.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.WATER]       = { level = 20, texture = "HarvestMap/Textures/Map/solvent.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.FISHING]     = { level = 20, texture = "HarvestMap/Textures/Map/fish.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.HEAVYSACK]     = { level = 20, texture = "HarvestMap/Textures/Map/heavysack.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.TROVE]      = { level = 20, texture = "HarvestMap/Textures/Map/trove.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.OLDTROVE]      = { level = 20, texture = "HarvestMap/Textures/Map/trove.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.JUSTICE]      = { level = 20, texture = "HarvestMap/Textures/Map/justice.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.TOUR]      = { level = 25, texture = "HarvestMap/Textures/Map/tour.dds", size = 32, tint = ZO_ColorDef:New(1, 0, 0, 1) },
	},

	compassLayouts = {
		[Harvest.BLACKSMITH]  = {texture = "HarvestMap/Textures/Compass/mining.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.CLOTHING]    = {texture = "HarvestMap/Textures/Compass/clothing.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.ENCHANTING]  = {texture = "HarvestMap/Textures/Compass/enchanting.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.ALCHEMY]     = {texture = "HarvestMap/Textures/Compass/alchemy.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.WOODWORKING] = {texture = "HarvestMap/Textures/Compass/wood.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.CHESTS]      = {texture = "HarvestMap/Textures/Compass/chest.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.WATER]       = {texture = "HarvestMap/Textures/Compass/solvent.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.FISHING]     = {texture = "HarvestMap/Textures/Compass/fish.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.HEAVYSACK]     = {texture = "HarvestMap/Textures/Compass/heavysack.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.TROVE]      = {texture = "HarvestMap/Textures/Compass/trove.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.OLDTROVE]      = {texture = "HarvestMap/Textures/Compass/trove.dds", maxDistance = 0.04, color = {1, 1, 1}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
		[Harvest.JUSTICE]      = { level = 20, texture = "HarvestMap/Textures/Map/justice.dds", size = 20, tint = ZO_ColorDef:New(1, 1, 1, 1) },
		[Harvest.TOUR]      = {texture = "HarvestMap/Textures/Compass/tour.dds", maxDistance = 1, color = {1, 0, 0}, additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset} },
	},

	isCompassVisible = true,
	minDistanceBetweenPins = 0.000049, -- 0.000049 or 0.007^2
	debug = false,
	verbose = false,
	hiddenTime = 0,
	showExactItems = false,
	hiddenOnHarvest = false,
	hideArrow = false,
	hideFarmingInterface = false,
}