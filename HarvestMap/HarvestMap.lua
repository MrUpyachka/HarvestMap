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

function Harvest.Verbose( message )
	if Harvest.AreVerboseMessagesEnabled() then
		HarvestDebugUtils.debug( message )
	end
end


--[[
-- Just an example of howto use controller.
]]--
assert(HarvestDB, "HarvestDB is nil")
local dbController = HarvestDbController:new(HarvestDB, CALLBACK_MANAGER) -- Eso global manager used, just for example.
dbController:start() -- Now its started and listens for requests.
local nodeResolver = HarvestNodeResolver:new(HarvestDB, CALLBACK_MANAGER, {})
-- TODO recreate node resolver on each map/zone change. Pass proper options/measurements (cache them somewhere).
nodeResolver:start()

-- this function returns the pinTypeId for the given item id and node name
function Harvest.GetPinTypeId( itemId, nodeName )
	-- get two pinTypes based on the item id and node name
	local itemIdPinType = Harvest.itemId2PinType[ itemId ]
	local nodeNamePinType = Harvest.nodeName2PinType[ zo_strlower( nodeName ) ]
	HarvestDebugUtils.debug( "Item id " .. tostring(itemId) .. " returns pin type " .. tostring(itemIdPinType))
	HarvestDebugUtils.debug( "Node name " .. tostring(nodeName) .. " returns pin type " .. tostring(nodeNamePinType))
	-- heavy sacks can contain material for different professions
	-- so don't use the item id to determine the pin type
	if Harvest.IsHeavySack( nodeName ) then
		return Harvest.HEAVYSACK
	end
	if Harvest.IsTrove( nodeName ) then
		return Harvest.TROVE
	end
	return itemIdPinType or nodeNamePinType
end

-- not just called by EVENT_LOOT_RECEIVED but also by Harvest.OnLootUpdated
function Harvest.OnLootReceived( eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf )
	-- don't touch the save files/tables while they are still being updated/refactored
	if not Harvest.IsUpdateQueueEmpty() then
		HarvestDebugUtils.debug( "OnLootReceived failed: HarvestMap is updating" )
		return
	end

	if not lootedBySelf then
		HarvestDebugUtils.debug( "OnLootReceived failed: wasn't looted by self" )
		return
	end

	local map, x, y, measurement = HarvestMapUtils.GetMapInformation()
	local isHeist = false
	-- only save something if we were harvesting or the target is a heavy sack or thieves trove
	if (not Harvest.wasHarvesting) and (not Harvest.IsHeavySack( Harvest.lastInteractableName )) and (not Harvest.IsTrove( Harvest.lastInteractableName )) then
		-- additional check for heist containers
		if not (lootType == LOOT_TYPE_QUEST_ITEM) or not HarvestMapUtils.getHeistPrefixIfPossible(map) then
			HarvestDebugUtils.debug( "OnLootReceived failed: wasn't harvesting" )
			HarvestDebugUtils.debug( "OnLootReceived failed: wasn't heist quest item" )
			HarvestDebugUtils.debug( "Interactable name is:" .. tostring(Harvest.lastInteractableName))
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
			HarvestDebugUtils.debug( "OnLootReceived failed: item id is nil" )
			return
		end
		-- get the pintype depending on the item we looted and the name of the harvest node
		-- eg jute will be saved as a clothing pin
		pinTypeId = Harvest.GetPinTypeId(itemId, Harvest.lastInteractableName)
		-- sometimes we can't get the pinType based on the itemId and node name
		-- ie some data in the localization is missing and nirncrux can be found in ore and wood
		-- abort if we couldn't find the correct pinType
		if pinTypeId == nil then
			HarvestDebugUtils.debug( "OnLootReceived failed: pin type id is nil" )
			return
		end
		-- if this pinType is supposed to be saved
		if not Harvest.IsPinTypeSavedOnGather( pinTypeId ) then
			HarvestDebugUtils.debug( "OnLootReceived failed: pin type is disabled in the options" )
			return
		end
	else
		pinTypeId = Harvest.JUSTICE
	end

	Harvest.ProcessData( map, x, y, measurement, pinTypeId, itemId )
	Harvest.FireEvent(Harvest.RESSOURCEFARMED, objectName, stackCount) -- needed for the harvest farm module
	-- to calculate the gold per minute score
end

