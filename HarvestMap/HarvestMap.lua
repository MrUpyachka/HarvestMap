if not Harvest then
	Harvest = {}
end

local Harvest = _G["Harvest"]

local AS = LibStub("AceSerializer-3.0h")
local LMP = LibStub("LibMapPins-1.0")
local COMPASS_PINS = LibStub("CustomCompassPins")
local GPS = LibStub("LibGPS2")

-- local references for global functions to improve the performance
-- of the functions called every frame
local GetMapPlayerPosition = _G["GetMapPlayerPosition"]
local GetInteractionType = _G["GetInteractionType"]
local INTERACTION_HARVEST = _G["INTERACTION_HARVEST"]
local pairs = _G["pairs"]
local tostring = _G["tostring"]
local zo_floor = _G["zo_floor"]


---
-- Function-adapter to invoke RefreshPins for all used pins controllers.
-- @param pinTypeId type ID of pins to refresh.
--
local function RefreshPinsInAllControllers(pinTypeId)
	LMP:RefreshPins(Harvest.GetPinType(pinTypeId))
	COMPASS_PINS:RefreshPins(Harvest.GetPinType(pinTypeId))
end
---
-- Function-adapter to invoke pin deletion for all used pins controllers.
-- @param pinTypeId type ID of pin.
-- @param node node to identify existing pin.
--
local function RemovePinInAllControllers(pinType, nodeData)
	LMP:RemoveCustomPin(pinType, nodeData)
	COMPASS_PINS:RemovePin(nodeData, pinType, nodeData[Harvest.X], nodeData[Harvest.Y])
end

---
-- Function-adapter to invoke pin creation for all used pins controllers.
-- @param pinTypeId type ID of pin.
-- @param nodeData data to fill pin properties.
--
local function CreatePinInAllControllers(pinType, nodeData)
	LMP:CreatePin(pinType, nodeData, nodeData[Harvest.X], nodeData[Harvest.Y])
	COMPASS_PINS:CreatePin(pinType, nodeData, nodeData[Harvest.X], nodeData[Harvest.Y])
end

-- returns informations regarding the current location
-- if viewedMap is true, the data is relative to the currently viewed map
-- otherwise the data is related to the map the player is currently on
function Harvest.GetLocation( viewedMap )
	local changed
	if not viewedMap then
		changed = (SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED)
	end

	local measurement = GPS:GetCurrentMapMeasurements( viewedMap ~= false )
	if not viewedMap then
		SetMapToPlayerLocation()
	end
	-- delves tend to be scaled down on the zone map, so we need to return a smaller value
	if Harvest.IsModifiedMap(GetMapContentType(), measurement) then
		local scale = math.sqrt(165)
		measurement = {scaleX = measurement.scaleX * scale,
		               scaleY = measurement.scaleY * scale,
		               offsetX = measurement.offsetX,
		               offsetY = measurement.offsetY }
	end

	local map = Harvest.GetMap()
	local x, y = GetMapPlayerPosition( "player" )
	if changed then
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
	end
	return map, x, y, measurement
end

-- returns true if the measurement is modified for this map
function Harvest.IsModifiedMap( mapType, measurement)
	return (mapType == MAP_CONTENT_DUNGEON and measurement and measurement.scaleX < 0.003)
end

function Harvest.GetMapData()
	local measurement = GPS:GetCurrentMapMeasurements(true)
	-- delves tend to be scaled down on the zone map, so we need to return a smaller value
	if GetMapContentType() == MAP_CONTENT_DUNGEON and measurement and measurement.scaleX < 0.003 then
		local scale = math.sqrt(165)
		measurement = {scaleX = measurement.scaleX / scale,
			scaleY = measurement.scaleY / scale,
			offsetX = measurement.offsetX,
			offsetY = measurement.offsetY }
	end

	local map = Harvest.GetMap()
	local x, y = GetMapPlayerPosition( "player" )
	return map, x, y, measurement
end

function Harvest.GetMap()
	local textureName = GetMapTileTexture()
	if Harvest.lastMapTexture ~= textureName then
		Harvest.lastMapTexture = textureName
		textureName = string.lower(textureName)
		textureName = string.gsub(textureName, "^.*maps/", "")
		textureName = string.gsub(textureName, "_%d+%.dds$", "")

		if textureName == "eyevea_base" then
			local worldMapName = GetUnitZone("player")
			worldMapName = string.lower(worldMapName)
			textureName = worldMapName .. "/" .. textureName
		else
			local heistMap = Harvest.IsHeistMap( textureName )
			if heistMap then
				Harvest.map = heistMap .. "_base"
				return Harvest.map
			end
		end

		Harvest.map = textureName
	end
	return Harvest.map
end

function Harvest.LocalToGlobal(x, y, measurement)
	if not measurement then
		return
	end
	x = x * measurement.scaleX + measurement.offsetX
	y = y * measurement.scaleY + measurement.offsetY
	return x, y
end

-- serialize the given node via the ACE library
-- serializing the data decreases the loadtimes and file size a lot
function Harvest.Serialize(data)
	return AS:Serialize(data)
end

-- register a dialog which is used to display deserialization errors
local deserializeDialog = {
	title = { text = "Deserialization Error" },
	mainText = { text =[[HarvestMap encountered an error:
The following string could not be deserialized:
<<1>>

Please report this error by posting a screenshot of this error message to the comment section of HarvestMap on esoui.com.
Please tell us in the comment as well, if you used the HarvestMerge website.]]},
	buttons = {
		[1] = {
			text = "Close",
		},
	}
}
ZO_Dialogs_RegisterCustomDialog("DESERIALIZE_ERROR", deserializeDialog)

-- this function deserializes the data and displays an error message if debug mode is enabled
function Harvest.Deserialize(data)
	local success, result = AS:Deserialize(data)
	--  it seems some bug in HarvestMerge deleted the x or y coordinates
	if success and Harvest.IsNodeValid(result) then
		return result
	else
		if Harvest.AreDebugMessagesEnabled() then
			ZO_Dialogs_ShowDialog("DESERIALIZE_ERROR", {}, { mainTextParams = { string.gsub(data,"%^","-") } } )
			d("fatal error while decoding node:")
			d(data)
		end
		Harvest.AddToErrorLog(data)
		Harvest.AddToErrorLog(result)
	end
	return nil
end

