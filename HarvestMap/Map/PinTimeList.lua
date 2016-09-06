--- Contains list mapping of pin indentifiers to their time.
HarvestPinTimeList = {}
--- Creates an instance of list.
function HarvestPinTimeList:new()
    local instance = { list = {} }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

--- Adds identifier and time for it to list.
-- @param id
-- @param time
--
function HarvestPinTimeList:add(id, time)
    self.list[id] = time
end

--- Returns time for specified id from list
-- @paran id pin identifier.
--
function HarvestPinTimeList:getTime(id)
    return self.list[id]
end

--- Removes identifier and its time from list.
-- @paran id pin identifier.
--
function HarvestPinTimeList:delete(id)
    self.list[id] = nil
end
