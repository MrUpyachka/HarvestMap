-- This script tries to find a good farming route for ressources.
-- This problem is not the same as TSP, as we do not have to farm every ressource,
-- we only want to find a route which has the best ressource per time ratio.
-- ...or equivalently the highest nodes per path length ratio, or the least average edge length
-- This problem is NP-complete, so I didn't bother creating an algorithm which calculates the optimal farming tour.
-- Luckily we have an abundance of nodes on maps so our tour needs to only visit a very small fraction of all nodes.
-- This benefits greedy algorithms a lot. For TSP the problem with greedy algorithms is, that at the end of our tour we tend to get really long paths.
-- With our abundance of nodes however, there is a close node most of the time, so we do not get these exessively large edge lengths near the end of our path.

-- I originally tried to solve the problem via ant colony optimization.
-- It turned out however, that greedy algorithms perform so well on our data at hand,
-- that the whole "learning" process of the ant colony optimization doesn't benefit the result for many iterations.
-- As I don't want to spend hours calculating an optimal path, I just settle for a greedy-like algorithm.
-- The below code is essentially a ACO algorithm, but with a pheromone influence of 0.

if not HarvestFarm then
	HarvestFarm = {}
end

local LMP = LibStub("LibMapPins-1.0")
local COMPASS_PINS = LibStub("CustomCompassPins")
local GPS = LibStub("LibGPS2")

local HarvestFarm = _G["HarvestFarm"]
local Harvest = _G["Harvest"]

local HarvestFarmCompassArrow = _G["HarvestFarmCompassArrow"]
local HarvestFarmCompass = _G["HarvestFarmCompass"]
local HarvestFarmCompassDistance = _G["HarvestFarmCompassDistance"]
local HarvestFarmCompassStats = _G["HarvestFarmCompassStats"]

local edges
local points
local lastPointIndex
local bestPath
local bestRatio
local num_data_points

local distance, realDistance
do
	-- these functions are called often every frame, so add local references for performance
	local sqrt = math.sqrt
	distance = function(a, b)
		local dx = a[1] - b[1]
		local dy = a[2] - b[2]
		return sqrt(dx * dx + dy * dy)
	end

	realDistance = function(a, b)
		local dx = a[3] - b[3]
		local dy = a[4] - b[4]
		return sqrt((dx * dx + dy * dy) / Harvest.GetGlobalMinDistanceBetweenPins()) * 10
	end
end

-- construct a graph with the ressource nodes as vertices, but the edges may only have a length of maxLength
local function constructGraph(maxLength)
	points = {}
	edges = {}
	num_data_points = 0

	local viewedMap = true
	local map, x, y, measurement = Harvest.GetLocation( viewedMap )
	-- don't use the helper on weird maps that have no valid meassurement
	if (not measurement) or Harvest.IsModifiedMap(GetMapContentType(), measurement) then
		return 1
	end

	-- to meters
	HarvestFarm.minLength = HarvestFarm.minLengthKM * 1000
	-- to global distance
	HarvestFarm.minLength = HarvestFarm.minLength * math.sqrt(Harvest.GetGlobalMinDistanceBetweenPins()) / 10
	-- to local distance
	HarvestFarm.minLength = HarvestFarm.minLength / measurement.scaleX

	-- add selected ressource nodes to the points/vertices list
	for _, pinTypeId in pairs(Harvest.PINTYPES) do
		if HarvestFarm.includedPinTypes[ pinTypeId ] then
			local nodes = Harvest.GetNodesOnMap( pinTypeId, map, measurement )
			for _, division in pairs(nodes) do
				if type(division) == "table" then -- .width key should be skipped
					for nodeIndex, node in pairs(division) do
						-- each point/vertex consists of and x and y coordinate and a list of the neighbors/edges
						table.insert(points, {node.data[1], node.data[2], node.global[1], node.global[2], edges={}})
						num_data_points = num_data_points + 1
					end
				end
			end
		end
	end
	-- no ressources available, return an error
	if (#points) == 0 then
		return 2
	end
	-- create the edges
	local dist, edge, pointA, pointB, remPoints
	for i = 1, num_data_points do
		for j = (i+1), num_data_points do
			pointA = points[i]
			pointB = points[j]
			dist = distance(points[i], points[j])
			if dist <= maxLength then
				-- each edge consists of the indizes of the two adjacent vertices, its distance and its pheromone value
				edge = { i, j, distance = dist}--, phero = 1 }
				table.insert(edges, edge)
				-- add the edge to the vertices' neighbor table
				pointA.edges[j] = edge
				pointB.edges[i] = edge
			end
		end
	end
	return 0
