---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

-- WoW Forever: the health of an enemy can be secret in a battleground. The bar takes secret values
-- (SetMinMaxValues / SetValue accept them), the text uses the secret-safe paths (SetFormattedText,
-- UnitHealthPercent, UnitHealthMissing). The heal prediction / absorb overlay is gone: Blizzard's
-- CompactUnitFrame_UpdateHealPrediction does arithmetic on those values and fails from addon code.

local HealthTextTypes = {
	health = COMPACT_UNIT_FRAME_PROFILE_HEALTHTEXT_HEALTH,
	losthealth = COMPACT_UNIT_FRAME_PROFILE_HEALTHTEXT_LOSTHEALTH,
	perc = COMPACT_UNIT_FRAME_PROFILE_HEALTHTEXT_PERC
}

local generalDefaults = {
	Background = {0, 0, 0, 0.66},
}

local defaultSettings = {
	Parent = "Button",
	Enabled = true,
	HealthTextEnabled = false,
	HealthTextType = "health",
	HealthText = {
		FontSize = 17,
		JustifyH = "CENTER",
		JustifyV = "TOP",
	},
	ActivePoints = 2,
	Points = {
		{
			Point = "BOTTOMLEFT",
			RelativeFrame = "Power",
			RelativePoint = "TOPLEFT",
		},
		{
			Point = "TOPRIGHT",
			RelativeFrame = "Button",
			RelativePoint = "TOPRIGHT",
		}
	}
}

local healthBar = WarLegendPvP:NewButtonModule({
	moduleName = "healthBar",
	localizedModuleName = L.HealthBar,
	defaultSettings = defaultSettings,
	generalDefaults = generalDefaults,
	events = {"UpdateHealth"},
	flags = {FixedPosition = true},
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})


function healthBar:AttachToPlayerButton(playerButton)
	playerButton.healthBar = CreateFrame('StatusBar', nil, playerButton)
	playerButton.healthBar:SetMinMaxValues(0, 1)

	playerButton.healthBar.HealthText = WarLegendPvP.MyCreateFontString(playerButton.healthBar)
	playerButton.healthBar.HealthText:SetPoint("BOTTOMLEFT", playerButton.healthBar, "BOTTOMLEFT", 3, 3)
	playerButton.healthBar.HealthText:SetPoint("TOPRIGHT", playerButton.healthBar, "TOPRIGHT", -3, -3)

	playerButton.healthBar.Background = playerButton.healthBar:CreateTexture(nil, 'BACKGROUND', nil, 2)
	playerButton.healthBar.Background:SetAllPoints()
	playerButton.healthBar.Background:SetTexture("Interface/Buttons/WHITE8X8")

	-- secret values: only handed to the font string, never compared or computed. Same calls as
	-- EllesmereUI's raid frames (EUI_RaidFrames_Update.lua): AbbreviateNumbers / SetFormattedText("%s"),
	-- UnitHealthMissing(unit, true), UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
	local function formatSecretNumber(value)
		if AbbreviateNumbers then return AbbreviateNumbers(value) end
		return value
	end

	local function updateSecretHealthText(self, unitID, health)
		local config = self.config
		if config.HealthTextType == "health" then
			self.HealthText:SetFormattedText("%s", formatSecretNumber(health))
			self.HealthText:Show()
		elseif config.HealthTextType == "losthealth" and unitID and UnitHealthMissing then
			self.HealthText:SetFormattedText("-%s", formatSecretNumber(UnitHealthMissing(unitID, true)))
			self.HealthText:Show()
		elseif config.HealthTextType == "perc" and unitID and UnitHealthPercent and CurveConstants then
			self.HealthText:SetFormattedText("%.0f%%", UnitHealthPercent(unitID, true, CurveConstants.ScaleTo100))
			self.HealthText:Show()
		else
			self.HealthText:Hide()
		end
	end

	playerButton.healthBar.UpdateHealthText = function(self, health, maxHealth, unitID)
		local config = self.config
		if not config or not config.HealthTextEnabled then return end
		if issecret(health) or issecret(maxHealth) then
			return updateSecretHealthText(self, unitID, health)
		end
		if health and maxHealth then
			if config.HealthTextType == "health" then
				self.HealthText:SetText(AbbreviateLargeNumbers(health))
				self.HealthText:Show()
			elseif config.HealthTextType == "losthealth" then
				local healthLost = maxHealth - health
				if healthLost > 0 then
					self.HealthText:SetText("-" .. AbbreviateLargeNumbers(healthLost))
					self.HealthText:Show()
				else
					self.HealthText:Hide()
				end
			elseif config.HealthTextType == "perc" and maxHealth > 0 then
				self.HealthText:SetFormattedText("%d%%", math.ceil(100 * (health / maxHealth)))
				self.HealthText:Show()
			else
				self.HealthText:Hide()
			end
		else
			self.HealthText:Hide()
		end
	end

	function playerButton.healthBar:UpdateHealth(unitID, health, maxHealth)
		self:SetMinMaxValues(0, maxHealth)
		self:SetValue(health)
		self:UpdateHealthText(health, maxHealth, unitID)
	end

	function playerButton.healthBar:ApplyAllSettings()
		if not self.config then return end
		local config = self.config
		self:SetStatusBarTexture(WarLegendPvP:GetBarTexture("health", playerButton.PlayerType))
		self.Background:SetVertexColor(unpack(config.Background))
		if config.HealthTextEnabled then
			self.HealthText:Show()
		else
			self.HealthText:Hide()
		end

		self.HealthText:ApplyFontStringSettings(config.HealthText)
		local playerDetails = playerButton.PlayerDetails
		if not playerDetails then return end
		-- WarLegend: class color, or the side's single color (Main.lua GetBarColor)
		self:SetStatusBarColor(WarLegendPvP:GetBarColor(playerButton))
		self:SetMinMaxValues(0, 1)
		self:SetValue(1)
		self:UpdateHealthText(false, false)
		-- WarLegend: keep the grey of an out of range player (PlayerButton.lua)
		if playerButton.ApplyRangeDesaturation then playerButton:ApplyRangeDesaturation() end
	end
	return playerButton.healthBar
end