function Harvest.IsNodeValid(node)
	if type(node[Harvest.X]) == "number" and type(node[Harvest.Y]) == "number" then
		-- sometimes encoding the coordinates is wrong and the become ridiculously large numbers or 0
		if node[Harvest.X] > 0 and node[Harvest.X] < 1 and node[Harvest.Y] > 0 and node[Harvest.Y] < 1 then
			return true
		end
	end
	return false
end

-- helper function to only display debug messages if the debug mode is enabled
function Harvest.Debug( message )
	if Harvest.AreDebugMessagesEnabled() or Harvest.AreVerboseMessagesEnabled() then
		d( message )
	end
end

function Harvest.Verbose( message )
	if Harvest.AreVerboseMessagesEnabled() then
		Harvest.Debug( message )
	end
end

-- this function returns the pinTypeId for the given item id and node name
function Harvest.GetPinTypeId( itemId, nodeName )
	-- get two pinTypes based on the item id and node name
	local itemIdPinType = Harvest.itemId2PinType[ itemId ]
	local nodeNamePinType = Harvest.nodeName2PinType[ zo_strlower( nodeName ) ]
	Harvest.Debug( "Item id " .. tostring(itemId) .. " returns pin type " .. tostring(itemIdPinType))
	Harvest.Debug( "Node name " .. tostring(nodeName) .. " returns pin type " .. tostring(nodeNamePinType))
	-- heavy sacks can contain material for different professions
	-- so don't use the item id to determine the pin type
	if Harvest.IsHeavySack( nodeName ) then
		return Harvest.HEAVYSACK
	end
	if Harvest.IsTrove( nodeName ) then
		return Harvest.TROVE
	end
	-- both returned the same pin type (or both are unknown/nil)
	if itemIdPinType == nodeNamePinType then
		return itemIdPinType
	end
	-- we allow this special case because of possible errors in the localization
	if nodeNamePinType == nil then
		return itemIdPinType
	end
	-- the pin types don't match, don't save the node as there is some error
	return nil
end

-- not just called by EVENT_LOOT_RECEIVED but also by Harvest.OnLootUpdated
function Harvest.OnLootReceived( eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf )
	-- don't touch the save files/tables while they are still being updated/refactored
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.Debug( "OnLootReceived failed: HarvestMap is updating" )
		return
	end

	if not lootedBySelf then
		Harvest.Debug( "OnLootReceived failed: wasn't looted by self" )
		return
	end

	local map, x, y, measurement = Harvest.GetLocation()
	local isHeist = false
	-- only save something if we were harvesting or the target is a heavy sack or thieves trove
	if (not Harvest.wasHarvesting) and (not Harvest.IsHeavySack( Harvest.lastInteractableName )) and (not Harvest.IsTrove( Harvest.lastInteractableName )) then
		-- additional check for heist containers
		if not (lootType == LOOT_TYPE_QUEST_ITEM) or not Harvest.IsHeistMap(map) then
			Harvest.Debug( "OnLootReceived failed: wasn't harvesting" )
			Harvest.Debug( "OnLootReceived failed: wasn't heist quest item" )
			Harvest.Debug( "Interactable name is:" .. tostring(Harvest.lastInteractableName))
			return
		else
			isHeist = true
		end
	end
	-- get the information we want to save
	local itemName, itemId, _
	local pinTypeId
	if not isHeist then
		itemName, _, _, itemId = ZO_LinkHandler_ParseLink( objectName )
		itemId = tonumber(itemId)
		if itemId == nil then
			-- wait what? does this even happen?! abort mission!
			Harvest.Debug( "OnLootReceived failed: item id is nil" )
			return
		end
		-- get the pintype depending on the item we looted and the name of the harvest node
		-- eg jute will be saved as a clothing pin
		pinTypeId = Harvest.GetPinTypeId(itemId, Harvest.lastInteractableName)
		-- sometimes we can't get the pinType based on the itemId and node name
		-- ie some data in the localization is missing and nirncrux can be found in ore and wood
		-- abort if we couldn't find the correct pinType
		if pinTypeId == nil then
			Harvest.Debug( "OnLootReceived failed: pin type id is nil" )
			return
		end
		-- if this pinType is supposed to be saved
		if not Harvest.IsPinTypeSavedOnGather( pinTypeId ) then
			Harvest.Debug( "OnLootReceived failed: pin type is disabled in the options" )
			return
		end
	else
		pinTypeId = Harvest.JUSTICE
	end

	Harvest.ProcessData( map, x, y, measurement, pinTypeId, itemId )
	HarvestFarm.FarmedANode(objectName, stackCount)
end

-- neded for those players that play without auto loot
function Harvest.OnLootUpdated()
	-- only save something if we were harvesting or the target is a heavy sack or thieves trove
	if (not Harvest.wasHarvesting) and (not Harvest.IsHeavySack( Harvest.lastInteractableName )) and (not Harvest.IsTrove( Harvest.lastInteractableName )) then
		Harvest.Debug( "OnLootUpdated failed: wasn't harvesting" )
		return
	end

	-- i usually play with auto loot on
	-- everything was programmed with auto loot in mind
	-- if auto loot is disabled (ie OnLootUpdated is called)
	-- let harvestmap believe auto loot is enabled by calling
	-- OnLootReceived for each item in the loot window
	local items = GetNumLootItems()
	Harvest.Debug( "HarvestMap will check " .. tostring(items) .. " items." )
	for lootIndex = 1, items do
		local lootId, _, _, count = GetLootItemInfo( lootIndex )
		Harvest.OnLootReceived( nil, nil, GetLootItemLink( lootId, LINK_STYLE_DEFAULT ), count, nil, nil, true )
	end

	-- when looting something, we have definitely finished the harvesting process
	if Harvest.wasHarvesting then
		Harvest.Debug( "All loot was handled. Set harvesting state to false." )
		Harvest.wasHarvesting = false
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

-- simple helper function which checks if a value is inside the table
-- does lua really not have a default function for this?
function Harvest.contains( table, value)
	for _, element in pairs(table) do
		if element == value then
			return true
		end
	end
	return false
end

