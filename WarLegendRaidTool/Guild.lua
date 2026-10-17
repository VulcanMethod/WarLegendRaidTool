-- WarLegend RaidTool - Guild tools
-- Inactive members, guild professions (synced between members who have the addon:
-- who can craft what), recruitment messages.
local W = WLRT
W.AddFR({
    ["Guild"] = "Guilde",
    ["Inactive"] = "Inactifs",
    ["Professions"] = "Métiers",
    ["Recruitment"] = "Recrutement",
    ["Offline for at least (days):"] = "Hors ligne depuis au moins (jours) :",
    ["Hide officers"] = "Cacher les officiers",
    ["Level"] = "Niveau",
    ["Offline"] = "Absent depuis",
    ["Public note"] = "Note publique",
    ["%d members"] = "%d membres",
    ["Export list"] = "Exporter la liste",
    ["Search a recipe or item:"] = "Chercher une recette ou un objet :",
    ["Recipe"] = "Recette",
    ["Crafters"] = "Artisans",
    ["Updated"] = "Mis à jour",
    ["All"] = "Tous",
    ["Ask the guild"] = "Demander à la guilde",
    ["Open each of your professions once so the addon can read your recipes."] =
        "Ouvre chacun de tes métiers une fois pour que l'addon lise tes recettes.",
    ["Data comes from guild members who have the addon."] = "Les données viennent des membres de la guilde qui ont l'addon.",
    ["Message %d"] = "Message %d",
    ["Channel (name or number):"] = "Canal (nom ou numéro) :",
    ["Post now"] = "Poster maintenant",
    ["Remind me every"] = "Me rappeler toutes les",
    ["min"] = "min",
    ["Time to post your recruitment message."] = "C'est l'heure de poster ton message de recrutement.",
    ["Post"] = "Poster",
    ["Channel not found: "] = "Canal introuvable : ",
    ["{guild} = guild name, {me} = your name. 255 characters max."] = "{guild} = nom de la guilde, {me} = ton nom. 255 caractères max.",
    ["<{guild}> is recruiting for its raids! All classes welcome, friendly and motivated. Whisper {me} for info."] =
        "<{guild}> recrute pour ses raids ! Toutes classes bienvenues, ambiance sympa et motivée. /w {me} pour infos.",
    ["Not in a guild."] = "Pas dans une guilde.",
    ["No profession link from %s yet: he must open his profession once with the addon."] =
        "Pas encore de lien de métier de %s : il doit ouvrir son métier une fois avec l'addon.",
    ["Click: open his profession. Shift-click: link it in the chat."] =
        "Clic : ouvrir son métier. Maj-clic : le lier dans le chat.",
    ["Ctrl-click: whisper him."] = "Ctrl-clic : le chuchoter.",
    ["Nobody has a recipe named \"%s\" (only members who have the addon and opened their professions)."] =
        "Personne n'a de recette « %s » (seulement les membres qui ont l'addon et ont ouvert leurs métiers).",
    ["Who can craft \"%s\":"] = "Qui peut fabriquer « %s » :",
    ["... and %d more: see Guild > Professions."] = "... et %d de plus : voir Guilde > Métiers.",
})
local L = W.L

local G = {}
W.Guild = G
local PREFIX = "WLRT_PROF"
local db

W.OnReady(function()
    db = W.DB("guild", { inactiveDays = 14, hideOfficers = true, channel = "LookingForGroup", interval = 15, remind = false,
        last = 0, sel = 1, profFilter = "" })
    if type(db.msgs) ~= "table" then db.msgs = { L("<{guild}> is recruiting for its raids! All classes welcome, friendly and motivated. Whisper {me} for info."), "", "" } end
    if type(db.data) ~= "table" then db.data = {} end
    -- members who have not synced for 90 days (left the guild...) are forgotten: the saved file stays small
    local cutoff, me = time() - 90 * 86400, W.Safe(UnitName("player"))
    for _, members in pairs(db.data) do
        for name, e in pairs(members) do
            if name ~= me and type(e) == "table" and (e.t or 0) < cutoff then members[name] = nil end
        end
    end
end)

