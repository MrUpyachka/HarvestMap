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

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestDbController:new(s , c)
    local instance = { storage = s, callbackController = c }
    self.__index = self
    setmetatable(instance, self)
    instance:initialize()
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
-- Starts listening of callbacks and their processing.
--
function HarvestDbController:start()
    self.callbackController:RegisterCallback(DELETE_NODE_REQUEST, self.onDeleteNodeRequest)
    -- TODO register for other callbacks
end
