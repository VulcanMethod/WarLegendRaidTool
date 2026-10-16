---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values
-- WoW Forever: swallow secret-value errors (enemy data hidden in combat), report everything else
function Data.SafeCall(f, ...)
	local ok, err = pcall(f, ...)
	if not ok and not (type(err) == "string" and err:find("secret", 1, true)) then
		geterrorhandler()(err)
	end
	return ok, err
end

local L = Data.L

local GetClassInfo = GetClassInfo
local GetNumSpecializationsForClassID = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID or GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID


Data.PlayerRoles = {"TANK", "HEALER", "DAMAGER"}

Data.CyrillicToRomanian = { -- source Wikipedia: https://en.wikipedia.org/wiki/Romanization_of_Russian
	["А"] = "a",
	["а"] = "a",
	["Б"] = "b",
	["б"] = "b",
	["В"] = "v",
	["в"] = "v",
	["Г"] = "g",
	["г"] = "g",
	["Д"] = "d",
	["д"] = "d",
	["Е"] = "e",
	["е"] = "e",
	["Ё"] = "e",
	["ё"] = "e",
	["Ж"] = "zh",
	["ж"] = "zh",
	["З"] = "z",
	["з"] = "z",
	["И"] = "i",
	["и"] = "i",
	["Й"] = "i",
	["й"] = "i",
	["К"] = "k",
	["к"] = "k",
	["Л"] = "l",
	["л"] = "l",
	["М"] = "m",
	["м"] = "m",
	["Н"] = "n",
	["н"] = "n",
	["О"] = "o",
	["о"] = "o",
	["П"] = "p",
	["п"] = "p",
	["Р"] = "r",
	["р"] = "r",
	["С"] = "s",
	["с"] = "s",
	["Т"] = "t",
	["т"] = "t",
	["У"] = "u",
	["у"] = "u",
	["Ф"] = "f",
	["ф"] = "f",
	["Х"] = "kh",
	["х"] = "kh",
	["Ц"] = "ts",
	["ц"] = "ts",
	["Ч"] = "ch",
	["ч"] = "ch",
	["Ш"] = "sh",
	["ш"] = "sh",
	["Щ"] = "shch",
	["щ"] = "shch",
	["Ъ"] = "ie",
	["ъ"] = "ie",
	["Ы"] = "y",
	["ы"] = "y",
	["Ь"] = "",
	["ь"] = "",
	["Э"] = "e",
	["э"] = "e",
	["Ю"] = "iu",
	["ю"] = "iu",
	["Я"] = "ia",
	["я"] = "ia"
}

Data.Buttons = {
	Target = TARGET,
	Focus = SET_FOCUS,
	Custom = L.UserDefined
}

Data.AllPositions = {
	TOPLEFT = L.TOPLEFT,
	TOP = L.TOP,
	TOPRIGHT = L.TOPRIGHT,
	LEFT = L.LEFT,
	CENTER = L.CENTER,
	RIGHT = L.RIGHT,
	BOTTOMLEFT = L.BOTTOMLEFT,
	BOTTOM = L.BOTTOM,
	BOTTOMRIGHT = L.BOTTOMRIGHT
}

Data.HorizontalDirections = {
	leftwards = L.Leftwards,
	rightwards = L.Rightwards
}
Data.VerticalDirections = {
	upwards = L.Upwards,
	downwards = L.Downwards
}


Data.BattlegroundspezificBuffs = { --key = mapID, value = table with key = faction(0 for hode, 1 for alliance) value spellId of the flag, minecart
	[1339] = {						-- Warsong Gulch, used to be mapID 443 before BFA
		[0] = 156621, 					-- Alliance Flag
		[1] = 156618 					-- Horde Flag
	},
	[1460] = {						-- Warsong Gulch, used in Classic, TBCC
		[0] = 301091, 					-- Alliance Flag
		[1] = 301089 					-- Horde Flag
	},
	[112] = {						-- Eye of the Storm, used to be mapID 482 before BFA
		[0] = 34976,  					-- Netherstorm Flag
		[1] = 34976						-- Netherstorm Flag
	},
	[1956] = {						-- Eye of the Storm, TBCC
		[0] = 34976,  					-- Netherstorm Flag
		[1] = 34976						-- Netherstorm Flag
	},
	[397] = {						-- Eye of the Storm (mapID RBG only? Not sure why there are two map IDs for Eye of the Storm), used to be mapID 813 before BFA
		[0] = 34976,  					-- Netherstorm Flag
		[1] = 34976						-- Netherstorm Flag
	},
	[206] = {						-- Twin Peaks, used to be mapID 626 before BFA
		[0] = 156621, 					-- Alliance Flag
		[1] = 156618 					-- Horde Flag
	},
	[2345] = {						-- Deephaul Ravine added in Patch 11.0.2
		[0] = 434339, 					-- Deephaul Crystal
		[1] = 434339 					-- Deephaul Crystal
	}
}


