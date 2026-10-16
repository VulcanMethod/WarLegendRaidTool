-- WarLegend RaidTool - Duel timer
-- A big countdown in the middle of the screen for duels: 3, 2, 1 before the start (the game's "Duel starting: %d"
-- system messages, DUEL_COUNTDOWN in the client's language), then "Fight!", and the 10 seconds left to come
-- back when out of the duel area (DUEL_OUTOFBOUNDS / DUEL_INBOUNDS). Cost: one text match per system message.
local W = WLRT
W.AddFR({
    ["Duel timer"] = "Chrono de duel",
    ["Show a big countdown for duels"] = "Afficher un gros compte à rebours pour les duels",
    ["Play a sound on each second"] = "Jouer un son à chaque seconde",
    ["Lock the countdown"] = "Verrouiller le compte à rebours",
    ["Size:"] = "Taille :",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["Duel"] = "Duel",
    ["Voice countdown (3, 2, 1...)"] = "Décompte vocal (3, 2, 1...)",
    ["Fight!"] = "Combat !",
    ["Out of the duel area"] = "Hors de la zone de duel",
    ["3, 2, 1 before a duel starts, then \"Fight!\"; and the 10 seconds left to come back when you leave the duel area."] =
        "3, 2, 1 avant le début d'un duel, puis « Combat ! » ; et les 10 secondes pour revenir quand tu sors de la zone de duel.",
})
local L = W.L
local db

local OUT_OF_BOUNDS = 10 -- seconds the game gives to come back

W.OnReady(function()
    db = W.DB("duelTimer", { enabled = true, sound = true, voice = true, locked = false, size = 72 })
    if type(db.point) ~= "table" then db.point = { "CENTER", "CENTER", 0, 160 } end
end)

-- "Duel starting: %d" -> a pattern catching the number, in the client's language
local countdownPattern
local function CountdownPattern()
    if countdownPattern ~= nil then return countdownPattern end
    countdownPattern = false
    if type(DUEL_COUNTDOWN) == "string" then
        -- every magic character escaped ("%" too), then the escaped "%%d" becomes the number capture
        -- (the same way as LootCouncil.lua's Pattern for the loot messages)
        local p = DUEL_COUNTDOWN:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%d", "(%%d+)")
        countdownPattern = "^" .. p
    end
    return countdownPattern
end

local frame
local function Place()
    local p = db.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Create()
    if frame then return end
    frame = CreateFrame("Frame", "WLRTDuelTimer", UIParent)
    frame:SetSize(260, 120)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    -- the number sits in an inner frame anchored at the center: W.Pulse makes it pop in place, as BigWigs
    frame.pulse = CreateFrame("Frame", nil, frame)
    frame.pulse:SetSize(1, 1)
    frame.pulse:SetPoint("CENTER", 0, 10)
    frame.big = frame.pulse:CreateFontString(nil, "OVERLAY")
    frame.big:SetPoint("CENTER")
    frame.sub = frame:CreateFontString(nil, "OVERLAY")
    W.SetFont(frame.sub, W.FONT, 16, "OUTLINE")
    frame.sub:SetPoint("TOP", frame.pulse, "CENTER", 0, -40)
    frame:Hide()
    Place()
end

local hideAt, boundsEnd, lastShown
local function Tick()
    if not frame:IsShown() then return end
    local now = GetTime()
    if boundsEnd then
        local left = math.ceil(boundsEnd - now)
        if left <= 0 then boundsEnd = nil; frame:Hide(); return end
        if left ~= lastShown then
            lastShown = left
            frame.big:SetText(left)
            W.Pulse(frame.pulse, 0.95)
            if db.voice and left <= 5 then
                W.CountdownVoice(left)
            elseif db.sound and SOUNDKIT then
                PlaySound(SOUNDKIT.RAID_WARNING, "Master")
            end
        end
    elseif hideAt and now >= hideAt then
        hideAt = nil
        frame:Hide()
    end
end

-- text, color, subtitle, seconds before it goes away (nil: until told)
local function Show(text, r, g, b, sub, duration)
    Create()
    W.SetFont(frame.big, W.FONT, db.size or 72, "OUTLINE")
    frame.big:SetText(text)
    frame.big:SetTextColor(r, g, b)
    frame.sub:SetText(sub or "")
    frame.sub:SetTextColor(r, g, b)
    hideAt = duration and (GetTime() + duration) or nil
    frame:SetScript("OnUpdate", Tick)
    frame:Show()
    W.Pulse(frame.pulse, duration or 0.95) -- the BigWigs "pop": large, settles, fades
end

local function Countdown(n)
    boundsEnd = nil
    Show(tostring(n), 1, 0.82, 0, L("Duel"), 1)
    if db.voice and n <= 5 then
        W.CountdownVoice(n)
    elseif db.sound and SOUNDKIT then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
    if n == 1 then
        W.After(1, function() Show(L("Fight!"), 0.2, 1, 0.2, nil, 1.2) end)
    end
end

W.On("CHAT_MSG_SYSTEM", function(text)
    if not db or not db.enabled then return end
    text = W.Safe(text)
    local pattern = CountdownPattern()
    if type(text) ~= "string" or not pattern then return end
    local n = tonumber(text:match(pattern))
    if n and n >= 1 and n <= 10 then Countdown(n) end
end)

W.On("DUEL_OUTOFBOUNDS", function()
    if not db or not db.enabled then return end
    boundsEnd, lastShown = GetTime() + OUT_OF_BOUNDS, nil
    Show(tostring(OUT_OF_BOUNDS), 1, 0.2, 0.2, L("Out of the duel area"))
end)
W.On("DUEL_INBOUNDS", function() if boundsEnd and frame then boundsEnd = nil; frame:Hide() end end)
W.On("DUEL_FINISHED", function() if frame then boundsEnd = nil; frame:Hide() end end)

W.RegisterModule("DuelTimer", L("Duel timer"), function(p)
    W.Title(p, L("Duel timer"))
    W.Check(p, L("Show a big countdown for duels"), function() return db.enabled end,
        function(v) db.enabled = v; if not v and frame then frame:Hide() end end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Play a sound on each second"), function() return db.sound end, function(v) db.sound = v end)
        :SetPoint("TOPLEFT", 32, -66)
    W.Check(p, L("Voice countdown (3, 2, 1...)"), function() return db.voice end, function(v) db.voice = v end)
        :SetPoint("TOPLEFT", 300, -66)
    W.Check(p, L("Lock the countdown"), function() return db.locked end, function(v) db.locked = v end)
        :SetPoint("TOPLEFT", 32, -90)
    W.Label(p, L("Size:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 36, -126)
    local sizes = {}
    for _, s in ipairs({ 48, 60, 72, 96, 120 }) do sizes[#sizes + 1] = { s, tostring(s) } end
    W.Cycle(p, 70, sizes, function() return db.size end, function(v) db.size = v end):SetPoint("TOPLEFT", 90, -121)
    W.Button(p, L("Test"), 110, 22, function()
        Countdown(3)
        W.After(1, function() Countdown(2) end)
        W.After(2, function() Countdown(1) end)
    end):SetPoint("TOPLEFT", 16, -160)
    W.Button(p, L("Reset position"), 160, 22, function()
        db.point = { "CENTER", "CENTER", 0, 160 }
        if frame then Place() end
    end):SetPoint("TOPLEFT", 132, -160)
    local info = W.Label(p, L("3, 2, 1 before a duel starts, then \"Fight!\"; and the 10 seconds left to come back when you leave the duel area."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -200)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)

W.slash.duel = function() W.Toggle("DuelTimer") end