-- neded for those players that play without auto loot
function Harvest.OnLootUpdated()
	-- only save something if we were harvesting or the target is a heavy sack or thieves trove
	if (not Harvest.wasHarvesting) and (not Harvest.IsHeavySack( Harvest.lastInteractableName )) and (not Harvest.IsTrove( Harvest.lastInteractableName )) then
		HarvestDebugUtils.debug( "OnLootUpdated failed: wasn't harvesting" )
		return
	end

	-- i usually play with auto loot on
	-- everything was programmed with auto loot in mind
	-- if auto loot is disabled (ie OnLootUpdated is called)
	-- let harvestmap believe auto loot is enabled by calling
	-- OnLootReceived for each item in the loot window
	local items = GetNumLootItems()
	HarvestDebugUtils.debug( "HarvestMap will check " .. tostring(items) .. " items." )
	for lootIndex = 1, items do
		local lootId, _, _, count = GetLootItemInfo( lootIndex )
		Harvest.OnLootReceived( nil, nil, GetLootItemLink( lootId, LINK_STYLE_DEFAULT ), count, nil, nil, true )
	end

	-- when looting something, we have definitely finished the harvesting process
	if Harvest.wasHarvesting then
		HarvestDebugUtils.debug( "All loot was handled. Set harvesting state to false." )
		Harvest.wasHarvesting = false
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

function Harvest.ProcessData(map, x, y, measurement, pinTypeId, itemId)
	HarvestDebugUtils.debug("Try process data. Type: " .. pinTypeId)
	CALLBACK_MANAGER:FireCallbacks(HarvestEvents.NODE_HARVESTED_EVENT, map, x, y, measurement, pinTypeId, GetTimeStamp(), itemId)
end

function Harvest.OnUpdate(time)

	-- update the update queue (importing/refactoring data)
	if not Harvest.IsUpdateQueueEmpty() then
		Harvest.UpdateUpdateQueue()
		return
	end

	local interactionType = GetInteractionType()
	local isHarvesting = (interactionType == INTERACTION_HARVEST)

	-- update the harvesting state. check if the character was harvesting something during the last two seconds
	if not isHarvesting then
		if Harvest.wasHarvesting and time - Harvest.harvestTime > 2000 then
			HarvestDebugUtils.debug( "Two seconds since last harvesting action passed. Set harvesting state to false." )
			Harvest.wasHarvesting = false
		end
	else
		if not Harvest.wasHarvesting then
			HarvestDebugUtils.debug( "Started harvesting. Set harvesting state to true." )
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
				HarvestDebugUtils.debug( "not a chest or justice container(?)" )
				return
			end
			local map, x, y, measurement = HarvestMapUtils.GetMapInformation()
			-- normal chests aren't owned and their interaction is called "unlock"
			-- other types of chests (ie for heists) aren't owned but their interaction is "search"
			-- safeboxes are owned
			if (not Harvest.lastInteractableOwned) and Harvest.lastInteractableAction == GetString(SI_GAMECAMERAACTIONTYPE12) then
				-- normal chest
				if not Harvest.IsPinTypeSavedOnGather( Harvest.CHESTS ) then
					HarvestDebugUtils.debug( "chests are disabled" )
					return
				end
				Harvest.ProcessData( map, x, y, measurement, Harvest.CHESTS )
			else
				-- heist chest or safebox
				if not Harvest.IsPinTypeSavedOnGather( Harvest.JUSTICE ) then
					HarvestDebugUtils.debug( "justice containers are disabled" )
					return
				end
				Harvest.ProcessData( map, x, y, measurement, Harvest.JUSTICE )
			end
		end
		-- the character started fishing
		if interactionType == INTERACTION_FISH then
			-- don't create new pin if fishing pins are disabled
			if not Harvest.IsPinTypeSavedOnGather( Harvest.FISHING ) then
				HarvestDebugUtils.debug( "fishing spots are disabled" )
				return
			end
			local map, x, y, measurement = HarvestMapUtils.GetMapInformation()
			Harvest.ProcessData( map, x, y, measurement, Harvest.FISHING )
		end
	end

end

-- this hack saves the name of the object that was last interacted with
local oldInteract = FISHING_MANAGER.StartInteraction
FISHING_MANAGER.StartInteraction = function(...)
	local action, interactableName, interactionBlocked, isOwned, additionalInteractInfo, context, contextLink, isCriminalInteract = GetGameCameraInteractableActionInfo()
	Harvest.lastInteractableAction = action
	Harvest.lastInteractableName = interactableName
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
	for _, layout in pairs( HarvestMapUtils.getCurrentMapLayouts() ) do
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
	return zo_floor(GetTimeStamp() / 3600) -- TODO widely used. FIXME Seems that also affects respawn time.
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
	-- initialize temporary variables
	Harvest.wasHarvesting = false
	Harvest.action = nil
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
