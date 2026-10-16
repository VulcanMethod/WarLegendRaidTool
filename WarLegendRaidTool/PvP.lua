-- WarLegend RaidTool - PvP
-- Battleground enemy / ally frames: the addon WarLegendRaidTool_PvP (BattleGroundEnemies cleaned up for
-- Forever), loaded on demand when entering a battleground or when this tab is opened. All its settings
-- are here (no separate options window).
local W = WLRT
local L = W.L
local db

local PVP_ADDON = "WarLegendRaidTool_PvP"
local loaded, loadFailed, waitCombat = false, false, false

W.AddFR({
    ["Battleground frames"] = "Cadres de champ de bataille",
    ["The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool."] =
        "Le module PvP est absent ou désactivé : installe le dossier WarLegendRaidTool_PvP à côté de WarLegendRaidTool.",
    ["Not in combat: the frames are loaded after the fight."] = "Pas en combat : les cadres seront chargés après le combat.",
    ["Show the enemy and ally frames in battlegrounds"] = "Afficher les cadres des ennemis et des alliés en champ de bataille",
    ["Style:"] = "Style :",
    ["Auto"] = "Auto",
    ["Blizzard"] = "Blizzard",
    ["EllesmereUI is not installed: Blizzard style."] = "EllesmereUI n'est pas installé : style Blizzard.",
    ["Lock the frames (unlocked: drag them to move)"] = "Verrouiller les cadres (déverrouillés : les glisser pour les déplacer)",
    ["Mouse wheel over the frames: previous / next target"] = "Molette sur les cadres : cible précédente / suivante",
    ["Hide the raid frames in battlegrounds"] = "Masquer les cadres de raid en champ de bataille",
    ["Tooltips"] = "Infobulles",
    ["Test mode"] = "Mode test",
    ["Test players:"] = "Joueurs en test :",
    ["Reset"] = "Réinitialiser",
    ["Reset all the battleground frame settings?"] = "Réinitialiser tous les réglages des cadres de champ de bataille ?",
    ["Enemies"] = "Ennemis",
    ["Allies"] = "Alliés",
    ["Show these frames"] = "Afficher ces cadres",
    ["Width:"] = "Largeur :",
    ["Height:"] = "Hauteur :",
    ["Scale:"] = "Échelle :",
    ["Health in %"] = "Vie en %",
    ["Shown on each player:"] = "Affiché sur chaque joueur :",
    ["The PvP module had an error while loading: see BugSack (/bugsack)."] =
        "Le module PvP a eu une erreur au chargement : voir BugSack (/bugsack).",
    ["PvP check:"] = "Vérif PvP :",
    ["in a battleground"] = "en champ de bataille",
    ["restriction"] = "restriction",
    ["chat lockdown"] = "verrouillage du chat",
    ["last battleground message"] = "dernier message du champ de bataille",
    ["secret"] = "secret",
    ["YES"] = "OUI",
    ["no"] = "non",
    ["not available on this client"] = "pas disponible sur ce client",
    ["no battleground message received since the last /reload"] = "aucun message de champ de bataille reçu depuis le dernier /reload",
    ["Battleground messages"] = "Messages du champ de bataille",
    ["ally auras: %d readable, %d secret"] = "auras des alliés : %d lisibles, %d secrètes",
    ["Not available on WoW Forever: auras, diminishing returns, trinket and racial (enemy data kept secret in battlegrounds)."] =
        "Pas disponible sur WoW Forever : auras, rendements décroissants, bijou et raciaux (infos ennemies secrètes en champ de bataille).",
})

-- Loads the PvP addon now (never in combat: it creates secure frames)
function W.LoadPvP()
    if loaded then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    if InCombatLockdown() then
        waitCombat = true
        W.Print(L("Not in combat: the frames are loaded after the fight."))
        return false
    end
    local ok = C_AddOns.LoadAddOn(PVP_ADDON)
    if not ok then
        loadFailed = true
        W.Print(L("The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool."))
        return false
    end
    loaded = true
    return true
end

local function InBattleground()
    local inInstance, kind = IsInInstance()
    return inInstance and kind == "pvp"
end

local function MaybeLoad()
    if not db or not db.enabled or W.access ~= true or loaded then return end
    if not InBattleground() then return end
    if InCombatLockdown() then waitCombat = true; return end
    W.LoadPvP()
end

W.OnReady(function()
    db = W.DB("pvp", { enabled = true })
end)
W.On("PLAYER_ENTERING_WORLD", MaybeLoad)
W.On("PLAYER_REGEN_ENABLED", function()
    if waitCombat then waitCombat = false; MaybeLoad() end
end)

W.slash.pvp = function() W.Toggle("PvPFrames") end

