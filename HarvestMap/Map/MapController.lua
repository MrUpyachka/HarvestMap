--- Root controller for map handling.
-- Resposibility:
-- Listen change of zone and updates configuration of map services.
--
HarvestMapController = {}


--[[ TODO list:
-- Move pins displaying logic to MapPinController.
--
 ]] --

--- self reference.
local self = HarvestMapController

--- Creates an instance of controller.
-- @param s storage of nodes.
-- @param c callbacks controller.
--
function HarvestMapController.new(s, c)
    self.storage = s
    self.callbackController = c
    return self
end

--- Stops inner controllers.
function HarvestMapController.stopControllers()
    if self.dbController then self.dbController:stop() end
    if self.nodeResolver then self.nodeResolver:stop() end
    HarvestDebugUtils.debug("HarvestMapController inner controllers stopped.")
end

--- Configures inner controllers for processing of new map.
-- @param map new map reference.
-- @param options new measurement options.
--
function HarvestMapController.configureEnvironmentForMap(map, options)
    if self.dbController or self.nodeResolver then
        self.stopControllers()
    end
    self.storage.checkAndUpdateCache(map, options)

    self.dbController = HarvestDbController:new(self.storage, self.callbackController) -- Eso global manager used, just for example.
    self.nodeResolver = HarvestNodeResolver:new(self.storage, self.callbackController, options) -- TODO measurements of map as options.

    self.dbController:start() -- Now its started and listens for requests.
    self.nodeResolver:start()
end

--- Cached value of current map.
local currentMap

--- Callback function for OnWorldMapChanged callback.
--
function HarvestMapController.onMapChanged()
    -- TODO investigate issue with heist maps.
    local map, x, y, options = HarvestMapUtils.GetMapInformation(true)
    --assert(type(self) ~= type(true))
    if map ~= currentMap then
        currentMap = map
        HarvestDebugUtils.debug("Map changed to: " .. map)
        self.configureEnvironmentForMap(map, options)
        self.pinController:onMapChanged(map)
    else
        HarvestDebugUtils.debug("Map is not changed: " .. map)
    end
end

---
-- Starts listening of callbacks/events and their processing.
--
function HarvestMapController.start()
    self.pinController = HarvestMapPinController:new(self.storage, self.callbackController)
    -- Register for ESO callback about displayed map changes.
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", self.onMapChanged)
    self.pinController:start()
    HarvestDebugUtils.debug("HarvestMapController controller started.")
end

---
-- Stops listening of callbacks/events and their processing.
--
function HarvestMapController.stop()
    CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", self.onMapChanged)
    self.stopControllers()
    self.pinController:stop()
    HarvestDebugUtils.debug("HarvestMapController controller stopped.")
end
