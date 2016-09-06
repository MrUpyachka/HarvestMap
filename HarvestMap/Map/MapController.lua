--- Root controller for map handling.
-- Resposibility:
-- Listen change of zone and updates configuration of map services.
--
HarvestMapController = {}


--[[ TODO list:
-- Move pins displaying logic to MapPinController.
--
 ]] --

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

--- Callback function for OnWorldMapChanged callback.
--
function HarvestMapController:onMapChanged()
    -- TODO investigate issue with heist maps.
    local map, x, y, options = HarvestMapUtils.GetMapInformation(true)
    if map ~= self.map then
        self.map = map
        HarvestDebugUtils.debug("Map changed to: " .. map)
        self:configureEnvironmentForMap(map, options)
        self.pinController:onMapChanged(map)
    else
        HarvestDebugUtils.debug("Map is not changed: " .. map)
    end
end

---
-- Starts listening of callbacks/events and their processing.
--
function HarvestMapController:start()
    self.pinController = HarvestMapPinController:new(self.storage, self.callbackController)
    -- Register for ESO callback about displayed map changes.
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", self.onMapChanged, self)
    self.pinController:start()
    HarvestDebugUtils.debug("HarvestMapController controller started.")
end

---
-- Stops listening of callbacks/events and their processing.
--
function HarvestMapController:stop()
    CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", self.onMapChanged)
    self:stopControllers()
    self.pinController:stop()
    HarvestDebugUtils.debug("HarvestMapController controller stopped.")
end
