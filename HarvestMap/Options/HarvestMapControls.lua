local LAM = LibStub("LibAddonMenu-2.0")
local COMPASS_PINS = LibStub("CustomCompassPins")

local function CreateFilter( pinTypeId )
	local pinTypeId = pinTypeId
	local filter = {
		type = "checkbox",
		name = Harvest.GetLocalization( "pintype" .. pinTypeId ),
		tooltip = Harvest.GetLocalization( "pintypetooltip" .. pinTypeId ),
		getFunc = function()
			return Harvest.IsPinTypeVisible( pinTypeId )
		end,
		setFunc = function( value )
			Harvest.SetPinTypeVisible( pinTypeId, value )
		end,
		default = Harvest.defaultSettings.isPinTypeVisible[ pinTypeId ],
	}
	return filter
end

local function CreateGatherFilter( pinTypeId )
	local pinTypeId = pinTypeId
	local gatherFilter = {
		type = "checkbox",
		name = zo_strformat( Harvest.GetLocalization( "savepin" ), Harvest.GetLocalization( "pintype" .. pinTypeId ) ),
		tooltip = Harvest.GetLocalization( "savetooltip" ),
		getFunc = function()
			return Harvest.IsPinTypeSavedOnGather( pinTypeId )
		end,
		setFunc = function( value )
			Harvest.SetPinTypeSavedOnGather( pinTypeId, value )
		end,
		default = Harvest.defaultSettings.isPinTypeSavedOnGather[ pinTypeId ],
	}
	return gatherFilter
end

local function CreateSizeSlider( pinTypeId )
	local pinTypeId = pinTypeId
	local sizeSlider = {
		type = "slider",
		name = Harvest.GetLocalization( "pinsize" ),
		tooltip =  zo_strformat( Harvest.GetLocalization( "pinsizetooltip" ), Harvest.GetLocalization( "pintype" .. pinTypeId ) ),
		min = 16,
		max = 64,
		getFunc = function()
			return Harvest.GetMapPinSize( pinTypeId )
		end,
		setFunc = function( value )
			Harvest.SetMapPinSize( pinTypeId, value )
		end,
		default = Harvest.defaultSettings.mapLayouts[ pinTypeId ].size,
	}
	return sizeSlider
end

local function CreateColorPicker( pinTypeId )
	local pinTypeId = pinTypeId
	local colorPicker = {
		type = "colorpicker",
		name = Harvest.GetLocalization( "pincolor" ),
		tooltip = zo_strformat( Harvest.GetLocalization( "pincolortooltip" ), Harvest.GetLocalization( "pintype" .. pinTypeId ) ),
		getFunc = function() return Harvest.GetPinColor( pinTypeId ) end,
		setFunc = function( r, g, b ) Harvest.SetPinColor( pinTypeId, r, g, b ) end,
		default = Harvest.defaultSettings.mapLayouts[ pinTypeId ].tint,
	}
	return colorPicker
end

