local LMP = LibStub("LibMapPins-1.0")

if not Harvest then
	Harvest = {}
end
local Harvest = _G["Harvest"]
local pairs = _G["pairs"]
local zo_floor = _G["zo_floor"]
local zo_max = _G["zo_max"]
local next = _G["next"]
local GetFrameTimeSeconds = _G["GetFrameTimeSeconds"]

-- simple queue which stores the divisions that need to be created

local creationQueue = { queue = {}, size = 0}

-- create a new queue entry for the pinType
-- overrides previous creation entries for the pinType as they are outdated by now
function creationQueue:StartNewCreation( pinTypeId )
	if self.queue[pinTypeId] then
		for _ in pairs(self.queue[pinTypeId].divisions) do
			self.size = self.size - 1
		end
	end
	self.queue[pinTypeId] = {divisions = {}, indices = {}}
end

-- adds the given division to the queue
function creationQueue:CreateDivisionForPinType( pinTypeId, division)
	self.size = self.size + 1
	table.insert(self.queue[pinTypeId].divisions, division)
end

function creationQueue:Clear()
	self.size = 0
	self.queue = {}
end

function creationQueue:Finished( pinTypeId, divisionIndex )
	self.size = self.size - 1
	self.queue[pinTypeId].divisions[divisionIndex] = nil
	self.queue[pinTypeId].indices[divisionIndex] = nil
	if not next(self.queue[pinTypeId].divisions) then
		self.queue[pinTypeId] = nil
	end
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
	x, y = Harvest.GetSubdivisionCoords(x, y, measurement)
	Harvest.lastDivisionX = x
	Harvest.lastDivisionY = y
	local nodes = Harvest.GetNodesOnMap( pinTypeId, map, measurement )
	local pinType = Harvest.GetPinType( pinTypeId )
	local pinData = LMP.pinManager.customPins[_G[pinType]]
	if not FyrMM then -- remove pins to fix the wayshrine bug (3.0.2)
	-- but with fyrmm this somehow results in missing map pins
	-- see comment section 11/13/15, 08:57 PM 
		LMP.pinManager:RemovePins(pinData.pinTypeString)
	end
	--Harvest.mapCounter[pinType] = Harvest.mapCounter[pinType] + 1
	creationQueue:StartNewCreation( pinTypeId )
	local division
	for i = -2, 2 do
		for j = -2, 2 do
			division = Harvest.GetSubdivision(nodes, x + i, y + j)
			if division then
				creationQueue:CreateDivisionForPinType( pinTypeId, division)
				--Harvest.AddPinsLater(Harvest.mapCounter[pinType], pinType, division, nil)
			end
		end
	end
end

function Harvest.UpdateMapPinCreation()
	if creationQueue.size == 0 then
		return -- nothing to display
	end

	if Harvest.IsHeatmapActive() then
		creationQueue:Clear()
		Harvest.Debug("no pins displayed as the heatmap mode is active")
		return
	end

	if not Harvest.IsUpdateQueueEmpty() then
		creationQueue:Clear()
		Harvest.Debug("no pins displayed as your data is still being refactored/updated")
		return
	end

	local time = GetFrameTimeSeconds()
	local hiddenTime = Harvest.GetHiddenTime() * 60 - 10
	local numPinsToAdd = Harvest.GetDisplaySpeed()

	local node, index, pinType, speed, prevNumPinsToAdd

	while numPinsToAdd > 0 and creationQueue.size > 0 do
		prevNumPinsToAdd = numPinsToAdd
		-- get the number of pins to be created per pin type
		speed = zo_max(zo_floor(numPinsToAdd / creationQueue.size), 1)

		for pinTypeId, pinTypeQueue in pairs(creationQueue.queue) do
			if Harvest.IsPinTypeVisible( pinTypeId ) then
				pinType = Harvest.GetPinType( pinTypeId )
				index = nil
				for divisionIndex, division in pairs(pinTypeQueue.divisions) do
					node = nil
					index = pinTypeQueue.indices[divisionIndex]
					for counter = 1, speed do
						index, node = next(division, index)
						if index == nil then
							creationQueue:Finished( pinTypeId, divisionIndex )
							Harvest.Debug("all pins of the pinType have been created: " .. tostring(pinTypeId) )
							break
						end

						if time - node.time > hiddenTime then
							LMP:CreatePin( pinType, node.data, node.data[Harvest.X], node.data[Harvest.Y] )
							node.hidden = false
							numPinsToAdd = numPinsToAdd - 1
							if numPinsToAdd == 0 then
								pinTypeQueue.indices[divisionIndex] = index
								--Harvest.Debug("all pins have been created" )
								return
							end
						else
							node.hidden = true
							Harvest.Debug("a pin of pintype " .. tostring(pinTypeId) .. " was hidden by the respawn timer" )
						end
					end
					pinTypeQueue.indices[divisionIndex] = index
				end
			else
				for divisionIndex, division in pairs(pinTypeQueue.divisions) do
					creationQueue:Finished( pinTypeId, divisionIndex )
				end
				creationQueue.queue[ pinTypeId ] = nil
				Harvest.Debug("no pins displayed as pin type is hidden: " .. tostring(pinTypeId) )
			end
		end
		-- this can happen because of the respawn timer or when there are no pins for the given pin types
		if prevNumPinsToAdd == numPinsToAdd then
			creationQueue:Clear()
			Harvest.Debug("there wasn't anything added in this iteration" )
			return
		end
	end
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
	if FyrMM then--or Harvest.HasPinVisibleDistance() then
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
			for x, divisions in pairs( Harvest.cache[ map ].subdivisions[ pinTypeId ]) do
				for y, division in pairs(divisions) do
					for index, node in pairs(division) do
						if node.data == pinTag then
							LMP:RemoveCustomPin( pinType, pinTag )
							saveFile.data[ map ][ pinTypeId ][ index ] = nil
							division[ index ] = nil
							return
						end
					end
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