Data.BattlegroundspezificDebuffs = { --key = mapID, value = table with key = number and value = debuff name
	[1339] = {						-- Warsong Gulch, used to be mapID 443 before BFA
		46392,						-- Focused Assault
		46393						-- Brutal Assault
	},
	[112] = {						-- Eye of the Storm, used to be mapID 482 before BFA
		46392,						-- Focused Assault
		46393						-- Brutal Assault
	},
	[397] = {						-- Eye of the Storm (mapID RBG only? Not sure why there are two map IDs for Eye of the Storm), used to be mapID 813 before BFA
		46392,						-- Focused Assault
		46393						-- Brutal Assault
	},
	[1956] = {						-- Eye of the Storm, TBCC
		46392,						-- Focused Assault
		46393						-- Brutal Assault
	},
	[206] = {						-- Twin Peaks, used to be mapID 626 before BFA
		46392,						-- Focused Assault
		46393						-- Brutal Assault
	},
	[417] = {						-- Temple of Kotmogu, used to be mapID 856 before BFA
		121164, 					-- Orb of Power, Blue
		121175, 					-- Orb of Power, Purple
		121177, 					-- Orb of Power, Orange
		121176 						-- Orb of Power, Green
	}
}



Data.Classes = {}
Data.RolesToSpec = {HEALER = {}, TANK = {}, DAMAGER = {}} --for Testmode only
Data.ClassList = {} -- For TBCC Testmode only

do

	local specIdToRessource = {
		--Death Knight
		[250] = "RUNIC_POWER",	--Blood
		[251] = "RUNIC_POWER",	--Frost
		[252] = "RUNIC_POWER",	--Unholy
		--Demon Hunter
		[577] = "FURY",			--Havoc
		[581] = "PAIN",			--Vengeance
		--Druid
		[102] = "LUNAR_POWER",	--Balance
		[103] = "ENERGY",		--Feral Combat
		[104] = "RAGE",			--Guardian
		[105] = "MANA",			--Restoration
		--Evoker
		[1467] = "Essence", 	--Devastation
		[1468] = "Essence",		--Preservation
		--Hunter
		[253] = "FOCUS",		--Beast Mastery
		[254] = "FOCUS",		--Marksmanship
		[255] = "FOCUS",		--Survival
		--Mage
		[62] = "MANA",			--Arcane
		[63] = "MANA",			--Fire
		[64] = "MANA",			--Frost
		--Monk
		[268] = "ENERGY",		--Brewmaster
		[269] = "ENERGY",		--Windwalker
		[270] = "MANA",			--Mistweaver
		--Paladin
		[65] = "MANA",			--Holy
		[66] = "MANA",			--Protection
		[70] = "MANA",			--Retribution
		--Priest
		[256] = "MANA",			--Discipline
		[257] = "MANA",			--Holy
		[258] = "INSANITY",		--Shadow
		--Rogue
		[259] = "ENERGY",		--Assassination
		[260] = "ENERGY",		--Outlaw
		[261] = "ENERGY",		--Subtlety
		--Shaman,
		[262] = "MAELSTROM",	--Elemental
		[263] = "MAELSTROM",	--Enhancement
		[264] = "MANA",			--Restoration
		--Warlock
		[265] = "MANA",			--Affliction
		[266] = "MANA",			--Demonology
		[267] = "MANA",			--Destruction
		--Warrior
		[71] = "RAGE",			--Arms
		[72] = "RAGE",			--Fury
		[73] = "RAGE"			--Protection
	}

	local ClassRessources = { --used for TBCC
		WARRIOR = "RAGE",
		PALADIN = "MANA",
		HUNTER = "MANA",
		ROGUE = "ENERGY",
		PRIEST = "MANA",
		SHAMAN = "MANA",
		MAGE = "MANA",
		WARLOCK = "MANA",
		DRUID = "MANA",
		MONK = "ENERGY",
		DEATHKNIGHT = "RUNIC_POWER",
		DEMONHUNTER = "FURY",
		EVOKER = "ESSENCE"
	}


	for classID = 1, GetNumClasses() do --example classes[EnglishClass][SpecName].
		local _, classToken = GetClassInfo(classID)
		if classToken then
			Data.Classes[classToken] = {Ressource = ClassRessources[classToken]}-- for Classic, TBCC Wrath, and any other expansions without specs and some brawls

			
			if GetNumSpecializationsForClassID and GetSpecializationInfoByID and GetSpecialization then --HasSpeccs
				for i = 1, GetNumSpecializationsForClassID(classID) or 0 do
					local specID,maleSpecName,_,icon,role = GetSpecializationInfoForClassID(classID, i, 2) -- male version
					if not (maleSpecName and Data.RolesToSpec[role]) then break end -- WoW Forever: no spec data

					Data.Classes[classToken][maleSpecName] = {roleID = role, specID = specID, specIcon = icon, Ressource = specIdToRessource[specID]}
					table.insert(Data.RolesToSpec[role], {classToken = classToken, specName = maleSpecName}) --for testmode

					--if specName == "Танцующий с ветром" then specName = "Танцующая с ветром" end -- fix for russian bug, fix added on 2017.08.27
					local specID,specName,_,icon,role = GetSpecializationInfoForClassID(classID, i, 3) -- female version
					if not Data.Classes[classToken][specName] then --there is a female version of that specName
						Data.Classes[classToken][specName] = Data.Classes[classToken][maleSpecName]
					end
				end
			end
			table.insert(Data.ClassList, classToken) -- test mode fallback when there is no spec
		end
	end
end

