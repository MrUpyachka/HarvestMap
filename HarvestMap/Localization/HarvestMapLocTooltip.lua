local LMP = LibStub("LibMapPins-1.0")

if not Harvest then
	Harvest = {}
end
local language = GetCVar("language.2")

function Harvest.GetLocalizedExactTooltip( itemId, pinTypeId )
	return Harvest.itemId2Tooltip[ itemId ] or Harvest.pinTypeId2Tooltip[ pinTypeId ]
end

local pinTypeId2Tooltip = {
	["en"] = {
		[Harvest.BLACKSMITH] = "Ore",
		[Harvest.CLOTHING] = "Fibre",
		[Harvest.ENCHANTING] = "Runestone",
		[Harvest.ALCHEMY] = "Herb",
		[Harvest.WOODWORKING] = "Wood",
		[Harvest.CHESTS] = "Chest",
		[Harvest.WATER] = "Solvent",
		[Harvest.FISHING] = "Fishing spot",
		[Harvest.HEAVYSACK] = "Heavy Sack",
		[Harvest.TROVE] = "Thieves Trove",
		[Harvest.OLDTROVE] = "Thieves Trove",
		[Harvest.JUSTICE] = "Justice Container",
	},
	["de"] = {
		[Harvest.BLACKSMITH] = "Erz",
		[Harvest.CLOTHING] = "Faser",
		[Harvest.ENCHANTING] = "Runenstein",
		[Harvest.ALCHEMY] = "Kraut",
		[Harvest.WOODWORKING] = "Holz",
		[Harvest.CHESTS] = "Schatztruhe",
		[Harvest.WATER] = "Wasser",
		[Harvest.FISHING] = "Fischgrund",
		[Harvest.HEAVYSACK] = "Schwerer Sack",
		[Harvest.TROVE] = "Diebesgut",
		[Harvest.OLDTROVE] = "Diebesgut",
		[Harvest.JUSTICE] = "Justiz Behälter",
	},
	["fr"] = {
		-- MOSTLY MISSING
		[Harvest.ENCHANTING] = "Pierre runique",
		[Harvest.FISHING] = "Poisson",
		[Harvest.CHESTS] = "Coffre au trésor",
		[Harvest.HEAVYSACK] = "Sac Lourd",
		[Harvest.TROVE] = "Trésor des voleurs",
		[Harvest.OLDTROVE] = "Trésor des voleurs",
	},
	["ru"] = {
		[Harvest.BLACKSMITH] = "Pудa",
		[Harvest.CLOTHING] = "Ткaнь",
		[Harvest.ENCHANTING] = "Pунa",
		[Harvest.ALCHEMY] = "Тpaвa",
		[Harvest.WOODWORKING] = "Дpeвecинa",
		[Harvest.CHESTS] = "Cундук",
		[Harvest.WATER] = "Pacтвopитeль",
		[Harvest.FISHING] = "Pыбнoe мecтo",
		[Harvest.HEAVYSACK] = "Тяжeлый мeшoк",
		[Harvest.TROVE] = "Вopoвcкoй тaйник",
		[Harvest.OLDTROVE] = "Вopoвcкoй тaйник",
		[Harvest.JUSTICE] = "Justice Container",
	},
}
Harvest.pinTypeId2Tooltip = pinTypeId2Tooltip["en"]
if pinTypeId2Tooltip[language] then
	for pinTypeId, tooltip in pairs(pinTypeId2Tooltip[language]) do
		Harvest.pinTypeId2Tooltip[pinTypeId] = tooltip
	end
end

