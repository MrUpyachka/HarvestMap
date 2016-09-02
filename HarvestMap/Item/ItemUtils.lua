--- Utils to help with processing of harvested items.
--
ItemUtils = {}

--- List of ignored types. This types of nodes have no fixed drop.
local ignoredTypes = {
    [Harvest.TROVE] = true,
    [Harvest.OLDTROVE] = true,
    [Harvest.HEAVYSACK] = true,
    [Harvest.FISHING] = true,
    [Harvest.CHESTS] = true,
    [Harvest.JUSTICE] = true,
    -- enchanting was removed with DB
    -- because there is now only one type of harvesting node
    -- for enchanting
    [Harvest.ENCHANTING] = true,
}

--- Checks that we need to handle list of items for specified type.
-- @param pinTypeId type identifier.
-- @return true if we need to store items list, false in opposite case.
--
function ItemUtils.isItemsListRequired(pinTypeId)
    return not ignoredTypes[pinTypeId]
end
