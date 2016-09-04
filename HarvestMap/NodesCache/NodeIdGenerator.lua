---
-- Used to generate unique identifier for specified node data.
--
HarvestNodeIdGenerator = {}

--- Creates an instance of generator.
--
function HarvestNodeIdGenerator:new()
    local instance = { lastId = 0 }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

--- Generates unique identifier for specified node data.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param item item which found inside
-- @return unique identifier. !!!NOTE!!!: Not number, but string.
--
function HarvestNodeIdGenerator:generate(type, timestamp, x, y, xg, yg, item)
    self.lastId = self.lastId + 1
    return self.lastId
end
