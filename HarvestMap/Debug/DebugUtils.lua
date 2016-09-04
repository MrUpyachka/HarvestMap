--- Utility tools for debugging
HarvestDebugUtils = {}

--- Prints execution time of function as debug message.
-- @param func function to execute
--
function HarvestDebugUtils.measureExecutionTime(func)
    local startTime = os.time()
    func()
    HarvestDebugUtils.debug("Time of execution: " .. (os.time() - startTime))
end

--- Helper function to only display debug messages if the debug mode is enabled
function HarvestDebugUtils.debug(message)
    -- TODO better toggling of debug
    if Harvest and (Harvest.AreDebugMessagesEnabled and Harvest.AreDebugMessagesEnabled() or Harvest.AreVerboseMessagesEnabled and Harvest.AreVerboseMessagesEnabled()) then
        d(message)
    end
end

---
-- Validates input data of any pin update event.
-- @param map map which contain node.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param measurement the measurement of the map, used to properly calculate distances between the new and the old pins.
-- @param pinTypeId type of node.
-- @param items discovered items.
-- @return true for valid data, false for empty or values with wrong format.
--
function HarvestDebugUtils.validatePinData(map, x, y, measurement, pinTypeId, items)
    if not map then
        HarvestDebugUtils.debug("Validation of data failed: map is nil")
        return false
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        HarvestDebugUtils.debug("Validation of data failed: coordinates aren't numbers: " .. type(x) .. " " .. type(y))
        return false
    end
    if not measurement then
        HarvestDebugUtils.debug("Validation of data failed: measurement is nil")
        return false
    end
    if not pinTypeId then
        HarvestDebugUtils.debug("Validation of data failed: pin type id is nil")
        return false
    end
    -- If the map is on the blacklist then don't save the data
    if Harvest.IsMapBlacklisted(map) then
        HarvestDebugUtils.debug("Validation of data failed: map " .. tostring(map) .. " is blacklisted")
        return false
    end
    return true -- Everything ok.
end
