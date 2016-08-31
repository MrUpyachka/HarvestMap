local LMP = LibStub("LibMapPins-1.0")

if not Harvest then
	Harvest = {}
end
local Harvest = _G["Harvest"]
local pairs = _G["pairs"]

function Harvest.AddMapPinCallback( pinTypeId )
	-- data is still being manipulated, better if we don't access it yet
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.Debug("step1: your data is still being refactored/updated" )
		return
	end

	Harvest.Debug("Refresh pins for pin type id " .. tostring(pinTypeId) )
	if not Harvest.IsPinTypeVisible( pinTypeId ) or Harvest.IsHeatmapActive() then
		Harvest.Debug("step1: pins type is hidden or heatmap mode is active" )
		return
	end


	local map, x, y, measurement = Harvest.GetLocation( true )
	local pinType = Harvest.GetPinType( pinTypeId )
	local pinData = LMP.pinManager.customPins[_G[pinType]]
	if not FyrMM then -- remove pins to fix the wayshrine bug (3.0.2)
	-- but with fyrmm this somehow results in missing map pins
	-- see comment section 11/13/15, 08:57 PM 
		LMP.pinManager:RemovePins(pinData.pinTypeString)
	end

	local iterator = HarvestDB.IteratorForVisibleNodesOfPinType(map, x, y, measurement, pinTypeId)
	local callback = function(nodeTag)
		local x, y = HarvestDB.GetPosition(nodeTag)
		LMP:CreatePin( pinType, nodeTag, x, y )
	end
	EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinType" .. pinTypeId)
	EVENT_MANAGER:RegisterForUpdate("HarvestMapPinType" .. pinTypeId, 200,
		function()
			if not Harvest.IsPinTypeVisible( pinTypeId ) or Harvest.IsHeatmapActive() then
				Harvest.Debug("step1: pins type is hidden or heatmap mode is active" )
				EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinType" .. pinTypeId)
				return
			end
			if iterator:run(Harvest.GetDisplaySpeed(), callback) then
				EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinType" .. pinTypeId)
			end
		end)
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
				Harvest.AddMapPinCallback( pinTypeId )
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
	for index, pinTypeId in pairs( Harvest.PINTYPES ) do
		Harvest.InitializeMapPinType( pinTypeId )
	end

	Harvest.RegisterForEvent(Harvest.NODEDELETED, function(event, nodeTag, pinTypeId)
		local pinType = Harvest.GetPinType(pinTypeId)
		LMP:RemoveCustomPin(pinType, nodeTag)
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
