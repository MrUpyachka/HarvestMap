---
-- Contains names of events which used by Harvest and its submodules.
--
HarvestEvents = {}

------------------------------------------------------------------------------------------------------------------------
-- Requests ------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--- Name for request to delete node.
-- Required parameters:
-- @param map map which contain interest node.
-- @param nodeTag identifier of node. nodeTag in harvestDB context.
--
HarvestEvents.DELETE_NODE_REQUEST = "HARVEST_DELETE_NODE_REQUEST"

---
-- Name for request to add new node.
-- @param map map which contain detected node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param xg global abscissa of point.
-- @param yg global ordinate of point.
-- @param pinTypeId type of detected node.
-- @param timestamp request firing time. In milliseconds.
-- @param items discovered items.
--
HarvestEvents.ADD_NODE_REQUEST = "HARVEST_ADD_NODE_REQUEST"

---
-- Name for request to update existing node.
-- @param id unique identifier of node.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param item discovered item.
--
HarvestEvents.UPDATE_NODE_REQUEST = "HARVEST_UPDATE_NODE_REQUEST"

------------------------------------------------------------------------------------------------------------------------
-- Notifications -------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--- Name of event to notify that node with identifier and type removed from storage.
-- Parameters:
-- @param nodeTag identifier of node. nodeTag in harvestDB context.
-- @param pinType type of pin.
--
HarvestEvents.NODE_DELETED_EVENT = "HARVEST_NODE_DELETED_EVENT"

--- Name of event to notify that new node added to storage.
-- Parameters:
-- @param id identifier of node.
--
HarvestEvents.NODE_ADDED_EVENT = "HARVEST_NODE_ADDED_EVENT" -- TODO implement handlers

--- Name of event to notify that node in storage updated.
-- Parameters:
-- @param id identifier of node.
--
HarvestEvents.NODE_UPDATED_EVENT = "HARVEST_NODE_UPDATED_EVENT" -- TODO implement handlers

--- Notification from harvesting handler about finished process.
-- @param map map which contain detected node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param measurement the measurement of the map, used to properly calculate distances between the new and the old pins.
-- @param pinTypeId type of detected node.
-- @param timestamp timestamp in milliseconds.
-- @param itemId discovered item.
--
HarvestEvents.NODE_HARVESTED_EVENT = "NODE_HARVESTED_EVENT"
