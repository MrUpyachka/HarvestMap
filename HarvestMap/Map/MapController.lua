--- Root controller for map handling.
-- Resposibility:
-- Listen change of zone and updates configuration of map services.
--
HarvestMapController = {}

--- Reference to LibMapPins.
local LMP = LibStub("LibMapPins-1.0")

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestMapController:new(s, c)
    local instance = { storage = s, callbackController = c }
    self.__index = self
    setmetatable(instance, self)
    return instance
end

--- Stops inner controllers.
function HarvestMapController:stopControllers()
    if self.dbController then self.dbController:stop() end
    if self.nodeResolver then self.nodeResolver:stop() end
    HarvestDebugUtils.debug("HarvestMapController inner controllers stopped.")
end

--- Configures inner controllers for processing of new map.
-- @param map new map reference.
-- @param options new measurement options.
--
function HarvestMapController:configureEnvironmentForMap(map, options)
    if self.dbController or self.nodeResolver then
        self:stopControllers()
    end
    self.storage.checkAndUpdateCache(map, options)

    self.dbController = HarvestDbController:new(self.storage, self.callbackController) -- Eso global manager used, just for example.
    self.nodeResolver = HarvestNodeResolver:new(self.storage, self.callbackController, options) -- TODO measurements of map as options.

    self.dbController:start() -- Now its started and listens for requests.
    self.nodeResolver:start()
end

local function displayPin(id, type, timestamp, x, y, xg, yg, items)
    local pinType = Harvest.GetPinType(type)
    LMP:CreatePin(pinType, id, x, y)
end

--- Callback for displaying of pins with spicified type on map.
function HarvestMapController:onDisplayPinTypeOnMap(type)
    HarvestDebugUtils.debug("Try display pin type <" .. Harvest.GetLocalization("pintype" .. type) .. ">")
    self.storage.forNodesOfType(type, displayPin)
    --[[
    if GetMapType() <= MAPTYPE_ZONE and LMP:IsEnabled(Harvest.GetPinType(type)) then
        HarvestDebugUtils.debug("Try display pin type <" .. Harvest.GetLocalization("pintype" .. type) .. ">")
        self.storage.forNodesOfType(type, displayPin)
    end
    ]]--
end

--- Registers all types of pins on map (for filtering and others).
function HarvestMapController:registerPinTypes()
    for _, pinType in pairs(Harvest.PINTYPES) do
        -- TODO investigate this more.
        local typeKey = Harvest.GetPinType(pinType)
        local localizedName = Harvest.GetLocalization("pintype" .. pinType)
        local pinLayout = HarvestMapUtils.getCurrentMapPinLayout(pinType)
        LMP:AddPinType(typeKey, function() self:onDisplayPinTypeOnMap(pinType) end, nil, pinLayout, Harvest.tooltipCreator)
        if pinType ~= Harvest.TOUR then
            local pve, pvp, imperial = LMP:AddPinFilter(typeKey, localizedName,
                false, Harvest.savedVars["settings"].isPinTypeVisible)
            local fun = function(button, state) Harvest.SetPinTypeVisible(pinType, state) end
            ZO_CheckButton_SetToggleFunction(pve, fun)
            ZO_CheckButton_SetToggleFunction(pvp, fun)
            ZO_CheckButton_SetToggleFunction(imperial, fun)
        end
        HarvestDebugUtils.debug("Filter of pin type <" .. localizedName .. "> registered")
    end
end

--- Callback function for OnWorldMapChanged callback.
--
function HarvestMapController:onMapChanged()
    local map, x, y, options = HarvestMapUtils.GetMapInformation(true)
    if map ~= self.map then
        self.map = map
        HarvestDebugUtils.debug("Map changed to: " .. map)
        self:configureEnvironmentForMap(map, options)
        if not self.pinTypesRegistered then
            -- Register them once.
            self.pinTypesRegistered = true
            self:registerPinTypes()
        end
        -- Next cycle removes all pins from LMP
        for _, pinType in pairs(Harvest.PINTYPES) do
            LMP:RefreshPins(Harvest.GetPinType(pinType))
        end
    else
        HarvestDebugUtils.debug("Map is not changed: " .. map)
    end
end

---
-- Starts listening of callbacks/events and their processing.
--
function HarvestMapController:start()
    -- Register for ESO callback about displayed map changes.
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", self.onMapChanged, self)

    HarvestDebugUtils.debug("HarvestMapController controller started.")
end

---
-- Stops listening of callbacks/events and their processing.
--
function HarvestMapController:stop()
    CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", self.onMapChanged)

    self:stopControllers()
    HarvestDebugUtils.debug("HarvestMapController controller stopped.")
end
