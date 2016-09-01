local LMP = LibStub("LibMapPins-1.0")
local COMPASS_PINS = LibStub("CustomCompassPins")

if not Harvest then
	Harvest = {}
end
local Harvest = _G["Harvest"]
local HarvestDB = _G["HarvestDB"]
local pairs = _G["pairs"]

---
-- Function-adapter to invoke RefreshPins for all used pins controllers.
-- @param pinTypeId type ID of pins to refresh.
--
local function RefreshPinsInAllControllers(pinTypeId)
	local pinType = Harvest.GetPinType(pinTypeId)
	LMP:RefreshPins(pinType)
	COMPASS_PINS:RefreshPins(pinType)
end
---
-- Function-adapter to invoke pin deletion for all used pins controllers.
-- @param nodeTag identifier of the that that is to be removed on map and compass
-- @param pinTypeId type ID of pin.
--
local function RemovePinInAllControllers(nodeTag, pinTypeId)
	local pinType = Harvest.GetPinType(pinTypeId)
	LMP:RemoveCustomPin(pinType, nodeTag)
	COMPASS_PINS:RemovePin(nodeTag, pinType)
end

---
-- Function-adapter to invoke pin creation for all used pins controllers.
-- @param nodeTag identifier of the that that is to be dispalyed on map and compass
-- @param pinTypeId type ID of pin.
--
local function CreatePinInAllControllers(nodeTag, pinTypeId)
	local pinType = Harvest.GetPinType(pinTypeId)
	local x, y = HarvestDB.GetPosition(nodeTag)
	LMP:CreatePin(pinType, nodeTag, x, y)
	COMPASS_PINS:CreatePin(pinType, nodeTag, x, y)
end

local function CreatePinOnMap(nodeTag, pinTypeId)
	local pinType = Harvest.GetPinType(pinTypeId)
	local x, y = HarvestDB.GetPosition(nodeTag)
	LMP:CreatePin(pinType, nodeTag, x, y)
end

---
-- Checks any configured map addons.
-- @return true if any minimap addon detected, false in opposite case.
local function isMapAddonCompatibilityRequired()
	-- TODO Other addons
	if AUI and AUI.Minimap or FyrMM then
		return true
	end
end

local function nodeCreatedOrUpdated(event, nodeTag, pinTypeId)
	local nodeAdded = (event == Harvest.NODECREATED)
	local nodeUpdated = (event == Harvest.NODEUPDATED)

	if Harvest.IsHeatmapActive() then
		HarvestHeat.RefreshHeatmap()
		return
	end

	if isMapAddonCompatibilityRequired() then
		if (nodeAdded or nodeUpdated)  then
			-- compatibility with minimap plugins means that we always need to refresh all pins on each update.
			-- TODO remove direct calls of refreshPins.
			Harvest.RefreshPins( pinTypeId )
		end
	else
		-- no addon is used, so we can refresh a single pin by removing and recreating it
		if nodeUpdated then
			RemovePinInAllControllers(nodeTag, pinTypeId)
		end
		-- the (re-)creation of the pin is only performed, if it wasn't hidden by the respawn timer
		if Harvest.IsHiddenOnHarvest() then
			Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinTypeId) )
			HarvestDB.SetHidden(nodeTag, true)
		else
			HarvestDB.SetHidden(nodeTag, false)
			CreatePinInAllControllers(nodeTag, pinTypeId)
		end
	end
end

-- harvestmap will hide recently visited pins for a given respawn time (time is set in the options)
function Harvest.UpdateHiddenTime(nodeTag, pinTypeId)
	local hidden = HarvestDB.IsHidden(nodeTag)
	if not hidden then
		HarvestDB.SetHidden(nodeTag, true)
		Harvest.FireEvent(Harvest.NODEHIDDEN, nodeTag)
		Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinTypeId) )
		RemovePinInAllControllers(pinTypeId, nodeTag)
	end
end

