local LMP = LibStub("LibMapPins-1.0")
local COMPASS_PINS = LibStub("CustomCompassPins")

if not Harvest then
	Harvest = {}
end

function Harvest.GetMaxCachedMaps()
	return Harvest.savedVars["settings"].maxCachedMaps
end

function Harvest.SetMaxCachedMaps( num )
	Harvest.savedVars["settings"].maxCachedMaps = num
end

function Harvest.GetGlobalMinDistanceBetweenPins()
	-- delves tend to be scaled down on the zone map, so we need to return a smaller value
	--if mapType == MAP_CONTENT_DUNGEON and measurement.scaleX < 0.003 then
	--	return 1e-9
	--end

	-- about 10m in tamriel map squared distance (only on zone/city maps)
	return 1.65e-7
end

function Harvest.IsFarmingInterfaceHidden()
	return Harvest.savedVars["settings"].hideFarmingInterface
end

function Harvest.SetFarmingInterfaceHidden( value )
	Harvest.savedVars["settings"].hideFarmingInterface = value
	if value then
		HarvestFarmCompass:SetHidden(true)
	end
end

function Harvest.IsArrowHidden()
	return Harvest.savedVars["settings"].hideArrow
end

function Harvest.SetArrowHidden( value )
	Harvest.savedVars["settings"].hideArrow = value
	if value then
		HarvestFarmCompassArrow:SetHidden(true)
	end
end

function Harvest.ArePinsAbovePOI()
	return (Harvest.savedVars["settings"].mapLayouts[1].level > 50)
end

function Harvest.SetPinsAbovePOI( value )
	local level = 20
	if value then
		level = 55
	end
	for pinTypeId, layout in pairs(Harvest.savedVars["settings"].mapLayouts) do
		if pinTypeId == Harvest.TOUR then
			layout.level = level + 1
		else
			layout.level = level
		end
		LMP:RefreshPins( Harvest.GetPinType( pinTypeId ) )
	end
end

function Harvest.AreExactItemsShown()
	return Harvest.savedVars["settings"].showExactItems
end

function Harvest.SetShowExactItems( value )
	Harvest.savedVars["settings"].showExactItems = value
end

function Harvest.IsHiddenOnHarvest()
	return Harvest.savedVars["settings"].hiddenOnHarvest
end

function Harvest.SetHiddenOnHarvest( value )
	Harvest.savedVars["settings"].hiddenOnHarvest = value
end

function Harvest.GetHiddenTime()
	return Harvest.savedVars["settings"].hiddenTime
end

function Harvest.SetHiddenTime(value)
	Harvest.savedVars["settings"].hiddenTime = value
	if value == 0 then
		Harvest.RefreshPins()
	end
end

function Harvest.SetHeatmapActive( value )
	local prevValue = Harvest.savedVars["settings"].heatmap
	Harvest.savedVars["settings"].heatmap = value
	HarvestHeat.RefreshHeatmap()
	Harvest.RefreshPins()
	if value then
		HarvestHeat.Initialize()
	else
		HarvestHeat.HideTiles()
	end
end

function Harvest.IsHeatmapActive()
	return (Harvest.savedVars["settings"].heatmap == true)
end

function Harvest.GetDisplayedCompassDistance()
	return Harvest.savedVars["settings"].compassLayouts[1].maxDistance * 1000
end

function Harvest.SetDisplayedCompassDistance( value )
	Harvest.savedVars["settings"].compassLayouts[1].maxDistance = value / 1000.0
end

function Harvest.GetDisplayedFOV()
	local FOV = Harvest.savedVars["settings"].compassLayouts[1].FOV or COMPASS_PINS.defaultFOV
	return zo_round(360 *  FOV / (2 * math.pi))
end

function Harvest.SetDisplayedFOV( value )
	for _, pinType in pairs(Harvest.PINTYPES) do
		Harvest.savedVars["settings"].compassLayouts[ pinType ].FOV = 2 * value * math.pi / 360
	end
	COMPASS_PINS:RefreshPins()
end

function Harvest.AreSettingsAccountWide()
	return Harvest.savedVars["global"].accountWideSettings
end

function Harvest.SetSettingsAccountWide( value )
	Harvest.savedVars["global"].accountWideSettings = value
	ReloadUI("ingame")
end

local difference -- temporary variable to save the new max timedifference until the apply button is hit
function Harvest.ApplyTimeDifference()
	if difference then
		Harvest.savedVars["global"].maxTimeDifference = difference
		Harvest.cache = {}
		Harvest.RefreshPins()
	end
end

function Harvest.GetMaxTimeDifference()
	return Harvest.savedVars["global"].maxTimeDifference
end

function Harvest.GetDisplayedMaxTimeDifference()
	return difference or Harvest.savedVars["global"].maxTimeDifference
end

function Harvest.SetDisplayedMaxTimeDifference(value)
	difference = value
end

function Harvest.IsPinTypeSavedOnImport( pinTypeId )
	return not (Harvest.savedVars["settings"].isPinTypeSavedOnImport[ pinTypeId ] == false)
