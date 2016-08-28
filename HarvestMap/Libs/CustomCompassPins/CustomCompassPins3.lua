-- CustomCompassPins by Shinni
local major = "CustomCompassPins"
local minor = 33

local COMPASS_PINS, oldminor = LibStub:NewLibrary(major, minor)
if not COMPASS_PINS then return end
--_G["COMPASS_PINS"] = COMPASS_PINS
COMPASS_PINS.version = minor
-- parent control of our compss pins
local PARENT = COMPASS.container
-- the default field of view of the pins, a custom fov can be set via the pin layout
COMPASS_PINS.defaultFOV = math.pi * 0.6
-- coefficients for different map sizes to make the fade distance of the pins approximately the same
local coefficients = {0.16, 1.08, 1.32, 1.14, 1.14, 1.23, 1.16, 1.24, 1.33, 1.00, 1.12, 1.00, 1.00, 0.89, 1.00, 1.37, 1.20, 4.27, 2.67, 3.20, 5.00, 8.45, 0.89, 0.10, 1.14 }
-- local refferences for things that are needed every frame
local CALLBACK_MANAGER = _G["CALLBACK_MANAGER"]
local CENTER = _G["CENTER"]
local GetPlayerCameraHeading = _G["GetPlayerCameraHeading"]
local GetMapPlayerPosition = _G["GetMapPlayerPosition"]
local pairs = _G["pairs"]
local zo_abs = _G["zo_abs"]
local pi = math.pi
local atan2 = math.atan2

local CompassPinManager = ZO_ControlPool:Subclass()

if oldminor then
	EVENT_MANAGER:UnregisterForUpdate("CustomCompassPins")
	EVENT_MANAGER:UnregisterForUpdate("CustomCompassPinsMapChange")
	-- these callbacks need to be removed before we overwrite the functions
	CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", COMPASS_PINS.OnWorldMapChanged)
	WORLD_MAP_SCENE:UnregisterCallback("StateChange", COMPASS_PINS.OnMapStateChange)
end

-- COMPASS_PINS:Initialize() will be called after the rest of this library was loaded
function COMPASS_PINS:Initialize()
	if oldminor then
		-- there was an old version of CCP loaded
		-- in this case we want to copy already registered pins
		local data = COMPASS_PINS.pinManager.pinData
		COMPASS_PINS.pinManager = CompassPinManager:New()
		if data then
			COMPASS_PINS.pinManager.pinData = {}
			local pinData = COMPASS_PINS.pinManager.pinData
			for _, pin in pairs(data) do
				pinData[pin.pinType] = pinData[pin.pinType] or {}
				pinData[pin.pinType][pin.pinTag] = pin
			end
		end
	else
		COMPASS_PINS.pinCallbacks = {}
		COMPASS_PINS.pinLayouts = {}
		COMPASS_PINS.pinManager = CompassPinManager:New()
	end
	self.needsRefresh = {} -- table to store in, which pintypes need to be refreshed
	self:RefreshDistanceCoefficient()
	-- update the position of the pins every 20 ms
	EVENT_MANAGER:RegisterForUpdate("CustomCompassPinsUpdate", 20, function() self:Update() end)
	-- every 3 seconds set the map to the player position
	-- the player might've entered/left a city etc
	local ZO_WorldMap = _G["ZO_WorldMap"]
	local SetMapToPlayerLocation = _G["SetMapToPlayerLocation"]
	local SET_MAP_RESULT_MAP_CHANGED = _G["SET_MAP_RESULT_MAP_CHANGED"]
	local GetMapTileTexture = _G["GetMapTileTexture"]
	EVENT_MANAGER:RegisterForUpdate("CustomCompassPinsMapChange", 3000, function()
		if ZO_WorldMap:IsHidden() then
			if(SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED) then
				CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
			-- check if an addon changed the map without calling the OnWorldMapChanged callback
			elseif COMPASS_PINS.map ~= GetMapTileTexture() then
				COMPASS_PINS.OnWorldMapChanged()
			end
		end
	end)
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", self.OnWorldMapChanged)
	WORLD_MAP_SCENE:RegisterCallback("StateChange", self.OnMapStateChange)
end

function COMPASS_PINS.OnWorldMapChanged()
	-- if the map changed, then we need to refresh the compass pins
	COMPASS_PINS.checkRefresh = true
end

function COMPASS_PINS.OnMapStateChange(oldState, newState)
	-- the player might have looked at another map,
	-- so we set the map back to the player's position
	-- when the map is closed
	if newState == SCENE_HIDDEN then
		if(SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED) then
			CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
		end
	end
