--- Utility tools to help with handling of current map data.
HarvestMapUtils = {}
local GPS = LibStub("LibGPS2")

--- List of heist map names.
local heistMaps = {
    "^thievesguild/thehideaway",
    "^thievesguild/secludedsewers",
    "^thievesguild/deathhollowhalls",
    "^thievesguild/glitteringgrotto",
    "^thievesguild/undergroundsepulcher",
}
--- Checks that specified map represents an heist location and returns name prefix.
-- @param map interest map.
-- @return prefix of heist if specified map related to an heist location, nil in opposite case.
--
function HarvestMapUtils.getHeistPrefixIfPossible(map)
    local prefix
    for _, regexp in pairs(heistMaps) do
        prefix = string.match(map, regexp)
        if prefix then
            return prefix
        end
    end
    return nil
end

--- Contains remembered map reference.
local map
--- Contains remembered map texture.
local lastMapTexture

--- Returns reference to currently displayed map.
-- @return map reference.
--
function HarvestMapUtils.getCurrentMap()
    local textureName = GetMapTileTexture()
    if Harvest.lastMapTexture ~= textureName then
        Harvest.lastMapTexture = textureName
        textureName = string.lower(textureName)
        textureName = string.gsub(textureName, "^.*maps/", "")
        textureName = string.gsub(textureName, "_%d+%.dds$", "")

        if textureName == "eyevea_base" then
            local worldMapName = GetUnitZone("player")
            worldMapName = string.lower(worldMapName)
            textureName = worldMapName .. "/" .. textureName
        else
            local heistMapPrefix = HarvestMapUtils.getHeistPrefixIfPossible(textureName)
            if heistMapPrefix then
                map = heistMapPrefix .. "_base"
                return map
            end
        end
        map = textureName
    end
    return map
end

--- Checks that map requries an mesurement modifications.
-- @param measurements the measurements of map.
-- @return true if the measurement is modified for this map.
-- ie dungeons have to be rescaled, otherwise distances get overestimated.
function HarvestMapUtils.isMeasurementsModificationRequired(measurements)
    return (GetMapContentType() == MAP_CONTENT_DUNGEON and measurements and measurements.scaleX < 0.003)
end

--- Returns informations regarding the current location
-- if viewedMap is true, the data is relative to the currently viewed map
-- otherwise the data is related to the map the player is currently on.
-- @param viewedMap means that map visible and should not be changed.
-- @return map current map reference.
-- @return x abscissa of point.
-- @return y ordinate of point.
-- @return measurements the measurement of map.
--
function HarvestMapUtils.GetMapInformation(viewedMap)
    local changed
    if not viewedMap then
        -- try to change map if not specified.
        changed = (SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED)
    end

    local mapMeasurements = GPS:GetCurrentMapMeasurements(viewedMap ~= false)
    if not viewedMap then
        SetMapToPlayerLocation() -- TODO FIXME why called twice?
    end
    -- delves tend to be scaled down on the zone map, so we need to return a smaller value
    if HarvestMapUtils.isMeasurementsModificationRequired(mapMeasurements) then
        local scale = math.sqrt(165)
        mapMeasurements = {
            scaleX = mapMeasurements.scaleX * scale,
            scaleY = mapMeasurements.scaleY * scale,
            offsetX = mapMeasurements.offsetX,
            offsetY = mapMeasurements.offsetY
        }
    end

    local map = HarvestMapUtils.getCurrentMap()
    local x, y = GetMapPlayerPosition("player")
    if changed then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    return map, x, y, mapMeasurements
end

--- Converts local coordinates to global depends on mesurement options.
-- @param x abscissa of point.
-- @param y ordinate of point.
-- @param measurements the measurement of map.
-- @return x global abscissa of point.
-- @return y global ordinate of point.
--
function HarvestMapUtils.convertLocalToGlobal(x, y, measurements)
    assert(measurements, "Unable to calculate global coordinates without measurement options")
    x = x * measurements.scaleX + measurements.offsetX
    y = y * measurements.scaleY + measurements.offsetY
    return x, y
end