-- refreshes the pins of the given pinType
-- if no pinType is given, all pins are refreshed
function Harvest.RefreshPins( pinTypeId )
	-- refresh all pins if no pin type was given
	if not pinTypeId then
		for _, pinTypeId in pairs(Harvest.PINTYPES ) do
			RefreshPinsInAllControllers(pinTypeId)
		end
		return
	end
	-- refresh only the pins of the given pin type
	if Harvest.contains( Harvest.PINTYPES, pinTypeId ) then
		RefreshPinsInAllControllers(pinTypeId)
	end
end

function Harvest.UpdateMapPins( timeInMs )
	if not Harvest.IsUpdateQueueEmpty() then
		return
	end
	if Harvest.IsHeatmapActive() then
		return
	end

	-- update the respawn timer feature, if it hides pins close to the player
	if Harvest.GetHiddenTime() > 0 and not Harvest.IsHiddenOnHarvest() then
		local map, x, y, measurement = Harvest.GetLocation(true)
		HarvestDB.ForCloseNodes(map, x, y, measurement, Harvest.UpdateHiddenTime)
	end

	if Harvest.HasPinVisibleDistance() then
		-- update the currently visible pins, if the limited view radius is enabled in the options
		if Harvest.lastViewedUpdate < timeInMs - 5000 and Harvest.HasPinVisibleDistance() then
			local map, x, y, measurement = Harvest.GetLocation( true )

			for _, pinTypeId in pairs(Harvest.PINTYPES) do
				if Harvest.IsPinTypeVisible( pinTypeId ) then
					HarvestDB.ForPrevAndCurVisiblePinsOfPinType(map, Harvest.lastViewedX, Harvest.lastViewedY, x, y,
						measurement, pinTypeId, RemovePinInAllControllers, CreatePinInAllControllers)
				end
			end

			Harvest.lastViewedX = x
			Harvest.lastViewedY = y
			Harvest.lastViewedUpdate = timeInMs
		end
	else
		if not Harvest.mapPinIterators then return end
		local numSteps = Harvest.GetDisplaySpeed()
		local empty = true
		for pinTypeId, iterator in pairs(Harvest.mapPinIterators) do
			if Harvest.IsPinTypeVisible( pinTypeId ) then
				if iterator:run(numSteps, CreatePinOnMap) then
					Harvest.mapPinIterators[pinTypeId] = nil
				else
					empty = false
				end
			else
				Harvest.mapPinIterators[pinTypeId] = nil
			end

		end

		if empty then
			Harvest.mapPinIterators = nil
		end
	end
end

function Harvest.PinTypeRefreshCallback( pinTypeId )
	-- data is still being manipulated, better if we don't access it yet
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.Debug("step1: your data is still being refactored/updated" )
		if Harvest.mapPinIterators then
			Harvest.mapPinIterators[pinTypeId] = nil
		end
		return
	end

	Harvest.Debug("Refresh pins for pin type id " .. tostring(pinTypeId) )
	if not Harvest.IsPinTypeVisible( pinTypeId ) or Harvest.IsHeatmapActive() then
		Harvest.Debug("step1: pins type is hidden or heatmap mode is active" )
		if Harvest.mapPinIterators then
			Harvest.mapPinIterators[pinTypeId] = nil
		end
		return
	end


	local map, x, y, measurement = Harvest.GetLocation( true )
	Harvest.lastViewedX = x
	Harvest.lastViewedY = y

	local pinType = Harvest.GetPinType( pinTypeId )
	local pinData = LMP.pinManager.customPins[_G[pinType]]
	if not FyrMM then -- remove pins to fix the wayshrine bug (3.0.2)
	-- but with fyrmm this somehow results in missing map pins
	-- see comment section 11/13/15, 08:57 PM 
		LMP.pinManager:RemovePins(pinData.pinTypeString)
	end

	if Harvest.HasPinVisibleDistance() then
		HarvestDB.ForVisibleNodesOfPinType(map, x, y, measurement, pinTypeId, CreatePinOnMap)
	else
		local iterator = HarvestDB.IteratorForVisibleNodesOfPinType(map, x, y, measurement, pinTypeId)
		Harvest.mapPinIterators = Harvest.mapPinIterators or {}
		Harvest.mapPinIterators[pinTypeId] = iterator
	end
end

Harvest.tooltipCreator = {
	creator = function( pin )
		local lines = Harvest.GetLocalizedTooltip( pin )
		for _, line in ipairs(lines) do
			InformationTooltip:AddLine( line )
		end
	end,
	tooltip = 1
}

