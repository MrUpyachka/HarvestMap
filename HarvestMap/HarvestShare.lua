
if not Harvest then
	Harvest = {}
end

local version = 0

local zo_floor = math.floor
--[[
function d(g)
	for i, v in pairs(g) do
		if type(v) == "table" then
			d(v)
		else
			print(i, v)
		end
	end
end
-- CHAT_SYSTEM.textEntry:SetText(Harvest.Encode({{0.5,0.5,{},{804},123987}},6))
-- ZO_LinkHandler_CreateLink("name",nil,"type",Harvest.Encode({{0.5,0.5,{},{804},123987}},6))
--]]
local function isValidNode(node)
	if node[1] < 0 or node[1] >= 1 then
		return false
	end
	if node[2] < 0 or node[2] >= 1 then
		return false
	end
	return true
end

function Harvest.Encode(list, pinTypeId)
	local bytes = {}
	-- first 3 bit are the version number, last 5 bit are the pin type
	table.insert(bytes, version * 2^5 + pinTypeId)
	local value
	-- sending string with invalid utf-8 encoding doesn't work properly
	-- so the most significant bit will always be zero to prevent that
	-- string are also null terminated, so i'll set the lsb to 1 as well
	-- this means we have 6 bit per byte left to pass information
	for _, node in pairs(list) do
		if isValidNode(node) then
			-- x coord, 2 byte or 12 bit
			value = zo_floor(node[1] * 2^12)
			table.insert(bytes, zo_floor(value / 2^6)*2+1)
			table.insert(bytes, (value % (2^6))*2+1)
			-- y coord, 2 byte or 12 bit
			value = zo_floor(node[2] * 2^12)
			table.insert(bytes, zo_floor(value / 2^6)*2+1)
			table.insert(bytes, (value % (2^6))*2+1)
			if node[4] then
				-- itemids are saved as 3 bytes, or 17 bit. the leading 18th information bit
				-- is set to 1 to differentiate it from the timestamp which is next
				for _, itemId in pairs(node[4]) do
					value = 2^17 + itemId
					table.insert(bytes, zo_floor(value / 2^12)*2+1)
					value = value % (2^12)
					table.insert(bytes, zo_floor(value / 2^6)*2+1)
					table.insert(bytes, (value % (2^6))*2+1)
				end
			end
			-- timestamps are saved as 4 bytes, or 23 bit. the leading 24th information bit
			-- is set to 0 to differentiate it from the item id
			value = node[5] or 0
			table.insert(bytes, zo_floor(value / 2^18)*2+1)
			value = value % (2^18)
			table.insert(bytes, zo_floor(value / 2^12)*2+1)
			value = value % (2^12)
			table.insert(bytes, zo_floor(value / 2^6)*2+1)
			table.insert(bytes, (value % (2^6))*2+1)
		end
	end
	d(bytes)
	return string.char(unpack(bytes))
end

function Harvest.Decode(str)
	local string = _G["string"]
	local value = string.byte(str, 1)
	local number = 0
	-- first 3 bit are the version number
	if version ~= zo_floor(value / (2^5)) then
		-- wrong version number
		return
	end
	-- the next 5 bit are the pin type id
	local pinTypeId = value % (2^5)

	local index = 2
	local result = {}
	local itemIds
	local x, y
	while(index < (#str)) do
		-- get x and y value from the first 4 byte
		value = (string.byte(str, index)-1) * 2^5 + (string.byte(str, index + 1) - 1) / 2
		index = index + 2
		x = value / 2^12
		value = (string.byte(str, index)-1) * 2^5 + (string.byte(str, index + 1) - 1) / 2
		index = index + 2
		y = value / 2^12
		-- get the item ids. they start with a most significant information bit of 1
		value = string.byte(str, index)
		itemIds = {}
		while(value >= 2^6) do
			value = (((value - 2^6 - 1) * 2^6 + string.byte(str, index+1) - 1) * 2^6 + string.byte(str, index + 2) - 1) / 2
			table.insert(itemIds, value)
			index = index + 3
			value = string.byte(str, index)
		end
		-- the next number doesn't have the 1 msb, so it is a timestamp
		value = ((((value-1) * 2^6 + string.byte(str, index+1)-1) * 2^6 + string.byte(str, index + 2)-1) * 2^6 + string.byte(str, index + 3) - 1) / 2
		index = index + 4
		table.insert(result, {x,y,{},itemIds, value})
	end
	return result
end