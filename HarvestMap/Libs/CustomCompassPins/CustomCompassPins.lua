-- CustomCompassPins by Shinni
local major = "CustomCompassPins"
local minor = 34

local COMPASS_PINS, oldminor = LibStub:NewLibrary(major, minor)
if not COMPASS_PINS then return end -- lib was already loaded

COMPASS_PINS.version = minor
-- parent control of our compss pins
local PARENT = COMPASS.container
-- GPS library, used for more consistent distances
local GPS = LibStub("LibGPS2")
-- the default field of view of the pins, a custom fov can be set via the pin layout
COMPASS_PINS.defaultFOV = math.pi * 0.6
-- local references for things that are needed every frame
local CALLBACK_MANAGER = _G["CALLBACK_MANAGER"]
local CENTER = _G["CENTER"]
local SET_MAP_RESULT_MAP_CHANGED = _G["SET_MAP_RESULT_MAP_CHANGED"]
local pairs = _G["pairs"]
local zo_abs = _G["zo_abs"]
local zo_floor = _G["zo_floor"]
local pi = math.pi
local atan2 = math.atan2
local ZO_WorldMap = _G["ZO_WorldMap"]
local SetMapToPlayerLocation = _G["SetMapToPlayerLocation"]
local GetMapTileTexture = _G["GetMapTileTexture"]
local GetFrameTimeMilliseconds = _G["GetFrameTimeMilliseconds"]
local GetPlayerCameraHeading = _G["GetPlayerCameraHeading"]
local GetMapPlayerPosition = _G["GetMapPlayerPosition"]

-- if there was an old version of the library loaded, we need to removed the old callbacks
if oldminor then
	EVENT_MANAGER:UnregisterForEvent("CustomCompassPins", PLAYER_ACTIVATED)
	EVENT_MANAGER:UnregisterForUpdate("CustomCompassPins")
	EVENT_MANAGER:UnregisterForUpdate("CustomCompassPinsMapChange")
	CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", COMPASS_PINS.OnWorldMapChanged)
	WORLD_MAP_SCENE:UnregisterCallback("StateChange", COMPASS_PINS.OnMapStateChange)
end

-- COMPASS_PINS:Initialize() will be called after the rest of this library was loaded
function COMPASS_PINS.Initialize()
	COMPASS_PINS.pinCallbacks = {}
	COMPASS_PINS.pinLayouts = {}
	COMPASS_PINS.visiblePins = {}
	COMPASS_PINS.pinTables = {}
	
	COMPASS_PINS.pinControlPool = ZO_ControlPool:New("ZO_MapPin", PARENT, "CustomPin")
	COMPASS_PINS.defaultMeasurement = {scaleX = 0, scaleY = 0}
	COMPASS_PINS.mapMeasurement = COMPASS_PINS.defaultMeasurement
	COMPASS_PINS.needsRefresh = {} -- table to store the pinType, which need to be refreshed

	-- don't do these update methods while the palyer is still in the loading screen
	EVENT_MANAGER:RegisterForEvent("CustomCompassPins", EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent("CustomCompassPins", EVENT_PLAYER_ACTIVATED)
		-- update the position of the pins every 20 ms
		EVENT_MANAGER:RegisterForUpdate("CustomCompassPinsUpdate", 20, COMPASS_PINS.Update)
		-- every 3 seconds set the map to the player position,
		-- because the player might've entered/left a city etc
		EVENT_MANAGER:RegisterForUpdate("CustomCompassPinsMapChange", 3000, COMPASS_PINS.SetMapToCurrentPosition)
	end)
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", COMPASS_PINS.OnWorldMapChanged)
	WORLD_MAP_SCENE:RegisterCallback("StateChange", COMPASS_PINS.OnMapStateChange)
end

function COMPASS_PINS.SetMapToCurrentPosition()
	-- don't change the map, if it is currently viewed
	if ZO_WorldMap:IsHidden() then
		if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
			CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
		-- check if another addon changed the map without calling the OnWorldMapChanged callback
		elseif COMPASS_PINS.currentMapTexture ~= GetMapTileTexture() then
			COMPASS_PINS.OnWorldMapChanged()
		end
	end
end

function COMPASS_PINS.OnWorldMapChanged()
	-- if the map changed, then we need to refresh the compass pins
	COMPASS_PINS.checkRefresh = true
end

function COMPASS_PINS.OnMapStateChange(oldState, newState)
	-- the player might have looked at a different map than the player is currently on,
	-- so we set the map back to the player's position, when the map is closed
	if newState == SCENE_HIDDEN then
		if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
			CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
		end
	end
end