function Harvest.InitializeMapPinType( pinTypeId )
	local pinType = Harvest.GetPinType( pinTypeId )
	
	if pinTypeId == Harvest.TOUR then
		LMP:AddPinType(
			pinType,
			HarvestFarm.MapCallback,
			nil,
			Harvest.GetMapPinLayout( pinTypeId ),
			Harvest.tooltipCreator
		)
	else
		LMP:AddPinType(
			pinType,
			function( g_mapPinManager )
				Harvest.PinTypeRefreshCallback( pinTypeId )
			end,
			nil,
			Harvest.GetMapPinLayout( pinTypeId ),
			Harvest.tooltipCreator
		)

		local pve, pvp, imperial = LMP:AddPinFilter(
			pinType,
			Harvest.GetLocalization( "pintype" .. pinTypeId ),
			false,
			Harvest.savedVars["settings"].isPinTypeVisible
		)
		local fun = function(button, state)
			Harvest.SetPinTypeVisible( pinTypeId, state )
		end
		ZO_CheckButton_SetToggleFunction(pve, fun)
		ZO_CheckButton_SetToggleFunction(pvp, fun)
		ZO_CheckButton_SetToggleFunction(imperial, fun)
	end
end

local nameFun = function( pin )
	local lines = Harvest.GetLocalizedTooltip( pin )
	return table.concat(lines, "\n") 
end

Harvest.debugHandler = {
	{
		name = nameFun,
		callback = function(pin)
			if not Harvest.IsDebugEnabled() or IsInGamepadPreferredMode() then
				for _,pinTypeId in pairs( Harvest.PINTYPES ) do
					local pinType = Harvest.GetPinType( pinTypeId )
					LMP:SetClickHandlers(pinType, nil, nil)
				end
				return
			end
			local pinType, pinTag = pin:GetPinTypeAndTag()
			local map = Harvest.GetMap()
			HarvestDB.DeleteNode(map, pinTag)
		end,
		show = function() return true end,
		duplicates = function(pin1, pin2) return not Harvest.IsDebugEnabled() end,
		gamepadName = nameFun
	}
}

function Harvest.InitializeMapMarkers()
	EVENT_MANAGER:RegisterForUpdate("HarvestMapMakers", 200, Harvest.UpdateMapPins)
	Harvest.RegisterForEvent(Harvest.NODECREATED, nodeCreatedOrUpdated)
	Harvest.RegisterForEvent(Harvest.NODEUPDATED, nodeCreatedOrUpdated)

	Harvest.pinIterators = {}

	Harvest.lastViewedX = -10
	Harvest.lastViewedY = -10
	Harvest.lastViewedUpdate = 0

	for index, pinTypeId in pairs( Harvest.PINTYPES ) do
		Harvest.InitializeMapPinType( pinTypeId )
	end

	Harvest.RegisterForEvent(Harvest.NODEDELETED, function(event, nodeTag, pinTypeId)
		RemovePinInAllControllers(nodeTag, pinTypeId)
	end)

	LMP:AddPinType(
		Harvest.GetPinType( "Debug" ),
		function( g_mapPinManager ) --gets called when debug is enabled
			if IsInGamepadPreferredMode() then
				for _, pinTypeId in pairs( Harvest.PINTYPES ) do
					local pinType = Harvest.GetPinType( pinTypeId )
					LMP:SetClickHandlers(pinType, nil, nil)
				end
				return
			end
			for _, pinTypeId in pairs( Harvest.PINTYPES ) do
				local pinType = Harvest.GetPinType( pinTypeId )
				LMP:SetClickHandlers(pinType, Harvest.debugHandler, nil)
			end
		end,
		nil,
		Harvest.GetMapPinLayout( 1 ),
		Harvest.tooltipCreator
	)
	-- debug pin type. when enabled clicking on pins deletes them
	LMP:AddPinFilter(
		Harvest.GetPinType( "Debug" ),
		Harvest.GetLocalization( "deletepinfilter" ),
		false,
		Harvest.savedVars["settings"].isPinTypeVisible
	)

end