-- /wl pvpcheck: are the 12.x addon restrictions active in this battleground? (runs only when typed)
-- C_RestrictedActions.IsAddOnRestrictionActive, C_ChatInfo.InChatMessagingLockdown (warcraft.wiki.gg).
-- The last battleground system message is only noted (secret or not, never read), for the flag carrier.
local lastBGMessage
local recentBGMessages = {} -- the last readable ones (memory only), for /wl bgmsg
local function NoteBGMessage(event)
    return function(text)
        local secret = (issecretvalue and issecretvalue(text)) or (canaccessvalue and not canaccessvalue(text)) or false
        lastBGMessage = { event = event, secret = secret, at = time() }
        if not secret and type(text) == "string" then
            table.insert(recentBGMessages, 1, date("%H:%M:%S") .. "  " .. event:gsub("CHAT_MSG_BG_SYSTEM_", "") .. "  " .. text)
            while #recentBGMessages > 30 do table.remove(recentBGMessages) end
        end
    end
end
W.On("CHAT_MSG_BG_SYSTEM_HORDE", NoteBGMessage("CHAT_MSG_BG_SYSTEM_HORDE"))
W.On("CHAT_MSG_BG_SYSTEM_ALLIANCE", NoteBGMessage("CHAT_MSG_BG_SYSTEM_ALLIANCE"))
W.On("CHAT_MSG_BG_SYSTEM_NEUTRAL", NoteBGMessage("CHAT_MSG_BG_SYSTEM_NEUTRAL"))

-- /wl bgmsg: the last battleground messages, to copy (to add the flag texts of a new battleground)
W.slash.bgmsg = function()
    W.TextPopup(L("Battleground messages"), #recentBGMessages > 0 and table.concat(recentBGMessages, "\n")
        or L("no battleground message received since the last /reload"), { hint = "Ctrl+C" })
end

local function Answer(value)
    if value == nil then return L("not available on this client") end
    if issecretvalue and issecretvalue(value) then return L("secret") end
    return value and L("YES") or L("no")
end