local itemId2Tooltip = {
	["en"] = {
		[808] = "Iron Ore",
		[5820] = "High Iron Ore",
		[23103] = "Orichalcum Ore",
		[23104] = "Dwarven Ore",
		[23105] = "Ebony Ore",
		[4482] = "Calcinium Ore",
		[23133] = "Galatite Ore",
		[23134] = "Quicksilver Ore",
		[23135] = "Voidstone Ore",
		[71198] = "Rubedite Ore",

		[812] = "Jute",
		[4464] = "Flax",
		[23129] = "Cotton",
		[23130] = "Spidersilk",
		[23131] = "Ebonthread",
		[33217] = "Kreshweed",
		[33218] = "Ironweed",
		[33219] = "Silverweed",
		[33220] = "Void Bloom",
		[71200] = "Ancestor Silk",

		[30148] = "Entoloma",
		[30149] = "Stinkhorn",
		[30151] = "Emetic Russula",
		[30152] = "Violet Coprinus",
		[30153] = "Namira's Rot",
		[30154] = "White Cap",
		[30155] = "Luminous Russula",
		[30156] = "Imp Stool",
		[30157] = "Blessed Thistle",
		[30158] = "Lady's Smock",
		[30159] = "Wormwood",
		[30160] = "Bugloss",
		[30161] = "Corn Flower",
		[30162] = "Dragonthorn",
		[30163] = "Mountain Flower",
		[30164] = "Columbine",
		[30165] = "Nirnroot",
		[30166] = "Water Hyacinth",
		[77590] = "Nightshade",
		
		[802] = "Maple",
		[521] = "Oak",
		[23117] = "Beech",
		[23118] = "Hickory",
		[23119] = "Yew",
		
		[818] = "Birch",
		[4439] = "Ashtree",
		[23137] = "Mahogany",
		[23138] = "Nightwood",
		[71199] = "Ruby Ash Wood",

		[883] = "Natural Water",
		[1187] =  "Clear Water",
		[4570] = "Pristine Water",
		[23265] = "Cleansed Water",
		[23266] = "Filtered Water",
		[23267] = "Purified Water",
		[23268] ="Cloud Mist",
		[64500] = "Star Dew",
		[64501] = "Lorkhan's Tears",
	},
	["de"] = {
		[808] = "Eisenerz",
		[4482] = "Kalciniumerz",
		[5820] = "Feineisenerz",
		[23103] = "Oreichalkoserz",
		[23104] = "Dwemererz",
		[23105] = "Ebenerz",
		[23133] = "Galatiterz",
		[23134] = "Flinksilbererz",--"Quecksilbererz", -- lol was translated to Flinksilber ingame...
		[23135] = "Leereneisenerz",
		[71198] = "Rubediterz",

		[812] = "Jute",
		[4464] = "Flachs",
		[23129] = "Baumwolle",
		[23130] = "Spinnenseide",
		[23131] = "Ebenseide",
		[33217] = "Kreshkraut",
		[33218] = "Eisenkraut",
		[33219] = "Silberkraut",
		[33220] = "Leerenblüte",
		[71200] = "Ahnenseide",

		[30148] = "Glöckling",
		[30149] = "Stinkmorchel",
		[30151] = "Brechtäubling",
		[30152] = "Violetter Tintling",
		[30153] = "Namiras Fäulnis",
		[30154] = "Weißkappe",
		[30155] = "Leuchttäubling",
		[30156] = "Koboldschemel",
		[30157] = "Benediktenkraut",
		[30158] = "Wiesenschaumkraut",
		[30159] = "Wermut",
		[30160] = "Wolfsauge",
		[30161] = "Kornblume",
		[30162] = "Drachendorn",
		[30163] = "Bergblume",
		[30164] = "Akelei",
		[30165] = "Nirnwurz",
		[30166] = "Wasser Hyacinth",
		[77590] = "Nachtschatten",

		[521] = "Eichenholz",
		[802] = "Ahornholz",
		[818] = "Birkenholz",
		[4439] = "Eschenholz",
		[23117] = "Buchenholz",
		[23118] = "Hickoryholz",
		[23119] = "Eibenholz",
		[23137] = "Mahagoniholz",
		[23138] = "Nachtholz",
		[71199] = "Rubinesche",

		[883] = "Natürliches Wasser",
		[1187] =  "Klares Wasser",--"Clear Water",
		[4570] = "Unberührtes Wasser",--"Pristine Water",
		[23265] = "Gesäubertes Wasser",--"Cleansed Water",
		[23266] = "Gefiltertes Wasser",--"Filtered Water",
		[23267] = "Gereinigtes Wasser",--"Purified Water",
		[23268] = "Wolkennebel",--"Cloud Mist"
		[64500] = "Sternentau",
		[64501] = "Lorkhans Tränen",
	},
	["fr"] = {
		[808] = "Minerai de Fer",
		[4482] = "Minerai de Calcinium",
		[5820] = "Minerai de Fer Noble",
		[23103] = "Minerai d'Orichalque",
		[23104] = "Minerai Dwemer",
		[23105] = "Minerai d'Ebonite",
		[23133] = "Minerai de Galatite",
		[23134] = "Minerai de Mercure",
		[23135] = "Minerai de Pierre de Vide",
		[71198] = "Minerai de Cuprite",

		[812] = "Jute",
		[4464] = "Lin",
		[23129] = "Coton",
		[23130] = "Toile D'araignée",
		[23131] = "Fil d'Ebonite",
		[33217] = "Fibre de Kresh",
		[33218] = "Herbe de Fer",
		[33219] = "Herbe d'Argent",
		[33220] = "Tissu de Vide",
		[71200] = "Soie Ancestrale",

		[30148] = "Entoloma",
		[30149] = "Mutinus Elégans",
		[30151] = "Russule Emetique",
		[30152] = "Violet Coprinus",
		[30153] = "Truffe de Namira",
		[30154] = "Chapeau Blanc",
		[30155] = "Russule Phosphorescente",
		[30156] = "Pied-de-Lutin",
		[30157] = "Chardon Béni",
		[30158] = "Cardamine des Prés",
		[30159] = "Absinthe",
		[30160] = "Noctuelle",
		[30161] = "Bleuet",
		[30162] = "Épine-de-Dragon",
		[30163] = "Lys des Cimes",
		[30164] = "Ancolie",
		[30165] = "Nirnrave",
		[30166] = "Jacinthe d'Eau",
		[77590] = "Belladone",

		[521] = "Chêne",
		[802] = "Érable",
		[818] = "Bouleau",
		[4439] = "Frêne",
		[23117] = "Hêtre",
		[23118] = "Noyer",
		[23119] = "If",
		[23137] = "Acajou",
		[23138] = "Bois de Nuit",
		[71199] = "Frêne Roux",

		[883] = "Eau Naturelle",
		[1187] =  "Eau Claire",--"Clear Water",
		[4570] = "Eau Limpide",--"Pristine Water",
		[23265] = "Eau Assainie",--"Cleansed Water",
		[23266] = "Eau Filtrée",--"Filtered Water",
		[23267] = "Eau Purifiée",--"Purified Water",
		[23268] = "Brume",--"Cloud Mist"
		[64500] = "Rosée Stellaire",
		[64501] = "Larmes de Lorkhan",
	},
	["ru"] = {
		[808] = "Жeлeзнaя pудa",
		[5820] = "Бoгaтaя жeлeзoм pудa",
		[23103] = "Opиxaлкoвaя pудa",
		[23104] = "Двeмepcкaя pудa",
		[23105] = "Эбoнитoвaя pудa",
		[4482] = "Кaльцинoвaя pудa",
		[23133] = "Гaлaтитoвaя pудa",
		[23134] = "Pтутнaя pудa",
		[23135] = "Пуcтoкaмeннaя pудa",
		[71198] = "Pубинoвaя pудa",

		[812] = "Джут",
		[4464] = "Лeн",
		[23129] = "Xлoпoк",
		[23130] = "Пaучий шeлк",
		[23131] = "Эбoнитoвaя нить",
		[33217] = "Кpeш-copняк",
		[33218] = "Жeлeзный copняк",
		[33219] = "Cepeбpяный copняк",
		[33220] = "Пуcтoцвeт",
		[71200] = "Шeлк-пpapoдитeль",

		[30148] = "Гoлубaя энтoлoмa",
		[30149] = "Цвeтoxвocтник вepeтeнoвидный",
		[30151] = "Жгучeeдкaя cыpoeжкa",
		[30152] = "Лилoвый кoпpинуc",
		[30153] = "Гниль Нaмиpы",
		[30154] = "Бeлянкa",
		[30155] = "Cвeтящaяcя cыpoeжкa",
		[30156] = "Бecoвcкий гpиб",
		[30157] = "Блaгocлoвeнный чepтoпoлox",
		[30158] = "Лугoвoй cepдeчник",
		[30159] = "Пoлынь",
		[30160] = "Вoлoвик",
		[30161] = "Вacилeк",
		[30162] = "Дpaкoний шип",
		[30163] = "Гopнoцвeт",
		[30164] = "Вoдocбop",
		[30165] = "Кopeнь Ниpнa",
		[30166] = "Вoдный гиaцинт",
		
		[802] = "Клeн",
		[521] = "Дуб",
		[23117] = "Бук",
		[23118] = "Гикopи",
		[23119] = "Тиc",
		
		[818] = "Бepeзa",
		[4439] = "Яceнь",
		[23137] = "Кpacнoe дepeвo",
		[23138] = "Нoчнoe дepeвo",
		[71199] = "Pубинoвый яceнь",

		[883] = "Пpиpoднaя вoдa",
		[1187] =  "Чиcтaя вoдa",
		[4570] = "Нeтpoнутaя вoдa",
		[23265] = "Oчищeннaя вoдa",
		[23266] = "Фильтpoвaннaя вoдa",
		[23267] = "Диcтилиpoвaннaя вoдa",
		[23268] ="Oблaчный пap",
		[64500] = "Звeзднaя poca",
		[64501] = "Cлeзы Лopxaнa",
	},
}
Harvest.itemId2Tooltip = itemId2Tooltip["en"]
if itemId2Tooltip[language] then
	for itemId, tooltip in pairs(itemId2Tooltip[language]) do
		Harvest.itemId2Tooltip[itemId] = tooltip
	end
