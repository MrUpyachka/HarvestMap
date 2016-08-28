-- DO NOT COPY THIS FILE INTO YOUR SavedVariables FOLDER

HarvestImport = {}

function HarvestImport.Import()
	if not Harvest.IsUpdateQueueEmpty() then
		d("HarvestMap can not import right now.")
		return
	end

	local saveFile = nil
	for profileName, profile in pairs( HarvestImport_SavedVars ) do
		for accountName, characters in pairs( profile ) do
			saveFile = characters["$AccountWide"] or {}
			saveFile = saveFile["nodes"] or {}
			saveFile.data = saveFile.data or {}
			-- update the data as it may be from an older version
			d("HarvestMap will update the old data from account " .. accountName .. " before importing it.")
			Harvest.UpdateDataVersion( saveFile )
		end
		
		for accountName, characters in pairs( profile ) do
			saveFile = characters["$AccountWide"] or {}
			saveFile = saveFile["nodes"] or {}
			saveFile.data = saveFile.data or {}
			-- update the data as it may be from an older version
			d("HarvestMap will import data from account " .. accountName .. ".")
			HarvestImport.ImportData( saveFile )
		end
	end

end

function HarvestImport.ImportData( importSaveFile )
	for map, data in pairs( importSaveFile.data ) do
		local zone = string.gsub( map, "/.*$", "" )
		if Harvest.IsZoneSavedOnImport( zone) then
			local file = Harvest.GetSaveFile( map )
			if file ~= nil then
				Harvest.AddToUpdateQueue(function()
					Harvest.ImportFromMap( map, data, file, true )
					Harvest.cache[ map ] = nil
					--importSaveFile.data[ map ] = nil
					d("Importing data. " .. Harvest.GetQueuePercent() .. "%")
				end)
			end
		end
	end
end

function HarvestImport.Export()
	if not Harvest.IsUpdateQueueEmpty() then
		d("HarvestMap can not export right now.")
		return
	end

	local data = {["data"] = {}}
	Harvest.AddToUpdateQueue(function()
		HarvestImport.ExportData( data, Harvest.savedVars["nodes"] )
		data.dataVersion = Harvest.savedVars["nodes"].dataVersion
		d("Exporting data. " .. Harvest.GetQueuePercent() .. "%")
	end)
	if HarvestAD then
		Harvest.AddToUpdateQueue(function()
			HarvestImport.ExportData( data, Harvest.savedVars["ADnodes"] )
			d("Exporting data. " .. Harvest.GetQueuePercent() .. "%")
		end)
	end
	if HarvestEP then
		Harvest.AddToUpdateQueue(function()
			HarvestImport.ExportData( data, Harvest.savedVars["EPnodes"] )
			d("Exporting data. " .. Harvest.GetQueuePercent() .. "%")
		end)
	end
	if HarvestDC then
		Harvest.AddToUpdateQueue(function()
			HarvestImport.ExportData( data, Harvest.savedVars["DCnodes"] )
			d("Exporting data. " .. Harvest.GetQueuePercent() .. "%")
		end)
	end

	Harvest.AddToUpdateQueue(function()
		HarvestImport_SavedVars["Default"] = {["@exporteddata"]= {["$AccountWide"] = {["nodes"] = data}}}
		ReloadUI("ingame")
	end)
end

function HarvestImport.ExportData( targetData, saveFile )
	for map, data in pairs( saveFile.data ) do
		targetData.data[map] = data
	end
end

local function OnLoad(eventCode, addOnName)
	if addOnName ~= "HarvestMapImport" then
		return
	end

	HarvestImport.savedVars = ZO_SavedVars:New("HarvestImport_SavedVars", 1)

	HarvestImport.InitializeImportOptions()
end

EVENT_MANAGER:RegisterForEvent("HarvestMap-Import", EVENT_ADD_ON_LOADED, OnLoad)
