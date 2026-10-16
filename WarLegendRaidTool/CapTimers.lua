-- WarLegend RaidTool - Base capture timers
-- Capping's Arathi Basin logic for any battleground with bases (Darkspear Island...): the map points of
-- interest change icon when a base is assaulted ("contested" icons), a bar then counts down the capture
-- time in the color of the team taking it. Same look as the Capping bars. Battlegrounds Capping already
-- covers (Arathi Basin, Alterac Valley) are left to it when it is loaded.
-- Cost: nothing outside battlegrounds; in one, the map is read when the game says it changed.
local W = WLRT
W.AddFR({
    ["Capture timers"] = "Chronos de capture",
    ["Show base capture timers in battlegrounds"] = "Afficher les chronos de capture des bases en champ de bataille",
    ["Lock the bars"] = "Verrouiller les barres",
    ["Capture time:"] = "Temps de capture :",
    ["%d s"] = "%d s",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["Map points now"] = "Points de la carte maintenant",
    ["When a base is assaulted (its map icon turns contested), a bar counts down until it is taken. Arathi Basin and Alterac Valley are left to Capping when it is installed. If a battleground shows no bar, open \"Map points now\" during an assault and send the text."] =
        "Quand une base est attaquée (son icône sur la carte passe en contesté), une barre compte jusqu'à la prise. Arathi et Alterac sont laissés à Capping s'il est installé. Si un champ de bataille n'affiche rien, ouvre « Points de la carte maintenant » pendant une attaque et envoie le texte.",
    ["Not in a battleground."] = "Pas en champ de bataille.",
})
local L = W.L
local db

-- contested icons (POI texture index) -> team taking the base; from Capping (Core.lua iconDataConflict)
local CONTESTED = {
    [3] = "Alliance", [13] = "Horde",   -- graveyard
    [8] = "Alliance", [11] = "Horde",   -- tower
    [17] = "Alliance", [19] = "Horde",  -- mine / stone
    [22] = "Alliance", [24] = "Horde",  -- lumber / wood
    [27] = "Alliance", [29] = "Horde",  -- blacksmith / anvil
    [32] = "Alliance", [34] = "Horde",  -- farm / house
    [37] = "Alliance", [39] = "Horde",  -- stables / horse
}
local TEAM_COLOR = { Alliance = { 0, 0, 1 }, Horde = { 1, 0, 0 } } -- Capping's colorAlliance / colorHorde
local CAPPING_ZONES = { [529] = true, [30] = true }            -- Arathi Basin, Alterac Valley (instance IDs)
local POI_ICONS = 136441                                       -- Interface/Minimap/POIIcons

local CAP_TEXTURE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
local CAP_W, CAP_H, CAP_FONT_SIZE = 200, 20, 10

W.OnReady(function()
    db = W.DB("capTimers", { enabled = true, locked = false, capTime = 60 })
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -150 } end
end)

---------------------------------------------------------------------------
-- Bars (the Capping look, as the graveyard timer)
---------------------------------------------------------------------------
local anchor
local bars, active = {}, {} -- active: [poi name] = { bar, ends, team }