end


local alchemyTable = {}
do
	local tooltip
	for _, group in pairs({
		{30148,30149,30151,30152,30153,30154,30155,30156}, -- mushrooms
		{30157,30158,30159,30160,30161,30162,30163,30164}, -- flowers
		{30165,30166},}) do -- water plants
		tooltip = {}
		for _, itemId in pairs(group) do
			table.insert(tooltip, itemId)
			alchemyTable[itemId] = tooltip
		end
	end
end


local zoneAllianceRank = {
	["coldharbor"] = {},
	["craglorn"] = {},
	["wrothgar"] = {},
	["thievesguild"] = {},
	["darkbrotherhood"] = {},
	["cyrodiil"] = {}
}
do

	local allianceZones = {
		{"auridon","grahtwood","greenshade","malabaltor","reapersmarch"},
		{"stonefalls","deshaan","shadowfen","eastmarch","therift"},
		{"glenumbra","stormhaven","rivenspire","alikr","bangkorai"},
	}
	for myAlliance = 1, 3 do
		for alliance, zones in pairs(allianceZones) do
			for rank, zone in pairs(zones) do
				zoneAllianceRank[zone] = zoneAllianceRank[zone] or {}
				zoneAllianceRank[zone][myAlliance] = rank + 6 * ((alliance - myAlliance) % 3)
			end
		end
		zoneAllianceRank["coldharbor"][myAlliance] = 6
		-- craglorn has the highest rank
		zoneAllianceRank["craglorn"][myAlliance] = 18
		-- rank 0 means scaling nodes
		zoneAllianceRank["wrothgar"][myAlliance] = 0
		zoneAllianceRank["thievesguild"][myAlliance] = 0
		zoneAllianceRank["darkbrotherhood"][myAlliance] = 0
		zoneAllianceRank["cyrodiil"][myAlliance] = 0
	end