end

function COMPASS_PINS:Refresh()
	-- in case an addon calls this while the map is open
	if not ZO_WorldMap:IsHidden() then
		self.checkRefresh = true
		return
	end
	
	self.checkRefresh = false
	local currentMap = GetMapTileTexture()
	-- if the map changed, we will have to refresh the pins
	if self.map ~= currentMap then
		self.map = currentMap
		self:RefreshDistanceCoefficient()
		self:RefreshPins()
	end
end

-- pinType should be a string eg "skyshard"
-- pinCallbacks should be a function, it receives the pinManager as argument
-- layout should be table, currently only the key texture is used (which should return a string)
function COMPASS_PINS:AddCustomPin(pinType, pinCallback, layout)
	if type(pinType) ~= "string" or self.pinLayouts[pinType] ~= nil or type(pinCallback) ~= "function" or type(layout) ~= "table" then return end
	layout.maxDistance = layout.maxDistance or 0.02
	layout.texture = layout.texture or "EsoUI/Art/MapPins/hostile_pin.dds"

	self.pinCallbacks[pinType] = pinCallback
	self.pinLayouts[pinType] = layout
	self.pinManager.pinData[pinType] = self.pinManager.pinData[pinType] or {}
end

-- refreshes/calls the pinCallback of the given pinType
-- refreshes all custom pins if no pinType is given
function COMPASS_PINS:RefreshPins(pinType)
	-- only refresh pins if the map is closed
	if not ZO_WorldMap:IsHidden() then
		if pinType then
			self.needsRefresh[pinType] = true
		else
			for pinType in pairs(self.pinCallbacks) do
				self.needsRefresh[pinType] = true
			end
		end
		return
	end
	if pinType then
		self.needsRefresh[pinType] = false
	else
		self.needsRefresh = {}
	end
	
	-- remove the old pins...
	self.pinManager:RemovePins(pinType)
	-- ...and call the callback functions to get new pins
	if pinType then
		if not self.pinCallbacks[pinType] then
			return
		end
		self.pinCallbacks[pinType](self.pinManager)
	else
		for tag, callback in pairs(self.pinCallbacks) do
			callback(self.pinManager)
		end
	end
end

function COMPASS_PINS:GetDistanceCoefficient()     --coefficient = Auridon size / current map size
	local coefficient = 1
	local mapId = GetCurrentMapIndex()
	if mapId then
		coefficient = coefficients[mapId] or 1       --zones and starting isles
	else
		if GetMapContentType() == MAP_CONTENT_DUNGEON then
			coefficient = 16                          --all dungeons, value between 8 - 47, usually 16
		elseif GetMapType() == MAPTYPE_SUBZONE then
			coefficient = 6                           --all subzones, value between 5 - 8, usually 6
		end
	end

	return math.sqrt(coefficient)                   --as we do not want that big difference, lets make it smaller...
end

function COMPASS_PINS:RefreshDistanceCoefficient()
	self.distanceCoefficient = self:GetDistanceCoefficient()
end

-- updates the pins (recalculates the position of the pins on the compass control)

function COMPASS_PINS:Update()
	-- no point wasting cpu time, if the compass isn't visible
	if PARENT:IsHidden() then
		return
	end
	-- there were some map changes, check if we need to refresh the pins, distance coefficients etc
	if self.checkRefresh then
		COMPASS_PINS:Refresh()
	end
	-- refresh those pins that need to be refreshed (because of COMPASS_PINS:Refresh()
	-- or because an addon called COMPASS_PINS:RefreshPins() while the map was open)
	for pinType, needed in pairs(self.needsRefresh) do
		if needed then
			COMPASS_PINS:RefreshPins(pinType)
		end
	end
	local heading = GetPlayerCameraHeading()
	if not heading then return end
	if heading > pi then --normalize heading to [-pi,pi]
	heading = heading - 2 * pi
	end

	local x, y = GetMapPlayerPosition("player")
	self.pinManager:Update(x, y, heading)
end

--
-- pin manager class, updates position etc
--
function CompassPinManager:New(...)
	local result = ZO_ControlPool.New(self, "ZO_MapPin", PARENT, "CustomPin")
	result:Initialize(...)

	return result
end

function CompassPinManager:Initialize(...)
	self.pinData = {}
	self.defaultAngle = 1
end

function CompassPinManager:GetNewPin(data)
	local pin, pinKey = self:AcquireObject()
	self:ResetPin(pin)
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