function COMPASS_PINS.Refresh()
	-- in case an addon calls this while the map is open
	if not ZO_WorldMap:IsHidden() then
		COMPASS_PINS.checkRefresh = true
		return
	end
	
	COMPASS_PINS.checkRefresh = false
	local mapTexture = GetMapTileTexture()
	-- if the map changed, we will have to refresh the pins
	if COMPASS_PINS.currentMapTexture ~= mapTexture then
		COMPASS_PINS.currentMapTexture = mapTexture
		COMPASS_PINS.mapMeasurement = GPS:GetCurrentMapMeasurements()
		if not COMPASS_PINS.mapMeasurement then
			COMPASS_PINS.mapMeasurement = COMPASS_PINS.defaultMeasurement
		end
		COMPASS_PINS:RefreshPins()
	end
end

-- pinType should be a string eg "skyshard"
-- pinCallbacks should be a function, which will be called when new pins should be created
-- layout should be a table, which defines a pin's texture and maxDistance
function COMPASS_PINS:AddCustomPin(pinType, pinCallback, layout)
	-- check if the given arguments have the corrent type, 
	-- to prevent errors in the OnUpdate callback, which are a lot harder to debug
	if type(pinType) ~= "string" or COMPASS_PINS.pinLayouts[pinType] ~= nil or
			type(pinCallback) ~= "function" or type(layout) ~= "table" then
		return
	end
	layout.maxDistance = layout.maxDistance or 0.02
	layout.maxDistance2 = layout.maxDistance * layout.maxDistance
	layout.texture = layout.texture or "EsoUI/Art/MapPins/hostile_pin.dds"
	
	COMPASS_PINS.pinCallbacks[pinType] = pinCallback
	COMPASS_PINS.pinLayouts[pinType] = layout
	COMPASS_PINS.pinTables[pinType] = COMPASS_PINS.pinTables[pinType] or {}
end

-- creates a pin of the given pinType at the given location
function COMPASS_PINS:CreatePin(pinType, pinTag, xLoc, yLoc)
	if not COMPASS_PINS.pinTables[pinType] then return end
	
	local data = {}
	data.xLoc = xLoc or 0
	data.yLoc = yLoc or 0
	data.pinType = pinType or "NoType"
	data.pinTag = pinTag or {}
	
	COMPASS_PINS:RemovePin(data.pinTag, data.pinType) -- added in 1.29
	-- some addons add new compass pins outside of this libraries callback
	-- function. in such a case the old pins haven't been removed yet and get stuck
	-- see destinations comment section 03/19/16 (uladz) and newer
	
	local layout = COMPASS_PINS.pinLayouts[pinType]
	local xCell = zo_floor(xLoc * COMPASS_PINS.mapMeasurement.scaleX / layout.maxDistance)
	local yCell = zo_floor(yLoc * COMPASS_PINS.mapMeasurement.scaleY / layout.maxDistance)

	COMPASS_PINS.pinTables[pinType][xCell] = COMPASS_PINS.pinTables[pinType][xCell] or {}
	COMPASS_PINS.pinTables[pinType][xCell][yCell] = COMPASS_PINS.pinTables[pinType][xCell][yCell] or {}
	COMPASS_PINS.pinTables[pinType][xCell][yCell][pinTag] = data
end

-- removes the pin with the given pinTag
-- the function is faster when the pinType is given as well
-- giving the position of the pin will speed up the deletion even further
-- returns true if the pin was deleted and false if the pin didn't exist in the first place
function COMPASS_PINS:RemovePin(pinTag, pinType, x, y)
	if pinType then
		if not COMPASS_PINS.pinTables[pinType] then return false end
		if x and y then
			x = zo_floor(xLoc * COMPASS_PINS.mapMeasurement.scaleX / layout.maxDistance)
			y = zo_floor(yLoc * COMPASS_PINS.mapMeasurement.scaleY / layout.maxDistance)
			local cell = COMPASS_PINS.pinTables[pinType][x]
			if cell then
				cell = cell[y]
				local pinData = cell[pinTag]
				if pinData then
					if pinData.pinKey then
						COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
					end
					cell[pinTag] = nil
					COMPASS_PINS.visiblePins[pinTag] = nil
					return true
				end
			end
			return false
		end
		for _, yCells in pairs(COMPASS_PINS.pinTables[pinType]) do
			for _, pins in pairs(yCells) do
				local pinData = pins[pinTag]
				if pinData then
					if pinData.pinKey then
						COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
					end
					pins[pinTag] = nil
					COMPASS_PINS.visiblePins[pinTag] = nil
					return true
				end
			end
		end
		return false
	end
	for pinType, _ in pairs(COMPASS_PINS.pinTables) do
		if COMPASS_PINS:RemovePin(pinTag, pinType) then
			return true
		end
	end
	return false