local function Place()
    local p = db.point
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function NewBar()
    local f = CreateFrame("Frame", nil, anchor)
    f:SetSize(CAP_W, CAP_H)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(CAP_H, CAP_H)
    f.icon:SetPoint("LEFT")
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT")
    f.bar:SetPoint("BOTTOMRIGHT")
    f.bar:SetStatusBarTexture(CAP_TEXTURE)
    local bg = f.bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(CAP_TEXTURE)
    bg:SetVertexColor(0, 0, 0, 0.75)
    f.time = f.bar:CreateFontString(nil, "OVERLAY")
    f.time:SetFont(W.FONT, CAP_FONT_SIZE, "")
    f.time:SetShadowOffset(1, -1)
    f.time:SetTextColor(1, 1, 1)
    f.time:SetPoint("RIGHT", -2, 0)
    f.text = f.bar:CreateFontString(nil, "OVERLAY")
    W.SetFont(f.text, W.FONT, CAP_FONT_SIZE, "")
    f.text:SetShadowOffset(1, -1)
    f.text:SetTextColor(1, 1, 1)
    f.text:SetPoint("LEFT", 2, 0)
    f.text:SetPoint("RIGHT", f.time, "LEFT", -2, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    return f
end

local function Layout()
    local list = {}
    for name, a in pairs(active) do list[#list + 1] = a; a.name = name end
    table.sort(list, function(x, y) return x.ends < y.ends end)
    for i, a in ipairs(list) do
        a.bar:ClearAllPoints()
        a.bar:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * CAP_H)
    end
    anchor:SetHeight(math.max(CAP_H, #list * CAP_H))
    anchor:SetShown(#list > 0 or anchor.unlockedShow)
end

local function StopBar(name)
    local a = active[name]
    if not a then return end
    a.bar:Hide()
    bars[#bars + 1] = a.bar
    active[name] = nil
    Layout()
end

local function StopAll()
    for name in pairs(active) do StopBar(name) end
end

local function StartBar(name, secs, team, poiIcon)
    StopBar(name)
    local bar = table.remove(bars) or NewBar()
    local c = TEAM_COLOR[team] or { 1, 1, 0 }
    bar.bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.bar:SetMinMaxValues(0, secs)
    bar.text:SetText(name)
    bar.icon:SetTexture(POI_ICONS)
    if poiIcon and GetPOITextureCoords then
        local l, r, t, b = GetPOITextureCoords(poiIcon)
        if l then bar.icon:SetTexCoord(l, r, t, b) end
    end
    bar:Show()
    active[name] = { bar = bar, ends = GetTime() + secs, team = team }
    Layout()
end

local acc = 0
local function OnUpdate(_, e)
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    local now = GetTime()
    for name, a in pairs(active) do
        local left = a.ends - now
        if left <= 0 then
            StopBar(name)
        else
            a.bar.bar:SetValue(left)
            if left < 10 then a.bar.time:SetFormattedText("%.1f", left)
            elseif left >= 60 then a.bar.time:SetFormattedText("%d:%02d", math.floor(left / 60), left % 60)
            else a.bar.time:SetFormattedText("%d", left) end
        end
    end
end

local function CreateAnchor()
    if anchor then return end
    anchor = CreateFrame("Frame", "WLRTCapTimersAnchor", UIParent)
    anchor:SetSize(CAP_W, CAP_H)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    anchor:SetScript("OnUpdate", OnUpdate)
    anchor:Hide()
    Place()
end

---------------------------------------------------------------------------
-- Map points of interest
---------------------------------------------------------------------------
local mapID, lastIcon = nil, {}

local function POIs()
    local out = {}
    if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return out end
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(mapID) or {}) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
        if info then
            out[#out + 1] = { name = W.Safe(info.name), icon = W.Safe(info.textureIndex), atlas = W.Safe(info.atlasName), id = id }
        end
    end
    return out
end

-- first look: remember the icons without starting bars (an assault already running is not timed)
local function Snapshot()
    wipe(lastIcon)
    for _, p in ipairs(POIs()) do
        if p.name then lastIcon[p.name] = p.icon or p.atlas end
    end
end

local function POIsUpdated()
    for _, p in ipairs(POIs()) do
        local key = p.icon or p.atlas
        if p.name and key and lastIcon[p.name] ~= key then
            lastIcon[p.name] = key
            local team = p.icon and CONTESTED[p.icon]
            if team then
                StartBar(p.name, db.capTime or 60, team, p.icon)
            else
                StopBar(p.name) -- taken, or defended
            end
        end
    end
end

local poiEv = W.On("AREA_POIS_UPDATED", POIsUpdated, nil, true)

local function InstanceID()
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if kind ~= "pvp" then return nil end
    return W.Safe(id)
end

local function CappingLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Capping")
end

local function Zone()
    local id = db and db.enabled and InstanceID()
    local on = id and not (CAPPING_ZONES[id] and CappingLoaded())
    W.Activate(poiEv, on and true or false)
    if anchor then StopAll() end
    if not on then mapID = nil; return end
    CreateAnchor()
    mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
    Snapshot()
end
W.On("PLAYER_ENTERING_WORLD", Zone)
W.On("ZONE_CHANGED_NEW_AREA", Zone)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function MapDump()
    if not InstanceID() then W.Print(L("Not in a battleground.")); return end
    if not mapID then mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player")) end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    local lines = { "instance " .. tostring(W.Safe(id)) .. " " .. tostring(W.Safe(name)) .. ", uiMap " .. tostring(mapID) }
    for _, p in ipairs(POIs()) do
        lines[#lines + 1] = tostring(p.name) .. "  icon=" .. tostring(p.icon) .. "  atlas=" .. tostring(p.atlas) .. "  poi=" .. tostring(p.id)
    end
    W.TextPopup(L("Map points now"), table.concat(lines, "\n"), { hint = "Ctrl+C" })
end

W.RegisterModule("CapTimers", L("Capture timers"), function(p)
    W.Title(p, L("Capture timers"))
    W.Check(p, L("Show base capture timers in battlegrounds"), function() return db.enabled end,
        function(v) db.enabled = v; Zone() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Lock the bars"), function() return db.locked end, function(v) db.locked = v end):SetPoint("TOPLEFT", 12, -66)
    W.Label(p, L("Capture time:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -102)
    local times = {}
    for _, s in ipairs({ 30, 45, 60, 64, 90, 120, 240 }) do times[#times + 1] = { s, string.format(L("%d s"), s) } end
    W.Cycle(p, 80, times, function() return db.capTime end, function(v) db.capTime = v end):SetPoint("TOPLEFT", 130, -97)
    W.Button(p, L("Test"), 110, 22, function()
        CreateAnchor()
        StartBar("Test Alliance", db.capTime or 60, "Alliance", 3)
        StartBar("Test Horde", math.floor((db.capTime or 60) / 2), "Horde", 13)
    end):SetPoint("TOPLEFT", 16, -130)
    W.Button(p, L("Reset position"), 160, 22, function()
        db.point = { "TOP", "TOP", 0, -150 }
        if anchor then Place() end
    end):SetPoint("TOPLEFT", 132, -130)
    W.Button(p, L("Map points now"), 200, 22, MapDump):SetPoint("TOPLEFT", 298, -130)
    local info = W.Label(p, L("When a base is assaulted (its map icon turns contested), a bar counts down until it is taken. Arathi Basin and Alterac Valley are left to Capping when it is installed. If a battleground shows no bar, open \"Map points now\" during an assault and send the text."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -170)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)

W.slash.caps = function() W.Toggle("CapTimers") end
