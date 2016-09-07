---
-- Controller for HarvestDB module. Responsibility of this controller is:
-- * handling of add/delete/update node requests.
-- NOTE: this module requires HarvestDB and must be loaded after it. Or fail in opposite case.
--
HarvestDbController = {}

-- TODO investigate howto avoid sending of map as parameter. Seems that it better to cache it inside an controller.
-- Seems that it used only in HarvestDB module to save nodes in static storage.
-- Also we need to have async entity which tracks changes of map (zone/location/level).


local NODE_DELETED_EVENT = HarvestEvents.NODE_DELETED_EVENT
local NODE_ADDED_EVENT = HarvestEvents.NODE_ADDED_EVENT
local NODE_UPDATED_EVENT = HarvestEvents.NODE_UPDATED_EVENT

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
-- @param id identifier of node.
--
function HarvestDbController:onDeleteNodeRequest(id)
    local type, timestamp, x, y, xg, yg, items = self.storage.deleteNode(id)
    self.callbackController:FireCallbacks(NODE_DELETED_EVENT, id, type)
end

---
-- Callback method to handle request to add node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param type type of detected node.
-- @param timestamp request firing time. In milliseconds.
-- @param items discovered items.
--
function HarvestDbController:onAddNodeRequest(x, y, xg, yg, type, timestamp, items)
    HarvestDebugUtils.debug("Try to add node with type " .. type)
    local id = self.storage.addNode(type, timestamp, x, y, xg, yg, items)
    self.callbackController:FireCallbacks(NODE_ADDED_EVENT, id)
    HarvestDebugUtils.debug("Node of type " .. type .. " with id: " .. id .. " successfully added.")
end

---
-- Callback method to handle request to update node.
-- @param id unique identifier of node.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param item discovered item.
--
function HarvestDbController:onUpdateNodeRequest(id, timestamp, x, y, xg, yg, item)
    HarvestDebugUtils.debug("Try to update node with id " .. id)
    self.storage.updateNode(id, timestamp, x, y, xg, yg, item)
    self.callbackController:FireCallbacks(NODE_UPDATED_EVENT, id)
    HarvestDebugUtils.debug("Node with id " .. id .. " update finished")
end

---
-- Starts listening of callbacks and their processing.
--
function HarvestDbController:start()
    self.callbackController:RegisterCallback(HarvestEvents.DELETE_NODE_REQUEST, self.onDeleteNodeRequest, self)
    self.callbackController:RegisterCallback(HarvestEvents.ADD_NODE_REQUEST, self.onAddNodeRequest, self)
    self.callbackController:RegisterCallback(HarvestEvents.UPDATE_NODE_REQUEST, self.onUpdateNodeRequest, self)
    -- TODO register for other callbacks
    HarvestDebugUtils.debug("HarvestDbController controller started.")
end

---
-- Stops listening of callbacks and their processing.
--
function HarvestDbController:stop()
    self.callbackController:UnregisterCallback(HarvestEvents.DELETE_NODE_REQUEST, self.onDeleteNodeRequest)
    self.callbackController:UnregisterCallback(HarvestEvents.ADD_NODE_REQUEST, self.onAddNodeRequest)
    self.callbackController:UnregisterCallback(HarvestEvents.UPDATE_NODE_REQUEST, self.onUpdateNodeRequest)
    HarvestDebugUtils.debug("HarvestDbController controller stopped.")
end
