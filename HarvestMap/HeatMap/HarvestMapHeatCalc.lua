
-- The code in this file will calculate the heat map via convolution.
-- The map is split into (HarvestHeat.numSubdivisions * 5)^2 sections.
-- We will then calculate the heat via convolution with a normal kernel with
-- standard deviation 2.5 and a stride of 5.
-- This way we get a heatmap of size (HarvestHeat.numSubdivisions)^2

HarvestHeat.kernelTable = {}
-- calculate the normal kernel
do
	local sum = 0
	local s = 12.5 -- (5/2)^2 * 2
	local val
	for i = 1, 15 do
		HarvestHeat.kernelTable[i] = {}
		for j = 1, 15 do
			val = (2.71828)^(-((i-8)^2+(j-8)^2)/s)
			sum = sum + val
			HarvestHeat.kernelTable[i][j] = val
		end
	end
	-- normalize the kernel
	for i = 1, 15 do
		for j = 1, 15 do
			HarvestHeat.kernelTable[i][j] = HarvestHeat.kernelTable[i][j] / sum
		end
	end
end

local function kernel(i,j)
	return HarvestHeat.kernelTable[i+8][j+8]
end

function HarvestHeat.CalculateHeatMap()
	local harvest = Harvest
	local harvestHeat = HarvestHeat
	-- only do this costly calculation if we are on a zone map
	-- the heatmap won't be displayed on other map types
	--if not (GetMapType() == MAPTYPE_ZONE) then
	--	return
	--end
	-- divide the map into (HarvestHeat.numSubdivisions * 5)^2 sections and count
	-- the number of pins in each section
	local map = {}
	for x = 0, (harvestHeat.numSubdivisions * 5 - 1) do
		map[x] = {}
		for y = 0, (harvestHeat.numSubdivisions * 5 - 1) do
			map[x][y] = 0
		end
	end
	local viewedMap = true
	local mapName, x, y, measurement = Harvest.GetLocation( viewedMap )
	for _, pinTypeId in pairs(harvest.PINTYPES) do
		if harvest.IsPinTypeVisible( pinTypeId ) then
			local nodes = harvest.GetNodesOnMap( pinTypeId, mapName, measurement )
			for _, division in pairs(divisions) do
				if type(division) == "table" then -- .width key should be skipped
					for nodeIndex, node in pairs(division) do
						x = zo_max(0, zo_min(zo_floor(node.data[1] * harvestHeat.numSubdivisions * 5), harvestHeat.numSubdivisions * 5 - 1))
						y = zo_max(0, zo_min(zo_floor(node.data[2] * harvestHeat.numSubdivisions * 5), harvestHeat.numSubdivisions * 5 - 1))
						map[x][y] = map[x][y] + 1
					end
				end
			end
		end
	end
	
	-- convolution with stride 5
	harvestHeat.maxHeat = 0
	harvestHeat.heatMap = {}
	local sum
	for x = 0, (harvestHeat.numSubdivisions - 1) do
		harvestHeat.heatMap[x] = {}
		for y = 0, (harvestHeat.numSubdivisions - 1) do
			sum = 0
			for i = -7, 7 do
				for j = -7, 7 do
					sum = sum + ((map[x*5+2+i] or {})[y*5+2+j] or 0) * kernel(i,j)
				end
			end
			harvestHeat.heatMap[x][y] = sum
			harvestHeat.maxHeat = zo_max(sum, harvestHeat.maxHeat)
		end
	end
	harvestHeat.needsRefresh = false
end

-- debug function which displays the heat map in the chat box
-- to bad the chat font isn't monospaced :(
function HarvestHeat.displayHeat(ratio)
	local str
	for y = 0, (numSubdivisions - 1) do
		str = ""
		for x = 0, (numSubdivisions - 1) do
			if HarvestHeat.heatMap[x][y] / HarvestHeat.maxHeat >= ratio then
				str = str .. "X"
			else
				str = str .. "_"
			end
		end
		d(str)
	end
end