-- creates a pin of the given pinType at the given location
function CompassPinManager:CreatePin(pinType, pinTag, xLoc, yLoc)
	if not self.pinData[pinType] then return end
	
	local data = {}
	data.xLoc = xLoc or 0
	data.yLoc = yLoc or 0
	data.pinType = pinType or "NoType"
	data.pinTag = pinTag or {}
	
	self:RemovePin(data.pinTag, data.pinType) -- added in 1.29
	-- some addons add new compass pins outside of this libraries callback
	-- function. in such a case the old pins haven't been removed yet and get stuck
	-- see destinations comment section 03/19/16 (uladz) and newer
	
	self.pinData[pinType][pinTag] = data
end

function CompassPinManager:RemovePin(pinTag, pinType)
	if pinType then
		if not self.pinData[pinType] then return end
		local entry = self.pinData[pinType][pinTag]
		if entry and entry.pinKey then
			self:ReleaseObject(entry.pinKey)
		end
		self.pinData[pinType][pinTag] = nil
		return
	end
	for pinType, pins in pairs(self.pinData) do
		local entry = pins[pinTag]
		if entry then
			if entry.pinKey then
				self:ReleaseObject(entry.pinKey)
			end
			pins[pinTag] = nil
			return
		end
	end
end

function CompassPinManager:RemovePins(pinType)
	if not pinType then
		self:ReleaseAllObjects()
		for pinType in pairs(self.pinData) do
			self.pinData[pinType] = {}
		end
	else
		local pins = self.pinData[pinType]
		if not pins then return end
		for pinTag, data in pairs(pins) do
			if data.pinKey then
				self:ReleaseObject(data.pinKey)
			end
			pins[pinTag] = nil
		end
	end
end

function CompassPinManager:ResetPin(pin)
	for _, layout in pairs(COMPASS_PINS.pinLayouts) do
		if layout.additionalLayout then
			layout.additionalLayout[2](pin)
		end
	end
end

function CompassPinManager:Update(x, y, heading)
	local value
	local pin
	local angle
	local normalizedAngle
	local xDif, yDif
	local layout
	local normalizedDistance
	local distance
	local width = PARENT:GetWidth()
	for pinType, pins in pairs(self.pinData) do
	layout = COMPASS_PINS.pinLayouts[pinType]
	distance = layout.maxDistance * COMPASS_PINS.distanceCoefficient
	distance = distance * distance -- square the value so we don't have to take the root in the next loop
	for pinTag, pinData in pairs(pins) do
		xDif = x - pinData.xLoc
		yDif = y - pinData.yLoc
		normalizedDistance = (xDif * xDif + yDif * yDif) / distance
		if normalizedDistance < 1 then
			if pinData.pinKey then
				pin = self:GetExistingObject(pinData.pinKey)
			else
				pin, pinData.pinKey = self:GetNewPin(pinData)
			end

			if pin then
				-- calculate angle between the camera's view direction and the pin
				-- the angle is in [-pi, pi]
				angle = -atan2(xDif, yDif)
				angle = (angle + heading)
				if angle > pi then
					angle = angle - 2 * pi
				elseif angle < -pi then
					angle = angle + 2 * pi
				end
				-- normalize the angle to [-1, 1] where (-) 1 is the left/right edge of the compass
				normalizedAngle = 2 * angle / (layout.FOV or COMPASS_PINS.defaultFOV)

				if zo_abs(normalizedAngle) > (layout.maxAngle or self.defaultAngle) then
					pin:SetHidden(true)
				else
					pin:ClearAnchors()
					pin:SetAnchor(CENTER, PARENT, CENTER, 0.5 * width * normalizedAngle, 0)
					pin:SetHidden(false)
					-- does the pin type have its own size definition?
					if layout.sizeCallback then
						layout.sizeCallback(pin, angle, normalizedAngle, normalizedDistance)
					else
						if zo_abs(normalizedAngle) > 0.25 then
							pin:SetDimensions(36 - 16 * zo_abs(normalizedAngle), 36 - 16 * zo_abs(normalizedAngle))
						else
							pin:SetDimensions(32, 32)
						end
					end

					pin:SetAlpha(1 - normalizedDistance)
					-- the pin type can have its own additional layout, like colors or something
					if layout.additionalLayout then
						layout.additionalLayout[1](pin, angle, normalizedAngle, normalizedDistance)
					end
				end
			else
				d("CustomCompassPin Error:")
				d("no pin with key " .. pinData.pinKey .. "found!")
			end
		else
			if pinData.pinKey then
				self:ReleaseObject(pinData.pinKey)
				pinData.pinKey = nil
			end
		end
	end
	end
end


COMPASS_PINS:Initialize()
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