end

local zoneRankPinTypeGroups = {
	-- aliance zones
	{
		[Harvest.BLACKSMITH] = {808},
		[Harvest.CLOTHING] = {812},
		[Harvest.WOODWORKING] = {802},
	},
	{
		[Harvest.BLACKSMITH] = {5820, 23103},
		[Harvest.CLOTHING] = {4464, 23129},
		[Harvest.WOODWORKING] = {521, 23117},
	},
	{
		[Harvest.BLACKSMITH] = {23103, 23104},
		[Harvest.CLOTHING] = {23129, 23130},
		[Harvest.WOODWORKING] = {23117, 23118},
	},
	{
		[Harvest.BLACKSMITH] = {23103, 23104},
		[Harvest.CLOTHING] = {23129, 23130},
		[Harvest.WOODWORKING] = {23117, 23118},
	},
	{
		[Harvest.BLACKSMITH] = {23104, 23105},
		[Harvest.CLOTHING] = {23130, 23131},
		[Harvest.WOODWORKING] = {23118, 23119},
	},
	-- cold harbor
	{
		[Harvest.BLACKSMITH] = {23105},
		[Harvest.CLOTHING] = {23131},
		[Harvest.WOODWORKING] = {23119},
	},
	-- cadwells silver
	{
		[Harvest.BLACKSMITH] = {4482},
		[Harvest.CLOTHING] = {33217},
		[Harvest.WOODWORKING] = {818},
	},
	{
		[Harvest.BLACKSMITH] = {4482},
		[Harvest.CLOTHING] = {33217},
		[Harvest.WOODWORKING] = {818},
	},
	{
		[Harvest.BLACKSMITH] = {4482, 23133},
		[Harvest.CLOTHING] = {33217, 33218},
		[Harvest.WOODWORKING] = {818, 4439},
	},
	{
		[Harvest.BLACKSMITH] = {23133},
		[Harvest.CLOTHING] = {33218},
		[Harvest.WOODWORKING] = {4439},
	},
	{
		[Harvest.BLACKSMITH] = {23133},
		[Harvest.CLOTHING] = {33218},
		[Harvest.WOODWORKING] = {4439},
	},
	-- missing coldharbor for silver
	{
		[Harvest.BLACKSMITH] = {23133},
		[Harvest.CLOTHING] = {33218},
		[Harvest.WOODWORKING] = {4439},
	},
	-- cadwells gold
	{
		[Harvest.BLACKSMITH] = {23134},
		[Harvest.CLOTHING] = {33219},
		[Harvest.WOODWORKING] = {23137},
	},
	{
		[Harvest.BLACKSMITH] = {23134},
		[Harvest.CLOTHING] = {33219},
		[Harvest.WOODWORKING] = {23137},
	},
	{
		[Harvest.BLACKSMITH] = {23134, 23135},
		[Harvest.CLOTHING] = {33219, 33220},
		[Harvest.WOODWORKING] = {23137, 23138},
	},
	{
		[Harvest.BLACKSMITH] = {23135},
		[Harvest.CLOTHING] = {33220},
		[Harvest.WOODWORKING] = {23138},
	},
	{
		[Harvest.BLACKSMITH] = {23135},
		[Harvest.CLOTHING] = {33220},
		[Harvest.WOODWORKING] = {23138},
	},
	-- missing coldharbor for gold,  can also be interpreted as craglorn
	{
		[Harvest.BLACKSMITH] = {23135},
		[Harvest.CLOTHING] = {33220},
		[Harvest.WOODWORKING] = {23138},
	},
}

