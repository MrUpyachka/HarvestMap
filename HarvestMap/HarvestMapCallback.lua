if not Harvest then
	Harvest = {}
end

local Harvest = _G["Harvest"]

Harvest.FOUNDDATA = 1
Harvest.NODECREATED = 2
Harvest.NODEUPDATED = 3
Harvest.NODEDELETED = 4
Harvest.NODEHIDDEN = 5
Harvest.NODEUNHIDDEN = 6

Harvest.SETTINGCHANGED = 7

Harvest.EVENTS = {
	Harvest.FOUNDDATA, Harvest.NODECREATED,
	Harvest.NODEUPDATED, Harvest.NODEDELETED,
	Harvest.SETTINGCHANGED, Harvest.NODEHIDDEN,
	Harvest.NODEUNHIDDEN,
}

Harvest.callbacks = {}
for index, event in pairs(Harvest.EVENTS) do
	Harvest.callbacks[event] = {}
end

function Harvest.RegisterForEvent(event, callback)
	assert(Harvest.callbacks[event]) -- valid event?
	assert(type(callback) == "function") -- valid callback?

	table.insert(Harvest.callbacks[event], callback)
end

function Harvest.FireEvent(event, ...)
	assert(Harvest.callbacks[event]) -- valid event?

	for _, callback in pairs(Harvest.callbacks[event]) do
		callback(event, ...)
	end
end