function Harvest.InitializeOptions()
	-- first LAM stuff, at the end of this function we will also create
	-- a custom checkbox in the map's filter menu for the heat map
	local panelData = {
		type = "panel",
		name = "HarvestMap",
		displayName = ZO_HIGHLIGHT_TEXT:Colorize("HarvestMap"),
		author = Harvest.author,
		version = Harvest.displayVersion,
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local optionsTable = setmetatable({}, { __index = table })
	
	if RequestOpenUnsafeURL then
		-- if the new URL feature exists (added in API version 16)
		optionsTable:insert({
			type = "description",
			title = nil,
			text = Harvest.GetLocalization("esouidescription"),
			width = "full",
		})
		
		optionsTable:insert({
			type = "button",
			name = Harvest.GetLocalization("openesoui"),
			func = function() RequestOpenUnsafeURL("http://www.esoui.com/downloads/info57") end,
			width = "half",
		})
		
		optionsTable:insert({
			type = "description",
			title = nil,
			text = Harvest.GetLocalization("mergedescription"),
			width = "full",
		})
		
		optionsTable:insert({
			type = "button",
			name = Harvest.GetLocalization("openmerge"),
			func = function() RequestOpenUnsafeURL("http://www.teso-harvest-merge.de") end,
			width = "half",
		})
		
		optionsTable:insert({
		type = "header",
		name = "",
	})
	end
	
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("timedifference"),
		tooltip = Harvest.GetLocalization("timedifferencetooltip"),
		warning = Harvest.GetLocalization("timedifferencewarning"),
		min = 0,
		max = 712,
		getFunc = function()
			return Harvest.GetDisplayedMaxTimeDifference() / 24
		end,
		setFunc = function( value )
			Harvest.SetDisplayedMaxTimeDifference(value * 24)
		end,
		width = "half",
		default = 0,
	})
	
	optionsTable:insert({
		type = "button",
		name = Harvest.GetLocalization("apply"),
		func = Harvest.ApplyTimeDifference,
		width = "half",
		warning = Harvest.GetLocalization("applywarning")
	})
	
	optionsTable:insert({
		type = "header",
		name = "",
	})

	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("account"),
		tooltip = Harvest.GetLocalization("accounttooltip"),
		getFunc = Harvest.AreSettingsAccountWide,
		setFunc = Harvest.SetSettingsAccountWide,
		width = "full",
		warning = Harvest.GetLocalization("accountwarning"),
	})
	
	optionsTable:insert({
		type = "header",
		name = "",
	})
	
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("maxcachedmaps"),
		tooltip = Harvest.GetLocalization("maxcachedmapstooltip"),
		--warning = Harvest.GetLocalizedHiddenTimeWarning(),
		min = 2,
		max = 10,
		getFunc = Harvest.GetMaxCachedMaps,
		setFunc = Harvest.SetMaxCachedMaps,
		default = Harvest.defaultSettings.maxCachedMaps,
	})
	
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("hasdrawdistance"),
		tooltip = Harvest.GetLocalization("hasdrawdistancetooltip"),
		getFunc = Harvest.HasPinVisibleDistance,
		setFunc = Harvest.SetHasPinVisibleDistance,
		default = Harvest.defaultSettings.hasMaxVisibleDistance,
		width = "half",
	})

	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("drawdistance"),
		tooltip = Harvest.GetLocalization("drawdistancetooltip"),
		--warning = Harvest.GetLocalizedHiddenTimeWarning(),
		min = 20,
		max = 250,
		getFunc = Harvest.GetDisplayPinVisibleDistance,
		setFunc = Harvest.SetPinVisibleDistance,
		default = 0,
		width = "half",
	})

	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("drawspeed"),
		tooltip = Harvest.GetLocalization("drawspeedtooltip"),
		--warning = Harvest.GetLocalizedHiddenTimeWarning(),
		min = 10,
		max = 500,
		getFunc = Harvest.GetDisplaySpeed,
		setFunc = Harvest.SetDisplaySpeed,
		default = Harvest.defaultSettings.displaySpeed,
	})
	
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("hiddentime"),
		tooltip = Harvest.GetLocalization("hiddentimetooltip"),
		warning = Harvest.GetLocalization("hiddentimewarning"),
		min = 0,
		max = 30,
		getFunc = Harvest.GetHiddenTime,
		setFunc = Harvest.SetHiddenTime,
		default = 0,
	})
	
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("hiddenonharvest"),
		tooltip = Harvest.GetLocalization("hiddenonharvesttooltip"),
		getFunc = Harvest.IsHiddenOnHarvest,
		setFunc = Harvest.SetHiddenOnHarvest,
		default = Harvest.defaultSettings.hiddenOnHarvest,
	})
	
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("exactitem"),
		tooltip = Harvest.GetLocalization("exactitemtooltip"),
		getFunc = Harvest.AreExactItemsShown,
		setFunc = Harvest.SetShowExactItems,
		default = Harvest.defaultSettings.showExactItems,
	})
	--[[
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalizedMinDistance(),
		tooltip = Harvest.GetLocalizedMinDistanceTooltip(),
		min = 25,
		max = 100,
		getFunc = Harvest.GetDisplayedMinDistanceBetweenPins,
		setFunc = Harvest.SetDisplayedMinDistanceBetweenPins,
		default = Harvest.defaultSettings.minDistanceBetweenPins * 1000000,
	})
	--]]
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("level"),
		tooltip = Harvest.GetLocalization("leveltooltip"),
		getFunc = Harvest.ArePinsAbovePOI,
		setFunc = Harvest.SetPinsAbovePOI,
		default = (Harvest.defaultSettings.mapLayouts[1].level > 50),
	})
	
	optionsTable:insert({
		type = "header",
		name = Harvest.GetLocalization("compassoptions"),
	})
	
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization("compass"),
		tooltip = Harvest.GetLocalization("compasstooltip"),
		getFunc = Harvest.AreCompassPinsVisible,
		setFunc = Harvest.SetCompassPinsVisible,
		default = Harvest.defaultSettings.isCompassVisible,
	})
	
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("fov"),
		tooltip = Harvest.GetLocalization("fovtooltip"),
		min = 90,
		max = 360,
		getFunc = Harvest.GetDisplayedFOV,
		setFunc = Harvest.SetDisplayedFOV,
		default = 100 * COMPASS_PINS.defaultFOV / (2 * math.pi)
	})
	
	optionsTable:insert({
		type = "slider",
		name = Harvest.GetLocalization("distance"),
		tooltip = Harvest.GetLocalization("distancetooltip"),
		min = 20,
		max = 500,
		getFunc = Harvest.GetDisplayedCompassDistance,
		setFunc = Harvest.SetDisplayedCompassDistance,
		default = Harvest.defaultSettings.compassLayouts[1].maxDistance * 1000
	})
	
	for _, pinTypeId in pairs( Harvest.PINTYPES ) do
		if pinTypeId ~= Harvest.TOUR then
			optionsTable:insert({
				type = "header",
				name = zo_strformat( Harvest.GetLocalization( "options" ), Harvest.GetLocalization( "pintype" .. pinTypeId ) )
			})
			optionsTable:insert( CreateFilter( pinTypeId ) )
			--optionsTable:insert( CreateImportFilter( pinTypeId ) ) -- moved to the HarvestImport folder
			optionsTable:insert( CreateGatherFilter( pinTypeId ) )
			optionsTable:insert( CreateSizeSlider( pinTypeId ) )
			optionsTable:insert( CreateColorPicker( pinTypeId ) )
		end
	end
	
	optionsTable:insert({
		type = "header",
		name = "Debug",
	})
	
	optionsTable:insert({
		type = "checkbox",
		name = Harvest.GetLocalization( "debug" ),
		tooltip = Harvest.GetLocalization( "debugtooltip" ),
		getFunc = Harvest.AreDebugMessagesEnabled,
		setFunc = Harvest.SetDebugMessagesEnabled,
		default = Harvest.defaultSettings.debug,
	})
	
	LAM:RegisterAddonPanel("HarvestMapControl", panelData)
	LAM:RegisterOptionControls("HarvestMapControl", optionsTable)
	
	-- heat map check box in the map's filter menu:
	-- code based on LibMapPin, see Libs/LibMapPin-1.0/LibMapPins-1.0.lua for credits
	local function AddCheckbox(panel, pinCheckboxText)
		local checkbox = panel.checkBoxPool:AcquireObject()
		ZO_CheckButton_SetLabelText(checkbox, pinCheckboxText)
		panel:AnchorControl(checkbox)
		return checkbox
	end

	local pve = AddCheckbox(WORLD_MAP_FILTERS.pvePanel, Harvest.GetLocalization( "filterheatmap" ))
	local pvp = AddCheckbox(WORLD_MAP_FILTERS.pvpPanel, Harvest.GetLocalization( "filterheatmap" ))
	local imperialPvP = AddCheckbox(WORLD_MAP_FILTERS.imperialPvPPanel, Harvest.GetLocalization( "filterheatmap" ))
	local fun = function(button, state)
		Harvest.SetHeatmapActive(state)
	end
	ZO_CheckButton_SetToggleFunction(pve, fun)
	ZO_CheckButton_SetToggleFunction(pvp, fun)
	ZO_CheckButton_SetToggleFunction(imperialPvP, fun)

	local mapFilterType = GetMapFilterType()
	if mapFilterType == MAP_FILTER_TYPE_STANDARD then
		ZO_CheckButton_SetCheckState(pve, Harvest.IsHeatmapActive())
	elseif mapFilterType == MAP_FILTER_TYPE_AVA_CYRODIIL then
		ZO_CheckButton_SetCheckState(pvp, Harvest.IsHeatmapActive())
	elseif mapFilterType == MAP_FILTER_TYPE_AVA_IMPERIAL then
		ZO_CheckButton_SetCheckState(imperialPvP, Harvest.IsHeatmapActive())
	end
end
