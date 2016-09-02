---
-- Controller for HarvestDB module. Responsibility of this controller is:
-- * handling of add/delete/update node requests.
-- NOTE: this module requires HarvestDB and must be loaded after it. Or fail in opposite case.
--
HarvestDbController = {}

---
-- Constants to define names for operations callbacks. TODO better place to avoid unnecessary dependencies.
--

-- TODO investigate howto avoid sending of map as parameter. Seems that it better to cache it inside an controller.
-- Seems that it used only in HarvestDB module to save nodes in static storage.
-- Also we need to have async entity which tracks changes of map (zone/location/level).


local DELETE_NODE_REQUEST = HarvestEvents.DELETE_NODE_REQUEST
local NODE_DELETED_EVENT = HarvestEvents.NODE_DELETED_EVENT
local ADD_NODE_REQUEST = HarvestEvents.ADD_NODE_REQUEST
local NODE_ADDED_EVENT = HarvestEvents.NODE_ADDED_EVENT

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestDbController:new(s , c)
    local instance = { storage = s, callbackController = c }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

---
-- Callback method to handle request for node deletion.
-- @param map map which contain interest node.
-- @param nodeTag identifier of node. nodeTag in harvestDB context.
--
function HarvestDbController:onDeleteNodeRequest(map, nodeTag)
    local node = self.storage.GetNodeFromMap(map, nodeTag)
    local pinTypeId = node.pinTypeId -- TODO return node data with pinTypeId from DB. Not implemented yet
    self.storage.DeleteNode(map, nodeTag)

    local pinType = Harvest.GetPinType(pinTypeId)
    -- TODO Seems that we can avoid pinTypeId parameter for deletion of pin. By optimization of storages in ralted libraries.
    self.callbackController:FireCallbacks(NODE_DELETED_EVENT, nodeTag, pinType)
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

---
-- Callback method to handle request to add node.
-- @param map map which contain interest node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param measurement the measurement of the map, used to properly calculate distances between the new and the old pins
-- @param pinTypeId
-- @param itemId
--
function HarvestDbController:onAddNodeRequest(map, x, y, measurement, pinTypeId, itemId)
    if not validatePinData(map, x, y, measurement, pinTypeId, itemId) then
        return
    end
    local index, node = HarvestDB.SaveData(map, x, y, measurement, pinTypeId, itemId)
    self.callbackController:FireCallbacks(NODE_ADDED_EVENT, node.tag) -- TODO FIXME pinTag?
end

---
-- Starts listening of callbacks and their processing.
--
function HarvestDbController:start()
    self.callbackController:RegisterCallback(DELETE_NODE_REQUEST, self.onDeleteNodeRequest)
    self.callbackController:RegisterCallback(ADD_NODE_REQUEST, self.onAddNodeRequest)
    -- TODO register for other callbacks
end