---
-- Checks if there is a node in the given nodes list which is close to the given coordinates.
-- @return the index of the close node if one is found, nil in opposite case.
function Harvest.GetNearestNodeIndex( nodes, x, y )
	local minDistance = Harvest.GetMinDistanceBetweenPins()
	local dx, dy
	-- node represents a raw list of data, not an table.
	for index, node in pairs( nodes ) do
		-- distance is sqrt(dx * dx + dy * dy) but for performance we compare the squared values
		-- Copypaste caused by perfomance optimization
		dx = node[Harvest.X] - x
		dy = node[Harvest.Y] - y
		if dx * dx + dy * dy < minDistance then -- the new node is too close to an old one, it's probably a duplicate
			return index
		end
	end
	return nil -- node not found.
end

-- same as IsNodeAlreadyFound but this one also checks the global distance
function Harvest.ShouldMergeNodes( nodes, x, y, measurement )
	local minDistance = Harvest.GetMinDistanceBetweenPins()
	local globalMinDistance = Harvest.GetGlobalMinDistanceBetweenPins()
	local globalX, globalY = Harvest.LocalToGlobal( x, y, measurement )
	local dx, dy
	local divX, divY = Harvest.GetSubdivisionCoords(x, y, measurement)
	local divisions, division
	for i = -1, 1 do
		for j = -1, 1 do
			division = Harvest.GetSubdivision(nodes, divX + i, divY + j)
			if division then
				for index, node in pairs( division ) do
					dx = node.data[Harvest.X] - x
					dy = node.data[Harvest.Y] - y
					if dx * dx + dy * dy < minDistance then -- the new node is too close to an old one, it's probably a duplicate
						return divX+i, divY+j, index
					end
					dx = node.global[Harvest.X] - globalX
					dy = node.global[Harvest.Y] - globalY
					if dx * dx + dy * dy < globalMinDistance then
						return divX+i, divY+j, index
					end
				end
			end
		end
	end

	return nil, nil, nil
end

---
-- Merges properties of an existing node with data from update event.
-- @param node existing node
-- @param x abscissa of update event.
-- @param y ordinate of update event.
-- @param measurement data of event.
-- @param pinTypeId type of resource from event.
-- @param itemId  unique id of item from event.
-- @param stamp event timestamp.
--
local function mergeNodeAndData(node, x, y, measurement, pinTypeId, itemId, stamp)
	local nodeUpdated = true -- TODO Rework this. Always updates coordinates.
	local nodeData = node.data
	-- update the timestamp of the nodes items
	if itemId and Harvest.ShouldSaveItemId(pinTypeId) then
		nodeData[Harvest.ITEMS] = nodeData[Harvest.ITEMS] or {}
		nodeData[Harvest.ITEMS][itemId] = stamp
	end

	-- update the pins position and version
	-- the old position could be outdated while the new one was just confirmed to be correct
	nodeData[Harvest.TIME] = stamp
	-- TODO discuss that it may be better to add some threshhold, before we update old coordinates.
	nodeData[Harvest.X] = x
	nodeData[Harvest.Y] = y
	node.global = { Harvest.LocalToGlobal(x, y, measurement) }
	nodeData[ Harvest.VERSION ] = Harvest.nodeVersion
	return nodeUpdated
end

---
-- Adds new node to specified collection.
-- @param nodes collection of nodes.
-- @param index index for new node.
-- @param x abscissa of update event.
-- @param y ordinate of update event.
-- @param measurement data of event.
-- @param nodeData data for new node.
-- @return created node.
--
local function addNodeData(nodes, index, x, y, measurement, nodeData)
	-- the new nodes needs to be saved at the same index in both tables.
	-- we need to save the data in serialized form in the save file,
	-- but also as deserialized table in the cache table for faster access.
	local divisionX, divisionY = Harvest.GetSubdivisionCoords( x, y, measurement )
	local division = Harvest.GetSubdivision(nodes, divisionX, divisionY)
	-- saving the node in deserialized form
	local node = { data = nodeData,
		time = GetFrameTimeSeconds(), -- time for the respawn timer
		global = { Harvest.LocalToGlobal(x, y, measurement) } } -- global coordinates for distance calculations
	division[index] = node
	return node
end

---
-- Validates input data of any pin update event.
-- @param map
-- @param x
-- @param y
-- @param measurement
-- @param pinTypeId
-- @param itemId
-- @return true for valid data, false for empty or values with wrong format.
--
local function validatePinData(map, x, y, measurement, pinTypeId, itemId)
	if not map then
		Harvest.Debug("Validation of data failed: map is nil")
		return false
	end
	if type(x) ~= "number" or type(y) ~= "number" then
		Harvest.Debug("Validation of data failed: coordinates aren't numbers")
		return false
	end
	if not measurement then
		Harvest.Debug("Validation of data failed: measurement is nil")
		return false
	end
	if not pinTypeId then
		Harvest.Debug("Validation of data failed: pin type id is nil")
		return false
	end
	-- If the map is on the blacklist then don't save the data
	if Harvest.IsMapBlacklisted(map) then
		Harvest.Debug("Validation of data failed: map " .. tostring(map) .. " is blacklisted")
		return false
	end
	return true -- Everything ok.
end

