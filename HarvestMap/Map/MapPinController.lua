--- Controller which handles visibility of pins on map.
-- Resposibility:
-- Listen for new pins - add to map, depends harvesting respawn.
-- Listen for harvesting - implements respawn logic.
-- Settings update for pin types - toggle visibility for pins of type.
--
HarvestMapPinController = {}

--- Reference to LibMapPins.
local LMP = LibStub("LibMapPins-1.0")

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
        pinTypeNodesToAdd = {}, -- Cache of nodes to be displayed.
        queueTypeAddInterval = 50, -- Time interval to split add of pins by type.
        pinAddPerTickLimit = 30,
    }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

--- Queue for processing of actions.
local actionsQueue = {}

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

--- Displays single pin by its id when harvesting respaw time will be exceeded.
-- @param id unique identifier of node.
--
function HarvestMapPinController:postponePinAddAfterHarvesting(id)
    self.postponedAddPinQueue[id] = Harvest.GetHiddenTime() * 60 + GetTimeStamp() -- In secons enough
end

---
-- Callback method to handle event that node updated.
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

---
-- Callback method to handle event that new node added.
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

--- Registers all types of pins on map (for filtering and others).
function HarvestMapPinController:registerPinTypes()
    for _, pinType in pairs(Harvest.PINTYPES) do
        -- TODO investigate this more.
        local typeKey = Harvest.GetPinType(pinType)
        local localizedName = Harvest.GetLocalization("pintype" .. pinType)
        local pinLayout = HarvestMapUtils.getCurrentMapPinLayout(pinType)
        LMP:AddPinType(typeKey, function() self:onDisplayPinTypeOnMap(pinType) end, nil, pinLayout, Harvest.tooltipCreator)
        if pinType ~= Harvest.TOUR then
            assert(Harvest.savedVars["settings"].isPinTypeVisible, "SavedVars nil")
            local pveControl, pvpControl, imperialControl =
            LMP:AddPinFilter(typeKey, localizedName, false, Harvest.savedVars["settings"].isPinTypeVisible)
            local toggle = function(button, state) Harvest.SetPinTypeVisible(pinType, state) end
            ZO_CheckButton_SetToggleFunction(pveControl, toggle)
            ZO_CheckButton_SetToggleFunction(pvpControl, toggle)
            ZO_CheckButton_SetToggleFunction(imperialControl, toggle)
        end
        HarvestDebugUtils.debug("Filter of pin type <" .. localizedName .. "> registered")
    end
end

--- Callback for displaying of pins with spicified type on map.
-- @param type type of node - typeId.
function HarvestMapPinController:onDisplayPinTypeOnMap(type)
    if self.map == nil then return end
    local nodes = self.storage.getNodesListOfType(type)
    self.pinTypeNodesToAdd[type] = nodes
    if nodes ~= nil then
        HarvestDebugUtils.debug("Try display pin type <" .. Harvest.GetLocalization("pintype" .. type) .. ">. Total: " .. #self.pinTypeNodesToAdd[type])
    end
    -- self.storage.forNodesOfType(type, displayPin)
end

--- Callback function for OnWorldMapChanged callback.
-- @param map new map.
--
function HarvestMapPinController:onMapChanged(map)
    self.map = map
    -- Reset internal queues.
    self.postponedAddPinQueue = {}
    self.pinTypeNodesToAdd = {}
    -- Storage changed, but LMP still displays old pins
    for _, pinType in pairs(Harvest.PINTYPES) do
        local typeKey = Harvest.GetPinType(pinType)
        if LMP:IsEnabled(typeKey) then
            LMP:RefreshPins()
        end
    end
end

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

--- Iterates over queue with postponed pins by type and displays them if necessary.
function HarvestMapPinController:processPostponedTypeAddQueue()
    local types = self.pinTypeNodesToAdd
    local limit = self.pinAddPerTickLimit
    for type, typeNodes in pairs(types) do
        HarvestDebugUtils.debug(#typeNodes .. " pins of type " .. type .. " to be displayed.")
        if #typeNodes > 0 then
            local counter = 0
            for nodeIndex, nodeId in pairs(typeNodes) do
                if counter > limit then return end
                counter = counter + 1
                self:displayPinById(nodeId)
                typeNodes[nodeIndex] = nil
            end
        else
            HarvestDebugUtils.debug("All pins of type " .. type .. " displayed.")
            types[type] = nil
        end
    end
end

---
-- Starts listening of callbacks and their processing.
--
function HarvestMapPinController:start()
    self:registerPinTypes()

    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPostponedAdd", self.queueCheckInterval, function() self:processPostponedQueue() end)
    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPinTypeRefresh", self.queueTypeAddInterval, function() self:processPostponedTypeAddQueue() end)

    self.callbackController:RegisterCallback(HarvestEvents.NODE_ADDED_EVENT, self.onNodeAdded, self)
    self.callbackController:RegisterCallback(HarvestEvents.NODE_UPDATED_EVENT, self.onNodeUpdated, self)
    HarvestDebugUtils.debug("HarvestDbController controller started.")
end

---
-- Starts listening of callbacks and their processing.
--
function HarvestMapPinController:stop()
    self:registerPinTypes()

    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPostponedAdd")
    EVENT_MANAGER:RegisterForUpdate("HarvestMapPinControllerPinTypeRefresh")

    self.callbackController:UnregisterCallback(HarvestEvents.NODE_ADDED_EVENT, self.onNodeAdded)
    self.callbackController:UnregisterCallback(HarvestEvents.NODE_UPDATED_EVENT, self.onNodeUpdated)
    HarvestDebugUtils.debug("HarvestDbController controller stopped.")
end
