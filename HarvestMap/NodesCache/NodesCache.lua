---
-- Implementation of cache for Harvest nodes.
-- Responsibility:
-- Fast access to node data by its identifier.
-- Not in resposibility:
-- Generation of node identifier. -- TODO separate generator of id for nodes.
-- Sorting/Indexation by any characteristic. -- TODO another implementations of cache, with index by type, for example.
--
HarvestNodesCache = {}

-- TODO list of maps with their list of pins by id
-- TODO list of divisions by their id
-- TODO Container with lists of nodes properties

--- Function to initialize lists.
--
function HarvestNodesCache:initialize()
    -- Hash maps. pin tag used as key.
    self.types = {} -- Actually its typeId's list
    self.timestamps = {} -- Time of last activity with node. In milliseconds.
    self.xLocals = {}
    self.yLocals = {}
    self.xGlobals = {}
    self.yGlobals = {}
    self.items = {}
    --[[ Each element  in <items> represents table:
    -- { {item1, harvestTime1},
    --   {item2, harvestTime2},
    --   ... and so on.
    -- }
     ]]
end

--- Creates an instance of cache.
-- @param m target map instance.
-- @param o options for cache.
--
function HarvestNodesCache:new(m , o)
    local instance = { map = m, options = o }
    self.__index = self
    setmetatable(instance, self)
    instance:initialize()
    return instance
end


--- Adds data to cache.
-- @param id node identifier.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age. In milliseconds.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param items items which could be found in this node.
--
function HarvestNodesCache:add(id, type, timestamp, x, y, xg, yg, items)
    self.types[id] = type
    self.timestamps[id] = timestamp
    self.xLocals[id] = x
    self.yLocals[id] = y
    self.xGlobals[id] = xg
    self.yGlobals[id] = yg
    self.items[id] = items
end

--- Removes data from cache.
-- @param id node identifier.
-- @return type type of node - typeId.
-- @return timestamp timestamp for tracking of age. In milliseconds.
-- @return x local abscissa of node.
-- @return y local ordinate of node.
-- @return xg global abscissa of node.
-- @return yg global ordinate of node.
-- @return items items table with timestamps: {itemId, timestamp} pairs.
--
function HarvestNodesCache:delete(id)
    local type = self.types[id]
    local timestamp = self.timestamps[id]
    local x = self.xLocals[id]
    local y = self.yLocals[id]
    local xg = self.xGlobals[id]
    local yg = self.yGlobals[id]
    local items = self.items[id]

    self.types[id] = nil
    self.timestamps[id] = nil
    self.xLocals[id] = nil
    self.yLocals[id] = nil
    self.xGlobals[id] = nil
    self.yGlobals[id] = nil
    self.items[id] = nil
    return type, timestamp, x, y, xg, yg, items
end

