if not Harvest then
	Harvest = {}
end

local Harvest = _G["Harvest"]

-- updating the data can take quite some time
-- to prevent the game from freezing, we break each update process down into smaller parts
-- the smaller parts are executed with a small delay (see Harvest.OnUpdate(time) )
-- updating data as well as other heavy tasks such as importing data are added to the following queue
Harvest.updateQueue = {}
Harvest.updateQueue.first = 1
Harvest.updateQueue.afterLast = 1
function Harvest.IsUpdateQueueEmpty()
	return (Harvest.updateQueue.first == Harvest.updateQueue.afterLast)
end
-- adds a function to the back of the queue
function Harvest.AddToUpdateQueue(fun)
	Harvest.updateQueue[Harvest.updateQueue.afterLast] = fun
	Harvest.updateQueue.afterLast = Harvest.updateQueue.afterLast + 1
end
-- adds a funciton to the front of the queue
function Harvest.AddToFrontOfUpdateQueue(fun)
	Harvest.updateQueue.first = Harvest.updateQueue.first - 1
	Harvest.updateQueue[Harvest.updateQueue.first] = fun
end
-- executes the first function in the queue, if the player is activated yet
do
	local IsPlayerActivated = _G["IsPlayerActivated"]

	function Harvest.UpdateUpdateQueue() --shitty function name is shitty
		if not IsPlayerActivated() then return end
		local fun = Harvest.updateQueue[Harvest.updateQueue.first]
		Harvest.updateQueue[Harvest.updateQueue.first] = nil
		Harvest.updateQueue.first = Harvest.updateQueue.first + 1

		fun()

		if Harvest.IsUpdateQueueEmpty() then
			Harvest.updateQueue.first = 1
			Harvest.updateQueue.afterLast = 1
			Harvest.RefreshPins()
		end
	end
end

function Harvest.GetQueuePercent()
	return zo_floor((Harvest.updateQueue.first/Harvest.updateQueue.afterLast)*100)
end

-- check if saved data is from an older version,
-- update the data if needed
function Harvest.UpdateDataVersion( saveFile )
	-- import old data (Orsinium Update)
	Harvest.UpdatePreOrsiniumData( saveFile )
	-- make itemID a list and fix the chest - fish - bug (Thieves Guild Update)
	Harvest.UpdateItemIdList( saveFile )
	-- add new trove type (Thieves Trove fix)
	Harvest.UpdateOldTrove( saveFile )
	-- dark brotherhood update, simplify data by removing unused fields
	-- remove node name, change itemid list to itemid -> timestamp table
	Harvest.UpdatePreDBData( saveFile )
end

function Harvest.UpdatePreDBData( saveFile )
	-- if no save file was given, update all save files
	if saveFile == nil then
		if HarvestAD then
			Harvest.UpdatePreDBData( Harvest.savedVars["ADnodes"] )
		end
		if HarvestDC then
			Harvest.UpdatePreDBData( Harvest.savedVars["DCnodes"] )
		end
		if HarvestEP then
			Harvest.UpdatePreDBData( Harvest.savedVars["EPnodes"] )
		end
		Harvest.UpdatePreDBData( Harvest.savedVars["nodes"] )
		return
	end
	-- save file is already updated
	if (saveFile.dataVersion or 0) >= 13 then
		return
	end
	-- add the update process to the queue
	Harvest.AddToUpdateQueue(function()
		d("HarvestMap is updating pre-Dark-Brotherhood data for a save file.")
		Harvest.DelayedUpdatePreDBData(saveFile, nil, nil, nil, nil, nil)
	end)
end

