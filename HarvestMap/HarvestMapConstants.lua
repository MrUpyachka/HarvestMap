
if not Harvest then
	Harvest = {}
end

-- data version numbers:
-- 10 = Orsinium (all nodes are saved as ACE strings)
-- 11 = Thieves Guild (nodes can now store multiple itemIds)
-- 12 = Trove fix
-- 13 = DB data (removed node names, enchantment item ids, added itemid -> timestamp format)
Harvest.dataVersion = 13

-- addon version numbers:
-- 0 or nil = before this number was introduced
-- 1 = filter local nodes which were saved with their global coords instead of local ones
-- since 2.3.0 incremental:
-- 2 = 2.3.0
Harvest.addonVersion = 3
Harvest.displayVersion = "3.3.1"

Harvest.author = "Shinni"
Harvest.logSize = 20 -- number of messages stored in the log field

-- node version which is saved for each node
-- the node version encodes the current game and addon version
-- this is used to detect invalid data caused by addon bugs and game changes (ie sometimes maps get rescaled/translated)
if GetESOVersionString then
	local version, update, patch = string.match(GetESOVersionString(), "(%d+)%.(%d+)%.(%d+)")
	-- encode 2.5.4 as 20504, let's hope we never get more than 99 patches for an update :D
	local versionInteger = tonumber(version) * 10000 + tonumber(update) * 100 + tonumber(patch)
	-- the addon has far less than 100 updates per year, so the upcoming 10 years should be fine with this offset
	Harvest.VersionOffset = 1000
	Harvest.nodeVersion = Harvest.VersionOffset * versionInteger + Harvest.addonVersion
	-- example: game version is 2.5.4, addon version is 2:
	-- node version is thus 20504002
else
	Harvest.VersionOffset = 1000
	Harvest.nodeVersion = Harvest.addonVersion
end

-- constants/enums for the file format
Harvest.X = 1
Harvest.Y = 2
Harvest.ITEMS = 4
Harvest.TIME = 5
Harvest.VERSION = 6

-- constants/enums for the pin types
Harvest.BLACKSMITH = 1
Harvest.CLOTHING = 2
Harvest.ENCHANTING = 3
Harvest.ALCHEMY = 4
Harvest.WOODWORKING = 5
Harvest.CHESTS = 6
Harvest.WATER = 7
Harvest.FISHING = 8
Harvest.HEAVYSACK = 9
Harvest.OLDTROVE = 10
Harvest.TROVE = 20 -- new thieves trove entry
Harvest.JUSTICE = 21
-- there seem to be old save files with a pinType of 22 ???
-- not sure what was used to be saved there...

Harvest.TOUR = 100 -- pin which displays the next ressource of the farming tour

Harvest.PINTYPES = {
	Harvest.BLACKSMITH, Harvest.CLOTHING,
	Harvest.ENCHANTING, Harvest.ALCHEMY,
	Harvest.WOODWORKING, Harvest.CHESTS,
	Harvest.WATER, Harvest.FISHING,
	Harvest.HEAVYSACK,
	Harvest.TOUR, Harvest.TROVE,
	Harvest.JUSTICE
}

Harvest.pinTypeId2TradeSkill = {
	[Harvest.BLACKSMITH] = CRAFTING_TYPE_BLACKSMITHING,
	[Harvest.CLOTHING] = CRAFTING_TYPE_CLOTHIER,
	[Harvest.WOODWORKING] = CRAFTING_TYPE_WOODWORKING,
}

-- HarvestMap uses pinTypeIds (numbers)
-- but zenimax's map pin API needs a string for each pin type
-- the following two functions convert between pinType string
-- and pinType Id
local pintypes = {} -- string creation is expensive, cache the result
for _, pinTypeId in pairs(Harvest.PINTYPES) do
	pintypes[pinTypeId] = "HrvstPin" .. pinTypeId
end
function Harvest.GetPinType( pinTypeId )
	return pintypes[pinTypeId] or ("HrvstPin" .. pinTypeId)
end

function Harvest.GetPinId( pinType )
	pinType = string.gsub( pinType, "HrvstPin", "" )
	return tonumber( pinType )
end

