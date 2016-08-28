
local function CreateImportFilter( pinTypeId )

	local pinTypeId = pinTypeId

	local importFilter = {
		type = "checkbox",
		name = Harvest.GetLocalization( "pintype" .. pinTypeId ),
		getFunc = function()
			return Harvest.IsPinTypeSavedOnImport( pinTypeId )
		end,
		setFunc = function( value )
			Harvest.SetPinTypeSavedOnImport( pinTypeId, value )
		end,
		default = Harvest.defaultSettings.isPinTypeSavedOnImport[ pinTypeId ],
		width = "half"
	}

	return importFilter

end

local function CreateZoneImportFilter( zone )

	local zone = zone

	local importFilter = {
		type = "checkbox",
		name = HarvestImport.GetLocalizedZone( zone ),
		getFunc = function()
			return Harvest.IsZoneSavedOnImport( zone )
		end,
		setFunc = function( value )
			Harvest.SetZoneSavedOnImport( zone, value )
		end,
		default = Harvest.defaultSettings.isZoneSavedOnImport[ zone ],
		width = "half"
	}

	return importFilter

end

function HarvestImport.InitializeImportOptions()
	local panelData = {
		type = "panel",
		name = "HarvestMap-Import",
		displayName = ZO_HIGHLIGHT_TEXT:Colorize("HarvestMap-Import"),
		author = Harvest.author,
		version = Harvest.displayVersion,
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local optionsTable = setmetatable({}, { __index = table })

	optionsTable:insert({
		type = "button",
		name = "Export",
		--tooltip = "Button's tooltip text.",
		func = HarvestImport.Export,
		width = "half",	--or "half" (optional)
		--warning = "Will need to reload the UI.",	--(optional)
	})

	optionsTable:insert({
		type = "description",
		--title = "My Title",	--(optional)
		title = nil,	--(optional)
		text = "Exports all your discovered pins into SavedVariables/HarvestMapImport.lua\nAfter the loading screen you can send this file to another player.",
		width = "full",	--or "half" (optional)
	})

	optionsTable:insert({
		type = "button",
		name = "Import",
		--tooltip = "Button's tooltip text.",
		func = HarvestImport.Import,
		width = "half",	--or "half" (optional)
		--warning = "Will need to reload the UI.",	--(optional)
	})
	
	optionsTable:insert({
		type = "description",
		--title = "My Title",	--(optional)
		title = nil,	--(optional)
		text = "Imports data found in SavedVariables/HarvestMapImport.lua\nNote that if you want to import multiple files, you have to be logged out when replacing the file with another one.",
		width = "full",	--or "half" (optional)
	})

	optionsTable:insert({
		type = "header",
		name = "Pin Type Settings",
	})

	optionsTable:insert({
		type = "description",
		--title = "My Title",	--(optional)
		title = nil,	--(optional)
		text = "Here you can select which pin types are imported.",
		width = "full",	--or "half" (optional)
	})

	 for _, pinTypeId in pairs( Harvest.PINTYPES ) do
		 if pinTypeId ~= Harvest.TOUR then
			 optionsTable:insert( CreateImportFilter( pinTypeId ) )
		 end
	 end

	optionsTable:insert({
		type = "header",
		name = "Zone Settings",
	})

	optionsTable:insert({
		type = "description",
		--title = "My Title",	--(optional)
		title = nil,	--(optional)
		text = "Here you can select which zone's data are imported.",
		width = "full",	--or "half" (optional)
	})

	for zone in pairs( Harvest.savedVars["settings"].isZoneSavedOnImport ) do
		optionsTable:insert( CreateZoneImportFilter( zone ) )
	end

	local LAM = LibStub("LibAddonMenu-2.0")
	LAM:RegisterAddonPanel("HarvestMapImportControl", panelData)
	LAM:RegisterOptionControls("HarvestMapImportControl", optionsTable)

end