function Harvest.UpdateOldTrove( saveFile )
	-- if no save file was given, update all save files
	if saveFile == nil then
		if HarvestAD then
			Harvest.UpdateOldTrove( Harvest.savedVars["ADnodes"] )
		end
		if HarvestDC then
			Harvest.UpdateOldTrove( Harvest.savedVars["DCnodes"] )
		end
		if HarvestEP then
			Harvest.UpdateOldTrove( Harvest.savedVars["EPnodes"] )
		end
		Harvest.UpdateOldTrove( Harvest.savedVars["nodes"] )
		return
	end
	-- save file is already updated
	if (saveFile.dataVersion or 0) >= 12 then
		return
	end
	-- add the update process to the queue
	Harvest.AddToUpdateQueue(function()
		for map, data in pairs(saveFile.data) do
			data[Harvest.TROVE] = data[Harvest.OLDTROVE]
		end
		saveFile.dataVersion = 12
	end)
end

function Harvest.UpdateItemIdList( saveFile )
	if saveFile == nil then
		if HarvestAD then
			Harvest.UpdateItemIdList( Harvest.savedVars["ADnodes"] )
		end
		if HarvestDC then
			Harvest.UpdateItemIdList( Harvest.savedVars["DCnodes"] )
		end
		if HarvestEP then
			Harvest.UpdateItemIdList( Harvest.savedVars["EPnodes"] )
		end
		Harvest.UpdateItemIdList( Harvest.savedVars["nodes"] )
		return
	end
	
	if (saveFile.dataVersion or 0) >= 11 then
		return
	end
	
	-- remove any old data in the thieves trove field.
	-- there might be some stuff like books left in very old save files
	--for map, data in pairs(saveFile.data) do
	--	data[Harvest.TROVE] = {}
	--end
	
	Harvest.AddToUpdateQueue(function()
		d("HarvestMap is updating pre-Thieves-Guild data for a save file.")
		Harvest.DelayedUpdateItemIdList(saveFile, nil, nil, nil, nil, nil)
	end)
end

function Harvest.UpdatePreOrsiniumData( saveFile )
	saveFile = saveFile or Harvest.savedVars["nodes"]

	if (saveFile.dataVersion or 0) >= 10 then
		return
	end

	Harvest.AddToUpdateQueue(function()
		d("HarvestMap is updating pre-Orsinium data for a save file.")
		Harvest.DelayedUpdatePreOrsiniumData(saveFile, nil, nil, nil, nil, nil)
	end)
end