end

-- removes all pins of the given pinType
-- if no pinType is given, all pins are removed
function COMPASS_PINS:RemovePins(pinType)
	if not pinType then
		COMPASS_PINS.pinControlPool:ReleaseAllObjects()
		COMPASS_PINS.visiblePins = {}
		for pinType in pairs(COMPASS_PINS.pinTables) do
			COMPASS_PINS.pinTables[pinType] = {}
		end
	else
		local xCells = COMPASS_PINS.pinTables[pinType]
		if not xCells then return end
		for _, yCells in pairs(xCells) do
			for _, cell in pairs(yCells) do
				for pinTag, pinData in pairs(cell) do
					if pinData.pinKey then
						COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
					end
					COMPASS_PINS.visiblePins[pinTag] = nil
					cell[pinTag] = nil
				end
			end
		end
	end
end

-- refreshes all pins of the given pinType or all pins, if no pinType is given.
-- refresh means: all pins are deleted and the pinType's callback functions are called to create new pins
-- however the refresh will be delayed if the worldmap is currently open
function COMPASS_PINS:RefreshPins(pinType)
	-- only refresh pins if the map is closed
	if not ZO_WorldMap:IsHidden() then
		-- if the map is open, delay the refresh until the map is closed
		if pinType then
			COMPASS_PINS.needsRefresh[pinType] = true
		else
			for pinType in pairs(COMPASS_PINS.pinCallbacks) do
				COMPASS_PINS.needsRefresh[pinType] = true
			end
		end
		return
	end
	
	if pinType then
		COMPASS_PINS.needsRefresh[pinType] = false
	else
		COMPASS_PINS.needsRefresh = {}
	end

	-- maybe the distance setting changed
	if pinType then
		local layout = COMPASS_PINS.pinLayouts[pinType]
		layout.maxDistance2 = layout.maxDistance * layout.maxDistance
	else
		for _, layout in pairs(COMPASS_PINS.pinLayouts) do
			layout.maxDistance2 = layout.maxDistance * layout.maxDistance
		end
	end
	-- remove the old pins...
	COMPASS_PINS:RemovePins(pinType)
	-- ...and call the callback functions to get new pins
	if pinType then
		if not COMPASS_PINS.pinCallbacks[pinType] then
			return
		end
		COMPASS_PINS.pinCallbacks[pinType](COMPASS_PINS)
	else
		for tag, callback in pairs(COMPASS_PINS.pinCallbacks) do
			callback(COMPASS_PINS)
		end
	end
end

-- updates the pins (recalculates the position of the pins on the compass control)
function COMPASS_PINS.Update()
	-- no point wasting cpu time, if the compass isn't visible
	if PARENT:IsHidden() then
		return
	end
	
	if COMPASS_PINS.checkRefresh then
		COMPASS_PINS:Refresh()
	end
	-- refresh those pins that need to be refreshed (because of a COMPASS_PINS.Refresh()
	-- or because an addon called COMPASS_PINS.RefreshPins() while the map was open)
	for pinType, needed in pairs(COMPASS_PINS.needsRefresh) do
		if needed then
			COMPASS_PINS.RefreshPins(pinType)
		end
	end
	
	-- update the compass pin controls
	local heading = GetPlayerCameraHeading()
	if not heading then return end
	if heading > pi then --normalize heading to [-pi,pi]
		heading = heading - 2 * pi
	end

	local x, y = GetMapPlayerPosition("player")
	local frameTime = GetFrameTimeMilliseconds()
	-- now check if there are pins that should newly appear on the compass
	local xCell, yCell, yCells, cells, layout
	for pinType, pinCells in pairs(COMPASS_PINS.pinTables) do
		layout = COMPASS_PINS.pinLayouts[pinType]
		xCell = zo_floor(x * COMPASS_PINS.mapMeasurement.scaleX / layout.maxDistance)
		yCell = zo_floor(y * COMPASS_PINS.mapMeasurement.scaleY / layout.maxDistance)
		for i = -1, 1 do
			yCells = pinCells[xCell + i]
			if yCells then
				for j = -1, 1 do
					cells = yCells[yCell + j]
					if cells then
						for pinTag, pinData in pairs(cells) do
							COMPASS_PINS.UpdatePin(x, y, heading, pinTag, pinData, layout)
							pinData.lastUpdate = frameTime
						end
					end
				end
			end
		end
	end
	
	-- some pins might be out of range and thus weren't updated by the loop before
	for pinTag, pinData in pairs(COMPASS_PINS.visiblePins) do
		if pinData.lastUpdate < frameTime then
			if pinData.pinKey then
				COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
				pinData.pinKey = nil
			end
			COMPASS_PINS.visiblePins[pinTag] = nil
		end
	end
	
