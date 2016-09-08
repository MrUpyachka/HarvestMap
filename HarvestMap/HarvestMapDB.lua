if not HarvestDB then
    HarvestDB = {}
end

local HarvestDB = _G["HarvestDB"]
local AS = LibStub("AceSerializer-3.0h")

--[[
--  The HarvestMap database consists of two parts:
--  1) the persistent savedVariables tables, which stores ACE serialized data
--  2) a cache table, which stores deserialized data allowing for faster read access
--
--  The structure of the serialized data must not be changed as there are external
--  programs and tools which rely on the current structure. (for instance the harvest merge website)
--
--  The datastructure used for the cached data can be changed in future updates.
--  It is only important that the cached data allows the following API functions to
--  be implemented in an efficient way.
--  All functions of the form HarvestDB.functionname are API functions.
--
--  Notes on the nodeTag:
--  A nodeTag is a unique identifier for a node. It could for instance be some index of the node in the database.
--  (right now the nodeTag is just the node itself in form of a table, because the datastructure of the cache isn't optimized yet)
--  The nodeTag is NOT called nodeIndex because the term/variablename nodeIndex is already used for the serialized data.
--  The nodeTag is identical to the pinTag used for the pin libraries.
--
--  Serialized data structure:
--  nodes = {
--  	firstLoaded = timestamp,
--  	lastLoaded = timestamp,
--  	dataVersion = versionNumber,
--  	data = {
--  		[map] = {
--  			[pinTypeId] = {
--  				[nodeIndex] = ACE (serialized data),
--  			}
--  		}
--  	}
--  }
--
--  right now the structure of the cache is like this:
--  cache = {
--  	[map] = {
-- 			[pinTypeId] = {
-- 				[nodeIndex] = {
-- 					data = {x, y, nil, {[itemId] = itemTimestamp}, timestamp, version}, -- deserialzed ACE string
-- 					time = hiddenTime,
-- 					hidden = isHidden,
--  				global = { globalX, globalY }
-- 				}
-- 			}
--  	}
--  }
--
--]]


local GetSubDivisionCoords, GetSubDivision, loadDivisionsOnMap
local GetNearestNodeIndex, ShouldMergeNodes, LoadToCache, Serialize, Deserialize
local CheckNodeVersion, GetSaveFile, GetSpecialSaveFile, IsNodeValid

-- TODO split module for several files. All iterators could be initialized separately. Root module should contain only "interface"


------------------------------------------------------------------------------------------------------------------------
-- Cache related logic -------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--[[
-- TODO list ( to not forget tomorrow ):
 - Check fields what we need in runtime and in static storage, seems that there is an difference -
 - Check todo's that all critical issues fixed -
 ]]
---
-- Generator of identifiers for nodes.
--
local idGenerator = HarvestNodeIdGenerator:new()

------------------------------------------------------------------------------------------------------------------------

--- Table with cached types of pins.
local cachedTypes = {}

------------------------------------------------------------------------------------------------------------------------
--- Checks that type already cached or not.
-- @param type node type - typeId.
-- @return true if nodes of these type already cached. false in opposite case.
--
local function isTypeCached(type)
    return cachedTypes[type]
end

local function setTypeCached(type, cached)
    cachedTypes[type] = cached
end

local function setAllTypesNotCached()
    cachedTypes = {}
end

------------------------------------------------------------------------------------------------------------------------
---
-- Cache of nodes indexed by nodes identifiers.
-- Contains node for current map, uses options(measurments).
--
local idCache

--- @return cache indexed by node identifiers.
function HarvestDB.getIdCache()
    return idCache
end

---
-- Cache of nodes indexed by their location.
-- Contains node for current map, uses options(measurments).
--
local locationCache

---
-- Cache of nodes indexed by their type.
--
local typeCache

--- General propeties of current map.
local map, options

------------------------------------------------------------------------------------------------------------------------
--- Check that cache for specified map exists and creates if not.
-- @param m target map instance.
-- @param o options for cache.
--
function HarvestDB.checkAndUpdateCache(m, o)
    map = m
    options = o

    -- if current cache not related with current map - create new one.
    -- TODO we can persist list of last previous caches
    -- if there is no cache - create.
    if idCache and map ~= idCache.map or not idCache then
        local o = ZO_DeepTableCopy(options) -- Options should be immutable for cache. To avoid unexpected behaviour.
        idCache = HarvestNodesCache:new(map, o)
        -- Create other caches together with idCache.
        locationCache = LocationSortedCache:new(map, { locationSize = 10, locationScale = 100 }) -- TODO FIXME proper processing of options.

        typeCache = {}

        setAllTypesNotCached() -- as soon as cache empty - there is no any cached type of nodes.
        HarvestDebugUtils.debug("Storage configured for " .. map .. ". All caches reset.")
    end
    -- TODO check other types of cache
end