function Harvest.DelayedUpdatePreDBData(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	local entry = nil
	local node
	local changed
	if nodeIndex ~= nil then
		entry = nodes[nodeIndex]
	end
	-- in this frame we will process 2000 nodes
	for counter = 1,2000 do
		while nodeIndex == nil do
			if pinTypes ~= nil then
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			while pinTypeId == nil do
				mapIndex, pinTypes = next(saveFile.data, mapIndex)
				if mapIndex == nil then
					saveFile.dataVersion = 13
					d("HarvestMap finished updating pre-Dark-Brotherhood data for this save file.")
					return
				end
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			nodeIndex, entry = next(nodes, nodeIndex)
		end
		-- here is the actual update part, all the stuff above is just used to delay the update over several frames
		changed = false
		node = Harvest.Deserialize(entry)
		if node then -- check if something went wrong while deserializing
			-- node name list gets removed to reduce filesize
			-- the node name list isn't needed anymore as tooltips are calculated via the item ids
			node[3] = nil
			-- change the itemid list to a itemid -> timestamp table
			-- create itemid list if it doesn't exist (chests, fishing holes etc)
			if not node[4] or not Harvest.ShouldSaveItemId(pinTypeId) then
				node[4] = {}
			end
			-- i got reports of savefiles that are still in pre TG format
			-- to prevent the following lines from crashing, check for such a case and repair the file
			if type(node[4]) ~= "table" then
				node[4] = { node[4] }
			end
			-- change the itemid list to a itemid -> timestamp table
			local itemId2Timestamp = {}
			for _, itemId in pairs(node[4]) do
				itemId2Timestamp[itemId] = 0
			end
			node[4] = itemId2Timestamp
			-- serialize the changed data and save it
			nodes[nodeIndex] = Harvest.Serialize(node)
		else -- node couldn't be deserialized, delete the corrupted data!
			nodes[nodeIndex] = nil
		end
		
		-- update stuff ends here
		nodeIndex, entry = next(nodes, nodeIndex)
	end
	-- add a new process to the front
	-- this way the next 2000 nodes will be updated
	-- (this needs to be added to the front, because at the back of the queue there could be updates for a newer data version
	-- the newer update should only be executed after this one has finished)
	Harvest.AddToFrontOfUpdateQueue(function()
		Harvest.DelayedUpdatePreDBData(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	end)
end

function Harvest.DelayedUpdateItemIdList(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	local entry = nil
	local node
	local changed
	if nodeIndex ~= nil then
		entry = nodes[nodeIndex]
	end
	-- in this frame we will process 2000 nodes
	for counter = 1,2000 do
		while nodeIndex == nil do
			if pinTypes ~= nil then
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			while pinTypeId == nil do
				mapIndex, pinTypes = next(saveFile.data, mapIndex)
				if mapIndex == nil then
					saveFile.dataVersion = 11
					d("HarvestMap finished updating pre-Thieves-Guild data for this save file.")
					return
				end
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			nodeIndex, entry = next(nodes, nodeIndex)
		end
		-- here is the actual update part, all the stuff above is just used to delay the update over several frames
		changed = false
		node = Harvest.Deserialize(entry)
		if node then -- check if something went wrong while deserializing
			if type(node[4]) == "number" then -- itemId (4th field) becomes a list
				node[4] = { node[4] }
				changed = true
				--nodes[nodeIndex] = Harvest.Serialize(node)
			end
			if pinTypeId == Harvest.FISHING then
				node[3] = { "fish" }
				changed = true
			end
			-- no itemIds for fishing, chest and thieves troves
			if not Harvest.ShouldSaveItemId(pinTypeId) then
				node[4] = nil
				changed = true
			end
			if changed then -- serialize the data again and save it, if something was changed by the update routine
				nodes[nodeIndex] = Harvest.Serialize(node)
			end
		else -- node couldn't be deserialized, delete the corrupted data!
			nodes[nodeIndex] = nil
		end
		
		-- update stuff ends here
		nodeIndex, entry = next(nodes, nodeIndex)
	end
	-- add a new process to the front
	-- this way the next 2000 nodes will be updated
	-- (this needs to be added to the front, because at the back of the queue there could be updates for a newer data version
	-- the newer update should only be executed after this one has finished)
	Harvest.AddToFrontOfUpdateQueue(function()
		Harvest.DelayedUpdateItemIdList(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	end)
end

function Harvest.DelayedUpdatePreOrsiniumData(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	local entry = nil
	if nodeIndex ~= nil then
		entry = nodes[nodeIndex]
	end
	for counter = 1,2000 do
		while nodeIndex == nil do
			if pinTypes ~= nil then
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			while pinTypeId == nil do
				mapIndex, pinTypes = next(saveFile.data, mapIndex)
				if mapIndex == nil then
					saveFile.dataVersion = 10
					d("HarvestMap finished updating pre-Orsinium data for this save file.")
					return
				end
				pinTypeId, nodes = next(pinTypes, pinTypeId)
			end
			nodeIndex, entry = next(nodes, nodeIndex)
		end
		if type(entry) == "table" then
			nodes[nodeIndex] = Harvest.Serialize(entry)
		end
		nodeIndex, entry = next(nodes, nodeIndex)
	end
	Harvest.AddToFrontOfUpdateQueue(function()
		Harvest.DelayedUpdatePreOrsiniumData(saveFile, pinTypes, nodes, mapIndex, pinTypeId, nodeIndex)
	end)
	--zo_callLater(function() Harvest.DelayedUpdatePreOrsiniumData(data, nodes, mapIndex, nodeIndex) end, 0.1)
end