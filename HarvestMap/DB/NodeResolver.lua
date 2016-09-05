--- Implements logic to resolve node data as an existing node.
-- Handles async events and fires async requests to add/update node.
--
HarvestNodeResolver = {}

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
-- @param o the measurement of the map, used to properly calculate distances between the new and the old pins.
-- TODO create resolver on each change of map. Use options to store measurements of map.
function HarvestNodeResolver:new(s, c, o)
    local instance = { storage = s, callbackController = c, options = o }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

---
-- Callback method to handle data about harvested node.
-- @param map map which contain detected node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param measurement the measurement of the map, used to properly calculate distances between the new and the old pins.
-- @param type type of detected node.
-- @param timestamp event time. In milliseconds.
-- @param item discovered item.
--
function HarvestNodeResolver:onHarvested(map, x, y, measurement, type, timestamp, item)
    HarvestDebugUtils.debug("Try to resolve node data for type " .. type)
    if not HarvestDebugUtils.validatePinData(map, x, y, measurement, type, item) then
        HarvestDebugUtils.debug("See validation errors")
        return
    end
    local xGlobal, yGlobal = HarvestMapUtils.convertLocalToGlobal(x, y, measurement)
    -- TODO get close by type.
    -- TODO assert that such type loaded to cache from save file.
    local existingId = self.storage.getCloseNodeOfType(x, y, xGlobal, yGlobal, type)
    if existingId then
        HarvestDebugUtils.debug("Node already exist: " .. existingId .. ". Notify to update.")
        -- node exist. Request update of its data.
        self.callbackController:FireCallbacks(HarvestEvents.UPDATE_NODE_REQUEST, existingId, timestamp, x, y, xGlobal, yGlobal, item)
    else
        HarvestDebugUtils.debug("New node detected. Notify to add.")
        -- new node detected. Request its saving.
        local items
        -- Prepare items ID's list if necessary.
        if ItemUtils.isItemsListRequired(type) then
            items = { [item] = timestamp }
        end
        self.callbackController:FireCallbacks(HarvestEvents.ADD_NODE_REQUEST, map, x, y, xGlobal, yGlobal, type, timestamp, items)
    end
end

--- Starts listening of callbacks and their processing.
function HarvestNodeResolver:start()
    self.callbackController:RegisterCallback(HarvestEvents.NODE_HARVESTED_EVENT, self.onHarvested, self)
    -- TODO register for other callbacks. Troves, chests and others.
    HarvestDebugUtils.debug("HarvestNodeResolver started.")
end
--- Stops listening of callbacks and their processing.
function HarvestNodeResolver:stop()
    self.callbackController:UnregisterCallback(HarvestEvents.NODE_HARVESTED_EVENT, self.onHarvested, self)
    HarvestDebugUtils.debug("HarvestNodeResolver stopped.")
end
