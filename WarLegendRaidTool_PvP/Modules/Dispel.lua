
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)

-- WarLegend: on the ally frames, what I can do for each player with my class.
--  * a debuff I can dispel: the frame border takes the dispel type color, and the debuff icon is shown
--    (filter "HARMFUL|RAID" = debuffs the player can remove; checked again with my class when readable)
--  * the buffs of my class (Fortitude, Mark of the Wild, Arcane Intellect, Blessings...): the icon is shown
--    when the player has it, greyed when it is missing (only for the long buffs, and Intellect / Spirit
--    only on mana users)
-- WoW Forever can keep auras secret in a battleground: an aura the client refuses is never read nor shown,
-- and a missing buff is only shown when every buff of the player was readable.

local W = WLRT
W.AddFR({
	["Dispels and my buffs (allies)"] = "Dissipations et mes buffs (alliés)",
})

local CreateFrame = CreateFrame
local GetTime = GetTime

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	UseButtonHeightAsHeight = true,
	Width = 1,
	ActivePoints = 1,
	Points = {
		{
			Point = "LEFT",
			RelativeFrame = "Button",
			RelativePoint = "RIGHT",
			OffsetX = 2
		}
	}
}

local dispel = WarLegendPvP:NewButtonModule({
	moduleName = "Dispel",
	localizedModuleName = W.L("Dispels and my buffs (allies)"),
	defaultSettings = defaultSettings,
	events = { "UnitIdUpdate", "PlayerButtonSizeChanged", "OnTestmodeEnabled", "OnTestmodeDisabled", "OnTestmodeTick" },
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

---------------------------------------------------------------------------
-- My class
---------------------------------------------------------------------------
-- dispel types each class removes (Classic spells; a warlock needs his Felhunter, the filter knows it)
local CLASS_DISPELS = {
	PRIEST = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	DRUID = { Curse = true, Poison = true },
	MAGE = { Curse = true },
	SHAMAN = { Poison = true, Disease = true },
	WARLOCK = { Magic = true },
}

-- buffs each class gives: spell IDs of one buff family (single and group versions), missing = show it greyed
-- when the player does not have it, mana = only on mana users
local CLASS_BUFFS = {
	PRIEST = {
		{ ids = { 1243, 21562 }, missing = true },               -- Power Word / Prayer of Fortitude
		{ ids = { 14752, 27681 }, missing = true, mana = true }, -- Divine Spirit / Prayer of Spirit
		{ ids = { 976, 27683 } },                                -- Shadow Protection / Prayer of Shadow Protection
		{ ids = { 6346 } },                                      -- Fear Ward
	},
	MAGE = {
		{ ids = { 1459, 23028 }, missing = true, mana = true },  -- Arcane Intellect / Arcane Brilliance
	},
	DRUID = {
		{ ids = { 1126, 21849 }, missing = true },               -- Mark / Gift of the Wild
		{ ids = { 467 } },                                       -- Thorns
	},
	PALADIN = {
		{ ids = { 19740, 25782 } }, -- Blessing of Might / Greater
		{ ids = { 19742, 25894 } }, -- Wisdom
		{ ids = { 20217, 25898 } }, -- Kings
		{ ids = { 1038, 25895 } },  -- Salvation
		{ ids = { 19977, 25890 } }, -- Light
		{ ids = { 20911, 25899 } }, -- Sanctuary
	},
}

-- click to dispel (like Decursive): mouse button 2 (right) = first list, 3 (middle) = second list; the first
-- spell I know of each list (highest version first)
local CLASS_DISPEL_SPELLS = {
	PRIEST = { [2] = { 527 }, [3] = { 552, 528 } },          -- Dispel Magic / Abolish, Cure Disease
	PALADIN = { [2] = { 4987, 1152 }, [3] = { 1152 } },      -- Cleanse (or Purify) / Purify
	DRUID = { [2] = { 2782 }, [3] = { 2893, 8946 } },        -- Remove Curse / Abolish, Cure Poison
	MAGE = { [2] = { 475 } },                                -- Remove Lesser Curse
	SHAMAN = { [2] = { 526 }, [3] = { 2870 } },              -- Cure Poison / Cure Disease
}

local DISPEL_COLOR = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
	Unknown = { 1, 0.5, 0 }, -- dispellable, but its type is kept secret
}

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture and GetSpellTexture(id)
end

local function Knows(id)
	if IsPlayerSpell then return IsPlayerSpell(id) end
	if IsSpellKnown then return IsSpellKnown(id) end
	return true
end

-- my buff families, built once: { names = { [name] = true }, icon, missing, mana }
local myBuffs, myDispels
local function MyClass()
	if myBuffs then return myBuffs, myDispels end
	local class = W.UnitClassToken("player")
	myDispels = CLASS_DISPELS[class] or {}
	myBuffs = {}
	for _, fam in ipairs(CLASS_BUFFS[class] or {}) do
		local names, known = {}, false
		for _, id in ipairs(fam.ids) do
			local n = W.SpellName(id)
			if n then names[n] = true end
			if Knows(id) then known = true end
		end
		local icon = SpellIcon(fam.ids[1])
		if known and icon and next(names) then
			myBuffs[#myBuffs + 1] = { names = names, icon = icon, missing = fam.missing, mana = fam.mana }
		end
	end
	return myBuffs, myDispels
end

-- name of the dispel spell for a mouse button (2 right, 3 middle), nil when I have none
function WarLegendPvP.GetDispelSpell(mouseButton)
	local list = (CLASS_DISPEL_SPELLS[W.UnitClassToken("player")] or {})[mouseButton]
	for _, id in ipairs(list or {}) do
		if Knows(id) then
			local name = W.SpellName(id)
			if name then return name end
		end
	end
end

---------------------------------------------------------------------------
-- Reading one unit (secret-safe: W.AuraByIndex gives false for an aura the client refuses)
---------------------------------------------------------------------------
local MAX_DEBUFFS = 4

-- missingOnly: the client's aura container already shows the debuffs and my buffs, only the missing ones
local function ReadUnit(unit, missingOnly)
	local buffs, dispels = MyClass()
	-- an aura the client keeps secret is skipped (never shown as "?"); a run of secret ones stops the scan
	local debuffs, border, secretRun = {}, nil, 0
	for i = 1, missingOnly and 0 or 40 do
		local a = W.AuraByIndex(unit, i, "HARMFUL|RAID")
		if a == nil then break end
		if a == false then
			secretRun = secretRun + 1
			if secretRun >= 8 then break end
		else
			secretRun = 0
			local icon, dtype = W.Safe(a.icon), W.Safe(a.dispelName)
			if icon and (not dtype or dispels[dtype]) then -- type unreadable: the filter said I can remove it
				local color = DISPEL_COLOR[dtype or "Unknown"] or DISPEL_COLOR.Unknown
				border = border or color
				if #debuffs < MAX_DEBUFFS then debuffs[#debuffs + 1] = { icon = icon, color = color } end
			end
		end
	end
	local have, allReadable = {}, true
	if #buffs > 0 then
		secretRun = 0
		for i = 1, 40 do
			local a = W.AuraByIndex(unit, i, "HELPFUL")
			if a == nil then break end
			local name = a and W.Safe(a.name)
			if not name then
				allReadable = false
				secretRun = secretRun + 1
				if secretRun >= 8 then break end
			else
				secretRun = 0
				for f, fam in ipairs(buffs) do
					if fam.names[name] then have[f] = true end
				end
			end
		end
	end
	local power = W.Safe(UnitPowerType(unit))
	local shown = {}
	for f, fam in ipairs(buffs) do
		if have[f] then
			if not missingOnly then shown[#shown + 1] = { icon = fam.icon } end
		elseif fam.missing and allReadable and not (fam.mana and power ~= 0) then
			shown[#shown + 1] = { icon = fam.icon, grey = true }
		end
	end
	return debuffs, shown, border
end

---------------------------------------------------------------------------
-- Frames on each ally button
---------------------------------------------------------------------------
function dispel:AttachToPlayerButton(playerButton)
	local f = CreateFrame("Frame", nil, playerButton)
	f.icons = {}
	playerButton.Dispel = f

	-- border around the whole button, in the dispel color
	local glow = CreateFrame("Frame", nil, playerButton, BackdropTemplateMixin and "BackdropTemplate")
	glow:SetPoint("TOPLEFT", playerButton, "TOPLEFT", -2, 2)
	glow:SetPoint("BOTTOMRIGHT", playerButton, "BOTTOMRIGHT", 2, -2)
	glow:SetFrameLevel(playerButton:GetFrameLevel() + 10)
	glow:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 2 })
	glow:Hide()
	f.glow = glow

	-- the client's aura container (secret-safe): dispellable debuffs (icon border + frame border in the
	-- dispel type color) then my buffs on the player; the missing buffs go on the left of the frame
	local NA = WarLegendPvP.NativeAuras
	if not playerButton.PlayerIsEnemy and NA and NA.Available() then
		f.native = NA.Create(f, {
			{ key = "dispel", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", max = MAX_DEBUFFS, size = 18, dispelBorder = true, frameGlow = true },
			{ key = "mine", filter = "HELPFUL|PLAYER", max = 4, size = 18 },
		}, playerButton)
		if f.native then
			f.left = CreateFrame("Frame", nil, playerButton)
			f.left:SetPoint("RIGHT", playerButton, "LEFT", -2, 0)
			f.left:SetSize(1, 18)
		end
	end

	local function Icon(i)
		local b = f.icons[i]
		if b then return b end
		b = CreateFrame("Frame", nil, f.left or f, BackdropTemplateMixin and "BackdropTemplate")
		b:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetPoint("TOPLEFT", 1, -1)
		b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
		b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		f.icons[i] = b
		return b
	end

	function f:Show_(debuffs, buffs, border)
		local size = math.max(10, (playerButton:GetHeight() or 20) - 4)
		local n = 0
		local function put(e, r, g, b, grey)
			n = n + 1
			local ic = Icon(n)
			ic:SetSize(size, size)
			ic:ClearAllPoints()
			if f.left then -- grows to the left of the frame
				ic:SetPoint("RIGHT", f.left, "RIGHT", -(n - 1) * (size + 2), 0)
			else
				ic:SetPoint("LEFT", f, "LEFT", (n - 1) * (size + 2), 0)
			end
			ic.tex:SetTexture(e.icon)
			ic.tex:SetDesaturated(grey and true or false)
			ic:SetAlpha(grey and 0.45 or 1)
			ic:SetBackdropBorderColor(r, g, b, 1)
			ic:Show()
		end
		for _, d in ipairs(debuffs) do put(d, d.color[1], d.color[2], d.color[3]) end
		for _, b in ipairs(buffs) do put(b, 0, 0, 0, b.grey) end
		for i = n + 1, #f.icons do f.icons[i]:Hide() end
		self:SetWidth(f.native and 8 * 20 or math.max(1, n * (size + 2)))
		if border then
			glow:SetBackdropBorderColor(border[1], border[2], border[3], 1)
			glow:Show()
		else
			glow:Hide()
		end
	end

	function f:Clear()
		for i = 1, #f.icons do f.icons[i]:Hide() end
		glow:Hide()
		if f.native then NA.SetUnit(f.native, nil) end
	end

	function f:Update()
		self.pending = false
		if not self.Enabled or playerButton.PlayerIsEnemy or self.testmode then return end
		local unit = playerButton:GetUnitID()
		if not unit or not UnitExists(unit) then return self:Clear() end
		if f.native then
			if f.nativeUnit ~= unit or not f.native:IsShown() then
				f.nativeUnit = unit
				NA.SetUnit(f.native, unit)
			end
			local ok, _, missing = pcall(ReadUnit, unit, true)
			self:Show_({}, ok and missing or {}, nil)
			return
		end
		local ok, debuffs, buffs, border = pcall(ReadUnit, unit)
		if not ok then return self:Clear() end
		self:Show_(debuffs, buffs, border)
	end

	-- UNIT_AURA can fire many times in a row: one read per button every 0.2 s at most
	function f:Schedule()
		if self.pending then return end
		self.pending = true
		C_Timer.After(0.2, function() f:Update() end)
	end

	function f:UnitIdUpdate() self:Schedule() end
	function f:PlayerButtonSizeChanged() self:Schedule() end

	function f:OnTestmodeEnabled()
		self.testmode = true
		if f.native then NA.SetUnit(f.native, nil); f.nativeUnit = nil end
	end
	function f:OnTestmodeDisabled() self.testmode = false; self:Clear(); f.nativeUnit = nil end
	function f:OnTestmodeTick()
		self.testmode = true
		if playerButton.PlayerIsEnemy then return end
		local buffs = MyClass()
		local shown = {}
		for _, fam in ipairs(buffs) do shown[#shown + 1] = { icon = fam.icon, grey = math.random(1, 2) == 1 } end
		if math.random(1, 3) == 1 then
			local types = { "Magic", "Curse", "Disease", "Poison" }
			local c = DISPEL_COLOR[types[math.random(1, 4)]]
			self:Show_({ { icon = 136118, color = c } }, shown, c)
		else
			self:Show_({}, shown, nil)
		end
	end

	function f:Disable() self:Clear() end

	function f:ApplyAllSettings()
		if not self.config then return end
		if playerButton.PlayerIsEnemy then self:Clear(); return end
		self:Schedule()
	end

	return f
end

-- one listener for every ally button
local auraFrame = CreateFrame("Frame")
auraFrame:RegisterEvent("UNIT_AURA")
auraFrame:SetScript("OnEvent", function(_, _, unit)
	if type(unit) ~= "string" or not (unit:find("^raid%d") or unit:find("^party%d") or unit == "player") then return end
	if not WarLegendPvP.states or not WarLegendPvP.states.real or not WarLegendPvP.states.real.isInBattleground then return end
	local ok, btn = pcall(WarLegendPvP.GetPlayerbuttonByUnitID, WarLegendPvP, unit)
	if ok and btn and not btn.PlayerIsEnemy and btn.Dispel and btn.Dispel.Enabled then btn.Dispel:Schedule() end
end)
