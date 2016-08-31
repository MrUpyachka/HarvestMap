if not Harvest then
	Harvest = {}
end

local Harvest = _G["Harvest"]
local HarvestDB = _G["HarvestDB"]

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

-- TODO move creation and deletion of pins to the HarvestMapMarkers.lua file via callbacks,
-- this way all pin related stuff is located in a single file.

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
-- @param pinTypeId type ID of pin.
-- @param node node to identify existing pin.
--
local function RemovePinInAllControllers(pinTypeId, nodeTag)
	local pinType = Harvest.GetPinType(pinTypeId)
	LMP:RemoveCustomPin(pinType, nodeTag)
	COMPASS_PINS:RemovePin(nodeTag, pinType)
end

---
-- Function-adapter to invoke pin creation for all used pins controllers.
-- @param pinTypeId type ID of pin.
-- @param nodeData data to fill pin properties.
--
local function CreatePinInAllControllers(pinTypeId, nodeTag)
	local pinType = Harvest.GetPinType(pinTypeId)
	local x, y = HarvestDB.GetPosition(nodeTag)
	LMP:CreatePin(pinType, nodeTag, x, y)
	COMPASS_PINS:CreatePin(pinType, nodeTag, x, y)
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
	HarvestFarm.FarmedANode(objectName, stackCount) -- TODO move this to HarvestMapFarm.lua via callback
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
-- Checks any configured map addons.
-- @return true if any minimap addon detected, false in opposite case.
local function isMapAddonCompatibilityRequired()
    -- TODO Other addons
    if AUI and AUI.Minimap or FyrMM then
        return true
    end
end

function Harvest.ProcessData(map, x, y, measurement, pinTypeId, itemId)
	Harvest.FireEvent(Harvest.FOUNDDATA, map, x, y, measurement, pinTypeId, itemId)
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
			RemovePinInAllControllers(pinTypeId, nodeTag)
		end
		-- the (re-)creation of the pin is only performed, if it wasn't hidden by the respawn timer
		if Harvest.IsHiddenOnHarvest() then
			Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinType) )
			HarvestDB.SetHidden(nodeTag, true)
		else
			HarvestDB.SetHidden(nodeTag, false)
			CreatePinInAllControllers(pinTypeId, nodeTag)
		end
	end
end

function Harvest.OnUpdate(time)

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

	-- update the respawn timer feature, if it hides pins close to the player
	if Harvest.GetHiddenTime() > 0 and not Harvest.IsHiddenOnHarvest() then
		local map, x, y, measurement = Harvest.GetLocation(true)
		HarvestDB.ForCloseNodes(map, x, y, measurement, Harvest.UpdateHiddenTime)
	end

	-- TODO reimplement the feature of displaying only nearby pins in a way
	-- that doesn't rely knowledge of the unterlying datastructure

	--[[
	-- update the currently visible pins, if the limited view radius is enabled in the options
	if Harvest.lastDivisionUpdate < time - 5000 and Harvest.HasPinVisibleDistance() then
		-- check if the player moved near the border of the currently drawn pins
		-- if the player is near the border, we need to refresh the pins, so they are drawn again
		local map, x, y, measurement = Harvest.GetLocation( true )
		local divisionX, divisionY = Harvest.GetSubdivisionCoords( x, y, measurement )
		if zo_abs(divisionX - Harvest.lastDivisionX) > 1 or zo_abs(divisionY - Harvest.lastDivisionY) > 1 then
			Harvest.lastDivisionX = divisionX
			Harvest.lastDivisionY = divisionY
			Harvest.lastDivisionUpdate = time
			Harvest.RefreshPins()
		end
	end
	--]]
end

-- harvestmap will hide recently visited pins for a given respawn time (time is set in the options)
function Harvest.UpdateHiddenTime(nodeTag, pinTypeId)
	local hidden = HarvestDB.IsHidden(nodeTag)
	if not hidden then
		HarvestDB.SetHidden(nodeTag, true)
		Harvest.FireEvent(Harvest.NODEHIDDEN, nodeTag)
		Harvest.Debug( "respawn timer has hidden a pin of pin type " .. tostring(pinType) )
		RemovePinInAllControllers(pinTypeId, nodeTag) -- TODO move this to HarvestMapMarkers.lua via callback,
		-- so everything pin related is there
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
	-- add callbacks
	Harvest.RegisterForEvent(Harvest.NODECREATED, nodeCreatedOrUpdated)
	Harvest.RegisterForEvent(Harvest.NODEUPDATED, nodeCreatedOrUpdated)
	-- initialize temporary variables
	Harvest.wasHarvesting = false
	Harvest.action = nil
	-- cache the ACE deserialized nodes
	-- this way changing maps multiple times will create less lag
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
	HarvestDB.Initialize()
	-- check if saved data is from an older version,
	-- update the data if needed
	Harvest.UpdateDataVersion()
	Harvest.AddToUpdateQueue(HarvestDB.InitializeAfterUpdate)
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
