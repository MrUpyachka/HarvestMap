local LMP = LibStub("LibMapPins-1.0")

if not Harvest then
	Harvest = {}
end

function Harvest.AddMapPinCallback( pinTypeId )
	Harvest.Debug("Refresh pins for pin type id " .. tostring(pinTypeId) )
	if not Harvest.IsPinTypeVisible( pinTypeId ) or Harvest.IsHeatmapActive() then
		Harvest.Debug("step1: pins type is hidden or heatmap mode is active" )
		return
	end
	-- data is still being manipulated, better if we don't access it yet
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.Debug("step1: your data is still being refactored/updated" )
		return
	end

	local map, x, y, measurement = Harvest.GetLocation( true )
	local nodes = Harvest.GetNodesOnMap( pinTypeId, map, measurement )
	local pinType = Harvest.GetPinType( pinTypeId )
	local pinData = LMP.pinManager.customPins[_G[pinType]]
	if not FyrMM then -- remove pins to fix the wayshrine bug (3.0.2)
	-- but with fyrmm this somehow results in missing map pins
	-- see comment section 11/13/15, 08:57 PM 
		LMP.pinManager:RemovePins(pinData.pinTypeString)
	end
	Harvest.mapCounter[pinType] = Harvest.mapCounter[pinType] + 1
	Harvest.AddPinsLater(Harvest.mapCounter[pinType], pinType, nodes, nil)
end

function Harvest.AddPinsLater(counter, pinType, nodes, index)
	-- map was changed while new pins are still being added
	-- abort adding new pins!
	
	if counter ~= Harvest.mapCounter[pinType] then
		Harvest.Debug("refresh was aborted for pintype " .. tostring(pinType) )
		return
	end

	if not Harvest.IsPinTypeVisible_string( pinType ) or Harvest.IsHeatmapActive() then
		Harvest.Debug("step2: pins type is hidden or heatmap mode is active for pintype " .. tostring(pinType) )
		Harvest.mapCounter[pinType] = 0
		return
	end
	
	-- data is still being manipulated, better if we don't access it yet
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.Debug("step2: your data is still being refactored/updated" )
		Harvest.mapCounter[pinType] = 0
		return
	end
	
	local time = GetFrameTimeSeconds()
	local hiddenTime = Harvest.GetHiddenTime() * 60 - 10
	local node = nil
	local lastIndex = index
	for counter = 1,10 do
		index, node = next(nodes, index)
		if index == nil then
			Harvest.mapCounter[pinType] = 0
			Harvest.Debug("displayed all pins of pintype " .. tostring(pinType) .. " last index was " .. tostring(lastIndex) )
			return
		end
		if time - node.time > hiddenTime then
			LMP:CreatePin( pinType, node.data, node.data[Harvest.X], node.data[Harvest.Y] )
			node.hidden = false
		else
			node.hidden = true
			Harvest.Debug("a pin of pintype " .. tostring(pinType) .. " was hidden by the respawn timer" )
		end
		lastIndex = index
	end
	if FyrMM then
		Harvest.AddPinsLater(counter, pinType, nodes, index)
	else
		zo_callLater(function() Harvest.AddPinsLater(counter, pinType, nodes, index) end, 0.1)
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
			pinType = LMP.pinManager.customPins[pinType].pinTypeString
			local pinTypeId = Harvest.GetPinId( pinType )
			--LMP:RemoveCustomPin( pinType, pinTag )
			local map = Harvest.GetMap()
			local saveFile = Harvest.GetSaveFile( map )
			for i, node in pairs( Harvest.cache[ map ][ pinTypeId ]) do
				if node.data == pinTag then
					LMP:RemoveCustomPin( pinType, pinTag )
					saveFile.data[ map ][ pinTypeId ][ i ] = nil
					Harvest.cache[ map ][ pinTypeId ][ i ] = nil
					return
				end
			end

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
