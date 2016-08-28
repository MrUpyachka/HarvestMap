HarvestEP = {}
HarvestEP.dataVersion = 13
HarvestEP.dataDefault = {
	data = {},
	dataVersion = HarvestEP.dataVersion
}

HarvestEP.zones = {
	["stonefalls"] = true,
	["deshaan"] = true,
	["shadowfen"] = true,
	["eastmarch"] = true,
	["therift"] = true
}

function HarvestEP.GetCurrentTimestamp()
	-- data is saved as string, to prevent the save file from bloating up, reduce the stamp to hours
	return zo_floor(GetTimeStamp() / 3600)
end

function HarvestEP.OnLoad(eventCode, addOnName)
	if addOnName ~= "HarvestMapEP" then
		return
	end

	HarvestEP.savedVars = ZO_SavedVars:NewAccountWide("HarvestEP_SavedVars", 1, "nodes", HarvestEP.dataDefault)
	if not HarvestEP.savedVars.firstLoaded then
		HarvestEP.savedVars.firstLoaded = HarvestEP.GetCurrentTimestamp()
	end
	HarvestEP.savedVars.lastLoaded = HarvestEP.GetCurrentTimestamp()
end

EVENT_MANAGER:RegisterForEvent("HarvestMap-EP-Zones", EVENT_ADD_ON_LOADED, HarvestEP.OnLoad)
