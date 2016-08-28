HarvestAD = {}
HarvestAD.dataVersion = 13
HarvestAD.dataDefault = {
	data = {},
	dataVersion = HarvestAD.dataVersion
}

HarvestAD.zones = {
	["auridon"] = true,
	["grahtwood"] = true,
	["greenshade"] = true,
	["malabaltor"] = true,
	["reapersmarch"] = true
}

function HarvestAD.GetCurrentTimestamp()
	-- data is saved as string, to prevent the save file from bloating up, reduce the stamp to hours
	return zo_floor(GetTimeStamp() / 3600)
end

function HarvestAD.OnLoad(eventCode, addOnName)
	if addOnName ~= "HarvestMapAD" then
		return
	end

	HarvestAD.savedVars = ZO_SavedVars:NewAccountWide("HarvestAD_SavedVars", 1, "nodes", HarvestAD.dataDefault)
	if not HarvestAD.savedVars.firstLoaded then
		HarvestAD.savedVars.firstLoaded = HarvestAD.GetCurrentTimestamp()
	end
	HarvestAD.savedVars.lastLoaded = HarvestAD.GetCurrentTimestamp()
end

EVENT_MANAGER:RegisterForEvent("HarvestMap-AD-Zones", EVENT_ADD_ON_LOADED, HarvestAD.OnLoad)