end

function COMPASS_PINS.UpdatePin(x, y, heading, pinTag, pinData, layout)
	local xDif = (x - pinData.xLoc) * COMPASS_PINS.mapMeasurement.scaleX
	local yDif = (y - pinData.yLoc) * COMPASS_PINS.mapMeasurement.scaleY
	local normalizedDistance = (xDif * xDif + yDif * yDif) / layout.maxDistance2
	-- the pin is out of range, so remove the pin control from the compass
	if normalizedDistance >= 1 then
		if pinData.pinKey then
			COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
			pinData.pinKey = nil
		end
		COMPASS_PINS.visiblePins[pinTag] = nil
		return
	end
	
	-- calculate angle between the camera's view direction and the pin
	-- the angle is in [-pi, pi]
	local angle = -atan2(xDif, yDif)
	angle = (angle + heading)
	if angle > pi then
		angle = angle - 2 * pi
	elseif angle < -pi then
		angle = angle + 2 * pi
	end
	-- normalize the angle to [-1, 1] where (-/+) 1 is the left/right edge of the compass
	local normalizedAngle = 2 * angle / (layout.FOV or COMPASS_PINS.defaultFOV)
	-- check if the bin is outside the FOV
	if zo_abs(normalizedAngle) > 1 then
		if pinData.pinKey then
			COMPASS_PINS.pinControlPool:ReleaseObject(pinData.pinKey)
			pinData.pinKey = nil
		end
		COMPASS_PINS.visiblePins[pinTag] = nil
		return
	end
	
	local pinControl
	if pinData.pinKey then
		pinControl = COMPASS_PINS.pinControlPool:GetExistingObject(pinData.pinKey)
	else
		pinControl = COMPASS_PINS.GetNewPinControl(pinData)
		COMPASS_PINS.visiblePins[pinTag] = pinData
	end
	pinControl:ClearAnchors()
	pinControl:SetAnchor(CENTER, PARENT, CENTER, 0.5 * PARENT:GetWidth() * normalizedAngle, 0)
	pinControl:SetHidden(false)
	-- does the pin type have its own size definition?
	if layout.sizeCallback then
		layout.sizeCallback(pinControl, angle, normalizedAngle, normalizedDistance)
	else
		if zo_abs(normalizedAngle) > 0.25 then
			pinControl:SetDimensions(36 - 16 * zo_abs(normalizedAngle), 36 - 16 * zo_abs(normalizedAngle))
		else
			pinControl:SetDimensions(32, 32)
		end
	end

	pinControl:SetAlpha(1 - normalizedDistance)
	-- the pin type can have its own additional layout, like colors or something
	if layout.additionalLayout then
		layout.additionalLayout[1](pinControl, angle, normalizedAngle, normalizedDistance)
	end
end

function COMPASS_PINS.GetNewPinControl(data)
	local pin, pinKey = COMPASS_PINS.pinControlPool:AcquireObject()
	data.pinKey = pinKey
	COMPASS_PINS.ResetPin(pin)
	pin:SetHandler("OnMouseDown", nil)
	pin:SetHandler("OnMouseUp", nil)
	pin:SetHandler("OnMouseEnter", nil)
	pin:SetHandler("OnMouseExit", nil)
	pin:GetNamedChild("Highlight"):SetHidden(true)

	pin.xLoc = data.xLoc
	pin.yLoc = data.yLoc
	pin.pinType = data.pinType
	pin.pinTag = data.pinTag

	local layout = COMPASS_PINS.pinLayouts[data.pinType]
	local texture = pin:GetNamedChild("Background")
	texture:SetTexture(layout.texture)

	return pin, pinKey
end

function COMPASS_PINS.ResetPin(pin)
	for _, layout in pairs(COMPASS_PINS.pinLayouts) do
		if layout.additionalLayout then
			layout.additionalLayout[2](pin)
		end
	end
end


COMPASS_PINS.Initialize()
--[[
example:

COMPASS_PINS:AddCustomPin("myCompassPins",
	function(pinManager)
		for _, pinTag in pairs(myData) do
			pinManager:CreatePin("myCompassPins", pinTag, pinTag.x, pinTag.y)
		end
	end,
	{ maxDistance = 0.05, texture = "esoui/art/compass/quest_assistedareapin.dds" })

--]]