------------------------------------------------------------------------------------------------------------------------
--- Duplicates node data to save file for specified map and node type.
-- @param id unique identifier of node.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param items items which could be found in this node.
--
local function updateSaveFile(id, type, timestamp, x, y, xg, yg, items)
    local map = idCache.map -- TODO cache map reference somewhere else.
    local dataToSerialize = { x, y, nil, items, timestamp / 3600000, Harvest.nodeVersion } -- Timestamp in hours enough for save file. TODO check back conversion on deserialization
    -- TODO investigate NodeVersion and adapter for different nodes versions. Better no ignore old versions if its impossible to convert them once.
    local saveFile = GetSaveFile(map)
    local mapData = saveFile.data[map] or {} -- save file tables might not exist yet
    saveFile.data[map] = mapData
    local typeOnMapData = mapData[type] or {} -- save file tables might not exist yet
    mapData[type] = typeOnMapData

    -- the third entry used to be the node name, but that data isn't used anymore. so save nil instead
    typeOnMapData[#typeOnMapData + 1] = Serialize(dataToSerialize) -- TODO FIXME calculate id in save file. Avoid usage of id from cache. Not tested.
end

------------------------------------------------------------------------------------------------------------------------
--- Adds data to all caches.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param items items which could be found in this node.
-- @return generated identifier of added node.
--
local function addNodeToCache(type, timestamp, x, y, xg, yg, items)
    assert(type, "Type of node to add cannot be empty")
    assert(timestamp, "Timestamp of node to add cannot be empty")
    assert(x, "X of node to add cannot be empty")
    assert(y, "Y of node to add cannot be empty")
    assert(xg, "Global X of node to add cannot be empty")
    assert(yg, "Global Y of node to add cannot be empty")
    local id = idGenerator:generate(type, timestamp, x, y, xg, yg, items)

    idCache:add(id, type, timestamp, x, y, xg, yg, items)

    -- Add to location cache
    locationCache:add(id, xg, yg)

    -- Add to type cache
    local typeNodes = typeCache[type] or {}
    typeCache[type] = typeNodes
    typeNodes[#typeNodes + 1] = id
    return id
end

------------------------------------------------------------------------------------------------------------------------
---
-- Merges information about items.
-- @param type type of node - typeId.
-- @param sourceItemsData existing information.
-- @param timestamp timestamp for tracking of age.
-- @param item discovered item.
-- @return new data for node.
--
local function mergeItemsData(type, sourceItemsData, item, timestamp)
    local result = sourceItemsData or {}
    -- update the timestamp of the nodes items
    if item and ItemUtils.isItemsListRequired(type) then
        result[item] = timestamp
    end
    return result
end

------------------------------------------------------------------------------------------------------------------------
--- Updates data of node in caches.
-- @param id unique identifier of node.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param item discovered item.
--
function HarvestDB.updateNodeInCache(id, timestamp, x, y, xg, yg, item)
    assert(id, "ID of node for update cannot be empty")
    assert(timestamp, "Timestamp for node to update cannot be empty")
    assert(x, "X of node for update cannot be empty")
    assert(y, "Y of node for update cannot be empty")
    assert(xg, "Global X for node to update cannot be empty")
    assert(yg, "Global Y for node to update cannot be empty")
    idCache.timestamps[id] = timestamp
    idCache.xLocals[id] = x
    idCache.yLocals[id] = y
    idCache.xGlobals[id] = xg
    idCache.yGlobals[id] = yg
    idCache.items[id] = mergeItemsData(idCache.types[id], idCache.items[id], item, timestamp)
end

local updateNodeInCache = HarvestDB.updateNodeInCache

------------------------------------------------------------------------------------------------------------------------
--- Deletes node from caches.
-- @param id unique identifier of node.
-- @return type type of node - typeId.
-- @return timestamp timestamp for tracking of age.
-- @return x local abscissa of node.
-- @return y local ordinate of node.
-- @return xg global abscissa of node.
-- @return yg global ordinate of node.
-- @return items items table with timestamps: {itemId, timestamp} pairs.
--
local function deleteNodeFromCache(id)
    local type, timestamp, x, y, xg, yg, items = idCache:delete(id) -- TODO supress local variables.

    -- Delete from location cache.
    local closestLocations = locationCache:getClosestLocations(xg, yg)
    local dx, dy

    for _, location in pairs(closestLocations) do
        for index, nodeId in pairs(location) do
            if nodeId == id then
                location[index] = nil
                break
            end
        end
    end

    -- Delete from type cache
    local typeNodes = typeCache[type]
    for index, identifier in pairs(typeNodes) do
        if id == identifier then
            typeNodes[index] = nil
            break
        end
    end
    return type, timestamp, x, y, xg, yg, items
end

------------------------------------------------------------------------------------------------------------------------
-- Cache related logic END ---------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- BEGIN Interface of storage to be used by controllers ----------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--- Adds new node.
-- @param type type of node - typeId.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param items items which could be found in this node.
-- @return generated identifier of added node.
--
function HarvestDB.addNode(type, timestamp, x, y, xg, yg, items)
    local id = addNodeToCache(type, timestamp, x, y, xg, yg, items)
    updateSaveFile(id, type, timestamp, x, y, xg, yg, items)
    return id
end

--- Updates data of node.
-- @param id unique identifier of node.
-- @param timestamp timestamp for tracking of age.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xg global abscissa of node.
-- @param yg global ordinate of node.
-- @param item discovered item.
--
function HarvestDB.updateNode(id, timestamp, x, y, xg, yg, item)
    updateNodeInCache(id, timestamp, x, y, xg, yg, item)
    updateSaveFile(id, idCache.types[id], timestamp, x, y, xg, yg, idCache.items[id])
end

------------------------------------------------------------------------------------------------------------------------
--- Deletes node.
-- @param id unique identifier of node.
-- @return type type of node - typeId.
-- @return timestamp timestamp for tracking of age.
-- @return x local abscissa of node.
-- @return y local ordinate of node.
-- @return xg global abscissa of node.
-- @return yg global ordinate of node.
-- @return items items table with timestamps: {itemId, timestamp} pairs.
--
function HarvestDB.deleteNode(id)
    local type, timestamp, x, y, xg, yg, items = deleteNodeFromCache(id)
    local map = idCache.map -- TODO cache map reference somewhere else.
    local saveFile = GetSaveFile(map)
    saveFile.data[map][type][id] = nil
    return type, timestamp, x, y, xg, yg, items
end

------------------------------------------------------------------------------------------------------------------------
--- Returns close node depends on minimum distance. NOTE: its not clossest node.
-- @param x local abscissa of node.
-- @param y local ordinate of node.
-- @param xGlobal abscissa of node.
-- @param yGlobal ordinate of node.
-- @param type interest type of node.
-- @return node identifier or nil if no node found in close area.
--
function HarvestDB.getCloseNodeOfType(x, y, xGlobal, yGlobal, type)
    -- TODO cache constants.
    local minDistance = Harvest.GetMinDistanceBetweenPins()
    local globalMinDistance = Harvest.GetGlobalMinDistanceBetweenPins()
    local closestLocations = locationCache:getClosestLocations(xGlobal, yGlobal)
    local dx, dy
    for _, location in pairs(closestLocations) do
        -- For each location.
        for __, id in pairs(location) do
            -- For each node in location.
            if idCache.types[id] == type then
                -- Only if node has specified type.
                dx = idCache.xLocals[id] - x
                dy = idCache.yLocals[id] - y
                -- Check local and global distance.
                if dx * dx + dy * dy < minDistance then
                    return id
                end
                dx = idCache.xGlobals[id] - xGlobal
                dy = idCache.yGlobals[id] - yGlobal
                if dx * dx + dy * dy < globalMinDistance then
                    return id
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------------------------------------------------------------------
--- Returns node data as tuple.
-- @param id unique identifier of node.
-- @return type type of node - typeId.
-- @return timestamp timestamp for tracking of age.
-- @return x local abscissa of node.
-- @return y local ordinate of node.
-- @return xg global abscissa of node.
-- @return yg global ordinate of node.
-- @return items items table with timestamps: {itemId, timestamp} pairs.
--
function HarvestDB.getNodeTuple(id)
    return idCache.types[id], idCache.timestamps[id], idCache.xLocals[id], idCache.yLocals[id],
    idCache.xGlobals[id], idCache.yGlobals[id], idCache.items[id]
end

------------------------------------------------------------------------------------------------------------------------
--- Loads nodes of specified type if they are not loaded yet.
-- @param type type of nodes - typeId.
--
function HarvestDB.loadNodesOfTypeIfNecessary(type)
    if not isTypeCached(type) then
        HarvestDB.loadDivisionsOnMapTODOrework(type, map, options)
        --HarvestDebugUtils.debug("Pins of type " .. Harvest.GetLocalization("pintype" .. type) .. " loaded to cache.")
    else
        -- HarvestDebugUtils.debug("Pins of type " .. Harvest.GetLocalization("pintype" .. type) .. " already loaded to cache. Avoid multiple loading.")
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Returns copy of list from cache of nodes by their type.
-- @param type type of node - typeId.
-- @return list with nodes identifiers.
--
function HarvestDB.getNodesListOfType(type)
    HarvestDB.loadNodesOfTypeIfNecessary(type)
    local typeData = typeCache[type]
    if typeData ~= nil then
        return ZO_DeepTableCopy(typeCache[type])
    else
        return nil
    end
end

------------------------------------------------------------------------------------------------------------------------
-- END Interface of storage to be used by controllers ------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

---
-- executes the callback function for each node that is close to the given position
-- this is for instance used by the respawn timer to hide nodes that are visited by the player
-- so while "close" doesn't have a strict definitions but it's something like within 5 or 10m
-- @param map the map whose nodes we want to iterate over
-- @param x position in relative map coordinates
-- @param y position in relative map coordinates
-- @param measurement measurement of the current map
-- @param callback a function of form function(nodeTag, pinTypeId) ... end, which is executed for each close pin
function HarvestDB.ForCloseNodes(map, x, y, measurement, callback)
    local minDistance = Harvest.GetMinDistanceBetweenPins()
    local divisionX, divisionY = GetSubDivisionCoords(x, y, measurement)
    local dx, dy, divisions, division, nodeTag

    for _, pinTypeId in pairs(Harvest.PINTYPES) do
        divisions = GetSubDivisionOnMap(pinTypeId, map)
        division = GetSubDivision(divisions, divisionX, divisionY)
        for i = -1, 1 do -- the player might be near the border of a division, so check the directly adjacent divisions as well
        for j = -1, 1 do
            division = GetSubDivision(divisions, divisionX + i, divisionY + j)
            if division then
                for nodeIndex, node in pairs(division) do
                    dx = x - node.data[Harvest.X]
                    dy = y - node.data[Harvest.Y]
                    if dx * dx + dy * dy < minDistance then
                        nodeTag = node
                        callback(nodeTag, pinTypeId)
                    end
                end
            end
        end
        end
    end
end

---
-- executes the callback function for each node of the given pinType that is within vision range
-- (this doesn't have to be exactly the vision radius, there can be a few more pins if that improves the performance)
-- @param map the map whose nodes we want to iterate over
-- @param x position in relative map coordinates
-- @param y position in relative map coordinates
-- @param measurement measurement of the current map
-- @param pinTypeId the pinType we want to iterate over
-- @param callback a function of form function(nodeTag, pinTypeId) ... end, which is executed for each pin
function HarvestDB.ForVisibleNodesOfPinType(map, x, y, measurement, pinTypeId, callback)
    local divisionX, divisionY = GetSubDivisionCoords(x, y, measurement)
    local divisions, division, nodeTag

    if not isTypeCached(pinTypeId) then return end

    divisions = GetSubDivisionsOnMap(pinTypeId, map, measurement)
    for i = -2, 2 do
        for j = -2, 2 do
            division = GetSubDivision(divisions, divisionX + i, divisionY + j)
            if division then
                for nodeIndex, node in pairs(division) do
                    nodeTag = node
                    callback(nodeTag, pinTypeId)
                end
            end
        end
    end
end

---
-- creates an iterator object, which will iterate over the same pins as the function ForVisibleNodesOfPinType
-- the iterator object has the function iterator:run(numNodes, callback) which will call the callback for the
-- next numNodes nodes. the iterator:run(numNodes, callback) returns true, when all nodes have been iterated over.
-- @param map
-- @param x
-- @param y
-- @param measurement
-- @param pinTypeId
--
function HarvestDB.IteratorForVisibleNodesOfPinType(map, x, y, measurement, pinTypeId)
    local iterator = {}
    iterator.divisionX, iterator.divisionY = GetSubDivisionCoords(x, y, measurement)

    iterator.divisions = GetSubDivisionsOnMap(pinTypeId, map, measurement)
    iterator.i = -2
    iterator.j = -2
    iterator.division = GetSubDivision(iterator.divisions,
        iterator.divisionX + iterator.i, iterator.divisionY + iterator.j)

    iterator.run = function(self, numNodes, callback)
        local next = _G["next"]
        while numNodes > 0 do
            -- most inner loop of the ForVisibleNodesOfPinType function
            if self.division then
                self.nodeIndex, self.nodeTag = next(self.division, self.nodeIndex)
            end
            if self.nodeIndex then
                callback(self.nodeTag, pinTypeId)
                numNodes = numNodes - 1
                if numNodes == 0 then
                    -- break the iterator, as numNodes were iterated over
                    -- the iterator can be continued via iterator:run(nodes, callback)
                    return false
                end
            else
                -- from most inner to the most outer loop
                self.j = self.j + 1
                if self.j <= 2 then
                    self.division = GetSubDivision(self.divisions,
                        self.divisionX + self.i, self.divisionY + self.j)
                else
                    self.j = -2
                    self.i = self.i + 1
                    if self.i > 2 then -- most outer loop has finished
                    return true -- iterator has finished
                    end
                end
            end
        end
    end

    return iterator
end

---
-- executes the callback function for each node that is within vision range
-- (this doesn't have to be exactly the vision radius, there can be a few more pins if that improves the performance)
-- @param map the map whose nodes we want to iterate over
-- @param x position in relative map coordinates
-- @param y position in relative map coordinates
-- @param measurement measurement of the current map
-- @param callback a function of form function(nodeTag, pinTypeId) ... end, which is executed for each pin
function HarvestDB.ForVisibleNodes(map, x, y, measurement, callback)
    local divisionX, divisionY = GetSubDivisionCoords(x, y, measurement)
    local divisions, division, nodeTag

    for _, pinTypeId in pairs(Harvest.PINTYPES) do
        divisions = GetSubDivisionsOnMap(pinTypeId, map, measurement)
        for i = -2, 2 do
            for j = -2, 2 do
                division = GetSubDivision(divisions, divisionX + i, divisionY + j)
                if division then
                    for nodeIndex, node in pairs(division) do
                        nodeTag = node
                        callback(nodeTag, pinTypeId)
                    end
                end
            end
        end
    end
end


function HarvestDB.ForPrevAndCurVisiblePinsOfPinType(map, previousX, previousY, currentX, currentY, measurement,
pinTypeId, previousCallback, currentCallback)

    local prevDivisionX, prevDivisionY = GetSubDivisionCoords(previousX, previousY, measurement)
    local curDivisionX, curDivisionY = GetSubDivisionCoords(currentX, currentY, measurement)
    if prevDivisionX == curDivisionX and prevDivisionY == curDivisionY then
        return
    end

    local divisions = GetSubDivisionsOnMap(pinTypeId, map, measurement)
    local division, nodeTag
    -- first iteratoe over all pins that are no longer visible
    for divisionX = prevDivisionX - 2, prevDivisionX + 2 do
        for divisionY = prevDivisionY - 2, prevDivisionY + 2 do
            -- check if the division is not part of the currently visible divisions
            if zo_abs(divisionX - curDivisionX) > 2 or zo_abs(divisionY - curDivisionY) > 2 then
                division = GetSubDivision(divisions, divisionX, divisionY)
                if division then
                    for nodeIndex, node in pairs(division) do
                        nodeTag = node
                        previousCallback(nodeTag, pinTypeId)
                    end
                end
            end
        end
    end
    -- now iterator over all pins that are visible from the current position but not from the previous position
    for divisionX = curDivisionX - 2, curDivisionX + 2 do
        for divisionY = curDivisionY - 2, curDivisionY + 2 do
            -- check if the division is not part of the previously visible divisions
            if zo_abs(divisionX - prevDivisionX) > 2 or zo_abs(divisionY - prevDivisionY) > 2 then
                division = GetSubDivision(divisions, divisionX, divisionY)
                if division then
                    for nodeIndex, node in pairs(division) do
                        nodeTag = node
                        currentCallback(nodeTag, pinTypeId)
                    end
                end
            end
        end
    end
end

function HarvestDB.ForAllNodesOfPinType(map, measurement, pinTypeId, callback)
    local divisions = GetSubDivisionsOnMap(pinTypeId, map, measurement)
    local nodeTag
    for _, division in pairs(divisions) do
        if type(division) == "table" then -- .width key should be skipped
        for nodeIndex, node in pairs(division) do
            nodeTag = node
            callback(nodeTag, pinTypeId)
        end
        end
    end
end

function HarvestDB.ForAllNodes(map, measurement, callback)
    for _, pinTypeId in pairs(Harvest.PINTYPES) do
        HarvestDB.ForAllNodesOfPinType(map, measurement, pinTypeId, callback)
    end
end


function HarvestDB.GetPosition(nodeTag)
    local nodeData = nodeTag.data
    return nodeData[Harvest.X], nodeData[Harvest.Y]
end


function HarvestDB.GetGlobalPosition(nodeTag)
    local node = nodeTag
    return node.global[Harvest.X], node.global[Harvest.Y]
end

function HarvestDB.IsHidden(nodeTag)
    local node = nodeTag
    return node.hidden
end

function HarvestDB.SetHidden(nodeTag, value)
    if not HarvestDB.IsHidden(nodeTag) then
        HarvestDB.SetVisitedTime(nodeTag, GetFrameTimeSeconds())
    end
    local node = nodeTag
    node.hidden = false
end

---
-- sets the time for the respawn timer.
-- @param nodeTag
-- @param time
--
function HarvestDB.SetVisitedTime(nodeTag, time)
    local node = nodeTag
    node.time = time
end

---
-- generates the {[itemId] = timestamp} table for the node represented by the given nodeTag
-- this function is only called, when the mouse is above a pin and the tooltip needs to be created.
-- @param id
--
function HarvestDB.GenerateItemTable(id)
    return idCache.items[id]
end

---
-- this imports data given in serialized form into the correct savefiles
-- @param map from which map the data is importet
-- @param data the serialized data that has to be imported
-- @param target the serialized data that receives the new data
-- @param checkPinType if true, data will be skipped if Harvest.IsPinTypeSavedOnImport(pinTypeId) returns false
function HarvestDB.ImportFromMap(map, data, target, checkPinType)
    local insert = table.insert
    local pairs = _G["pairs"]
    local zo_max = _G["zo_max"]
    local type = _G["type"]
    local next = _G["next"]

    -- nothing to merge, data can simply be copied
    if target.data[map] == nil then
        target.data[map] = data
        return
    end
    -- the target table contains already a bunch of nodes, so the data has to be merged
    local targetData
    local newNode
    local index = 0
    local oldNode
    local timestamp = Harvest.GetCurrentTimestamp()
    for _, pinTypeId in pairs(Harvest.PINTYPES) do
        if (not checkPinType) or Harvest.IsPinTypeSavedOnImport(pinTypeId) then
            if target.data[map][pinTypeId] == nil then
                -- nothing to merge for this pin type, just copy the data
                target.data[map][pinTypeId] = data[pinTypeId]
            else
                -- deserialize target data and clear the serialized target data table (we'll fill it again at the end)
                targetData = {}
                for _, node in pairs(target.data[map][pinTypeId]) do
                    node = Deserialize(node)
                    if node then -- check if something went wrong while deserializing the node
                    insert(targetData, node)
                    end
                end
                target.data[map][pinTypeId] = {}
                -- deserialize every new node and merge them with the old nodes
                data[pinTypeId] = data[pinTypeId] or {}
                for _, entry in pairs(data[pinTypeId]) do
                    newNode = Deserialize(entry)
                    if newNode then -- check if something went wrong while deserializing the node
                    -- If the node is new enough to be saved
                    if (Harvest.GetMaxTimeDifference() == 0) or ((timestamp - (newNode[Harvest.TIME] or 0)) <= Harvest.GetMaxTimeDifference()) then
                        -- If we have found this node already then we don't need to save it again
                        index = GetNearestNodeIndex(targetData, newNode[Harvest.X], newNode[Harvest.Y])
                        if index then
                            oldNode = targetData[index]
                            -- add the node's item ids
                            if ItemUtils.isItemsListRequired(pinTypeId) then
                                if newNode[Harvest.ITEMS] then
                                    -- merge itemid->timestamp tables by saving the higher timestamps of both tables
                                    if oldNode[Harvest.ITEMS] then
                                        for itemId, stamp in pairs(newNode[Harvest.ITEMS]) do
                                            oldNode[Harvest.ITEMS][itemId] = zo_max(oldNode[Harvest.ITEMS][itemId] or 0, stamp)
                                        end
                                    else
                                        oldNode[Harvest.ITEMS] = newNode[Harvest.ITEMS]
                                    end
                                end
                            elseif oldNode[Harvest.ITEMS] and next(oldNode[Harvest.ITEMS]) ~= nil then
                                oldNode[Harvest.ITEMS] = {}
                            end
                            -- update the timestamp of the node, to confirm it's a recent position
                            -- keep the newer position as that one is less likely to be wrong/outdated
                            if oldNode[Harvest.TIME] and newNode[Harvest.TIME] then
                                if oldNode[Harvest.TIME] < newNode[Harvest.TIME] then
                                    oldNode[Harvest.TIME] = newNode[Harvest.TIME]
                                    oldNode[Harvest.X] = newNode[Harvest.X]
                                    oldNode[Harvest.Y] = newNode[Harvest.Y]
                                    oldNode[Harvest.VERSION] = newNode[Harvest.VERSION] or 0
                                end
                            elseif newNode[Harvest.TIME] then
                                oldNode[Harvest.TIME] = newNode[Harvest.TIME]
                                oldNode[Harvest.X] = newNode[Harvest.X]
                                oldNode[Harvest.Y] = newNode[Harvest.Y]
                                oldNode[Harvest.VERSION] = newNode[Harvest.VERSION] or 0
                            end
                        else
                            insert(targetData, newNode)
                        end
                    end
                    end
                end
                -- serialize the new data
                for _, node in pairs(targetData) do
                    insert(target.data[map][pinTypeId], Serialize(node))
                end
            end
        end
    end
end

---
-- performs actions that need to be executed AFTER the save file update routine
function HarvestDB.InitializeAfterUpdate()
    -- move data to correct save files
    -- if AD was disabled while harvesting in AD, everything was saved in ["nodes"]
    -- when ad is enabled, everything needs to be moved to that save file
    -- HOWEVER, only execute this after the save files were updated!
    for map, data in pairs(HarvestDB.savedVars["nodes"].data) do
        local zone = string.gsub(map, "/.*$", "")
        local file = GetSpecialSaveFile(map)
        if file ~= nil then
            Harvest.AddToUpdateQueue(function()
                HarvestDB.ImportFromMap(map, data, file)
                HarvestDB.savedVars["nodes"].data[map] = nil
                HarvestDebugUtils.debug("Moving old data to the correct save files. " .. tostring(Harvest.GetQueuePercent()) .. "%")
            end)
        end
    end
end

---
-- this functions i called when the addon is loaded
-- initializes savedVariables, cache, reigsters callbacks etc
function HarvestDB.Initialize()
    HarvestDB.cache = {}
    HarvestDB.lastCachedIndex = 0
    HarvestDB.savedVars = {}
    -- nodes are saved account wide
    HarvestDB.savedVars["nodes"] = ZO_SavedVars:NewAccountWide("Harvest_SavedVars", 2, "nodes", Harvest.dataDefault)
    if not HarvestDB.savedVars["nodes"].firstLoaded then
        HarvestDB.savedVars["nodes"].firstLoaded = Harvest.GetCurrentTimestamp()
    end
    HarvestDB.savedVars["nodes"].lastLoaded = Harvest.GetCurrentTimestamp()
    -- load other node addons, if they are activated
    if HarvestAD then
        HarvestDB.savedVars["ADnodes"] = HarvestAD.savedVars
    end
    if HarvestEP then
        HarvestDB.savedVars["EPnodes"] = HarvestEP.savedVars
    end
    if HarvestDC then
        HarvestDB.savedVars["DCnodes"] = HarvestDC.savedVars
    end

    local clearCacheCondition = {
        hasviewdistance = true,
        viewdistance = true,
        applytimedifference = true,
    }
    local clearCache = function(event, setting, value)
        if clearCacheCondition[setting] then
            HarvestDB.cache = {}
        end
    end
    Harvest.RegisterForEvent(Harvest.SETTINGCHANGED, clearCache)
end

-- #######################################################
-- end of API functions, the rest is internal stuff
-- #######################################################

---
-- Checks if there is a node in the given nodes list which is close to the given coordinates.
-- @return the index of the close node if one is found, nil in opposite case.
function GetNearestNodeIndex(nodes, x, y)
    local minDistance = Harvest.GetMinDistanceBetweenPins()
    local dx, dy
    -- node represents a raw list of data, not an table.
    for index, node in pairs(nodes) do
        -- distance is sqrt(dx * dx + dy * dy) but for performance we compare the squared values
        -- Copypaste caused by perfomance optimization
        dx = node[Harvest.X] - x
        dy = node[Harvest.Y] - y
        if dx * dx + dy * dy < minDistance then -- the new node is too close to an old one, it's probably a duplicate
        return index
        end
    end
    return nil -- node not found.
end

-- serialize the given node via the ACE library
-- serializing the data decreases the loadtimes and file size a lot
function Serialize(data)
    return AS:Serialize(data)
end

-- register a dialog which is used to display deserialization errors
local deserializeDialog = {
    title = { text = "Deserialization Error" },
    mainText = {
        text = [[HarvestMap encountered an error:
The following string could not be deserialized:
<<1>>

Please report this error by posting a screenshot of this error message to the comment section of HarvestMap on esoui.com.
Please tell us in the comment as well, if you used the HarvestMerge website.]]
    },
    buttons = {
        [1] = {
            text = "Close",
        },
    }
}
ZO_Dialogs_RegisterCustomDialog("DESERIALIZE_ERROR", deserializeDialog)

-- this function deserializes the data and displays an error message if debug mode is enabled
function Deserialize(data)
    local success, result = AS:Deserialize(data)
    --  it seems some bug in HarvestMerge deleted the x or y coordinates
    if success and IsNodeValid(result) then
        return result
    else
        if Harvest.AreDebugMessagesEnabled() then
            ZO_Dialogs_ShowDialog("DESERIALIZE_ERROR", {}, { mainTextParams = { string.gsub(data, "%^", "-") } })
            d("fatal error while decoding node:")
            d(data)
        end
        Harvest.AddToErrorLog(data)
        Harvest.AddToErrorLog(result)
    end
    return nil
end

function IsNodeValid(node)
    if type(node[Harvest.X]) == "number" and type(node[Harvest.Y]) == "number" then
        -- sometimes encoding the coordinates is wrong and the become ridiculously large numbers or 0
        if node[Harvest.X] > 0 and node[Harvest.X] < 1 and node[Harvest.Y] > 0 and node[Harvest.Y] < 1 then
            return true
        end
    end
    return false
end

-- returns the correct table for the map (HarvestMap, HarvestMapAD/DC/EP save file tables)
-- will return HarvestMap's table if the correct table doesn't currently exist.
-- ie the HarvestMapAD addon isn't currently active
function GetSaveFile(map)
    return GetSpecialSaveFile(map) or HarvestDB.savedVars["nodes"]
end

-- returns the correct (external) table for the map or nil if no such table exists
function GetSpecialSaveFile(map)
    local zone = string.gsub(map, "/.*$", "")
    if HarvestAD then
        if HarvestAD.zones[zone] then
            return HarvestDB.savedVars["ADnodes"]
        end
    end
    if HarvestEP then
        if HarvestEP.zones[zone] then
            return HarvestDB.savedVars["EPnodes"]
        end
    end
    if HarvestDC then
        if HarvestDC.zones[zone] then
            return HarvestDB.savedVars["DCnodes"]
        end
    end
    return nil
end

local zo_floor = _G["zo_floor"]
local next = _G["next"]
local globalLocalDistance = 0.009
--[[
local hewsbaneMap = "thievesguild/hewsbane_base"
local dbRelease = 406860
local translation = 201/824
local scale = 1.013
--]]
-- returns isValidNode, wasNodeChanged
function CheckNodeVersion(pinTypeId, node, map, measurement)
    local version = node.data[Harvest.VERSION] or 0
    local addonVersion = version % Harvest.VersionOffset
    local gameVersion = zo_floor(version / Harvest.VersionOffset)
    if addonVersion < 1 then
        -- filter nodes which were saved with their global coordinates
        if (node.global[Harvest.X] - node.data[Harvest.X]) ^ 2 + (node.global[Harvest.Y] - node.data[Harvest.Y]) ^ 2 < globalLocalDistance then
            return false, false
        end
        --[[
        if map == hewsbaneMap then
            if (node.data[Harvest.TIME] or 0) < dbRelease then
                node.data[Harvest.X] = (node.data[Harvest.X] - translation) / scale + translation
                node.data[Harvest.Y] = (node.data[Harvest.Y] - translation) / scale + translation
                node.global[Harvest.X], node.global[Harvest.Y] = HarvestMapUtils.convertLocalToGlobal(node.data[Harvest.X], node.data[Harvest.Y])
                return true
            end
        end
        --]] --
    end

    -- the harvest merge website doesn't remove the item ids for enchanting pins etc...
    if not ItemUtils.isItemsListRequired(pinTypeId) then
        if node.data[Harvest.ITEMS] and next(node.data[Harvest.ITEMS]) ~= nil then
            node.data[Harvest.ITEMS] = {}
            return true, true
        end
    end
    return true, false
end


function GetSubDivision(divisions, divisionX, divisionY)
    if not divisions or divisionX < 0 or divisionX >= divisions.width then return nil
    end
    return divisions[divisionX + divisionY * divisions.width]
end

function GetSubDivisionCoords(x, y, measurement)
    if not measurement then
        return 0, 0
    end
    x = zo_floor(x / Harvest.GetPinVisibleDistance() * measurement.scaleX)
    y = zo_floor(y / Harvest.GetPinVisibleDistance() * measurement.scaleY)
    return x, y
end

-- TODO Rework and split this function.
function HarvestDB.loadDivisionsOnMapTODOrework(type, map, measurement)
    assert(type, "Type cannot be empty")
    assert(map, "Map cannot be empty")
    assert(measurement, "Options cannot be empty")

    local unpack = _G["unpack"]
    local zo_max = _G["zo_max"]
    local pairs = _G["pairs"]
    local localToGlobal = HarvestMapUtils.convertLocalToGlobal
    -- create table if it doesn't exist yet
    local saveFile = GetSaveFile(map)
    -- TODO investigate how to perform re-indexation for nodes in save file.
    saveFile.data[map] = (saveFile.data[map]) or {}
    saveFile.data[map][type] = (saveFile.data[map][type]) or {}
    if not saveFile.data[map] or not saveFile.data[map][type] then
        --HarvestDebugUtils.debug("No data for type " .. Harvest.GetLocalization("pintype" .. type) .. " on map " .. map)
    end
    local nodes = saveFile.data[map][type]
    local timestamp = Harvest.GetCurrentTimestamp()
    local maxIndex = 0
    local newNode, deserializedNode
    local cachedNodes = {}
    local validNode, changedNode
    local valid
    local count = 0
    -- deserialize the nodes and check their node version
    for index, node in pairs(nodes) do
        deserializedNode = Deserialize(node)
        validNode = false
        if deserializedNode and ((Harvest.GetMaxTimeDifference() == 0) or ((timestamp - (deserializedNode[Harvest.TIME] or 0)) < Harvest.GetMaxTimeDifference())) then
            -- TODO FIXME why time always 0?
            newNode = { typeId = type, data = deserializedNode, time = 0, global = { localToGlobal(deserializedNode[Harvest.X], deserializedNode[Harvest.Y], measurement) } }
            validNode, changedNode = CheckNodeVersion(type, newNode, map, measurement)
            if validNode then
                count = count + 1
                cachedNodes[index] = newNode
                maxIndex = zo_max(maxIndex, index)
                if changedNode then
                    nodes[index] = Serialize(newNode.data)
                end
            end
        end
        -- nodes which weren't loaded are invalid and can be deleted from the save file
        if not validNode then
            nodes[index] = nil
        end
    end
    --HarvestDebugUtils.debug("Found " .. count .. " nodes of type " .. pinTypeId)
    -- merge close nodes based on more accurate map size measurements
    local dx, dy, x1, y1, x2, y2
    local nodeA, nodeB
    local distance = Harvest.GetGlobalMinDistanceBetweenPins()
    -- merge close nodes
    local totalMerged = 0
    for i = 1, maxIndex do
        if cachedNodes[i] then
            nodeA = cachedNodes[i]
            x1, y1 = unpack(nodeA.global)
            for j = i + 1, maxIndex do
                if cachedNodes[j] then
                    nodeB = cachedNodes[j]
                    x2, y2 = unpack(nodeB.global)

                    dx = x1 - x2
                    dy = y1 - y2
                    if dx * dx + dy * dy < distance then
                        -- keep the node with the more recent timestamp
                        if (nodeA.data[Harvest.TIME] or 0) > (nodeB.data[Harvest.TIME] or 0) then
                            if nodeB.data[Harvest.ITEMS] then
                                nodeA.data[Harvest.ITEMS] = nodeA.data[Harvest.ITEMS] or {}
                                for itemId, stamp in pairs(nodeB.data[Harvest.ITEMS]) do
                                    nodeA.data[Harvest.ITEMS][itemId] = zo_max(nodeA.data[Harvest.ITEMS][itemId] or 0, stamp)
                                end
                            end
                            cachedNodes[j] = nil
                            nodes[j] = nil
                            nodes[i] = Serialize(nodeA.data)
                        else
                            if nodeA.data[Harvest.ITEMS] then
                                nodeB.data[Harvest.ITEMS] = nodeB.data[Harvest.ITEMS] or {}
                                for itemId, stamp in pairs(nodeA.data[Harvest.ITEMS]) do
                                    nodeB.data[Harvest.ITEMS][itemId] = zo_max(nodeB.data[Harvest.ITEMS][itemId] or 0, stamp)
                                end
                            end
                            cachedNodes[i] = nil
                            nodes[i] = nil
                            nodes[j] = Serialize(nodeB.data)
                            break
                        end
                        totalMerged = totalMerged + 1
                    end
                end
            end
        end;
    end
    if totalMerged > 0 then
        HarvestDebugUtils.debug("Duplicates merged: " .. totalMerged .. " of type " .. type)
    end

    local identifier, timestamp, x, y, xg, yg, items

    if not isTypeCached(type) then
        setTypeCached(type, true)
        for index, node in pairs(cachedNodes) do
            timestamp = node.time
            x = node.data[Harvest.X]
            y = node.data[Harvest.Y]
            xg = node.global[1]
            yg = node.global[2]
            items = node.data[Harvest.ITEMS]
            local id = addNodeToCache(type, timestamp, x, y, xg, yg, items)
        end

        local locationsNumber = 0
        local minNodes = 6666666
        local maxNodes = 0
        local totalNodes = 0
        local size
        for key, location in pairs(locationCache.locations) do
            size = #location
            if size < minNodes then minNodes = size
            end
            if size > maxNodes then maxNodes = size
            end
            totalNodes = totalNodes + size
            locationsNumber = locationsNumber + 1
        end
        --HarvestDebugUtils.debug("Nodes sorted by their location. Total: " .. totalNodes)
        --HarvestDebugUtils.debug("Locations size: " .. locationCache.locationSize)
        --HarvestDebugUtils.debug("Locations number: " .. locationsNumber)
        --HarvestDebugUtils.debug("Max for location: " .. maxNodes)
        --HarvestDebugUtils.debug("Min for location: " .. minNodes)
        if totalNodes > 0 then
            HarvestDebugUtils.debug("Average nodes per location: " .. (totalNodes / locationsNumber))
        else
            --HarvestDebugUtils.debug("No nodes found for type " .. type .. " on map " .. map)
        end
    else
        --HarvestDebugUtils.debug("Nodes of type " .. pinTypeId .. " already in cache.")
    end
end

-- loads the nodes to cache and returns them
-- if no measurement was given and the nodes could thus not be loaded to the cache,
-- return an empty list instead
local function GetSubDivisionsOnMap(pinTypeId, map, measurement)
    assert(map, "Map cannot be empty")
    assert(measurement, "Measurement cannot be empty")
    -- data is stored as ACE strings
    -- this functions deserializes the strings and saves the results in the cache
    if not HarvestDB.cache[map] then
        HarvestDB.lastCachedIndex = HarvestDB.lastCachedIndex + 1
        for map, data in pairs(HarvestDB.cache) do
            if data.index <= HarvestDB.lastCachedIndex - Harvest.GetMaxCachedMaps() then
                HarvestDB.cache[map] = nil
            end
        end
        HarvestDB.cache[map] = { index = HarvestDB.lastCachedIndex, subdivisions = {} }
    end
    -- only deserialize/load the data if it hasn't been loaded already
    if isTypeCached(pinTypeId) then
        --HarvestDebugUtils.debug("Pins of type " .. pinTypeId .. " already loaded. Avoid multiple loading.")
        return HarvestDB.cache[map].subdivisions[pinTypeId]
    end
    local unpack = _G["unpack"]
    local zo_max = _G["zo_max"]
    local pairs = _G["pairs"]
    local localToGlobal = HarvestMapUtils.convertLocalToGlobal
    -- create table if it doesn't exist yet
    local saveFile = GetSaveFile(map)
    saveFile.data[map] = (saveFile.data[map]) or {}
    saveFile.data[map][pinTypeId] = (saveFile.data[map][pinTypeId]) or {}
    local nodes = saveFile.data[map][pinTypeId]
    local timestamp = Harvest.GetCurrentTimestamp()
    local maxIndex = 0
    local newNode, deserializedNode
    local cachedNodes = {}
    local validNode, changedNode
    local valid
    local count = 0
    -- deserialize the nodes and check their node version
    for index, node in pairs(nodes) do
        deserializedNode = Deserialize(node)
        validNode = false
        if deserializedNode and ((Harvest.GetMaxTimeDifference() == 0) or ((timestamp - (deserializedNode[Harvest.TIME] or 0)) < Harvest.GetMaxTimeDifference())) then
            -- TODO FIXME why time always 0?
            newNode = { typeId = pinTypeId, data = deserializedNode, time = 0, global = { localToGlobal(deserializedNode[Harvest.X], deserializedNode[Harvest.Y], measurement) } }
            validNode, changedNode = CheckNodeVersion(pinTypeId, newNode, map, measurement)
            if validNode then
                count = count + 1
                cachedNodes[index] = newNode
                maxIndex = zo_max(maxIndex, index)
                if changedNode then
                    nodes[index] = Serialize(newNode.data)
                end
            end
        end
        -- nodes which weren't loaded are invalid and can be deleted from the save file
        if not validNode then
            nodes[index] = nil
        end
    end
    --HarvestDebugUtils.debug("Found " .. count .. " nodes of type " .. pinTypeId)
    -- merge close nodes based on more accurate map size measurements
    local dx, dy, x1, y1, x2, y2
    local nodeA, nodeB
    local distance = Harvest.GetGlobalMinDistanceBetweenPins()
    -- merge close nodes
    local totalMerged = 0
    for i = 1, maxIndex do
        if cachedNodes[i] then
            nodeA = cachedNodes[i]
            x1, y1 = unpack(nodeA.global)
            for j = i + 1, maxIndex do
                if cachedNodes[j] then
                    nodeB = cachedNodes[j]
                    x2, y2 = unpack(nodeB.global)

                    dx = x1 - x2
                    dy = y1 - y2
                    if dx * dx + dy * dy < distance then
                        -- keep the node with the more recent timestamp
                        if (nodeA.data[Harvest.TIME] or 0) > (nodeB.data[Harvest.TIME] or 0) then
                            if nodeB.data[Harvest.ITEMS] then
                                nodeA.data[Harvest.ITEMS] = nodeA.data[Harvest.ITEMS] or {}
                                for itemId, stamp in pairs(nodeB.data[Harvest.ITEMS]) do
                                    nodeA.data[Harvest.ITEMS][itemId] = zo_max(nodeA.data[Harvest.ITEMS][itemId] or 0, stamp)
                                end
                            end
                            cachedNodes[j] = nil
                            nodes[j] = nil
                            nodes[i] = Serialize(nodeA.data)
                        else
                            if nodeA.data[Harvest.ITEMS] then
                                nodeB.data[Harvest.ITEMS] = nodeB.data[Harvest.ITEMS] or {}
                                for itemId, stamp in pairs(nodeA.data[Harvest.ITEMS]) do
                                    nodeB.data[Harvest.ITEMS][itemId] = zo_max(nodeB.data[Harvest.ITEMS][itemId] or 0, stamp)
                                end
                            end
                            cachedNodes[i] = nil
                            nodes[i] = nil
                            nodes[j] = Serialize(nodeB.data)
                            break
                        end
                        totalMerged = totalMerged + 1
                    end
                end
            end
        end;
    end
    --HarvestDebugUtils.debug("Duplicates merged: " .. totalMerged .. " of type " .. pinTypeId)

    local subdivisions = { width = zo_floor(1 / Harvest.GetPinVisibleDistance() * measurement.scaleX) + 1 }
    local subdivisionX, subdivisionY, index
    local identifier, type, timestamp, x, y, xg, yg, items

    for index, node in pairs(cachedNodes) do
        subdivisionX, subdivisionY = GetSubDivisionCoords(node.data[1], node.data[2], measurement)
        subdivisions[subdivisionX + subdivisionY * subdivisions.width] = subdivisions[subdivisionX + subdivisionY * subdivisions.width] or {}
        subdivisions[subdivisionX + subdivisionY * subdivisions.width][index] = node
    end
    HarvestDB.cache[map].subdivisions[pinTypeId] = subdivisions
    return subdivisions
end