end

function Harvest.SetPinTypeSavedOnImport( pinTypeId, value )
	Harvest.savedVars["settings"].isPinTypeSavedOnImport[ pinTypeId ] = value
end

function Harvest.IsZoneSavedOnImport( zone )
	if Harvest.savedVars["settings"].isZoneSavedOnImport[ zone ] == nil then
		return true
	end
	return Harvest.savedVars["settings"].isZoneSavedOnImport[ zone ]
end

function Harvest.SetZoneSavedOnImport( zone, value )
	Harvest.savedVars["settings"].isZoneSavedOnImport[ zone ] = value
end

function Harvest.AreCompassPinsVisible()
	return Harvest.savedVars["settings"].isCompassVisible
end

function Harvest.SetCompassPinsVisible( value )
	Harvest.savedVars["settings"].isCompassVisible = value
	COMPASS_PINS:RefreshPins()
end

function Harvest.GetCompassLayouts()
	return Harvest.savedVars["settings"].compassLayouts
end

function Harvest.GetCompassPinLayout( pinTypeId )
	return Harvest.savedVars["settings"].compassLayouts[ pinTypeId ]
end

function Harvest.GetMapLayouts()
	return Harvest.savedVars["settings"].mapLayouts
end

function Harvest.GetMapPinLayout( pinTypeId )
	return Harvest.savedVars["settings"].mapLayouts[ pinTypeId ]
end

function Harvest.IsPinTypeVisible( pinTypeId )
	return Harvest.savedVars["settings"].isPinTypeVisible[ Harvest.GetPinType(pinTypeId) ]
end

function Harvest.IsPinTypeVisible_string( pinType )
	return Harvest.savedVars["settings"].isPinTypeVisible[ pinType ]
end

function Harvest.SetPinTypeVisible( pinTypeId, value )
	local pinType = Harvest.GetPinType( pinTypeId )
	Harvest.savedVars["settings"].isPinTypeVisible[ pinType ] = value
	LMP:SetEnabled( pinType, value )
	COMPASS_PINS:RefreshPins(Harvest.GetPinType( pinTypeId ))
	HarvestHeat.RefreshHeatmap()
end

function Harvest.IsDebugEnabled()
	return Harvest.savedVars["settings"].isPinTypeVisible[ Harvest.GetPinType( "Debug" ) ]
end

function Harvest.SetDebugEnabled( value )
	Harvest.savedVars["settings"].isPinTypeVisible[ Harvest.GetPinType( "Debug" ) ] = value
	LMP:SetEnabled(  Harvest.GetPinType( "Debug" ), value )
end

function Harvest.AreVerboseMessagesEnabled()
	return Harvest.savedVars["settings"].verbose
end

function Harvest.SetVerboseMessagesEnabled( value )
	Harvest.savedVars["settings"].verbose = value
end

function Harvest.AreDebugMessagesEnabled()
	return Harvest.savedVars["settings"].debug
end

function Harvest.SetDebugMessagesEnabled( value )
	Harvest.savedVars["settings"].debug = value
end

function Harvest.IsPinTypeSavedOnGather( pinTypeId )
	return not (Harvest.savedVars["settings"].isPinTypeSavedOnGather[ pinTypeId ] == false)
end

function Harvest.SetPinTypeSavedOnGather( pinTypeId, value )
	Harvest.savedVars["settings"].isPinTypeSavedOnGather[ pinTypeId ] = value
end

function Harvest.GetMinDistanceBetweenPins()
	return Harvest.defaultSettings.minDistanceBetweenPins
	--return Harvest.savedVars["settings"].minDistanceBetweenPins
end

function Harvest.GetDisplayedMinDistanceBetweenPins()
	return Harvest.savedVars["settings"].minDistanceBetweenPins * 1000000
end

function Harvest.SetDisplayedMinDistanceBetweenPins( value )
	Harvest.savedVars["settings"].minDistanceBetweenPins = value * 0.000001
end

function Harvest.GetMapPinSize( pinTypeId )
	return Harvest.savedVars["settings"].mapLayouts[ pinTypeId ].size
end

function Harvest.SetMapPinSize( pinTypeId, value )
	Harvest.savedVars["settings"].mapLayouts[ pinTypeId ].size = value
	LMP:SetLayoutKey( Harvest.GetPinType( pinTypeId ), "size", value )
	Harvest.RefreshPins( pinTypeId )
end

function Harvest.GetPinColor( pinTypeId )
	return Harvest.savedVars["settings"].mapLayouts[ pinTypeId ].tint:UnpackRGB()
end

function Harvest.SetPinColor( pinTypeId, r, g, b )
	Harvest.savedVars["settings"].mapLayouts[ pinTypeId ].tint:SetRGB( r, g, b )
	Harvest.savedVars["settings"].compassLayouts[ pinTypeId ].color = { r, g, b }
	LMP:GetLayoutKey( Harvest.GetPinType( pinTypeId ), "tint" ):SetRGB( r, g, b )
	Harvest.RefreshPins( pinTypeId )
end