local craftingRankPinTypeGroups = {
	-- iron etc
	{
		[Harvest.BLACKSMITH] = {808},
		[Harvest.CLOTHING] = {812},
		[Harvest.WOODWORKING] = {802},
	},
	-- high iron
	{
		[Harvest.BLACKSMITH] = {5820},
		[Harvest.CLOTHING] = {4464},
		[Harvest.WOODWORKING] = {521},
	},
	-- oricalcum
	{
		[Harvest.BLACKSMITH] = {23103},
		[Harvest.CLOTHING] = {23129},
		[Harvest.WOODWORKING] = {23117},
	},
	--dwarven ore
	{
		[Harvest.BLACKSMITH] = {23104},
		[Harvest.CLOTHING] = {23130},
		[Harvest.WOODWORKING] = {23118},
	},
	-- ebonstuff
	{
		[Harvest.BLACKSMITH] = {23105},
		[Harvest.CLOTHING] = {23131},
		[Harvest.WOODWORKING] = {23119},
	},
	-- first VR stuff silver
	{
		[Harvest.BLACKSMITH] = {4482},
		[Harvest.CLOTHING] = {33217},
		[Harvest.WOODWORKING] = {818},
	},
	-- 2nd VR stuff silver
	{
		[Harvest.BLACKSMITH] = {23133},
		[Harvest.CLOTHING] = {33218},
		[Harvest.WOODWORKING] = {4439},
	},
	-- first VR stuff gold
	{
		[Harvest.BLACKSMITH] = {23134},
		[Harvest.CLOTHING] = {33219},
		[Harvest.WOODWORKING] = {23137},
	},
	-- 2nd VR stuff gold
	{
		[Harvest.BLACKSMITH] = {23135},
		[Harvest.CLOTHING] = {33220},
		[Harvest.WOODWORKING] = {23138},
	},
	-- ruby stuff
	{
		[Harvest.BLACKSMITH] = {71198},
		[Harvest.CLOTHING] = {71200},
		[Harvest.WOODWORKING] = {71199},
	},
}