-- this function tries to save the given data
-- this function is only used by the harvesting part of HarvestMap
-- import and merge features do not use this function
-- @return {
--   nodeAdded - true if new node detected, false in opposite case.
--   nodeUpdated - true if data of existing node updated, false in opposite case.
--   node - updated or created node.
-- }
function Harvest.SaveData( map, x, y, measurement, pinTypeId, itemId )
	Harvest.Debug( "Try to save data for pin of type " ..  pinTypeId)
	-- check input data and that save-file exists.
	local saveFile = Harvest.GetSaveFile( map )
	if not validatePinData(map, x, y, measurement, pinTypeId, itemId) or not saveFile then
		return
	end

	-- save file tables might not exist yet
	saveFile.data[ map ] = saveFile.data[ map ] or {}
	saveFile.data[ map ][ pinTypeId ] = saveFile.data[ map ][ pinTypeId ] or {}

	local nodes = Harvest.GetNodesOnMap( pinTypeId, map, measurement )
	local pinType = Harvest.GetPinType( pinTypeId )
	local stamp = Harvest.GetCurrentTimestamp()

	local nodeAdded = false -- Means that new node detected and saved.
	local nodeUpdated = false -- Means that an existing node updated with new data.

	-- If we have found this node already then we don't need to save it again
	local divisionX, divisionY, index = Harvest.ShouldMergeNodes( nodes, x, y, measurement )
	local node
	local nodeData
	if index then
		node = Harvest.GetSubdivision(nodes, divisionX, divisionY)[index]

		-- TODO rework this to avoid deletion of pin inside save function. See ProcessData(..)
		RemovePinInAllControllers(pinType, node.data) -- Remove before merge. While coordinates not changed.

		nodeUpdated = mergeNodeAndData(node, x, y, measurement, pinTypeId, itemId, stamp)
		nodeData = node.data -- to store it in common way
	else
		-- index for new node.
		index = #(saveFile.data[ map ][ pinTypeId ]) + 1
		-- no any existing node found. new one should be added.
		nodeAdded = true
		local itemIds
		-- Prepare items ID's list if necessary.
		if Harvest.ShouldSaveItemId( pinTypeId ) then
			itemIds = { [itemId] = stamp }
		end
		nodeData = { x, y, nil, itemIds, stamp, Harvest.nodeVersion }
	end

	-- the third entry used to be the node name, but that data isn't used anymore. so save nil instead
	saveFile.data[ map ][ pinTypeId ][index] = Harvest.Serialize( nodeData )

	if nodeAdded then
		-- No any pin - save in runtime data.
		node = addNodeData(nodes, index, x, y, measurement, nodeData)
	end

	if nodeAdded then
		Harvest.Debug( "data was saved and a new pin was created" )
	elseif nodeUpdated then
		Harvest.Debug( "data was merged with a previous node" )
	else
		Harvest.Debug( "data processed, no any updates required" )
	end

	return nodeAdded, nodeUpdated, node
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

---
-- Checks that update of data required, performs actions for data update and invokes pins refresh if necessary.
-- @param map current map for processing.
-- @param x abscissa of update event.
-- @param y ordinate of update event.
-- @param measurement data of event.
-- @param pinTypeId type of resource from event.
-- @param itemId unique id of item.
--
function Harvest.ProcessData(map, x, y, measurement, pinTypeId, itemId)
	local nodeAdded, nodeUpdated, node = Harvest.SaveData(map, x, y, measurement, pinTypeId)
	local pinType = Harvest.GetPinType(pinTypeId)
	if (nodeAdded or nodeUpdated) and Harvest.IsHiddenOnHarvest() then
		-- If node updated. its pin already removed TODO fix this behavior.\
		-- don't redraw the pin, if the respawn timer is used for recently harvested ressources
		if not node.hidden then
			Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinType) )
			node.hidden = true
		end
		Harvest.Debug( "Pin hidden because its harvested just now.")
		node.time = GetFrameTimeSeconds()
	elseif (nodeAdded or nodeUpdated) then
		-- For update node pin already removed just before the moment when we update position with latest one.
		-- TODO seems that its wrong solution and its better to cache old position to remove/move old pin after all calculation.
		node.hidden = false
		CreatePinInAllControllers(pinType, node.data)
	end
	-- if a minimap is loaded, we have to refresh all pins
	-- otherwise the (re-)creation of the new/updates node is enough
	if (nodeAdded or nodeUpdated) and isMapAddonCompatibilityRequired() then
		-- compatibility with minimap plugins means that we always need to refresh all pins on each update.
		-- TODO remove direct calls of refreshPins.
		Harvest.RefreshPins( pinTypeId )
	end
end

function Harvest.OnUpdate(time)
	Harvest.UpdateMapPinCreation()
	--Harvest.UpdateCompassPinCreation()
	-- display delayed error message
	-- this message is saved by a process which must not crash (ie deserialization)
	if Harvest.error then
		local e = Harvest.error
		Harvest.error = nil
		error(e)
	end

	-- update the update queue (importing/refactoring data)
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.UpdateUpdateQueue()
		return
	end

	-- is there a pinType whose pins have to be refreshed? (ie was something harvested?)
	if Harvest.needsRefresh then
		-- only refresh the data after the loot window is closed
		-- (AUI prevents refreshing pins while the loot window is open)
		if LOOT_WINDOW.control:IsControlHidden() then
			for pinTypeId,need in pairs(Harvest.needsRefresh) do
				if need then
					Harvest.RefreshPins( pinTypeId )
				end
			end
			HarvestHeat.RefreshHeatmap()
			Harvest.needsRefresh = nil
		end
	end

	local interactionType = GetInteractionType()
	local isHarvesting = (interactionType == INTERACTION_HARVEST)

	-- update the harvesting state. check if the character was harvesting something during the last two seconds
	if not isHarvesting then
		if Harvest.wasHarvesting and time - Harvest.harvestTime > 2000 then
			Harvest.Debug( "Two seconds since last harvesting action passed. Set harvesting state to false." )
			Harvest.wasHarvesting = false
		end
	else
		if not Harvest.wasHarvesting then
			Harvest.Debug( "Started harvesting. Set harvesting state to true." )
		end
		Harvest.wasHarvesting = true
		Harvest.harvestTime = time
	end

	-- the character started a new interaction
	if interactionType ~= Harvest.lastInteractType then
		Harvest.lastInteractType = interactionType
		-- the character started picking a lock
		if interactionType == INTERACTION_LOCKPICK then
			-- if the interactable is owned by an NPC but the action isn't called "Steal From"
			-- then it wasn't a safebox but a simple door: don't place a chest pin
			if Harvest.lastInteractableOwned and (not (Harvest.lastInteractableAction == GetString(SI_GAMECAMERAACTIONTYPE20))) then
				Harvest.Debug( "not a chest or justice container(?)" )
				return
			end
			local map, x, y, measurement = Harvest.GetLocation()
			-- normal chests aren't owned and their interaction is called "unlock"
			-- other types of chests (ie for heists) aren't owned but their interaction is "search"
			-- safeboxes are owned
			if (not Harvest.lastInteractableOwned) and Harvest.lastInteractableAction == GetString(SI_GAMECAMERAACTIONTYPE12) then
				-- normal chest
				if not Harvest.IsPinTypeSavedOnGather( Harvest.CHESTS ) then
					Harvest.Debug( "chests are disabled" )
					return
				end
				Harvest.ProcessData( map, x, y, measurement, Harvest.CHESTS )
			else
				-- heist chest or safebox
				if not Harvest.IsPinTypeSavedOnGather( Harvest.JUSTICE ) then
					Harvest.Debug( "justice containers are disabled" )
					return
				end
				Harvest.ProcessData( map, x, y, measurement, Harvest.JUSTICE )
			end
		end
		-- the character started fishing
		if interactionType == INTERACTION_FISH then
			-- don't create new pin if fishing pins are disabled
			if not Harvest.IsPinTypeSavedOnGather( Harvest.FISHING ) then
				Harvest.Debug( "fishing spots are disabled" )
				return
			end
			local map, x, y, measurement = Harvest.GetLocation()
			Harvest.ProcessData( map, x, y, measurement, Harvest.FISHING )
		end
	end

	-- update the respawn timer feature
	Harvest.UpdateHiddenTime(time / 1000) -- function was written with seconds in mind instead of miliseconds

	if Harvest.lastDivisionUpdate < time - 5000 and Harvest.HasPinVisibleDistance() then
		local map, x, y, measurement = Harvest.GetLocation( true )
		local divisionX, divisionY = Harvest.GetSubdivisionCoords( x, y, measurement )
		if zo_abs(divisionX - Harvest.lastDivisionX) > 1 or zo_abs(divisionY - Harvest.lastDivisionY) > 1 then
			Harvest.lastDivisionX = divisionX
			Harvest.lastDivisionY = divisionY
			Harvest.lastDivisionUpdate = time
			Harvest.RefreshPins()
		end
	end