W.slash.pvpcheck = function()
    local inInstance, kind = IsInInstance()
    W.Print(L("PvP check:") .. " " .. L("in a battleground") .. " = " .. Answer(inInstance and kind == "pvp"))
    local types = Enum and Enum.AddOnRestrictionType
    local isActive = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    if types and isActive then
        for _, name in ipairs({ "PvPMatch", "Combat", "Map", "Chat" }) do
            if types[name] then
                W.Print("  " .. L("restriction") .. " " .. name .. " = " .. Answer(isActive(types[name])))
            end
        end
    else
        W.Print("  C_RestrictedActions: " .. L("not available on this client"))
    end
    local lockdown
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then lockdown = C_ChatInfo.InChatMessagingLockdown() end
    W.Print("  " .. L("chat lockdown") .. " = " .. Answer(lockdown))
    -- auras of my team (the ally frames show them only when readable)
    local readable, secret = 0, 0
    local units = W.InRaid() and { "raid1", "raid2", "raid3", "raid4", "raid5" } or { "player" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
                for i = 1, 40 do
                    local a = W.AuraByIndex(unit, i, filter)
                    if a == nil then break end
                    if a then readable = readable + 1 else secret = secret + 1 end
                    if secret >= 40 then break end
                end
            end
        end
    end
    W.Print("  " .. string.format(L("ally auras: %d readable, %d secret"), readable, secret))
    if lastBGMessage then
        W.Print("  " .. L("last battleground message") .. " (" .. date("%H:%M:%S", lastBGMessage.at) .. ") " ..
            L("secret") .. " = " .. Answer(lastBGMessage.secret))
    else
        W.Print("  " .. L("no battleground message received since the last /reload"))
    end
end

-- value lists of the cycle buttons
local STYLES = { { "auto", "Auto" }, { "eui", "EllesmereUI" }, { "blizzard", "Blizzard" } }
local WIDTHS, HEIGHTS, SCALES = {}, {}, {}
for _, v in ipairs({ 140, 160, 180, 200, 220, 240, 260 }) do WIDTHS[#WIDTHS + 1] = { v, tostring(v) } end
for _, v in ipairs({ 18, 22, 26, 28, 32, 38, 47 }) do HEIGHTS[#HEIGHTS + 1] = { v, tostring(v) } end
for _, v in ipairs({ 0.8, 0.9, 1, 1.1, 1.2, 1.3 }) do SCALES[#SCALES + 1] = { v, tostring(v) } end

-- the frames of one side (Enemies / Allies)
local function BuildSide(f, pvp, side)
    W.Check(f, L("Show these frames"), function() return pvp:GetSideSetting(side, "Enabled") end,
        function(v) pvp:SetSideSetting(side, "Enabled", v) end):SetPoint("TOPLEFT", 12, -4)

    local rows = { { L("Width:"), "Width", WIDTHS }, { L("Height:"), "Height", HEIGHTS }, { L("Scale:"), "Scale", SCALES } }
    for i, row in ipairs(rows) do
        local x = 16 + (i - 1) * 140
        W.Label(f, row[1], "GameFontHighlightSmall"):SetPoint("TOPLEFT", x, -38)
        W.Cycle(f, 64, row[3], function() return pvp:GetSideSetting(side, row[2]) end,
            function(v) pvp:SetSideSetting(side, row[2], v) end):SetPoint("TOPLEFT", x + 58, -33)
    end

    W.Check(f, L("Health in %"), function() return pvp:GetSideSetting(side, "HealthText") end,
        function(v) pvp:SetSideSetting(side, "HealthText", v) end):SetPoint("TOPLEFT", 12, -62)

    W.Label(f, L("Shown on each player:"), "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, -94)
    for i, moduleName in ipairs(pvp.ToggleableModules) do
        local module = pvp.ButtonModules[moduleName]
        if module then
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            W.Check(f, module.localizedModuleName or moduleName,
                function() return pvp:GetSideSetting(side, "Modules", moduleName) end,
                function(v) pvp:SetSideSetting(side, "Modules", v, moduleName) end
            ):SetPoint("TOPLEFT", 12 + col * 220, -110 - row * 24)
        end
    end
end

W.RegisterModule("PvPFrames", "Battleground frames", function(p)
    W.Title(p, L("Battleground frames"))
    if not W.LoadPvP() or not WarLegendPvP or not WarLegendPvP.db then
        local why
        if loadFailed then
            why = L("The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool.")
        elseif InCombatLockdown() then
            why = L("Not in combat: the frames are loaded after the fight.") .. " (/reload)"
        else
            why = L("The PvP module had an error while loading: see BugSack (/bugsack).")
        end
        local label = W.Label(p, why, "GameFontDisable")
        label:SetPoint("TOPLEFT", 16, -44)
        label:SetWidth(440)
        return
    end
    local pvp = WarLegendPvP

    W.Check(p, L("Show the enemy and ally frames in battlegrounds"), function() return db.enabled end,
        function(v)
            db.enabled = v
            pvp:SetSetting("ShowBGEInBattleground", v)
            MaybeLoad()
        end):SetPoint("TOPLEFT", 12, -40)

    W.Label(p, L("Style:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -72)
    local styles = {}
    for _, s in ipairs(STYLES) do styles[#styles + 1] = { s[1], L(s[2]) } end
    W.Cycle(p, 110, styles, function() return pvp:GetSetting("Style") end,
        function(v) pvp:SetSetting("Style", v) end):SetPoint("TOPLEFT", 70, -67)
    if not pvp:HasEllesmereUI() then
        W.Label(p, L("EllesmereUI is not installed: Blizzard style."), "GameFontDisableSmall"):SetPoint("TOPLEFT", 190, -72)
    end

    local checks = {
        { L("Lock the frames (unlocked: drag them to move)"), "Locked" },
        { L("Mouse wheel over the frames: previous / next target"), "EnableMouseWheelPlayerTargeting" },
        { L("Hide the raid frames in battlegrounds"), "DisableRaidFramesInBattleground" },
        { L("Tooltips"), "ShowTooltips" },
    }
    for i, c in ipairs(checks) do
        W.Check(p, c[1], function() return pvp:GetSetting(c[2]) end,
            function(v) pvp:SetSetting(c[2], v) end):SetPoint("TOPLEFT", 12, -92 - (i - 1) * 24)
    end

    W.Button(p, L("Test mode"), 110, 22, function() pvp.ToggleTestmode() end):SetPoint("TOPLEFT", 16, -192)
    W.Button(p, L("Reset"), 110, 22, function()
        W.Confirm(L("Reset all the battleground frame settings?"), function()
            pvp:ResetSettings()
            if p:IsShown() then p:Hide(); p:Show() end -- the checkboxes sync on show
        end)
    end):SetPoint("TOPLEFT", 132, -192)

    -- test mode player count (1 to 40, the BattleGroundEnemies slider): - / + and quick sizes
    W.Label(p, L("Test players:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 262, -197)
    local count = W.Label(p, "", "GameFontHighlight")
    count:SetPoint("TOPLEFT", 386, -196)
    count:SetWidth(30)
    count:SetJustifyH("CENTER")
    local function ShowCount() count:SetText(pvp:GetTestPlayerCount()) end
    local function Change(value)
        pvp:SetTestPlayerCount(value)
        ShowCount()
    end
    W.Button(p, "-", 26, 22, function() Change(pvp:GetTestPlayerCount() - 1) end):SetPoint("TOPLEFT", 358, -192)
    W.Button(p, "+", 26, 22, function() Change(pvp:GetTestPlayerCount() + 1) end):SetPoint("TOPLEFT", 418, -192)
    for i, size in ipairs({ 10, 15, 20, 40 }) do
        W.Button(p, tostring(size), 34, 22, function() Change(size) end):SetPoint("TOPLEFT", 452 + (i - 1) * 38, -192)
    end
    ShowCount()
    p:HookScript("OnShow", ShowCount) -- after a reset, or a change made elsewhere

    local tabs = W.SubTabs(p, { L("Enemies"), L("Allies") }, nil, -224)
    BuildSide(tabs.frames[1], pvp, "Enemies")
    BuildSide(tabs.frames[2], pvp, "Allies")
    tabs:Select(1)

    local note = W.Label(p, L("Not available on WoW Forever: auras, diminishing returns, trinket and racial (enemy data kept secret in battlegrounds)."), "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 10)
    note:SetWidth(440)
end)
