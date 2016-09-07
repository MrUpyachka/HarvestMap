------------------------------------------------------------------------------------------------------------------------
-- Controller which handles visibility of pins on map.
-- Resposibility:
-- Listen for new pins - add to map, depends harvesting respawn.
-- Listen for harvesting - implements respawn logic.
-- Settings update for pin types - toggle visibility for pins of type.
--
HarvestMapPinController = {}

------------------------------------------------------------------------------------------------------------------------
-- Here is the desription of this module.
-- Implements class for handling of nodes from storage(passed through constructor new(storage, ...)
-- and siplaying of them on map and compass.
-- Each instance of class has methods start() and stop() to control displaying of pins.
-- After start it registers itself in callback controller(passed through constructor new(..., callbackController)
-- for listening of next event:
-- HarvestEvents.NODE_ADDED_EVENT
-- @see onNodeAdded(...)
-- HarvestEvents.NODE_UPDATED_EVENT
-- @see onNodeUpdated(...)
-- HarvestEvents.NODE_DELETED_EVENT
-- @see onNodeDeleted(...)
-- Class implements rules for displaying of pins inside each function described above.
-- Also, each instance contains three types of cache:
-- Cache of nodes by their ID with assigned time to be displayed - used for processing of respawn time after harvesting.
-- @see queueCheckInterval interval for processor of cache.
-- Two separate caches of nodes by their type, for map and compass:
-- Cache of nodes by their type to be displayed - used in background activity to display only limited number of pins
-- per call of worker.
-- @see pinTypeNodesToAddToMap nodes to be added to map.
-- @see pinTypeNodesToAddToCompass nodes to be added to compass.
-- @see pinAddPerTickLimit limit of pin add operations per one processor call.
-- @see queueTypeAddInterval interval for processor of cache.
-- Content of this caches filled by corresponding callback of map/compass adapter:
-- @see onDisplayPinTypeOnMap(..)
-- @see onDisplayPinTypeOnCompass(..)
--
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Reference to LibMapPins.
local LMP = LibStub("LibMapPins-1.0") --- Map adapter.
local COMPASS = LibStub("CustomCompassPins") --- Compass adapter.
------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestMapPinController:new(s, c)
    local instance = {
        storage = s,
        callbackController = c,
        postponedAddPinQueue = {}, --- Queue which contains items with specified time to run.
        queueCheckInterval = 1000, -- Time interval to check pins with postponed add.
        pinTypeNodesToAddToMap = {}, -- Cache of nodes to be displayed on map.
        pinTypeNodesToAddToCompass = {}, -- Cache of nodes to be displayed on compass.
        queueTypeAddInterval = 50, -- Time interval to split add of pins by type.
        pinAddPerTickLimit = 30,
    }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

------------------------------------------------------------------------------------------------------------------------
--- Displays single pin on map.
-- @param id unique identifier of node.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param items items which could be found in this node.
--
local function displayPin(id, type, timestamp, x, y, xg, yg, items)
    local pinType = Harvest.GetPinType(type)
    LMP:CreatePin(pinType, id, x, y)
end

--- Displays single pin by its id.
-- @param id unique identifier of node.
--
function HarvestMapPinController:displayPinById(id)
    local type, timestamp, x, y, xg, yg, items = self.storage.getNodeTuple(id)
    displayPin(id, type, timestamp, x, y, xg, yg, items)
end

--- Displays single pin by its id only if its pinType enabled.
-- @param id unique identifier of node.
--
function HarvestMapPinController:displayPinIfEnabled(id)
    local type, timestamp, x, y, xg, yg, items = self.storage.getNodeTuple(id)
    local pinType = Harvest.GetPinType(type)
    if LMP:IsEnabled(pinType) then
        LMP:CreatePin(pinType, id, x, y)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Displays single pin  by its id on compass.
-- @param id unique identifier of node.
--
function HarvestMapPinController:displayPinOnCompassById(id)
    local type, timestamp, x, y, xg, yg, items = self.storage.getNodeTuple(id)
    local pinType = Harvest.GetPinType(type)
    COMPASS:CreatePin(pinType, id, x, y)
end

------------------------------------------------------------------------------------------------------------------------
--- Displays single pin by its id when harvesting respaw time will be exceeded.
-- @param id unique identifier of node.
--
function HarvestMapPinController:postponePinAddAfterHarvesting(id)
    self.postponedAddPinQueue[id] = Harvest.GetHiddenTime() * 60 + GetTimeStamp() -- In secons enough
end

------------------------------------------------------------------------------------------------------------------------
--- Callback method to handle event that node updated.
-- @param id unique identifier of node.
--
function HarvestMapPinController:onNodeUpdated(id)
    HarvestDebugUtils.debug("Node " .. id .. " updated. Check visibility.")
    if Harvest.IsHiddenOnHarvest() then
        HarvestDebugUtils.debug("Hide after update.") -- TODO another event to do this. Its not clear with hide on update.
        local typeKey = Harvest.GetPinType(self.storage.getIdCache().types[id])
        LMP:RemoveCustomPin(typeKey, id)
        self:postponePinAddAfterHarvesting(id)
    else
        HarvestDebugUtils.debug("Still visible due settings configuration.")
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callback method to handle event that new node added.
-- @param id unique identifier of node.
--
function HarvestMapPinController:onNodeAdded(id)
    HarvestDebugUtils.debug("Node " .. id .. " added. Check visibility.")
    if Harvest.IsHiddenOnHarvest() then
        HarvestDebugUtils.debug("Just harvested - not displayed.") -- TODO another event to do this. Its not clear with hide on update.
        local typeKey = Harvest.GetPinType(self.storage.getIdCache().types[id])
        LMP:RemoveCustomPin(typeKey, id)
        self:postponePinAddAfterHarvesting(id)
    else
        HarvestDebugUtils.debug("Visible due settings configuration.")
        self:displayPinById(id)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callback method to handle event that node deleted.
-- @param id unique identifier of node.
-- @param type type identifier.
--
function HarvestMapPinController:onNodeDeleted(id ,type)
    local typeKey = Harvest.GetPinType(type)
    LMP:RemoveCustomPin(typeKey, id)
    HarvestDebugUtils.debug("Pin " .. id .. " deleted.")
end

------------------------------------------------------------------------------------------------------------------------
local debugHandler = {
    {
        name = function(pin)
            local pinType, id = pin:GetPinTypeAndTag()
            local lines = Harvest.GetLocalizedTooltip(pin)
            return table.concat(lines, "_D_" .. id .. "\n")
        end,
        callback = function(pin)
            local pinType, id = pin:GetPinTypeAndTag()
            HarvestDebugUtils.debug("Debug handler of pin <" .. id .. ">")
            CALLBACK_MANAGER:FireCallbacks(HarvestEvents.DELETE_NODE_REQUEST, id) -- Just fire event into the same callback manager.
        end,
    }
}

--- Registers specified in type by key on map.
-- @param pinType id of type.
--
function HarvestMapPinController:registerPinTypeOnMap(pinType)
    local typeKey = Harvest.GetPinType(pinType)
    local localizedName = Harvest.GetLocalization("pintype" .. pinType)
    local pinLayout = HarvestMapUtils.getCurrentMapPinLayout(pinType)
    LMP:AddPinType(typeKey, function() self:onDisplayPinTypeOnMap(pinType) end, nil, pinLayout, Harvest.tooltipCreator)
    if pinType ~= Harvest.TOUR then
        local pveControl, pvpControl, imperialControl =
        LMP:AddPinFilter(typeKey, localizedName, false, Harvest.savedVars["settings"].isPinTypeVisible)
        local toggle = function(button, state) Harvest.SetPinTypeVisible(pinType, state) end
        ZO_CheckButton_SetToggleFunction(pveControl, toggle)
        ZO_CheckButton_SetToggleFunction(pvpControl, toggle)
        ZO_CheckButton_SetToggleFunction(imperialControl, toggle)
        HarvestDebugUtils.debug("Filter of pin type <" .. localizedName .. "> registered")
    end
    if not Harvest.IsDebugEnabled() then
        HarvestDebugUtils.debug("Debug enabled")
        LMP:SetClickHandlers(typeKey, debugHandler, nil)
        HarvestDebugUtils.debug("Debug handler of pin type <" .. localizedName .. "> registered")
    end
end

--- Registers specified in type by key on map.
-- @param pinType id of type.
--
function HarvestMapPinController:registerPinTypeOnCompass(pinType)
    local typeKey = Harvest.GetPinType(pinType)
    local callback
    if pinType == Harvest.TOUR then
        callback = HarvestFarm.CompassCallback
    else
        callback = function() d("Compass callback") self:onDisplayPinTypeOnCompass(pinType) end
    end

    COMPASS:AddCustomPin(typeKey, callback, Harvest.GetCompassPinLayout(pinType))
end

--- Registers all types of pins on map (for filtering and others).
function HarvestMapPinController:registerPinTypes()
    for _, pinType in pairs(Harvest.PINTYPES) do
        self:registerPinTypeOnMap(pinType)
        --self:registerPinTypeOnCompass(pinType)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callback for displaying of pins with spicified type on map.
-- @param type type of node - typeId.
function HarvestMapPinController:onDisplayPinTypeOnMap(type)
    -- TODO unregister worker if it has empty queue
    if self.map == nil then return end
    local nodes = self.storage.getNodesListOfType(type)
    self.pinTypeNodesToAddToMap[type] = nodes
    if nodes ~= nil then
        -- HarvestDebugUtils.debug("Try display pin type <" .. Harvest.GetLocalization("pintype" .. type) .. ">. Total: " .. #nodes)
    end
    -- self.storage.forNodesOfType(type, displayPin)
end

--- Callback for displaying of pins with spicified type on compass.
-- @param type type of node - typeId.
function HarvestMapPinController:onDisplayPinTypeOnCompass(type)
    if self.map == nil then return end
    local nodes = self.storage.getNodesListOfType(type)
    self.pinTypeNodesToAddToCompass[type] = nodes
    if nodes ~= nil then
        HarvestDebugUtils.debug("Try display pin on compass for type <" .. Harvest.GetLocalization("pintype" .. type) .. ">. Total: " .. #nodes)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callback function for OnWorldMapChanged callback.
-- @param map new map.
--
function HarvestMapPinController:onMapChanged(map)
    self.map = map
    -- Reset internal queues.
    self.postponedAddPinQueue = {}
    self.pinTypeNodesToAddToMap = {}
    self.pinTypeNodesToAddTCompass = {}
    -- Storage changed, but LMP still displays old pins
    LMP:RefreshPins()
    --COMPASS:RefreshPins()
    HarvestDebugUtils.debug("Refresh started")
    --[[
    for _, pinType in pairs(Harvest.PINTYPES) do
        local typeKey = Harvest.GetPinType(pinType)
        if LMP:IsEnabled(typeKey) then


        end
    end
    ]]--
end

------------------------------------------------------------------------------------------------------------------------
--- Iterates over queue with postponed pins and displays them if necessary.
function HarvestMapPinController:processPostponedQueue()
    local currentTime = GetTimeStamp()
    for id, time in pairs(self.postponedAddPinQueue) do
       if currentTime > time then
           self:displayPinIfEnabled(id)
           self.postponedAddPinQueue[id] = nil
           HarvestDebugUtils.debug("Pin " .. id .. " displayed after harvesting")
       else
           -- HarvestDebugUtils.debug("Pin " .. id .. " was harvested " .. ((time - currentTime)) .. "s ago. ")
       end
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Iterates over specified queue with postponed pins by type and calls specified callback for each nodeId.
-- @param types list of nodes bt their type.
-- @param limit limit of displayed pins for one invokation.
-- @param callback callback to be invoked with node identifier as parameter.
--
local function processPostponedTypeAddQueue(types, limit, callback)
    for type, typeNodes in pairs(types) do
        --HarvestDebugUtils.debug(#typeNodes .. " pins of type " .. type .. " to be displayed.")
        if #typeNodes > 0 then
            local counter = 0
            for nodeIndex, nodeId in pairs(typeNodes) do
                if counter > limit then return end
                counter = counter + 1
                callback(nodeId)
                typeNodes[nodeIndex] = nil
            end
        else
            --HarvestDebugUtils.debug("All pins of type " .. type .. " displayed.")
            types[type] = nil
        end
    end
end

--- Iterates over queue with postponed pins by type and displays them if necessary.
function HarvestMapPinController:processPostponedTypeAddQueue()
    local types = self.pinTypeNodesToAddToMap
    local limit = self.pinAddPerTickLimit
    processPostponedTypeAddQueue(types, limit, function(id) self:displayPinById(id) end)
end

--- Iterates over queue with postponed pins by type and displays them if necessary.
function HarvestMapPinController:processPostponedTypeAddCompassQueue()
    local types = self.pinTypeNodesToAddToCompass
    local limit = self.pinAddPerTickLimit
    processPostponedTypeAddQueue(types, limit, function(id) self:displayPinOnCompassById(id) d("Add to compass: " .. id) end)
end


------------------------------------------------------------------------------------------------------------------------
--- Starts listening of callbacks and their processing.
--
function HarvestMapPinController:start()
    self:registerPinTypes()

    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPostponedAdd", self.queueCheckInterval, function() self:processPostponedQueue() end)
    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPinTypeRefresh", self.queueTypeAddInterval, function() self:processPostponedTypeAddQueue() end)
    --EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPinTypeRefreshCompass", self.queueTypeAddInterval, function() self:processPostponedTypeAddCompassQueue() end)

    self.callbackController:RegisterCallback(HarvestEvents.NODE_ADDED_EVENT, self.onNodeAdded, self)
    self.callbackController:RegisterCallback(HarvestEvents.NODE_UPDATED_EVENT, self.onNodeUpdated, self)
    self.callbackController:RegisterCallback(HarvestEvents.NODE_DELETED_EVENT, self.onNodeDeleted, self)
    HarvestDebugUtils.debug("HarvestDbController controller started.")
end

---
-- Starts listening of callbacks and their processing.
--
function HarvestMapPinController:stop()
    EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinControllerPostponedAdd")
    EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinControllerPinTypeRefresh")
    EVENT_MANAGER:UnregisterForUpdate("HarvestMapPinControllerPinTypeRefreshCompass")

    self.callbackController:UnregisterCallback(HarvestEvents.NODE_ADDED_EVENT, self.onNodeAdded)
    self.callbackController:UnregisterCallback(HarvestEvents.NODE_UPDATED_EVENT, self.onNodeUpdated)
    self.callbackController:UnregisterCallback(HarvestEvents.NODE_DELETED_EVENT, self.onNodeDeleted)
    HarvestDebugUtils.debug("HarvestDbController controller stopped.")
end