-- Recipe lists were tables of numbers: now compact "id,id,..." text (about 3x less memory)
W.Migration(2, "guild", function(all)
    local g = all.guild
    if type(g) ~= "table" or type(g.data) ~= "table" then return end
    for _, members in pairs(g.data) do
        for _, e in pairs(type(members) == "table" and members or {}) do
            if type(e) == "table" and type(e.rec) == "table" then
                for prof, ids in pairs(e.rec) do
                    if type(ids) == "table" then e.rec[prof] = table.concat(ids, ",") end
                end
            end
        end
    end
end)

local function GuildName()
    return (GetGuildInfo and GetGuildInfo("player")) or nil
end

local function Data()
    local g = GuildName() or "?"
    db.data[g] = db.data[g] or {}
    return db.data[g]
end

local function Me() return W.Safe(UnitName("player")) or "?" end

---------------------------------------------------------------------------
-- Inactive members
---------------------------------------------------------------------------
function G.Inactive()
    local out = {}
    if not W.IsInGuild() then return out end
    for i = 1, (GetNumGuildMembers() or 0) do
        local name, rank, rankIndex, level, _, _, note, _, online, _, class = GetGuildRosterInfo(i)
        name = W.Safe(name)
        if name and not online then
            local y, m, d, h = 0, 0, 0, 0
            if GetGuildRosterLastOnline then y, m, d, h = GetGuildRosterLastOnline(i) end
            local days = (y or 0) * 365 + (m or 0) * 30 + (d or 0) + (h or 0) / 24
            if days >= (db.inactiveDays or 14) and not (db.hideOfficers and (rankIndex or 9) <= 1) then
                out[#out + 1] = { name = W.BaseName(name), rank = rank, level = level, class = class, days = days, note = note or "" }
            end
        end
    end
    table.sort(out, function(a, b) return a.days > b.days end)
    return out
end

---------------------------------------------------------------------------
-- Professions: mine, read from the game
---------------------------------------------------------------------------
-- the 12 professions of WoW: Forever (checked on wowhead.com/forever and Naowh Forever's recipe data)
local PROF_SPELLS = { 2259, 2018, 7411, 4036, 2108, 3908, 2575, 8613, 2550, 3273, 7620, 2366 }
local profNames
local function ProfNames()
    if profNames then return profNames end
    profNames = { Herbalism = true, Herboristerie = true }
    for _, id in ipairs(PROF_SPELLS) do
        local n = W.SpellName(id)
        if n then profNames[n] = true end
    end
    return profNames
end

local function OwnProfessions()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local idx = { GetProfessions() }
        for i = 1, 6 do
            if idx[i] then
                local name, _, rank, max = GetProfessionInfo(idx[i])
                if name then out[#out + 1] = { n = name, r = rank or 0, m = max or 0 } end
            end
        end
    end
    if #out == 0 and GetNumSkillLines and GetSkillLineInfo then
        local names = ProfNames()
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
            if name and not header and names[name] then out[#out + 1] = { n = name, r = rank or 0, m = max or 0 } end
        end
    end
    return out
end

local function MyEntry()
    local d = Data()
    local me = d[Me()] or { rec = {} }
    d[Me()] = me
    me.rec = me.rec or {}
    return me
end

-- Reads the learned recipes of the open profession window (own window only).
-- WoW: Forever uses the modern profession API (C_TradeSkillUI, ProfessionsFrame), like Naowh Forever:
-- recipe IDs are spell IDs (Forever's new recipes have 7-digit ones, e.g. 1259342 Simple Poultice).
local function ScanRecipes()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then return end
    if (C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked())
        or (C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild())
        or (C_TradeSkillUI.IsNPCCrafting and C_TradeSkillUI.IsNPCCrafting()) then return end
    local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local prof = base and base.professionName
    if (not prof or prof == "") and C_TradeSkillUI.GetChildProfessionInfo then
        local child = C_TradeSkillUI.GetChildProfessionInfo()
        prof = child and child.professionName
    end
    if not prof or prof == "" then return end
    local ids = {}
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then ids[#ids + 1] = id end
    end
    if #ids == 0 then return end
    table.sort(ids)
    local me = MyEntry()
    local list = table.concat(ids, ",")
    local changed = me.rec[prof] ~= list
    me.rec[prof] = list -- compact text: a few KB per member instead of a table of numbers
    -- the profession link (as a shift-click on the profession): the others open my recipe list with it
    if C_TradeSkillUI.GetTradeSkillListLink then
        local ok, link = pcall(C_TradeSkillUI.GetTradeSkillListLink)
        link = ok and W.Safe(link)
        if type(link) == "string" and link:find("|Htrade:", 1, true) then
            me.links = me.links or {}
            if me.links[prof] ~= link then me.links[prof] = link; changed = true end
        end
    end
    me.profs = OwnProfessions()
    me.t = time()
    if changed then G.Broadcast() end
    return true
end

-- The list update fires on every craft: once the window has been read, wait 30 s before
-- reading it again (opening a profession or learning a recipe still reads it right away).
local SCAN_GAP = 30
local scanPending, lastScan = false, -SCAN_GAP
local function Scan(force)
    if not force and GetTime() - lastScan < SCAN_GAP then return end
    local ok, done = pcall(ScanRecipes)
    if ok and done then lastScan = GetTime() end
end
W.On("TRADE_SKILL_LIST_UPDATE", function()
    if scanPending or GetTime() - lastScan < SCAN_GAP then return end
    scanPending = true
    W.After(1, function() scanPending = false; Scan() end)
end)
W.On("TRADE_SKILL_SHOW", function() W.After(1.5, function() Scan(true) end) end)
W.On("NEW_RECIPE_LEARNED", function() W.After(1, function() Scan(true) end) end)

---------------------------------------------------------------------------
-- Sync with the guild
---------------------------------------------------------------------------
local function Encode(e)
    local p = {}
    for _, x in ipairs(e.profs or {}) do p[#p + 1] = x.n .. ":" .. x.r .. ":" .. x.m end
    local r = {}
    for prof, ids in pairs(e.rec or {}) do r[#r + 1] = prof .. "=" .. (type(ids) == "table" and table.concat(ids, ",") or ids) end
    -- profession links: "prof \31 link" separated by \30 (a link holds ":" ";" and "=")
    local l = {}
    for prof, link in pairs(e.links or {}) do l[#l + 1] = prof .. "\31" .. link end
    return W.Pack("D", table.concat(p, ";"), table.concat(r, ";"), table.concat(l, "\30"))
end

function G.Broadcast()
    if not W.IsInGuild() then return end
    local me = MyEntry()
    me.profs = OwnProfessions()
    me.t = me.t or time()
    W.SendLong(PREFIX, Encode(me), "GUILD")
end

local lastAsk = 0
function G.Ask()
    if not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.SendLong(PREFIX, "Q", "GUILD")
end

local answering
W.OnAddonLong(PREFIX, function(msg, from, _, full)
    if from == Me() or not W.GuildMember(full or from) then return end -- guild members only
    local t = W.Unpack(msg)
    if t[1] == "Q" then
        if answering then return end
        answering = true
        W.After(2 + math.random() * 10, function() answering = false; G.Broadcast() end)
    elseif t[1] == "D" then
        local e = { t = time(), profs = {}, rec = {}, links = {} }
        for n, r, m in (t[2] or ""):gmatch("([^:;]+):(%d+):(%d+)") do e.profs[#e.profs + 1] = { n = n, r = tonumber(r), m = tonumber(m) } end
        for prof, list in (t[3] or ""):gmatch("([^=;]+)=([%d,]+)") do
            if #prof <= 40 and #list <= 20000 then e.rec[prof] = list end -- kept as compact text
        end
        for prof, link in (t[4] or ""):gmatch("([^\30\31]+)\31([^\30]+)") do
            if #prof <= 40 and #link <= 4000 and link:find("|Htrade:", 1, true) then e.links[prof] = link end
        end
        Data()[from] = e
        G.RefreshProfs()
    end
end)

W.On("PLAYER_ENTERING_WORLD", function(isLogin)
    if isLogin then W.After(40, function() if W.IsInGuild() then G.Broadcast() end end) end
end)

---------------------------------------------------------------------------
-- Recruitment
---------------------------------------------------------------------------
local function Fill(msg)
    return ((msg or ""):gsub("{guild}", GuildName() or ""):gsub("{me}", Me()))
end

function G.Post()
    local msg = Fill(db.msgs[db.sel] or "")
    if msg == "" then return end
    local chan = db.channel or ""
    local id = tonumber(chan) or (GetChannelName and GetChannelName(chan))
    if not id or id == 0 then W.Print(L("Channel not found: ") .. chan); return end
    if not W.SendChat(msg:sub(1, 255), "CHANNEL", id) then
        W.Print(L("Channel not found: ") .. chan)
        return
    end
    db.last = time()
end

-- the reminder timer only runs while the reminder is on
local ticking = false
local function Tick()
    if not db or not db.remind or not W.IsInGuild() then ticking = false; return end
    W.After(30, Tick)
    if time() - (db.last or 0) >= (db.interval or 15) * 60 and not (InCombatLockdown and InCombatLockdown()) then
        db.last = time() -- one reminder per interval, even if ignored
        W.Confirm(L("Time to post your recruitment message.") .. "\n\n|cffaaaaaa" .. Fill(db.msgs[db.sel]) .. "|r", G.Post, L("Post"))
    end
end
local function StartTick()
    if ticking or not db or not db.remind then return end
    ticking = true
    W.After(30, Tick)
end
W.On("PLAYER_LOGIN", function() W.After(30, StartTick) end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local UI = {}

function G.RefreshInactive()
    if not UI.inactive or not UI.inactive:IsVisible() then return end
    local rows = {}
    for _, m in ipairs(G.Inactive()) do
        rows[#rows + 1] = { cells = { W.ColorName(m.name, m.class), m.rank or "", m.level or "", string.format(L("%dd"), math.floor(m.days)), m.note } }
    end
    UI.inactive:SetData(rows)
    UI.count:SetText(string.format(L("%d members"), #rows))
end

local function BuildInactive(p)
    local lbl = W.Label(p, L("Offline for at least (days):"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -10)
    local box = W.EditBox(p, 40, 4)
    box:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    box:SetNumeric(true)
    box:SetScript("OnShow", function(self) self:SetText(tostring(db.inactiveDays)) end)
    box:SetScript("OnTextChanged", function(self) db.inactiveDays = tonumber(self:GetText()) or 0; G.RefreshInactive() end)
    W.Check(p, L("Hide officers"), function() return db.hideOfficers end, function(v) db.hideOfficers = v; G.RefreshInactive() end)
        :SetPoint("LEFT", box, "RIGHT", 16, 0)
    UI.count = W.Label(p, "", "GameFontNormalSmall")
    UI.count:SetPoint("TOPLEFT", 480, -10)
    W.Button(p, L("Export list"), 110, 22, function()
        local t = {}
        for _, m in ipairs(G.Inactive()) do t[#t + 1] = W.CSV(m.name, m.rank or "", math.floor(m.days)) end
        W.TextPopup(L("Inactive"), table.concat(t, "\n"), { hint = "Ctrl+C" })
    end):SetPoint("TOPRIGHT", -16, -6)
    UI.inactive = W.Table(p, { { L("Name"), 130 }, { L("Rank"), 110 }, { L("Level"), 50, "CENTER" }, { L("Offline"), 90, "CENTER" },
        { L("Public note"), 260 } }, 460)
    UI.inactive:SetPoint("TOPLEFT", 10, -40)
    p:SetScript("OnShow", function() W.RequestGuildRoster(); G.RefreshInactive() end)
end

local recipeNames, recipeLower = {}, {}
local function RecipeName(id)
    local n = recipeNames[id]
    if not n then n = W.SpellName(id); recipeNames[id] = n end
    return n or ("#" .. id)
end

-- lowercase name, cached: the search runs on every key press over every member's recipes
local function RecipeLower(id)
    local n = recipeLower[id]
    if not n then
        n = RecipeName(id):lower()
        if recipeNames[id] then recipeLower[id] = n end -- not cached while the name is unknown
    end
    return n
end

local function Online(name)
    local g = W.GuildInfo(name)
    return g and g.online
end

-- "Who can craft X?": the recipes whose name holds the text (an item link counts as its name), each with
-- its crafters, online ones first. filter: one profession, or "" for all.
local function SearchText(text)
    text = text or ""
    return (text:match("%[(.-)%]") or text):match("^%s*(.-)%s*$"):lower()
end

function G.FindCrafters(search, filter)
    local d = Data()
    local by = {}
    for n, e in pairs(d) do
        for prof, list in pairs(e.rec or {}) do
            if filter == "" or prof == filter then
                if type(list) == "table" then list = table.concat(list, ",") end
                for id in list:gmatch("%d+") do
                    id = tonumber(id)
                    if RecipeLower(id):find(search, 1, true) then
                        by[id] = by[id] or {}
                        by[id].prof = prof
                        table.insert(by[id], n)
                    end
                end
            end
        end
    end
    local found = {}
    for id, names in pairs(by) do
        table.sort(names, function(a, b)
            local oa, ob = Online(a) and 1 or 0, Online(b) and 1 or 0
            if oa ~= ob then return oa > ob end
            return a < b
        end)
        found[#found + 1] = { id = id, prof = names.prof, names = names }
    end
    table.sort(found, function(a, b) return RecipeName(a.id) < RecipeName(b.id) end)
    return found
end

local function CrafterNames(names)
    local out = {}
    for _, n in ipairs(names) do out[#out + 1] = Online(n) and ("|cff33ff66" .. n .. "|r") or ("|cff999999" .. n .. "|r") end
    return table.concat(out, ", ")
end

function G.RefreshProfs()
    if not UI.profs or not UI.profs:IsVisible() then return end
    local d = Data()
    local search = SearchText(UI.search:GetText())
    local filter = db.profFilter or ""
    local rows = {}
    if search == "" then
        local names = {}
        for n in pairs(d) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do
            local e = d[n]
            local parts, keep = {}, filter == ""
            for _, x in ipairs(e.profs or {}) do
                -- the skill alone ("Alchemy 150"), nothing once it reaches 300 (the max)
                parts[#parts + 1] = x.n .. (((x.r or 0) < 300) and (" " .. x.r) or "")
                if x.n == filter then keep = true end
            end
            if keep then
                local g = W.GuildInfo(n)
                rows[#rows + 1] = { member = n, cells = { (Online(n) and "|cff33ff66*|r " or "  ") .. W.ColorName(n, g and g.class), table.concat(parts, ", "), W.Ago(e.t) } }
            end
        end
        UI.profHead1:SetText(L("Name")); UI.profHead2:SetText(L("Professions"))
    else
        for _, r in ipairs(G.FindCrafters(search, filter)) do
            -- a click opens this profession of the first crafter (online ones first)
            rows[#rows + 1] = { member = r.names[1], prof = r.prof, recipe = true, cells = { RecipeName(r.id), CrafterNames(r.names), "" } }
            if #rows >= 300 then break end
        end
        UI.profHead1:SetText(L("Recipe")); UI.profHead2:SetText(L("Crafters"))
    end
    UI.profs:SetData(rows)
end

local function ProfFilterValues()
    local seen, vals = {}, { { "", L("All") } }
    for _, e in pairs(Data()) do
        for _, x in ipairs(e.profs or {}) do
            if not seen[x.n] then seen[x.n] = true; vals[#vals + 1] = { x.n, x.n } end
        end
    end
    table.sort(vals, function(a, b) if a[1] == "" then return true elseif b[1] == "" then return false end return a[1] < b[1] end)
    return vals
end

---------------------------------------------------------------------------
-- A member's profession, as a shift-click on a profession link in the chat: click = open it (the game's
-- profession window shows his recipes), shift-click = put the link in the chat box.
---------------------------------------------------------------------------
local function OpenProfessionLink(link)
    if IsShiftKeyDown() and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
        return
    end
    local ref = link:match("|H(.-)|h")
    if ref and SetItemRef then pcall(SetItemRef, ref, link, "LeftButton") end
end

local linkMenu
local function MemberLinks(member, onlyProf)
    local e = member and Data()[member]
    local list = {}
    for prof, link in pairs(e and e.links or {}) do
        if not onlyProf or prof == onlyProf then list[#list + 1] = { prof, link } end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

local function ShowMemberLinks(member, onlyProf)
    local list = MemberLinks(member, onlyProf)
    if #list == 0 then
        W.Print(string.format(L("No profession link from %s yet: he must open his profession once with the addon."), member or "?"))
        return
    end
    if #list == 1 then OpenProfessionLink(list[1][2]); return end
    -- several professions: a small menu at the cursor
    if not linkMenu then
        linkMenu = CreateFrame("Frame", "WLRTProfessionLinkMenu", UIParent, W.BT)
        linkMenu:SetFrameStrata("DIALOG")
        W.Backdrop(linkMenu, 0.97)
        linkMenu.buttons = {}
        tinsert(UISpecialFrames, "WLRTProfessionLinkMenu")
    end
    for i, entry in ipairs(list) do
        local b = linkMenu.buttons[i]
        if not b then
            b = W.Button(linkMenu, "", 170, 20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 22)
            linkMenu.buttons[i] = b
        end
        b:SetText(entry[1])
        b:SetScript("OnClick", function() linkMenu:Hide(); OpenProfessionLink(entry[2]) end)
        b:Show()
    end
    for i = #list + 1, #linkMenu.buttons do linkMenu.buttons[i]:Hide() end
    W.Size(linkMenu, 182, 12 + #list * 22)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    linkMenu:ClearAllPoints()
    linkMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
    linkMenu:Show()
    W.After(8, function() if linkMenu then linkMenu:Hide() end end)
end

local function BuildProfs(p)
    local lbl = W.Label(p, L("Search a recipe or item:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -10)
    UI.search = W.EditBox(p, 200, 60)
    UI.search:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.search:SetScript("OnTextChanged", G.RefreshProfs)
    W.LinkTarget(UI.search) -- shift-click an item while typing: its name is searched
    local filterBtn
    filterBtn = W.Button(p, L("All"), 130, 22, function()
        local vals = ProfFilterValues()
        local idx = 1
        for i, v in ipairs(vals) do if v[1] == db.profFilter then idx = i end end
        local nxt = vals[(idx % #vals) + 1]
        db.profFilter = nxt[1]
        filterBtn:SetText(nxt[2])
        G.RefreshProfs()
    end)
    filterBtn:SetPoint("LEFT", UI.search, "RIGHT", 10, 0)
    filterBtn:SetText(db.profFilter ~= "" and db.profFilter or L("All"))
    W.Button(p, L("Ask the guild"), 130, 22, function() G.Ask(); G.Broadcast() end):SetPoint("TOPRIGHT", -16, -6)
    UI.profs = W.Table(p, { { L("Name"), 200 }, { L("Professions"), 480 }, { L("Updated"), 70, "CENTER" } }, 420)
    UI.profs:SetPoint("TOPLEFT", 10, -40)
    UI.profs.onClick = function(d)
        if not d.member then return end
        if IsControlKeyDown() and ChatFrame_SendTell then ChatFrame_SendTell(d.member); return end
        ShowMemberLinks(d.member, d.prof)
    end
    UI.profs.onEnter = function(d, row)
        if not d.member then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.member, 1, 1, 1)
        GameTooltip:AddLine(L("Click: open his profession. Shift-click: link it in the chat."), 0.8, 0.8, 0.8, true)
        if d.recipe then GameTooltip:AddLine(L("Ctrl-click: whisper him."), 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end
    -- the table headers change with the mode
    UI.profHead1, UI.profHead2 = UI.profs.heads[1], UI.profs.heads[2]
    local h1 = W.Label(p, L("Open each of your professions once so the addon can read your recipes."), "GameFontDisableSmall")
    h1:SetPoint("BOTTOMLEFT", 14, 22)
    local h2 = W.Label(p, L("Data comes from guild members who have the addon."), "GameFontDisableSmall")
    h2:SetPoint("BOTTOMLEFT", 14, 6)
    p:SetScript("OnShow", function() G.Ask(); G.RefreshProfs() end)
end

local function BuildRecruit(p)
    local box
    local tabs = {}
    local function sync()
        box:SetText(db.msgs[db.sel] or "")
        for i, b in ipairs(tabs) do
            W.SetSelected(b, i == db.sel)
        end
    end
    for i = 1, 3 do
        tabs[i] = W.Button(p, string.format(L("Message %d"), i), 100, 22, function() db.sel = i; sync() end)
        tabs[i]:SetPoint("TOPLEFT", 14 + (i - 1) * 104, -6)
    end
    local bg
    bg, box = W.MultiEdit(p, 640, 120, 255)
    bg:SetPoint("TOPLEFT", 14, -34)
    local count = W.Label(p, "", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, -4)
    box:SetScript("OnTextChanged", function(self)
        db.msgs[db.sel] = self:GetText()
        count:SetText(#Fill(self:GetText()) .. "/255")
    end)
    local help = W.Label(p, L("{guild} = guild name, {me} = your name. 255 characters max."), "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -4)
    local cl = W.Label(p, L("Channel (name or number):"), "GameFontHighlightSmall")
    cl:SetPoint("TOPLEFT", 16, -186)
    local chan = W.EditBox(p, 160, 40)
    chan:SetPoint("LEFT", cl, "RIGHT", 8, 0)
    chan:SetScript("OnShow", function(self) self:SetText(db.channel or "") end)
    chan:SetScript("OnTextChanged", function(self) db.channel = self:GetText() end)
    W.Button(p, L("Post now"), 130, 22, G.Post):SetPoint("LEFT", chan, "RIGHT", 12, 0)
    W.Check(p, L("Remind me every"), function() return db.remind end, function(v) db.remind = v; StartTick() end):SetPoint("TOPLEFT", 12, -216)
    W.Cycle(p, 80, { { 10, "10 " .. L("min") }, { 15, "15 " .. L("min") }, { 20, "20 " .. L("min") }, { 30, "30 " .. L("min") }, { 60, "60 " .. L("min") } },
        function() return db.interval end, function(v) db.interval = v end):SetPoint("TOPLEFT", 160, -216)
    p:SetScript("OnShow", sync)
end

W.RegisterModule("Guild", L("Guild"), function(p)
    W.Title(p, L("Guild"))
    UI.tabs = W.SubTabs(p, { L("Inactive"), L("Professions"), L("Recruitment") })
    BuildInactive(UI.tabs.frames[1])
    BuildProfs(UI.tabs.frames[2])
    BuildRecruit(UI.tabs.frames[3])
    UI.tabs:Select(1)
end, function()
    if UI.tabs then UI.tabs:Select(UI.tabs.current or 1) end
end)

W.On("GUILD_ROSTER_UPDATE", function() if W.IsShown("Guild") then G.RefreshInactive() end end)

-- /wl craft <name or item link>: who can craft it, in the chat; alone: the Professions tab
W.slash.craft = function(rest)
    local search = SearchText(rest)
    if search == "" or not db then
        if not W.IsShown("Guild") then W.Toggle("Guild") end
        if UI.tabs then UI.tabs:Select(2) end
        return
    end
    local found = G.FindCrafters(search, "")
    local shown = (rest or ""):match("%[(.-)%]") or (rest or ""):match("^%s*(.-)%s*$")
    if #found == 0 then W.Print(string.format(L("Nobody has a recipe named \"%s\" (only members who have the addon and opened their professions)."), shown)); return end
    W.Print(string.format(L("Who can craft \"%s\":"), shown))
    for i, r in ipairs(found) do
        if i > 8 then W.Print(string.format(L("... and %d more: see Guild > Professions."), #found - 8)); break end
        W.Print("  " .. RecipeName(r.id) .. " (" .. r.prof .. "): " .. CrafterNames(r.names))
    end
end
