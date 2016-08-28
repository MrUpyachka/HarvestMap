HarvestDC = {}
HarvestDC.dataVersion = 13
HarvestDC.dataDefault = {
	data = {},
	dataVersion = HarvestDC.dataVersion
}

HarvestDC.zones = {
	["glenumbra"] = true,
	["stormhaven"] = true,
	["rivenspire"] = true,
	["alikr"] = true,
	["bangkorai"] = true
}

function HarvestDC.GetCurrentTimestamp()
	-- data is saved as string, to prevent the save file from bloating up, reduce the stamp to hours
	return zo_floor(GetTimeStamp() / 3600)
end

function HarvestDC.OnLoad(eventCode, addOnName)
	if addOnName ~= "HarvestMapDC" then
		return
	end

	HarvestDC.savedVars = ZO_SavedVars:NewAccountWide("HarvestDC_SavedVars", 1, "nodes", HarvestDC.dataDefault)
	if not HarvestDC.savedVars.firstLoaded then
		HarvestDC.savedVars.firstLoaded = HarvestDC.GetCurrentTimestamp()
	end
	HarvestDC.savedVars.lastLoaded = HarvestDC.GetCurrentTimestamp()
end

EVENT_MANAGER:RegisterForEvent("HarvestMap-DC-Zones", EVENT_ADD_ON_LOADED, HarvestDC.OnLoad)