function Harvest.GetLocalizedZoneItemNames(zone, itemIds, alliance, pinTypeId, craftingRank, playerRank)
	local tooltip = {}
	local group
	if itemIds then
		for itemId, _ in pairs(itemIds) do
			if pinTypeId == Harvest.ALCHEMY then
				-- add plants from the same group (flowers, mushrooms, water plants)
				group = alchemyTable[itemId]
				if group then
					for _, groupId in pairs(group) do
						tooltip[groupId] = Harvest.itemId2Tooltip[groupId]
					end
				end
			end
			
			-- add ressources that should spawn in this zone (in respect to alliance/cadwell's silver/cadwell's gold)
			local zoneRank = (zoneAllianceRank[zone] or {})[alliance]
			if zoneRank then
				if zoneRank > 0 then
					group = zoneRankPinTypeGroups[zoneRank][pinTypeId]
					if group then
						for _, groupId in pairs(group) do
							tooltip[groupId] = Harvest.itemId2Tooltip[groupId]
						end
					end
				else -- a scaling zone such as wrothgar
					if craftingRank then
						-- based on crafting level
						group = craftingRankPinTypeGroups[craftingRank][pinTypeId]
						if group then
							for _, groupId in pairs(group) do
								tooltip[groupId] = Harvest.itemId2Tooltip[groupId]
							end
						end
						-- based on character level
						group = craftingRankPinTypeGroups[Harvest.GetLevel2CraftingRank(playerRank)][pinTypeId]
						if group then
							for _, groupId in pairs(group) do
								tooltip[groupId] = Harvest.itemId2Tooltip[groupId]
							end
						end
					end
				end
			end
		end
		-- we weren't able to add anything, try to get the tooltip from the item id
		if next(tooltip) == nil then
			for itemId, _ in pairs(itemIds) do
				tooltip[itemId] = Harvest.itemId2Tooltip[itemId]
			end
		end
	end
	-- still nothing? try get a tooltip based on the pinType
	if next(tooltip) == nil then
		tooltip[pinTypeId] = Harvest.pinTypeId2Tooltip[pinTypeId]
	end
	if next(tooltip) == nil then
		tooltip[1] = "Unknown item"
	end
	return tooltip
end

local craftingRankMinLevel = {
	[1] = 0, --iron
	[2] = 16, --steel
	[3] = 26, --orichalcum
	[4] = 36, --dwarven
	[5] = 46, --ebony
	[6] = 51, --calcinium
	[7] = 54, --galatite
	[8] = 57, --quicksilver
	[9] = 59, --voidstone
	[10] = 65, --rubedite
}
function Harvest.GetLevel2CraftingRank(playerRank)
	for rank, level in ipairs(craftingRankMinLevel) do
		if playerRank < level then
			return rank - 1
		end
	end
	return 10
end

function Harvest.GetLocalizedTooltip( pin )
	local result = {}
	
	local pinTypeId = Harvest.GetPinId( LMP.pinManager.customPins[pin.m_PinType].pinTypeString )
	
	if pinTypeId == Harvest.TOUR then
		table.insert(result, "Next ressource of your farming tour" )
		return result
	end
	
	if Harvest.IsDebugEnabled() then
		table.insert(result, "Click to delete:" )
	end

	local itemIds = pin.m_PinTag[4]
	
	local lines = {}
	if Harvest.AreExactItemsShown() then
		local text
		if Harvest.ShouldSaveItemId(pinTypeId) then
			for itemId, _ in pairs( itemIds ) do
				text = Harvest.GetLocalizedExactTooltip( itemId, pinTypeId )
				if text then
					-- different itemIDs may result in the same tooltip line, ie runes
					if not Harvest.contains(lines, text) then
						table.insert(lines, text)
					end
				end
			end
		end
		-- nothing was added, try to get a tooltip based on the pinTypeId
		if next(lines) == nil then
			text = Harvest.pinTypeId2Tooltip[ pinTypeId ]
			if text then
				if not Harvest.contains(lines, text) then
					table.insert(lines, text)
				end
			end
		end
		-- still nothing? then we just add some error text
		if next(lines) == nil then
			table.insert(lines, "Unknown item" )
		end
	else
		-- get the rank of the crafting skill line which belongs to this pinTypeId
		local tradeSkill = Harvest.pinTypeId2TradeSkill[pinTypeId]
		local rank
		if tradeSkill then
			local skillType, skillIndex = GetCraftingSkillLineIndices(tradeSkill)
			rank = GetSkillAbilityUpgradeInfo(skillType, skillIndex, 1)
		end
		--if Harvest.ShouldSaveItemId(pinTypeId) then --chests, troves and fish don't have item ids
		local zone = GetMapTileTexture()
		zone = string.lower(zone)
		zone = string.gsub(zone, "^.*maps/", "")
		zone = string.gsub(zone, "_%d+%.dds$", "")
		zone = string.gsub(zone, "/.*$", "")
		local tooltip = Harvest.GetLocalizedZoneItemNames(zone, itemIds, GetUnitAlliance("player"), pinTypeId, rank, GetUnitEffectiveLevel("player") )
		local text = {}
		local counter = 0
		for _, line in pairs(tooltip) do
			if (#text) >= 3 then
				table.insert(lines, table.concat(text, ", ") )
				text = {}
			else
				table.insert(text, line)
			end
		end
		if (#text) > 0 then
			table.insert(lines, table.concat(text, ", ") )
		end
	end
	for _, line in ipairs(lines) do
		table.insert(result, line)
	end
	return result
end