end

-- this function lets the given ant move along one edge
-- the return value is true, if the ant was able to move and false if the ant is stuck and dies a horrible death by the GC
local updateAnt
do
	-- local references because this is called many times each frame
	local table = _G["table"]
	local next = _G["next"]
	local random = math.random
	local pairs = _G["pairs"]

	updateAnt = function(ant)
		local point = points[ant.currentIndex] -- the current vertex the ant is on
		local possible = {} -- list of all vertices the ant can move to during this step and their probabilities
		local total = 0 -- number of possible vertices
		local prob

		for neighborIndex, edge in pairs(point.edges) do
			-- only vertices the ant hasn't visited yet can be visited
			if not ant.visited[neighborIndex] then
				-- the may only return to its starting vertex, if its path is long enough
				if neighborIndex ~= ant.startIndex or ant.pathLength >= HarvestFarm.minLength then
					-- probability of the ant taking this edge
					--prob = ((edge.phero)^HarvestFarm.alpha * (1/edge.distance)^HarvestFarm.beta )
					prob = (1/edge.distance)^10
					total = total + prob
					table.insert(possible, {index=neighborIndex, edge=edge, prob=prob} )
				end
			end
		end
		-- check if the ant can go somewhere
		if next(possible) == nil then
			return false
		end
		-- now the ant is going to choose an edge to walk on
		prob = random() * total
		for _, neighbor in pairs(possible) do
			prob = prob - neighbor.prob
			-- will the ant take this edge?
			if prob <= 0 then
				ant.visited[neighbor.index] = true
				ant.currentIndex = neighbor.index
				ant.pathLength = ant.pathLength + neighbor.edge.distance
				table.insert(ant.path, neighbor.index)--edge)
				return true
			end
		end
		return false -- rounding error :(
	end
end

-- this function starts the calculation (without any pheromone update)
function HarvestFarm.Start()
	HarvestFarm.lastMap = GetMapTileTexture()
	HarvestFarm.bestPath = nil
	HarvestFarm.finishTime = nil
	HarvestFarm.numFarmedNodes = 0

	lastPointIndex = nil
	bestPath = nil
	bestRatio = 0

	local result = constructGraph(HarvestFarm.maxDist)
	if result == 0 then
		-- register the update function which will handle the actual computing of the path
		EVENT_MANAGER:RegisterForUpdate("HarvestFarm", 0, HarvestFarm.Compute)
	elseif result == 1 then
		ZO_Dialogs_ShowDialog("HARVESTFARM_INVALID_MAP", {}, { mainTextParams = {} } )
	elseif result == 2 then
		ZO_Dialogs_ShowDialog("HARVESTFARM_NO_RESSOURCES", {}, { mainTextParams = {} } )
	end
end

-- this function updates the ants
do
	local next = _G["next"]
	local zo_max = _G["zo_max"]
	local GetGameTimeMilliseconds = _G["GetGameTimeMilliseconds"]
	function HarvestFarm.Compute()
		local startTime = GetGameTimeMilliseconds()
		local ant, ratio
		-- update the ants for about 10 milliseconds, then stop until the next frame to prevent freezing the game
		while(GetGameTimeMilliseconds() - startTime < 20) do
			lastPointIndex = next(points, lastPointIndex)
			if not lastPointIndex then
				break
			end
			ant = {visited={}, currentIndex=lastPointIndex, startIndex=lastPointIndex, pathLength=0, path = {}}
			while(updateAnt(ant)) do
				if ant.currentIndex == ant.startIndex then
					ratio = ((#(ant.path)) / ant.pathLength)
					if ratio > bestRatio then
						bestRatio = ratio
						bestPath = ant.path
					end
					break
				end
			end
		end
		if lastPointIndex then
			HarvestFarm.bar:SetValue(zo_max(100 * (lastPointIndex / num_data_points), 1))
		else
			HarvestFarm.bar:SetValue(100)
			HarvestFarm.Finish()
		end
	end
end

function HarvestFarm.ReduceCrossings()
	-- crossing sections are not optimal and can always be reduced
	-- this leads to a shorter and thus better tour
	-- the below code will search for two edges that cross each other
	-- the first edge connects the two vertices with index bestPath[previousPathIndex]
	-- and bestPath[pathIndex]
	-- the second edge connects the vertices with index bestPath[previousOtherPathIndex]
	-- and bestPath[otherPathIndex]
	local again = true
	while(again) do
		again = false
		local deb = d
		local previousPathIndex = #bestPath
		local previousOtherPathIndex
		local a,b,c,d,e,f,det
		local lambda, mu
		for pathIndex = 1, #bestPath do
			if again then break end
			-- please excuse this horrible code. it's essentially just solving a 2x2 linear system to check if the two edges intersect each other
			a = points[bestPath[pathIndex]][1] - points[bestPath[previousPathIndex]][1]
			c = points[bestPath[pathIndex]][2] - points[bestPath[previousPathIndex]][2]
			previousOtherPathIndex = pathIndex + 1
			-- check the current edge with all other edges
			for otherPathIndex = (pathIndex + 2), (#bestPath) do
				if again then break end
				-- some more lineare algebra without proper variable names hooray
				b = points[bestPath[previousOtherPathIndex]][1] - points[bestPath[otherPathIndex]][1]
				d = points[bestPath[previousOtherPathIndex]][2] - points[bestPath[otherPathIndex]][2]
				e = points[bestPath[previousOtherPathIndex]][1] - points[bestPath[previousPathIndex]][1]
				f = points[bestPath[previousOtherPathIndex]][2] - points[bestPath[previousPathIndex]][2]
				det = a*d - b*c
				if det ~= 0 then
					lambda = (d*e - b*f) / det
					mu = (a*f - c*e) / det
					-- check if the two edges cross each other
					if lambda > 0 and lambda < 1 and mu > 0 and mu < 1 then
						again = true
						--deb("remove")
						-- if they do, untangle the crossing
						for i = 0, 99999 do--math.huge do
						if (pathIndex+i) >= (previousOtherPathIndex-i) then
							--deb("switched", i)
							break
						end
						a = bestPath[pathIndex+i]
						bestPath[pathIndex+i] = bestPath[previousOtherPathIndex-i]
						bestPath[previousOtherPathIndex-i] = a
						end -- end for
					end
				end
				previousOtherPathIndex = otherPathIndex
			end -- end for
			previousPathIndex = pathIndex
			--table.insert(bestPathPoints, points[pointIndex])
		end
	end
end

function HarvestFarm.Finish()
	-- the calculation is over, so we can remove the update part
	EVENT_MANAGER:UnregisterForUpdate("HarvestFarm")
	-- output the results to the user and display the discovered path
	if bestPath then
		HarvestFarm.ReduceCrossings()
		-- the bestPath list consists of indices of the visited vertices
		-- we now create a list of these vertices objects/tables, so we can delete all the other vertices
		-- and all the edges. otherwise they'd use up a lot of memory
		local bestPathPoints = {}
		local length = 0
		local lastPoint = points[bestPath[#bestPath]]
		local point
		for _, pointIndex in ipairs(bestPath) do
			point = points[pointIndex]
			point.edges = nil
			length = length + realDistance(point, lastPoint)
			table.insert(bestPathPoints, point)
			lastPoint = point
		end
		HarvestFarm.bestPath = bestPathPoints
		HarvestFarm.nextPointIndex = 1
		HarvestFarm.finishTime = GetFrameTimeMilliseconds()
		HarvestFarm.numFarmedNodes = 0

		Harvest.RefreshPins( Harvest.TOUR )
		HarvestFarm.DisplayPath()

		ZO_Dialogs_ShowDialog("HARVESTFARM_RESULT", {}, { mainTextParams = { tostring(zo_round(((#bestPath) / length) * 100 * 1000) / 100) } } )
		HarvestFarmCompass:SetHidden(Harvest.IsFarmingInterfaceHidden())

		EVENT_MANAGER:RegisterForUpdate("HarvestFarmUpdatePosition", 50, HarvestFarm.UpdatePosition)

	else
		ZO_Dialogs_ShowDialog("HARVESTFARM_ERROR", {}, { mainTextParams = {} } )
		HarvestFarmCompass:SetHidden(true)
		EVENT_MANAGER:UnregisterForUpdate("HarvestFarmUpdatePosition")
	end
	-- delete all the data to get memory back (whenever the GC kicks in)
	bestPath = nil
	points = nil
	edges = nil
end

-- this function will display/remove/refresh the tour on the map
function HarvestFarm.DisplayPath()
	-- remove the displayed path and only draw a new one, if one was discovered
	HarvestFarm.linkPool:ReleaseAllObjects()
	if HarvestFarm.minimapPool then
		HarvestFarm.minimapPool:ReleaseAllObjects()
	end
	if not HarvestFarm.bestPath then
		return
	end
	-- check if we calculated the path for the currently displayed map
	if HarvestFarm.lastMap == GetMapTileTexture() then
		-- create the line sections of the path
		-- each line section combines two points, so we need the previous point as well
		-- the "previous" point of the first point is the very last point of our tour.
		local lastPoint = HarvestFarm.bestPath[#HarvestFarm.bestPath]
		local linkControl
		for _, point in pairs(HarvestFarm.bestPath) do
			linkControl = HarvestFarm.linkPool:AcquireObject()
			linkControl.startX = point[1]
			linkControl.startY = point[2]
			linkControl.endX = lastPoint[1]
			linkControl.endY = lastPoint[2]
			linkControl:SetTexture("EsoUI/Art/AvA/AvA_transitLine_dashed.dds")
			linkControl:SetColor(1,0,0,1)
			linkControl:SetDrawLevel(10)
			lastPoint = point
		end
		if HarvestFarm.minimapPool then
			for _, point in pairs(HarvestFarm.bestPath) do
				linkControl = HarvestFarm.minimapPool:AcquireObject()
				linkControl.startX = point[1]
				linkControl.startY = point[2]
				linkControl.endX = lastPoint[1]
				linkControl.endY = lastPoint[2]
				linkControl:SetTexture("EsoUI/Art/AvA/AvA_transitLine_dashed.dds")
				linkControl:SetColor(1,0,0,1)
				linkControl:SetDrawLevel(10)
				lastPoint = point
			end
		end
		-- correctly display the line sections on the map
		local mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
		local links = HarvestFarm.linkPool:GetActiveObjects()
		for _, link in pairs(links) do
			local startX, startY, endX, endY = link.startX * mapWidth, link.startY * mapHeight, link.endX * mapWidth, link.endY * mapHeight
			ZO_Anchor_LineInContainer(link, nil, startX, startY, endX, endY)
		end
		if HarvestFarm.minimapPool then
			if Fyr_MM_Scroll_Map then
				mapWidth, mapHeight = Fyr_MM_Scroll_Map:GetDimensions()
			else
				mapWidth, mapHeight = AUI_MapContainer:GetDimensions()
			end
			links = HarvestFarm.minimapPool:GetActiveObjects()
			for _, link in pairs(links) do
				local startX, startY, endX, endY = link.startX * mapWidth, link.startY * mapHeight, link.endX * mapWidth, link.endY * mapHeight
				ZO_Anchor_LineInContainer(link, nil, startX, startY, endX, endY)
			end
		end
	end
end

function HarvestFarm.FarmedANode(link, count)
	if not HarvestFarm.finishTime then
		return
	end
	if MasterMerchant then
		HarvestFarm.numFarmedNodes = HarvestFarm.numFarmedNodes + (MasterMerchant:itemStats(link).avgPrice or 0) * count
	else
		HarvestFarm.numFarmedNodes = HarvestFarm.numFarmedNodes + 1
	end
end

do
	local sqrt = math.sqrt
	local pi = math.pi
	local atan2 = math.atan2
	local zo_round = _G["zo_round"]
	local zo_abs = _G["zo_abs"]
	local format = string.format
	local GetPlayerCameraHeading = _G["GetPlayerCameraHeading"]
	local GetMapPlayerPosition = _G["GetMapPlayerPosition"]

	function HarvestFarm.UpdatePosition(time)
		-- does the path exist yet (or are we still calculating?)
		local bestPath = HarvestFarm.bestPath
		if not bestPath then
			HarvestFarmCompass:SetHidden(true)
			return
		end
		HarvestFarmCompass:SetHidden(Harvest.IsFarmingInterfaceHidden())
		local x, y = GPS:LocalToGlobal(GetMapPlayerPosition( "player" ))

		if x and y then
			local pointA = bestPath[HarvestFarm.nextPointIndex]
			local minDistance = Harvest.GetGlobalMinDistanceBetweenPins()
			-- are we close to pointA ?
			local dx = x - pointA[3]
			local dy = y - pointA[4]
			if dx * dx + dy * dy < minDistance then
				HarvestFarm.UpdateToNextTarget()
			end

			HarvestFarmCompassArrow:SetHidden(Harvest.IsArrowHidden())
			HarvestFarmCompassDistance:SetText(format("%d m", zo_round(sqrt((dx * dx + dy * dy) / minDistance)*10) ))
			if not Harvest.IsArrowHidden() then
				local angle = -atan2(dx, dy)
				angle = (angle + GetPlayerCameraHeading())
				HarvestFarmCompassArrow:SetTextureRotation(-angle, 0.5, 0.5)
				if angle > pi then
					angle = angle - 2 * pi
				elseif angle < -pi then
					angle = angle + 2 * pi
				end
				angle = zo_abs(angle / pi)
				HarvestFarmCompassArrow:SetColor(2*angle-angle*angle, 1 - angle*angle, 0, 0.75)
			end
		else
			HarvestFarmCompassDistance:SetText("Unknown")
			HarvestFarmCompassArrow:SetHidden(true)
		end

		HarvestFarmCompassStats:SetText(format("%.2f", HarvestFarm.numFarmedNodes / (time - HarvestFarm.finishTime) * 1000 * 60))
	end
end

do
	local lastTime = 0
	function HarvestFarm.UpdateToNextTarget()
		HarvestFarm.nextPointIndex = ((HarvestFarm.nextPointIndex) % (#(HarvestFarm.bestPath))) + 1
		Harvest.RefreshPins( Harvest.TOUR )
		local time = GetFrameTimeMilliseconds()
		if time - lastTime > 1000 then
			CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_EVENT_SMALL_TEXT, SOUNDS.QUEST_OBJECTIVE_STARTED, "HarvestMap farming tour updated")
			lastTime = time
		end
	end
end

function HarvestFarm.MapCallback(pinmanager)
	--LMP.pinManager:RemovePins(LMP.pinManager.customPins[_G[ Harvest.GetPinType( Harvest.TOUR )]].pinTypeString)
	if not HarvestFarm.bestPath then return end
	if not (HarvestFarm.lastMap == GetMapTileTexture()) then return end
	local point = HarvestFarm.bestPath[HarvestFarm.nextPointIndex]
	LMP:CreatePin( Harvest.GetPinType(Harvest.TOUR) , point, point[1], point[2] )
end

function HarvestFarm.CompassCallback(pinmanager)
	if not HarvestFarm.bestPath then return end
	if not (HarvestFarm.lastMap == GetMapTileTexture()) then return end
	local point = HarvestFarm.bestPath[HarvestFarm.nextPointIndex]
	pinmanager:CreatePin( Harvest.GetPinType(Harvest.TOUR) , point, point[1], point[2] )
end

function HarvestFarm.additionalLayout( pin )
	local color = COMPASS_PINS.pinLayouts[ pin.pinType ].color
	if not color then
		return
	end

	local tex = pin:GetNamedChild( "Background" )
	tex:SetColor(color[1] , color[2] , color[3], 1)
	tex:SetDrawLevel(10)
end

function HarvestFarm.additionalLayoutReset( pin )
	local tex = pin:GetNamedChild( "Background" )
	tex:SetColor( 1, 1, 1, 1 )
	tex:SetDrawLevel(0)
end

function HarvestFarm.RemoveTour()
	HarvestFarm.lastMap = nil
	HarvestFarm.lastZoneIndex = nil
	HarvestFarm.lastMapType = nil

	HarvestFarm.bestPath = nil
	HarvestFarm.finishTime = nil
	HarvestFarm.numFarmedNodes = 0

	EVENT_MANAGER:UnregisterForUpdate("HarvestFarm")
	EVENT_MANAGER:UnregisterForUpdate("HarvestFarmUpdatePosition")

	bestPath = nil
	points = nil
	edges = nil

	HarvestFarmCompass:SetHidden(true)
	Harvest.RefreshPins( Harvest.TOUR )
	HarvestFarm.DisplayPath()
end

-- do addon dependant hooks a bit later, as harvestmap might've been loaded earlier
function HarvestFarm.PostInitialize()
	if Fyr_MM_Scroll_Map then
		HarvestFarm.minimapPool = ZO_ControlPool:New("HarvestLink", Fyr_MM_Scroll_Map, "MiniLink")
	elseif AUI_MapContainer then
		HarvestFarm.minimapPool = ZO_ControlPool:New("HarvestLink", AUI_MapContainer, "MiniLink")
	end

	if MasterMerchant then
		HarvestFarmCompassStatsText:SetText( Harvest.GetLocalization( "goldperminute" ) )
	else
		HarvestFarmCompassStatsText:SetText( Harvest.GetLocalization( "nodesperminute" ) )
	end
	HarvestFarmCompassSkipNodeButton:SetText( Harvest.GetLocalization( "skiptarget" ) )
	HarvestFarmCompassDistanceText:SetText( Harvest.GetLocalization( "distancetotarget" ) )
	HarvestFarmCompassArrowCheckText:SetText( Harvest.GetLocalization( "showarrow" ) )

	if Fyr_MM_Scroll_Map then
		local oldDimensionsMM = Fyr_MM_Scroll_Map.SetDimensions
		Fyr_MM_Scroll_Map.SetDimensions = function(self, mapWidth, mapHeight, ...)
			local links = HarvestFarm.minimapPool:GetActiveObjects()
			for _, link in pairs(links) do
				local startX, startY, endX, endY = link.startX * mapWidth, link.startY * mapHeight, link.endX * mapWidth, link.endY * mapHeight
				ZO_Anchor_LineInContainer(link, nil, startX, startY, endX, endY)
			end
			oldDimensionsMM(self, mapWidth, mapHeight, ...)
		end
	elseif AUI_MapContainer then
		local oldDimensionsMM = AUI_MapContainer.SetDimensions
		AUI_MapContainer.SetDimensions = function(self, mapWidth, mapHeight, ...)
			local links = HarvestFarm.minimapPool:GetActiveObjects()
			for _, link in pairs(links) do
				local startX, startY, endX, endY = link.startX * mapWidth, link.startY * mapHeight, link.endX * mapWidth, link.endY * mapHeight
				ZO_Anchor_LineInContainer(link, nil, startX, startY, endX, endY)
			end
			oldDimensionsMM(self, mapWidth, mapHeight, ...)
		end
		-- AUI's minimap doesn't seem to fire OnWorldMapChanged until the map is opened
		local oldRefresh = AUI.Minimap.Map.Refresh
		AUI.Minimap.Map.Refresh = function(...)
			HarvestFarm.DisplayPath()
			oldRefresh(...)
		end
	end
end

-- called from OnAddonLoaded
function HarvestFarm.Initialize()
	-- from a node only that are closer than this distance will be considered as neighbors
	HarvestFarm.maxDist = 0.1
	-- minimum length of the path, can be set in the farming options panel
	HarvestFarm.minLengthKM = 3
	-- pin types that are included in the helper, can be set in the options panel
	HarvestFarm.includedPinTypes = {}
	-- link pool for the line sections, which are used to display the path on the map
	HarvestFarm.linkPool = ZO_ControlPool:New("HarvestLink", ZO_WorldMapContainer, "Link")

	HarvestFarmCompassArrow = _G["HarvestFarmCompassArrow"]
	HarvestFarmCompass = _G["HarvestFarmCompass"]
	HarvestFarmCompassDistance = _G["HarvestFarmCompassDistance"]
	HarvestFarmCompassStats = _G["HarvestFarmCompassStats"]

	-- initialize the checkbox in the farming helpers stat interface
	ZO_CheckButton_SetCheckState(HarvestFarmCompassArrowCheckButton, not Harvest.IsArrowHidden())
	ZO_CheckButton_SetToggleFunction(HarvestFarmCompassArrowCheckButton, function() Harvest.SetArrowHidden(not Harvest.IsArrowHidden()) end)

	-- register dialogs which will display the result to the user
	local pathDialog = {
		title = { text = Harvest.GetLocalization( "farmresult" ) },
		mainText = { text = Harvest.GetLocalization( "farmnotour" ) },
		buttons = {
			[1] = {
				text = GetString(SI_DIALOG_CLOSE),
			},
		}
	}
	ZO_Dialogs_RegisterCustomDialog("HARVESTFARM_ERROR", pathDialog)

	pathDialog = {
		title = { text = Harvest.GetLocalization( "farmerror" ) },
		mainText = { text = Harvest.GetLocalization( "farmnoressources" ) },
		buttons = {
			[1] = {
				text = GetString(SI_DIALOG_CLOSE),
			},
		}
	}
	ZO_Dialogs_RegisterCustomDialog("HARVESTFARM_NO_RESSOURCES", pathDialog)

	pathDialog = {
		title = { text = Harvest.GetLocalization( "farmerror" ) },
		mainText = { text = Harvest.GetLocalization( "farminvalidmap" ) },
		buttons = {
			[1] = {
				text = GetString(SI_DIALOG_CLOSE),
			},
		}
	}
	ZO_Dialogs_RegisterCustomDialog("HARVESTFARM_INVALID_MAP", pathDialog)

	pathDialog = {
		title = { text = Harvest.GetLocalization( "farmresult" ) },
		mainText = { text = Harvest.GetLocalization( "farmsuccess" ) },
		buttons = {
			[1] = {
				text = GetString(SI_DIALOG_CLOSE),
			},
		}
	}
	ZO_Dialogs_RegisterCustomDialog("HARVESTFARM_RESULT", pathDialog)

	-- when the map changes, we have to remove/display the calculated route
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", HarvestFarm.DisplayPath)

	-- hack into the SetDimensions function as we need to scale the displayed path whenever the user zooms in/out
	local oldDimensions = ZO_WorldMapContainer.SetDimensions
	ZO_WorldMapContainer.SetDimensions = function(self, mapWidth, mapHeight, ...)
		local links = HarvestFarm.linkPool:GetActiveObjects()
		for _, link in pairs(links) do
			local startX, startY, endX, endY = link.startX * mapWidth, link.startY * mapHeight, link.endX * mapWidth, link.endY * mapHeight
			ZO_Anchor_LineInContainer(link, nil, startX, startY, endX, endY)
		end
		oldDimensions(self, mapWidth, mapHeight, ...)
	end

	--------------------------------------
	-- construct the farming helper/options panel
	--------------------------------------

	-- add the HarvestFarm panel to the right side of the worldmap
	ZO_CreateStringId("HARVESTFARM_NAME", "HarvestFarm")
	local buttonData = {
		normal = "EsoUI/Art/inventory/inventory_tabicon_crafting_up.dds",
		pressed = "EsoUI/Art/inventory/inventory_tabicon_crafting_down.dds",
		highlight = "EsoUI/Art/inventory/inventory_tabicon_crafting_over.dds",
	}
	local farmFragment = ZO_FadeSceneFragment:New(HarvestFarmControl)
	WORLD_MAP_INFO.modeBar:Add(HARVESTFARM_NAME, {farmFragment}, buttonData)

	HarvestFarmControlPaneScrollChild:SetWidth(HarvestFarmControlPane:GetWidth())
	-- add controls to the newly created panel
	-- the descriptions and sliders of LibAddonMenu are nice, I'm gonna steal them :)
	HarvestFarmControlPaneScrollChild.panel = HarvestFarmControlPaneScrollChild
	HarvestFarmControlPaneScrollChild.panel.data = {}
	-- add the general HarvestFarm description
	local definition = {
		type = "description",
		title = "",
		text = Harvest.GetLocalization( "farmdescription" ),
	}
	local control = LAMCreateControl.description(HarvestFarmControlPaneScrollChild, definition)
	control:SetAnchor(TOPLEFT, HarvestFarmControlPaneScrollChild, TOPLEFT, 0, 0)
	local lastControl = control
	-- add the slider for the minimum route length
	local definition = {
		type = "slider",
		name = Harvest.GetLocalization( "farmminlength" ),
		tooltip =  Harvest.GetLocalization( "farmminlengthtooltip" ),
		min = 1,
		max = 10,
		getFunc = function()
			return HarvestFarm.minLengthKM
		end,
		setFunc = function( value )
			HarvestFarm.minLengthKM = value
		end,
		default = 3,
	}
	control = LAMCreateControl.slider(HarvestFarmControlPaneScrollChild, definition)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
	local lastControl = control
	-- add description to explain what the minimum route length is for
	definition = {
		type = "description",
		title = "",
		text = Harvest.GetLocalization( "farmminlengthdescription" ),
	}
	local control = LAMCreateControl.description(HarvestFarmControlPaneScrollChild, definition)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 10)
	lastControl = control
	-- add a button to start the calculation of the farming route
	control = WINDOW_MANAGER:CreateControlFromVirtual(nil, HarvestFarmControlPaneScrollChild, "ZO_DefaultButton")
	control:SetText( Harvest.GetLocalization( "calculatetour" ) )
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
	control:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 20)
	control:SetClickSound("Click")
	control:SetHandler("OnClicked", function(self, ...)
		HarvestFarm.Start()
	end)
	lastControl = control
	-- add a loading bar to display the process of the calculation
	control = WINDOW_MANAGER:CreateControl(nil, HarvestFarmControlPaneScrollChild, CT_STATUSBAR)
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 4, 20)
	control:SetAnchor(BOTTOMRIGHT, lastControl, BOTTOMRIGHT, -4, 50)
	control:SetMinMax(0,100)
	control:SetAlpha(1)
	control:SetColor(0.2,1,0.2)
	control:SetValue(0)
	lastControl = control
	HarvestFarm.bar = control
	-- add a nice frame to make the bar appear neater :)
	control = WINDOW_MANAGER:CreateControl(nil, lastControl, CT_BACKDROP)
	control:SetCenterColor(0, 0, 0)
	control:SetAnchor(TOPLEFT, lastControl, TOPLEFT, -4, -4)
	control:SetAnchor(BOTTOMRIGHT, lastControl, BOTTOMRIGHT, 4, 4)
	control:SetEdgeTexture("EsoUI\\Art\\Tooltips\\UI-SliderBackdrop.dds", 32, 4)
	-- show interface
	definition = {
		type = "checkbox",
		name = Harvest.GetLocalization( "showtourinterface" ),
		getFunc = function()
			return not Harvest.IsFarmingInterfaceHidden()
		end,
		setFunc = function( value )
			Harvest.SetFarmingInterfaceHidden(not value)
		end,
	}
	local control = LAMCreateControl.checkbox(HarvestFarmControlPaneScrollChild, definition)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
	lastControl = control
	HarvestFarm.interfaceCheckbox = control
	-- remove tour button
	control = WINDOW_MANAGER:CreateControlFromVirtual(nil, HarvestFarmControlPaneScrollChild, "ZO_DefaultButton")
	control:SetText( Harvest.GetLocalization( "canceltour" ) )
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
	control:SetAnchor(TOPRIGHT, lastControl, BOTTOMRIGHT, 0, 20)
	control:SetClickSound("Click")
	control:SetHandler("OnClicked", HarvestFarm.RemoveTour)
	lastControl = control
	--------------------------------------
	-- filters
	definition = {
		type = "header",
		name = Harvest.GetLocalization( "ressourcetypes" ),
	}
	local control = LAMCreateControl.header(HarvestFarmControlPaneScrollChild, definition)
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
	lastControl = control
	for _, pinTypeId in pairs(Harvest.PINTYPES) do
		if pinTypeId ~= Harvest.TOUR then
			definition = {
				type = "checkbox",
				name = Harvest.GetLocalization( "pintype" .. pinTypeId ),
				getFunc = function()
					return HarvestFarm.includedPinTypes[ pinTypeId ]
				end,
				setFunc = function( value )
					HarvestFarm.includedPinTypes[ pinTypeId ] = value
				end,
			}
			local control = LAMCreateControl.checkbox(HarvestFarmControlPaneScrollChild, definition)
			control:ClearAnchors()
			control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 20)
			lastControl = control
		end
	end
end

