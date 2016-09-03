--- Implements cache which provides faster access for nearest nodes.
LocationSortedCache = {}

--- Function to initialize lists.
--
function LocationSortedCache:initialize()
    -- Hash maps. pin tag used as key.
    self.locations = {} -- Acces to any location by X and Y.
    self.locationSize = self.options.locationSize
    self.locationScale = self.options.locationScale
end

--- Creates an instance of cache.
-- @param m target map instance.
-- @param o options for cache.
--
function LocationSortedCache:new(m , o)
    local instance = { map = m, options = o }
    self.__index = self
    setmetatable(instance, self)
    instance:initialize()
    return instance
end

local modf = math.modf

--- Adds node to cache depends on its coordinates.
-- @param id node identifier.
-- @param x abscissa of node.
-- @param y ordinate of node.
--
function LocationSortedCache:add(id, x, y)
    local row = modf(x*self.locationScale)
    local column = modf(y*self.locationScale)
    local key = row + column*self.locationSize
    local location = self.locations[key] or {}
    self.locations[key] = location
    location[#location + 1] = id
    Harvest.Debug("R: " .. row .. " C: " .. column)
end
