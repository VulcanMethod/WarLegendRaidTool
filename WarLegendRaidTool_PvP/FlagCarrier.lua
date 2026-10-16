---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)

---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

-- WoW Forever: flag carriers in Warsong Gulch (and any battleground using the same flag messages).
-- Retail showed the flag carriers as arena1 / arena2 units, Forever has no arena units, so (like
-- BattlegroundTargets) the carriers are read from the battleground messages:
--   "The Alliance flag was picked up by X!", "... was dropped by X!", "X captured the Horde flag!"
-- CHAT_MSG_BG_SYSTEM_HORDE / _ALLIANCE tell the faction of the carrier (picked up, dropped).
-- Message patterns taken from BattlegroundTargets (localized-carrier.lua).

local issecret = issecretvalue or function() return false end

local patternsByLocale = {
	deDE = {
		picked = "(.+) hat die Flagge der .+ aufgenommen!",
		picked2 = "(.+) hat die Flagge der .+ aufgenommen!",
		dropped = "fallenlassen!",
		captured = "errungen!",
	},
	esES = {
		picked = "¡(.+) ha cogido la bandera",
		picked2 = "¡(.+) ha cogido la bandera",
		dropped = "dejado caer la bandera",
		captured = "capturado la bandera",
	},
	esMX = {
		picked = "¡(.+) ha tomado la bandera",
		picked2 = "¡(.+) ha tomado la bandera",
		dropped = "dejado caer la bandera",
		captured = "capturado la bandera",
	},
	frFR = {
		picked = "a été ramassé par (.+) !",
		picked2 = "a été ramassé par (.+) !",
		dropped = "a été lâché",
		captured = "a pris le drapeau",
	},
	itIT = {
		picked = "(.+) ha raccolto la bandiera",
		picked2 = "(.+) ha raccolto la bandiera",
		dropped = "lasciato cadere la bandiera",
		captured = "conquistato la bandiera",
	},
	koKR = {
		picked = "(.+)|1이;가; (.+) 깃발을 손에 넣었습니다!",
		picked2 = "(.+)|1이;가; (.+) 깃발을 손에 넣었습니다!",
		dropped = "깃발을 떨어뜨렸습니다!",
		captured = "깃발 쟁탈에 성공했습니다!",
	},
	ptBR = {
		picked = "(.+) pegou a Bandeira da .+!",
		picked2 = "(.+) pegou a Bandeira da .+!",
		dropped = "largou a Bandeira",
		captured = "capturou a Bandeira",
	},
	ruRU = {
		picked = "(.+) несет флаг Орды!",
		picked2 = "Флаг Альянса у |3%-1%((.+)%)!",
		dropped = "роняет",
		captured = "захватывает",
	},
	zhCN = {
		picked = "旗帜被([^%s]+)拔起了！",
		picked2 = "旗帜被([^%s]+)拔起了！",
		dropped = "丢掉了",
		captured = "夺取",
	},
	zhTW = {
		picked = "被(.+)拔掉了!",
		picked2 = "被(.+)拔掉了!",
		dropped = "丟掉了",
		captured = "佔據了",
	},
	enUS = {
		picked = "was picked up by (.+)!",
		picked2 = "was picked up by (.+)!",
		dropped = "was dropped",
		captured = "captured the",
	},
}

local patterns = patternsByLocale[GetLocale()] or patternsByLocale.enUS
-- frFR: the space before "!" is a non-breaking space on some clients and a normal one on others
if GetLocale() == "frFR" then
	patterns.picked = "ramass\195\169 par (.-)[ \194\160]*!"
	patterns.picked2 = patterns.picked
end

-- "Name !" -> "Name", also drops the color codes some clients put around the name
local function cleanName(name)
	if not name then return end
	name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	name = name:gsub("^[%s\194\160]+", ""):gsub("[%s\194\160]+$", "")
	if name == "" then return end
	return name
end

-- the mainframe of the players of that faction ("Horde" / "Alliance")
local function getMainFrameForFaction(faction)
	if not faction or not WarLegendPvP.UserFaction then return end
	if faction == WarLegendPvP.UserFaction then
		return WarLegendPvP.Allies
	end
	return WarLegendPvP.Enemies
end

local function clearCarriers(mainFrame)
	if not mainFrame then return end
	for _, playerButton in pairs(mainFrame.Players) do
		if playerButton.hasFlag and not playerButton.PlayerDetails.isFakePlayer then
			playerButton:SetFlagCarrier(false)
		end
	end
end

function WarLegendPvP:ResetFlagCarriers()
	clearCarriers(self.Allies)
	clearCarriers(self.Enemies)
end

local function findCarrier(name, faction)
	local preferred = getMainFrameForFaction(faction)
	local playerButton = preferred and WarLegendPvP.FindPlayerInTable(preferred.Players, name, true)
	if playerButton then return playerButton end
	return WarLegendPvP.FindPlayerInTable(WarLegendPvP.Enemies.Players, name, true)
		or WarLegendPvP.FindPlayerInTable(WarLegendPvP.Allies.Players, name, true)
end

function WarLegendPvP:HandleBattlegroundMessage(message, faction)
	if issecret(message) or type(message) ~= "string" then return end
	if self:IsTestmodeOrEditmodeActive() then return end
	if not self.states.real.isInBattleground then return end

	local name = cleanName(message:match(patterns.picked) or message:match(patterns.picked2))
	if name then
		local playerButton = findCarrier(name, faction)
		self:Debug("Flag picked up", name, playerButton and playerButton.PlayerDetails.PlayerName)
		if playerButton then
			clearCarriers(playerButton.MainFrame) -- one carrier per team
			playerButton:SetFlagCarrier(true)
		end
		return
	end

	if message:find(patterns.captured, 1, true) then
		self:Debug("Flag captured")
		self:ResetFlagCarriers()
		return
	end

	if message:find(patterns.dropped, 1, true) then
		self:Debug("Flag dropped", faction)
		local mainFrame = getMainFrameForFaction(faction)
		if mainFrame then
			clearCarriers(mainFrame)
		else
			self:ResetFlagCarriers()
		end
	end
end

function WarLegendPvP:CHAT_MSG_BG_SYSTEM_HORDE(message)
	self:HandleBattlegroundMessage(message, "Horde")
end

function WarLegendPvP:CHAT_MSG_BG_SYSTEM_ALLIANCE(message)
	self:HandleBattlegroundMessage(message, "Alliance")
end

-- battlegrounds that announce their flag in the neutral color (WoW Forever's Darkspear Island...):
-- no faction, the carrier is looked for in both teams
function WarLegendPvP:CHAT_MSG_BG_SYSTEM_NEUTRAL(message)
	self:HandleBattlegroundMessage(message, nil)
end
