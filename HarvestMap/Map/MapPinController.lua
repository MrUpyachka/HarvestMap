--- Controller which handles visibility of pins on map.
-- Resposibility:
-- Listen for new pins - add to map, depends harvesting respawn.
-- Listen for harvesting - implements respawn logic.
-- Settings update for pin types - toggle visibility for pins of type.
--
HarvestMapPinController = {}

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestMapPinController:new(s , c)
    local instance = { storage = s, callbackController = c }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

---
-- Callback method to handle event that node updated.
-- @param id unique identifier of node.
--
function HarvestDbController:onNodeUpdated(id)
    HarvestDebugUtils.debug("Node " .. id .. " updated. Check visibility.")
    -- TODO implement logic
end

---
-- Callback method to handle event that new node added.
-- @param id unique identifier of node.
--
function HarvestDbController:onNodeAdded(id)
    HarvestDebugUtils.debug("Node " .. id .. " added. Check visibility.")
    -- TODO implement logic
    local type, timestamp, x, y, xg, yg, items = self.storage.getNodeTuple(id)
end


---
-- Starts listening of callbacks and their processing.
--
function HarvestDbController:start()
    self.callbackController:RegisterCallback(HarvestEvents.NODE_ADDED_EVENT, self.onNodeAdded, self)
    self.callbackController:RegisterCallback(HarvestEvents.NODE_UPDATED_EVENT, self.onNodeUpdated, self)
    HarvestDebugUtils.debug("HarvestDbController controller started.")
end