end

-- harvestmap will hide recently visited pins for a given respawn time (time is set in the options)
-- this function handles this respawn timer feature
-- this function also updates the last visited pin for the farming helper
function Harvest.UpdateHiddenTime(time)
	local hiddenTime = Harvest.GetHiddenTime()
	-- this function could result in a performance loss
	-- so don't do anything if it isn't needed
	if hiddenTime == 0 then
		return
	end

	hiddenTime = hiddenTime * 60 -- minutes to seconds

	local map, x, y, measurement = Harvest.GetLocation(true)
	local divisionX, divisionY = Harvest.GetSubdivisionCoords( x, y, measurement )
	local divisions, division
	local dx, dy
	local minDistance = Harvest.GetMinDistanceBetweenPins()
	local nodes, pinType
	local onHarvest = Harvest.IsHiddenOnHarvest()
	-- iterating over all the pins on the current map
	for _, pinTypeId in pairs(Harvest.PINTYPES) do
		-- if the pins are insivible, there is nothing we need to do...
		if Harvest.IsPinTypeVisible( pinTypeId ) then
			nodes = Harvest.GetNodesOnMap( pinTypeId, map )
			pinType = Harvest.GetPinType( pinTypeId )
			-- check if one of the visible pins needs to be hidden
			division = Harvest.GetSubdivision(nodes, divisionX + i, divisionY + j)
			if division then
				for _, node in pairs(division) do
					dx = x - node.data[Harvest.X]
					dy = y - node.data[Harvest.Y]
					if (not onHarvest) and dx * dx + dy * dy < minDistance then
						-- the player is close to the pin
						-- now check if it has a pin
						if not node.hidden then
							Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinType) )
							RemovePinInAllControllers(pinType, node.data)
							node.hidden = true
						end
						node.time = time
					else
						-- the player isn't close to the pin, so check if we have to show it again
						-- TODO not all pins are checked, only those in the player's subdivision
						if node.hidden and (time - node.time > hiddenTime) then
							--if not ZO_WorldMap_IsWorldMapShowing() then
							--	if(SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED) then
							--		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
							--		return
							--	end
							--end
							Harvest.Debug( "respawn timer displayed pin " .. tostring(node.data) .. " of pin type " .. tostring(pinType) .. " again" )
							CreatePinInAllControllers(pinType, node.data)
							node.hidden = false
						end
					end
				end
			end
		end
	end
end

-- this hack saves the name of the object that was last interacted with
local oldInteract = FISHING_MANAGER.StartInteraction
FISHING_MANAGER.StartInteraction = function(...)
	local action, name, blockedNode, isOwned = GetGameCameraInteractableActionInfo()
	Harvest.lastInteractableAction = action
	Harvest.lastInteractableName = name
	Harvest.lastInteractableOwned = isOwned
	return oldInteract(...)
end

-- some data structures canot be properly saved, this function restores them after the addon is fully loaded
function Harvest.FixSaveFile()
	-- functions can not be saved, so reload them
	for pinTypeId, layout in pairs( Harvest.GetCompassLayouts() ) do
		if pinTypeId == Harvest.TOUR then
			layout.additionalLayout = {HarvestFarm.additionalLayout, HarvestFarm.additionalLayoutReset}
		else
			layout.additionalLayout = {Harvest.additionalLayout, Harvest.additionalLayoutReset}
		end
	end
	-- tints cannot be saved (only as rgba table) so restore these tables to tint objects
	for _, layout in pairs( Harvest.GetMapLayouts() ) do
		if layout.color then
			layout.tint = ZO_ColorDef:New(unpack(layout.color))
			layout.color = nil
		else
			layout.tint = ZO_ColorDef:New(layout.tint)
		end
	end
end

-- returns hours since 1970
function Harvest.GetCurrentTimestamp()
	-- data is saved/serializes as string. to prevent the save file from bloating up, reduce the stamp to hours
	return zo_floor(GetTimeStamp() / 3600)
end


