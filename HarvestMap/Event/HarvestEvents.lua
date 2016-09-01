---
-- Contains names of events which used by Harvest and its submodules.
--
HarvestEvents = {}

--- Name for request to delete node.
-- Required parameters:
-- @param map map which contain interest node.
-- @param nodeTag identifier of node. nodeTag in harvestDB context.
--
HarvestEvents.DELETE_NODE_REQUEST = "HARVEST_DELETE_NODE_REQUEST"

HarvestEvents.UPDATE_NODE_REQUEST = "HARVEST_UPDATE_NODE_REQUEST" -- TODO implement

HarvestEvents.ADD_NODE_REQUEST = "HARVEST_ADD_NODE_REQUEST" -- TODO implement

--- Name of event to notify that pin with identifier and type removed.
-- Parameters:
-- @param nodeTag identifier of node. nodeTag in harvestDB context.
-- @param pinType type of pin.
--
HarvestEvents.NODE_DELETED_EVENT = "HARVEST_NODE_DELETED_EVENT"

HarvestEvents.NODE_ADDED_EVENT = "HARVEST_NODE_ADDED_EVENT" -- TODO implement

HarvestEvents.NODE_UPDATED_EVENT = "HARVEST_NODE_UPDATED_EVENT" -- TODO implement