local shouldNotSaveItemId = {
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
function Harvest.ShouldSaveItemId(pinTypeId)
	return not shouldNotSaveItemId[pinTypeId]
end

-- maps that shouldn't display pins
local mapBlacklist = {
	["tamriel/tamriel"] = true,
	["tamriel/mundus_base"] = true,
	--"cyrodiil/ava_aldmeri",
	--"cyrodiil/ava_ebonheart",
	--"aldmeri/aldmeridominion_base",
	--"daggerfall/daggerfallalliance_base",
	--"ebonheart/ebonheartpact_base",
}

function Harvest.IsMapBlacklisted( map )
	return mapBlacklist[ map ]
end

local isNodeNameHeavySack = {
	["heavy sack"] = true,
	["heavy crate"] = true, -- special nodes in cold harbor
	["schwerer sack"] = true,
	["sac lourd"] = true,
	["Òüæeìÿé íeúoê"] = true, -- russian
}

function Harvest.IsHeavySack( nodeName )
	return isNodeNameHeavySack[ zo_strlower( nodeName) ]
end

local isNodeNameTrove = {
	["thieves trove"] = true,
	["diebesgut"] = true,
	["trésor des voleurs"] = true,
	["�?opoácêoé Òaéîèê"] = true,
}

function Harvest.IsTrove( nodeName )
	return isNodeNameTrove[ zo_strlower( nodeName) ]
end

local heistMaps = {
	"^thievesguild/thehideaway",
	"^thievesguild/secludedsewers",
	"^thievesguild/deathhollowhalls",
	"^thievesguild/glitteringgrotto",
	"^thievesguild/undergroundsepulcher",
}
function Harvest.IsHeistMap( map )
	local prefix = nil
	for _, regexp in pairs(heistMaps) do
		prefix = string.match(map, regexp)
		if prefix then
			return prefix
		end
	end
	return false
end
--[[
local isNodeNameJusticeContainer = {
	["safebox"] = true,
	["wertkasette"] = true,
	["cassette"] = true,
	-- the previous entries aren't actually needed
	-- the ones below howeber are
	["pouch of rare gemstones"] = true,
	["deadric strongbox"] = true,
}

function Harvest.IsJusticeContainer( nodeName )
	return isNodeNameJusticeContainer[ zo_strlower( nodeName) ]
end
--]]
Harvest.itemId2PinType = {
	[808] = Harvest.BLACKSMITH,
	[4482] = Harvest.BLACKSMITH,
	[4995] = Harvest.BLACKSMITH,
	[5820] = Harvest.BLACKSMITH,
	[23103] = Harvest.BLACKSMITH,
	[23104] = Harvest.BLACKSMITH,
	[23105] = Harvest.BLACKSMITH,
	[23133] = Harvest.BLACKSMITH,
	[23134] = Harvest.BLACKSMITH,
	[23135] = Harvest.BLACKSMITH,
	[71198] = Harvest.BLACKSMITH,

	[812] = Harvest.CLOTHING,
	[4464] = Harvest.CLOTHING,
	[23129] = Harvest.CLOTHING,
	[23130] = Harvest.CLOTHING,
	[23131] = Harvest.CLOTHING,
	[33217] = Harvest.CLOTHING,
	[33218] = Harvest.CLOTHING,
	[33219] = Harvest.CLOTHING,
	[33220] = Harvest.CLOTHING,
	[71200] = Harvest.CLOTHING,

	[45806] = Harvest.ENCHANTING,
	[45807] = Harvest.ENCHANTING,
	[45808] = Harvest.ENCHANTING,
	[45809] = Harvest.ENCHANTING,
	[45810] = Harvest.ENCHANTING,
	[45811] = Harvest.ENCHANTING,
	[45812] = Harvest.ENCHANTING,
	[45813] = Harvest.ENCHANTING,
	[45814] = Harvest.ENCHANTING,
	[45815] = Harvest.ENCHANTING,
	[45816] = Harvest.ENCHANTING,
	[45817] = Harvest.ENCHANTING,
	[45818] = Harvest.ENCHANTING,
	[45819] = Harvest.ENCHANTING,
	[45820] = Harvest.ENCHANTING,
	[45821] = Harvest.ENCHANTING,
	[45822] = Harvest.ENCHANTING,
	[45823] = Harvest.ENCHANTING,
	[45824] = Harvest.ENCHANTING,
	[45825] = Harvest.ENCHANTING,
	[45826] = Harvest.ENCHANTING,
	[45827] = Harvest.ENCHANTING,
	[45828] = Harvest.ENCHANTING,
	[45829] = Harvest.ENCHANTING,
	[45830] = Harvest.ENCHANTING,
	[45831] = Harvest.ENCHANTING,
	[45832] = Harvest.ENCHANTING,
	[45833] = Harvest.ENCHANTING,
	[45834] = Harvest.ENCHANTING,
	[45835] = Harvest.ENCHANTING,
	[45836] = Harvest.ENCHANTING,
	[45837] = Harvest.ENCHANTING,
	[45838] = Harvest.ENCHANTING,
	[45839] = Harvest.ENCHANTING,
	[45840] = Harvest.ENCHANTING,
	[45841] = Harvest.ENCHANTING,
	[45842] = Harvest.ENCHANTING,
	[45843] = Harvest.ENCHANTING,
	[45844] = Harvest.ENCHANTING,
	[45845] = Harvest.ENCHANTING,
	[45846] = Harvest.ENCHANTING,
	[45847] = Harvest.ENCHANTING,
	[45848] = Harvest.ENCHANTING,
	[45849] = Harvest.ENCHANTING,
	[45850] = Harvest.ENCHANTING,
	[45851] = Harvest.ENCHANTING,
	[45852] = Harvest.ENCHANTING,
	[45853] = Harvest.ENCHANTING,
	[45854] = Harvest.ENCHANTING,
	[45855] = Harvest.ENCHANTING,
	[45856] = Harvest.ENCHANTING,
	[45857] = Harvest.ENCHANTING,
	[54248] = Harvest.ENCHANTING,
	[54253] = Harvest.ENCHANTING,
	[54289] = Harvest.ENCHANTING,
	[54294] = Harvest.ENCHANTING,
	[54297] = Harvest.ENCHANTING,
	[54299] = Harvest.ENCHANTING,
	[54306] = Harvest.ENCHANTING,
	[54330] = Harvest.ENCHANTING,
	[54331] = Harvest.ENCHANTING,
	[54342] = Harvest.ENCHANTING,
	[54373] = Harvest.ENCHANTING,
	[54374] = Harvest.ENCHANTING,
	[54375] = Harvest.ENCHANTING,
	[54481] = Harvest.ENCHANTING,
	[54482] = Harvest.ENCHANTING,
	[64509] = Harvest.ENCHANTING,
	[68341] = Harvest.ENCHANTING,
	[64508] = Harvest.ENCHANTING,
	[68340] = Harvest.ENCHANTING,
	[68342] = Harvest.ENCHANTING,

	[30148] = Harvest.ALCHEMY,
	[30149] = Harvest.ALCHEMY,
	[30151] = Harvest.ALCHEMY,
	[30152] = Harvest.ALCHEMY,
	[30153] = Harvest.ALCHEMY,
	[30154] = Harvest.ALCHEMY,
	[30155] = Harvest.ALCHEMY,
	[30156] = Harvest.ALCHEMY,
	[30157] = Harvest.ALCHEMY,
	[30158] = Harvest.ALCHEMY,
	[30159] = Harvest.ALCHEMY,
	[30160] = Harvest.ALCHEMY,
	[30161] = Harvest.ALCHEMY,
	[30162] = Harvest.ALCHEMY,
	[30163] = Harvest.ALCHEMY,
	[30164] = Harvest.ALCHEMY,
	[30165] = Harvest.ALCHEMY,
	[30166] = Harvest.ALCHEMY,
	[77590] = Harvest.ALCHEMY, -- Nightshade, added in DB

	[521] = Harvest.WOODWORKING,
	[802] = Harvest.WOODWORKING,
	[818] = Harvest.WOODWORKING,
	[4439] = Harvest.WOODWORKING,
	[23117] = Harvest.WOODWORKING,
	[23118] = Harvest.WOODWORKING,
	[23119] = Harvest.WOODWORKING,
	[23137] = Harvest.WOODWORKING,
	[23138] = Harvest.WOODWORKING,
	[71199] = Harvest.WOODWORKING,

	[883] = Harvest.WATER,
	[1187] = Harvest.WATER,
	[4570] = Harvest.WATER,
	[23265] = Harvest.WATER,
	[23266] = Harvest.WATER,
	[23267] = Harvest.WATER,
	[23268] = Harvest.WATER,
	[64500] = Harvest.WATER,
	[64501] = Harvest.WATER
}

local nodeName2PinType = {
	["Heavy Sack"] = Harvest.HEAVYSACK,
	["Schwerer Sack"] = Harvest.HEAVYSACK,
	["Sac Lourd"] = Harvest.HEAVYSACK,
	["Òüæeìÿé íeúoê"] = Harvest.HEAVYSACK,

	["Thieves Trove"] = Harvest.TROVE,
	["Diebesgut"] = Harvest.TROVE,
	["Trésor des voleurs"] = Harvest.TROVE,
	["�?opoácêoé Òaéîèê"] = Harvest.TROVE,
	
	["Iron Ore"] = Harvest.BLACKSMITH,
	["High Iron Ore"] = Harvest.BLACKSMITH,
	["Orichalc Ore"] = Harvest.BLACKSMITH,
	["Orichalcum Ore"] = Harvest.BLACKSMITH,
	["Dwarven Ore"] = Harvest.BLACKSMITH,
	["Ebony Ore"] = Harvest.BLACKSMITH,
	["Calcinium Ore"] = Harvest.BLACKSMITH,
	["Galatite Ore"] = Harvest.BLACKSMITH,
	["Quicksilver Ore"] = Harvest.BLACKSMITH,
	["Voidstone Ore"] = Harvest.BLACKSMITH,
	["Rubedite Ore"] = Harvest.BLACKSMITH,

	["Eisenerz"] = Harvest.BLACKSMITH,
	["Feineisenerz"] = Harvest.BLACKSMITH,
	["Orichalc Ore"] = Harvest.BLACKSMITH,
	["Oreichalkoserz"] = Harvest.BLACKSMITH,
	["Dwemererz"] = Harvest.BLACKSMITH,
	["Ebenerz"] = Harvest.BLACKSMITH,
	["Kalciniumerz"] = Harvest.BLACKSMITH,
	["Galatiterz"] = Harvest.BLACKSMITH,
	["Quicksilver Ore"] = Harvest.BLACKSMITH,
	["Leerensteinerz"] = Harvest.BLACKSMITH,
	["Rubediterz"] = Harvest.BLACKSMITH,

	["Minerai de Fer"] = Harvest.BLACKSMITH,
	["Minerai de Fer Noble"] = Harvest.BLACKSMITH,
	["Minerai d'Orichalque"] = Harvest.BLACKSMITH,
	["Minerai Dwemer"] = Harvest.BLACKSMITH,
	["Minerai d'Ebonite"] = Harvest.BLACKSMITH,
	["Minerai de Calcinium"] = Harvest.BLACKSMITH,
	["Minerai de Galatite"] = Harvest.BLACKSMITH,
	["Quicksilver Ore"] = Harvest.BLACKSMITH,
	["Minerai de Pierre du Vide"] = Harvest.BLACKSMITH,
	["Minerai de Cuprite"] = Harvest.BLACKSMITH,

	["Cotton"] = Harvest.CLOTHING,
	["Ebonthread"] = Harvest.CLOTHING,
	["Flax"] = Harvest.CLOTHING,
	["Ironweed"] = Harvest.CLOTHING,
	["Jute"] = Harvest.CLOTHING,
	["Kreshweed"] = Harvest.CLOTHING,
	["Silverweed"] = Harvest.CLOTHING,
	["Spidersilk"] = Harvest.CLOTHING,
	["Void Bloom"] = Harvest.CLOTHING,
	["Silver Weed"] = Harvest.CLOTHING,
	["Kresh Weed"] = Harvest.CLOTHING,
	["Ancestor Silk"] = Harvest.CLOTHING,

	["Baumwolle"] = Harvest.CLOTHING,
	["Ebenseide"] = Harvest.CLOTHING,
	["Flachs"] = Harvest.CLOTHING,
	["Eisenkraut"] = Harvest.CLOTHING,
	["Jute"] = Harvest.CLOTHING,
	["Kreshweed"] = Harvest.CLOTHING,
	["Silverweed"] = Harvest.CLOTHING,
	["Spinnenseide"] = Harvest.CLOTHING,
	["Leere Bl�te"] = Harvest.CLOTHING,
	["Silver Weed"] = Harvest.CLOTHING,
	["Kresh Weed"] = Harvest.CLOTHING,
	["Ahnenseide"] = Harvest.CLOTHING,

	["Coton"] = Harvest.CLOTHING,
	["Fil d'Ebonite"] = Harvest.CLOTHING,
	["Lin"] = Harvest.CLOTHING,
	["Herbe de Fer"] = Harvest.CLOTHING,
	["Jute"] = Harvest.CLOTHING,
	["Kreshweed"] = Harvest.CLOTHING,
	["Silverweed"] = Harvest.CLOTHING,
	["Toile d'Araign�e"] = Harvest.CLOTHING,
	["Fleur du Vide"] = Harvest.CLOTHING,
	["Silver Weed"] = Harvest.CLOTHING,
	["Kresh Weed"] = Harvest.CLOTHING,
	["Soie Ancestrale"] = Harvest.CLOTHING,

	["Aspect Rune"] = Harvest.ENCHANTING,
	["Essence Rune"] = Harvest.ENCHANTING,
	["Potency Rune"] = Harvest.ENCHANTING,

	["Aspektrune"] = Harvest.ENCHANTING,
	["Essenzrune"] = Harvest.ENCHANTING,
	["Machtrune"] = Harvest.ENCHANTING,

	["Rune d'Aspect"] = Harvest.ENCHANTING,
	["Rune d'Essence"] = Harvest.ENCHANTING,
	["Rune de Puissance"] = Harvest.ENCHANTING,

	["Blessed Thistle"] = Harvest.ALCHEMY,
	["Entoloma"] = Harvest.ALCHEMY,
	["Bugloss"] = Harvest.ALCHEMY,
	["Columbine"] = Harvest.ALCHEMY,
	["Corn Flower"] = Harvest.ALCHEMY,
	["Dragonthorn"] = Harvest.ALCHEMY,
	["Emetic Russula"] = Harvest.ALCHEMY,
	["Imp Stool"] = Harvest.ALCHEMY,
	["Lady's Smock"] = Harvest.ALCHEMY,
	["Luminous Russula"] = Harvest.ALCHEMY,
	["Mountain Flower"] = Harvest.ALCHEMY,
	["Namira's Rot"] = Harvest.ALCHEMY,
	["Nirnroot"] = Harvest.ALCHEMY,
	["Stinkhorn"] = Harvest.ALCHEMY,
	["Violet Coprinus"] = Harvest.ALCHEMY,
	["Violet Copninus"] = Harvest.ALCHEMY,
	["Water Hyacinth"] = Harvest.ALCHEMY,
	["White Cap"] = Harvest.ALCHEMY,
	["Wormwood"] = Harvest.ALCHEMY,
	["Nightshade"] = Harvest.ALCHEMY, -- needs to be confirmed!

	["Benediktenkraut"] = Harvest.ALCHEMY,
	["Gl�ckling"] = Harvest.ALCHEMY,
	["Wolfsauge"] = Harvest.ALCHEMY,
	["Akelei"] = Harvest.ALCHEMY,
	["Kornblume"] = Harvest.ALCHEMY,
	["Drachendorn"] = Harvest.ALCHEMY,
	["Brecht�ubling"] = Harvest.ALCHEMY,
	["Koboldschemel"] = Harvest.ALCHEMY,
	["Wiesenschaumkraut"] = Harvest.ALCHEMY,
	["Leuchtt�ubling"] = Harvest.ALCHEMY,
	["Bergblume"] = Harvest.ALCHEMY,
	["Namiras F�ulnis"] = Harvest.ALCHEMY,
	["Nirnwurz"] = Harvest.ALCHEMY,
	["Stinkmorchel"] = Harvest.ALCHEMY,
	["Violetter Tintling"] = Harvest.ALCHEMY,
	["Wasserhyazinthe"] = Harvest.ALCHEMY,
	["Wei�kappe"] = Harvest.ALCHEMY,
	["Wermut"] = Harvest.ALCHEMY,
	["Nachtschatten"] = Harvest.ALCHEMY, -- needs to be confirmed!

	["Chardon Béni"] = Harvest.ALCHEMY,
	["Entoloma Bleue"] = Harvest.ALCHEMY,
	["Noctuelle"] = Harvest.ALCHEMY,
	["Ancolie"] = Harvest.ALCHEMY,
	["Bleuet"] = Harvest.ALCHEMY,
	["�?pine-de-Dragon"] = Harvest.ALCHEMY,
	["Russule Emetique"] = Harvest.ALCHEMY,
	["Pied-de-Lutin"] = Harvest.ALCHEMY,
	["Cardamine des Prés"] = Harvest.ALCHEMY,
	["Russule Phosphorescente"] = Harvest.ALCHEMY,
	["Lys des Cimes"] = Harvest.ALCHEMY,
	["Truffe de Namira"] = Harvest.ALCHEMY,
	["Nirnrave"] = Harvest.ALCHEMY,
	["Mutinus Elégans"] = Harvest.ALCHEMY,
	["Coprin Violet"] = Harvest.ALCHEMY,
	["Jacinthe d'Eau"] = Harvest.ALCHEMY,
	["Chapeau Blanc"] = Harvest.ALCHEMY,
	["Absinthe"] = Harvest.ALCHEMY,
	["Belladone"] = Harvest.ALCHEMY, -- needs to be confirmed!

	["Ashtree"] = Harvest.WOODWORKING,
	["Beech"] = Harvest.WOODWORKING,
	["Birch"] = Harvest.WOODWORKING,
	["Hickory"] = Harvest.WOODWORKING,
	["Mahogany"] = Harvest.WOODWORKING,
	["Maple"] = Harvest.WOODWORKING,
	["Nightwood"] = Harvest.WOODWORKING,
	["Oak"] = Harvest.WOODWORKING,
	["Yew"] = Harvest.WOODWORKING,
	["Ruby Ash Wood"] = Harvest.WOODWORKING,

	["Eschenholz"] = Harvest.WOODWORKING,
	["Buche"] = Harvest.WOODWORKING,
	["Buchenholz"] = Harvest.WOODWORKING,
	["Birkenholz"] = Harvest.WOODWORKING,
	["Hickoryholz"] = Harvest.WOODWORKING,
	["Mahagoniholz"] = Harvest.WOODWORKING,
	["Ahornholz"] = Harvest.WOODWORKING,
	["Nachtholz"] = Harvest.WOODWORKING,
	["Eiche"] = Harvest.WOODWORKING,
	["Eichenholz"] = Harvest.WOODWORKING,
	["Eibenholz"] = Harvest.WOODWORKING,
	["Rubinesche"] = Harvest.WOODWORKING,

	["Frêne"] = Harvest.WOODWORKING,
	["Fr�ne"] = Harvest.WOODWORKING,
	["Hêtre"] = Harvest.WOODWORKING,
	["H�tre"] = Harvest.WOODWORKING,
	["Bouleau"] = Harvest.WOODWORKING,
	["Hickory"] = Harvest.WOODWORKING,
	["Acajou"] = Harvest.WOODWORKING,
	["�?rable"] = Harvest.WOODWORKING,
	["�rable"] = Harvest.WOODWORKING,
	["Bois de Nuit"] = Harvest.WOODWORKING,
	["Chêne"] = Harvest.WOODWORKING,
	["Ch�ne"] = Harvest.WOODWORKING,
	["If"] = Harvest.WOODWORKING,
	["Frêne Roux"] = Harvest.WOODWORKING,
	["Fr�ne Roux"] = Harvest.WOODWORKING,

	["Pure Water"] = Harvest.WATER,
	["Water Skin"] = Harvest.WATER,

	["Reines Wasser"] = Harvest.WATER,
	["Wasserhaut"] = Harvest.WATER,

	["Eau Pure"] = Harvest.WATER,
	["Outre d'Eau"] = Harvest.WATER,

}

Harvest.nodeName2PinType = {}
for key, value in pairs( nodeName2PinType ) do
	Harvest.nodeName2PinType[ zo_strlower( key ) ] = value
end
nodeName2PinType = nil