-- imports all the nodes on 'map' from the table 'data' into the table 'target'
-- if checkPinType is true, data will be skipped if Harvest.IsPinTypeSavedOnImport(pinTypeId) returns false
function Harvest.ImportFromMap( map, data, target, checkPinType )
	local insert = table.insert
	local pairs = _G["pairs"]
	local zo_max = _G["zo_max"]
	local type = _G["type"]
	local next = _G["next"]

	-- nothing to merge, data can simply be copied
	if target.data[ map ] == nil then
		target.data[ map ] = data
		return
	end
	-- the target table contains already a bunch of nodes, so the data has to be merged
	local targetData
	local newNode
	local index = 0
	local oldNode
	local timestamp = Harvest.GetCurrentTimestamp()
	for _, pinTypeId in pairs( Harvest.PINTYPES ) do
		if (not checkPinType) or Harvest.IsPinTypeSavedOnImport( pinTypeId ) then
			if target.data[ map ][ pinTypeId ] == nil then
				-- nothing to merge for this pin type, just copy the data
				target.data[ map ][ pinTypeId ] = data[ pinTypeId ]
			else
				-- deserialize target data and clear the serialized target data table (we'll fill it again at the end)
				targetData = {}
				for _, node in pairs( target.data[ map ][ pinTypeId ] ) do
					node = Harvest.Deserialize(node)
					if node then -- check if something went wrong while deserializing the node
						insert(targetData, node)
					end
				end
				target.data[ map ][ pinTypeId ] = {}
				-- deserialize every new node and merge them with the old nodes
				data[ pinTypeId ] = data[ pinTypeId ] or {}
				for _, entry in pairs( data[ pinTypeId ] ) do
					newNode = Harvest.Deserialize( entry )
					if newNode then -- check if something went wrong while deserializing the node
						-- If the node is new enough to be saved
						if (Harvest.GetMaxTimeDifference() == 0) or ((timestamp - (newNode[Harvest.TIME] or 0)) <= Harvest.GetMaxTimeDifference()) then
							-- If we have found this node already then we don't need to save it again
							index = Harvest.GetNearestNodeIndex( targetData, newNode[Harvest.X], newNode[Harvest.Y] )
							if index then
								oldNode = targetData[ index ]
								-- add the node's item ids
								if Harvest.ShouldSaveItemId( pinTypeId ) then
									if newNode[Harvest.ITEMS] then
										-- merge itemid->timestamp tables by saving the higher timestamps of both tables
										if oldNode[Harvest.ITEMS] then
											for itemId, stamp in pairs( newNode[Harvest.ITEMS] ) do
												oldNode[Harvest.ITEMS][itemId] = zo_max(oldNode[Harvest.ITEMS][itemId] or 0, stamp)
											end
										else
											oldNode[Harvest.ITEMS] = newNode[Harvest.ITEMS]
										end
									end
								elseif oldNode[Harvest.ITEMS] and next( oldNode[Harvest.ITEMS] ) ~= nil then
									oldNode[Harvest.ITEMS] = {}
								end
								-- update the timestamp of the node, to confirm it's a recent position
								-- keep the newer position as that one is less likely to be wrong/outdated
								if oldNode[Harvest.TIME] and newNode[Harvest.TIME] then
									if oldNode[Harvest.TIME] < newNode[Harvest.TIME] then
										oldNode[Harvest.TIME] = newNode[Harvest.TIME]
										oldNode[Harvest.X] = newNode[Harvest.X]
										oldNode[Harvest.Y] = newNode[Harvest.Y]
										oldNode[Harvest.VERSION] = newNode[Harvest.VERSION] or 0
									end
								elseif newNode[Harvest.TIME] then
									oldNode[Harvest.TIME] = newNode[Harvest.TIME]
									oldNode[Harvest.X] = newNode[Harvest.X]
									oldNode[Harvest.Y] = newNode[Harvest.Y]
									oldNode[Harvest.VERSION] = newNode[Harvest.VERSION] or 0
								end
							else
								insert(targetData, newNode)
							end
						end
					end
				end
				-- serialize the new data
				for _, node in pairs( targetData ) do
					insert(target.data[ map ][ pinTypeId ], Harvest.Serialize(node))
				end
			end
		end
	end
end

-- returns the correct table for the map (HarvestMap, HarvestMapAD/DC/EP save file tables)
-- will return HarvestMap's table if the correct table doesn't currently exist.
-- ie the HarvestMapAD addon isn't currently active
function Harvest.GetSaveFile( map )
	return Harvest.GetSpecialSaveFile( map ) or Harvest.savedVars["nodes"]
end

-- returns the correct (external) table for the map or nil if no such table exists
function Harvest.GetSpecialSaveFile( map )
	local zone = string.gsub( map, "/.*$", "" )
	if HarvestAD then
		if HarvestAD.zones[ zone ] then
			return Harvest.savedVars["ADnodes"]
		end
	end
	if HarvestEP then
		if HarvestEP.zones[ zone ] then
			return Harvest.savedVars["EPnodes"]
		end
	end
	if HarvestDC then
		if HarvestDC.zones[ zone ] then
			return Harvest.savedVars["DCnodes"]
		end
	end
	return nil
end

-- this function moves data from the HarvestMap addon to HarvestMapAD/DC/EP
function Harvest.MoveData()
	for map, data in pairs( Harvest.savedVars["nodes"].data ) do
		local zone = string.gsub( map, "/.*$", "" )
		local file = Harvest.GetSpecialSaveFile( map )
		if file ~= nil then
			Harvest.AddToUpdateQueue(function()
				Harvest.ImportFromMap( map, data, file )
				Harvest.savedVars["nodes"].data[ map ] = nil
				Harvest.Debug("Moving old data to the correct save files. " .. tostring(Harvest.GetQueuePercent()) .. "%")
			end)
		end
	end
end

do
	local zo_floor = _G["zo_floor"]
	local next = _G["next"]
	local globalLocalDistance = 0.009
	--[[
	local hewsbaneMap = "thievesguild/hewsbane_base"
	local dbRelease = 406860
	local translation = 201/824
	local scale = 1.013
	--]]
	-- returns isValidNode, wasNodeChanged
	function Harvest.CheckNodeVersion( pinTypeId, node, map, measurement )
		local version = node.data[Harvest.VERSION] or 0
		local addonVersion = version % Harvest.VersionOffset
		local gameVersion = zo_floor(version / Harvest.VersionOffset)
		if addonVersion < 1 then
			-- filter nodes which were saved with their global coordinates
			if (node.global[Harvest.X] - node.data[Harvest.X])^2 + (node.global[Harvest.Y] - node.data[Harvest.Y])^2 < globalLocalDistance then
				return false, false
			end
			--[[
			if map == hewsbaneMap then
				if (node.data[Harvest.TIME] or 0) < dbRelease then
					node.data[Harvest.X] = (node.data[Harvest.X] - translation) / scale + translation
					node.data[Harvest.Y] = (node.data[Harvest.Y] - translation) / scale + translation
					node.global[Harvest.X], node.global[Harvest.Y] = Harvest.LocalToGlobal(node.data[Harvest.X], node.data[Harvest.Y])
					return true
				end
			end
			--]]
		end
		-- the harvest merge website doesn't remove the item ids for enchanting pins etc...
		if not Harvest.ShouldSaveItemId( pinTypeId ) then
			if node.data[ Harvest.ITEMS ] and next( node.data[ Harvest.ITEMS ] ) ~= nil then
				node.data[ Harvest.ITEMS ] = {}
				return true, true
			end
		end
		return true, false
	end
end

-- TODO camel-case for naming, GetSubDivision.
function Harvest.GetSubdivision(divisions, divisionX, divisionY)
	if divisionX < 0 or divisionX >= divisions.width then return nil end
	return divisions[divisionX + divisionY * divisions.width]
end

function Harvest.GetSubdivisionCoords(x, y, measurement)
	if not measurement then
		return 0, 0
	end
	x = zo_floor(x / Harvest.GetPinVisibleDistance() * measurement.scaleX)
	y = zo_floor(y / Harvest.GetPinVisibleDistance() * measurement.scaleY)
	return x, y
end

-- data is stored as ACE strings
-- this functions deserializes the strings and saves the results in the cache
function Harvest.LoadToCache( pinTypeId, map, measurement )
	if not Harvest.cache[ map ] then
		Harvest.lastCachedIndex = Harvest.lastCachedIndex + 1
		for map, data in pairs(Harvest.cache) do
			if data.index <= Harvest.lastCachedIndex - Harvest.GetMaxCachedMaps() then
				Harvest.cache[ map ] = nil
			end
		end
		Harvest.cache[ map ] = {index = Harvest.lastCachedIndex, subdivisions = {}}
	end
	-- only deserialize/load the data if it hasn't been loaded already
	if Harvest.cache[ map ].subdivisions[ pinTypeId ] == nil and measurement then
		local unpack = _G["unpack"]
		local zo_max = _G["zo_max"]
		local pairs = _G["pairs"]
		local localToGlobal = Harvest.LocalToGlobal
		-- create table if it doesn't exist yet
		local saveFile = Harvest.GetSaveFile(map)
		saveFile.data[ map ] = (saveFile.data[ map ]) or {}
		saveFile.data[ map ][ pinTypeId ] = (saveFile.data[ map ][ pinTypeId ]) or {}
		local nodes = saveFile.data[ map ][ pinTypeId ]
		local timestamp = Harvest.GetCurrentTimestamp()
		local maxIndex = 0
		local newNode, deserializedNode
		local cachedNodes = {}
		local validNode, changedNode
		local valid
		-- deserialize the nodes and check their node version
		for index, node in pairs( nodes ) do
			deserializedNode = Harvest.Deserialize( node )
			validNode = false
			if deserializedNode and ((Harvest.GetMaxTimeDifference() == 0) or ((timestamp - (deserializedNode[Harvest.TIME] or 0)) < Harvest.GetMaxTimeDifference())) then
				newNode = { data = deserializedNode, time = 0, global = { localToGlobal(deserializedNode[Harvest.X], deserializedNode[Harvest.Y], measurement) } }
				validNode, changedNode = Harvest.CheckNodeVersion( pinTypeId, newNode, map, measurement )
				if validNode then
					cachedNodes[index] = newNode
					maxIndex = zo_max(maxIndex, index)
					if changedNode then
						nodes[index] = Harvest.Serialize( newNode.data )
					end
				end
			end
			-- nodes which weren't loaded are invalid and can be deleted from the save file
			if not validNode then
				nodes[ index ] = nil
			end
		end

		-- merge close nodes based on more accurate map size measurements
		local dx, dy, x1, y1, x2, y2
		local nodeA, nodeB
		local distance = Harvest.GetGlobalMinDistanceBetweenPins()
		-- merge close nodes
		for i = 1, maxIndex do if cachedNodes[i] then
			nodeA = cachedNodes[i]
			x1, y1 = unpack(nodeA.global)
			for j = i+1, maxIndex do if cachedNodes[j] then
				nodeB = cachedNodes[j]
				x2, y2 = unpack(nodeB.global)

				dx = x1 - x2
				dy = y1 - y2
				if dx * dx + dy * dy < distance then
					-- keep the node with the more recent timestamp
					if (nodeA.data[Harvest.TIME] or 0) > (nodeB.data[Harvest.TIME] or 0) then
						if nodeB.data[Harvest.ITEMS] then
							nodeA.data[Harvest.ITEMS] = nodeA.data[Harvest.ITEMS] or {}
							for itemId, stamp in pairs(nodeB.data[Harvest.ITEMS]) do
								nodeA.data[Harvest.ITEMS][itemId] = zo_max(nodeA.data[Harvest.ITEMS][itemId] or 0, stamp)
							end
						end
						cachedNodes[j] = nil
						nodes[j] = nil
						nodes[i] = Harvest.Serialize(nodeA.data)
					else
						if nodeA.data[Harvest.ITEMS] then
							nodeB.data[Harvest.ITEMS] = nodeB.data[Harvest.ITEMS] or {}
							for itemId, stamp in pairs(nodeA.data[Harvest.ITEMS]) do
								nodeB.data[Harvest.ITEMS][itemId] = zo_max(nodeB.data[Harvest.ITEMS][itemId] or 0, stamp)
							end
						end
						cachedNodes[i] = nil
						nodes[i] = nil
						nodes[j] = Harvest.Serialize(nodeB.data)
						break
					end
				end
			end; end
		end; end

		local subdivisions = { width = zo_floor(1 / Harvest.GetPinVisibleDistance() * measurement.scaleX) + 1 }
		local subdivisionX, subdivisionY, index
		for index, node in pairs(cachedNodes) do
			subdivisionX, subdivisionY = Harvest.GetSubdivisionCoords(node.data[1], node.data[2], measurement)
			subdivisions[subdivisionX + subdivisionY * subdivisions.width] = subdivisions[subdivisionX + subdivisionY * subdivisions.width] or {}
			subdivisions[subdivisionX + subdivisionY * subdivisions.width][index] = node
		end
		Harvest.cache[ map ].subdivisions[ pinTypeId ] = subdivisions
	end
	return Harvest.cache[ map ].subdivisions[ pinTypeId ]
end

-- loads the nodes to cache and returns them
-- if no measurement was given and the nodes could thus not be loaded to the cache,
-- return an empty list instead
function Harvest.GetNodesOnMap( pinTypeId, map, measurement )
	return Harvest.LoadToCache( pinTypeId, map, measurement ) or {}
end

function Harvest.GetErrorLog()
	return Harvest.savedVars["global"].errorlog
end

function Harvest.AddToErrorLog(message)
	local log = Harvest.savedVars["global"].errorlog
	if #log - log.start > Harvest.logSize then
		log[log.start] = nil
		log.start = log.start + 1
	end
	table.insert(Harvest.savedVars["global"].errorlog, message)
end

function Harvest.ClearErrorLog()
	Harvest.savedVars["global"].errorlog = {start = 1}
end

function Harvest.InitializeSavedVariables()
	Harvest.savedVars = {}
	-- global settings that are always account wide
	Harvest.savedVars["global"] = ZO_SavedVars:NewAccountWide("Harvest_SavedVars", 3, "global", Harvest.defaultGlobalSettings)
	if not Harvest.savedVars["global"].maxTimeDifference then --this setting was added in 3.0.8
		Harvest.savedVars["global"].maxTimeDifference = 0
	end
	if not Harvest.savedVars["global"].errorlog then --this log was added in 3.1.11
		Harvest.savedVars["global"].errorlog = {start = 1}
	end
	-- nodes are saved account wide
	Harvest.savedVars["nodes"]  = ZO_SavedVars:NewAccountWide("Harvest_SavedVars", 2, "nodes", Harvest.dataDefault)
	if not Harvest.savedVars["nodes"].firstLoaded then
		Harvest.savedVars["nodes"].firstLoaded = Harvest.GetCurrentTimestamp()
	end
	Harvest.savedVars["nodes"].lastLoaded = Harvest.GetCurrentTimestamp()
	-- load other node addons, if they are activated
	if HarvestAD then
		Harvest.savedVars["ADnodes"]  = HarvestAD.savedVars
	end
	if HarvestEP then
		Harvest.savedVars["EPnodes"]  = HarvestEP.savedVars
	end
	if HarvestDC then
		Harvest.savedVars["DCnodes"]  = HarvestDC.savedVars
	end
	-- depending on the account wide setting, the settings may not be saved per character
	if Harvest.savedVars["global"].accountWideSettings then
		Harvest.savedVars["settings"] = ZO_SavedVars:NewAccountWide("Harvest_SavedVars", 2, "settings", Harvest.defaultSettings )
	else
		Harvest.savedVars["settings"] = ZO_SavedVars:New("Harvest_SavedVars", 2, "settings", Harvest.defaultSettings )
	end
	-- the settings might be from a previous HarvestMap version, in which case there might be missing attributes
	-- initilaize these missing attributes
	for key, value in pairs(Harvest.defaultSettings) do
		if Harvest.savedVars["settings"][key] == nil then
			Harvest.savedVars["settings"][key] = value
		end
	end
	Harvest.savedVars["settings"].mapLayouts[Harvest.JUSTICE].texture = Harvest.defaultSettings.mapLayouts[Harvest.JUSTICE].texture
	Harvest.savedVars["settings"].compassLayouts[Harvest.JUSTICE].texture = Harvest.defaultSettings.compassLayouts[Harvest.JUSTICE].texture
	-- the player recently updated to version 3.3.2
	if Harvest.savedVars["settings"].hasMaxVisibleDistance == nil then
		for pinTypeId, layout in pairs(Harvest.savedVars["settings"].compassLayouts) do
			layout.maxDistance = Harvest.defaultSettings.compassLayouts[pinTypeId].maxDistance
		end
	end
end

function Harvest.OnLoad(eventCode, addOnName)
	if addOnName ~= "HarvestMap" then
		return
	end
	-- initialize temporary variables
	Harvest.wasHarvesting = false
	Harvest.action = nil
	-- cache the ACE deserialized nodes
	-- this way changing maps multiple times will create less lag
	Harvest.cache = {}
	Harvest.lastCachedIndex = 0
	Harvest.lastDivisionX = -10
	Harvest.lastDivisionY = -10
	Harvest.lastDivisionUpdate = 0
	-- mapCounter and compassCounter are used by the delayed pin creation procedure
	-- these procedures are in the HarvestMapMarkers.lua and HarvestMapCompass.lua
	Harvest.mapCounter = {}
	for _, pinTypeId in pairs(Harvest.PINTYPES) do
		Harvest.mapCounter[Harvest.GetPinType( pinTypeId )] = 0
	end
	Harvest.compassCounter = {}
	for _, pinTypeId in pairs(Harvest.PINTYPES) do
		Harvest.compassCounter[Harvest.GetPinType( pinTypeId )] = 0
	end
	-- initialize save variables
	Harvest.InitializeSavedVariables()
	-- check if saved data is from an older version,
	-- update the data if needed
	Harvest.UpdateDataVersion()
	-- move data to correct save files
	-- if AD was disabled while harvesting in AD, everything was saved in ["nodes"]
	-- when ad is enabled, everything needs to be moved to that save file
	-- HOWEVER, only execute this after the save files were updated!
	Harvest.AddToUpdateQueue(Harvest.MoveData)
	-- some data cannot be properly saved, ie functions or tints.
	-- repair this data
	Harvest.FixSaveFile()
	-- initialize pin callback functions
	Harvest.InitializeMapMarkers()
	Harvest.InitializeCompassMarkers()
	-- create addon option panels
	Harvest.InitializeOptions()
	-- initialize bonus features
	if Harvest.IsHeatmapActive() then
		HarvestHeat.Initialize()
	end
	HarvestFarm.Initialize()

	EVENT_MANAGER:RegisterForUpdate("HarvestMap", 200, Harvest.OnUpdate)
	-- add these callbacks only after the addon has loaded to fix SnowmanDK's bug (comment section 20.12.15)
	EVENT_MANAGER:RegisterForEvent("HarvestMap", EVENT_LOOT_RECEIVED, Harvest.OnLootReceived)
	EVENT_MANAGER:RegisterForEvent("HarvestMap", EVENT_LOOT_UPDATED, Harvest.OnLootUpdated)

end

-- initialization which is dependant on other addons is done on EVENT_PLAYER_ACTIVATED
-- because harvestmap might've been loaded before them
function Harvest.OnActivated()
	HarvestFarm.PostInitialize()
	EVENT_MANAGER:UnregisterForEvent("HarvestMap", EVENT_PLAYER_ACTIVATED, Harvest.OnActivated)
end

EVENT_MANAGER:RegisterForEvent("HarvestMap", EVENT_ADD_ON_LOADED, Harvest.OnLoad)
EVENT_MANAGER:RegisterForEvent("HarvestMap", EVENT_PLAYER_ACTIVATED, Harvest.OnActivated)
