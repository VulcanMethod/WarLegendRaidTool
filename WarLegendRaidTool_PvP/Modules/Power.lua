---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

local PowerBarColor = PowerBarColor --table
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local math_random = math.random

local generalDefaults = {
	Background = {0, 0, 0, 0.66},
	OnlyShowForHealers = false
}

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	Height = 5,
	ActivePoints = 2,
	Points = {
		{
			Point = "BOTTOMLEFT",
			RelativeFrame = "Button",
			RelativePoint = "BOTTOMLEFT",
		},
		{
			Point = "BOTTOMRIGHT",
			RelativeFrame = "Button",
			RelativePoint = "BOTTOMRIGHT",
		}
	}
}



local flags = {
	SetZeroHeightWhenDisabled = true,
	FixedPosition = true
}

local power = WarLegendPvP:NewButtonModule({
	moduleName = "Power",
	localizedModuleName = L.PowerBar,
	flags = flags,
	defaultSettings = defaultSettings,
	generalDefaults = generalDefaults,
	events = {"UnitIdUpdate", "UpdatePower"},
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

function power:AttachToPlayerButton(playerButton)
	playerButton.Power = CreateFrame('StatusBar', nil, playerButton)
	playerButton.Power:SetMinMaxValues(0, 1)
	playerButton.Power.maxValue = 1


	--playerButton.Power.Background = playerButton.Power:CreateTexture(nil, 'BACKGROUND', nil, 2)
	playerButton.Power.Background = playerButton.Power:CreateTexture(nil, 'BACKGROUND', nil, 2)
	playerButton.Power.Background:SetAllPoints()
	playerButton.Power.Background:SetTexture("Interface/Buttons/WHITE8X8")


	function playerButton.Power:UpdateMinMaxValues(max)
		if max and issecret(max) then
			self:SetMinMaxValues(0, max)
			self.maxValue = nil
			return
		end
		if max and max ~= self.maxValue then
			self:SetMinMaxValues(0, max)
			self.maxValue = max
		end
	end

	function playerButton.Power:CheckForNewPowerColor(powerToken)
		--self:Debug("CheckForNewPowerColor", powerToken)

		if self.powerToken ~= powerToken then
			local color = PowerBarColor[powerToken]
			if color then
				self:SetStatusBarColor(color.r, color.g, color.b)
				self.powerToken = powerToken
			end
		end
	end

	function playerButton.Power:UnitIdUpdate(unitID)
		if unitID then
			local powerType, powerToken, altR, altG, altB = UnitPowerType(unitID)

			self:CheckForNewPowerColor(powerToken)
			self:UpdatePower(unitID)
		end
	end


	function playerButton.Power:UpdatePower(unitID)
		--self:Debug("UpdatePower", unitID, powerToken)
		if unitID then
			self:UpdateMinMaxValues(UnitPowerMax(unitID))
			self:SetValue(UnitPower(unitID))
		else
			--for testmode
			self:SetValue(math_random(0, 100)/100)
		end
	end


	function playerButton.Power:ApplyAllSettings()
		if not self.config then return end
		-- power
		self:SetHeight(self.config.Height or 0.01)

		self:SetStatusBarTexture(WarLegendPvP:GetBarTexture("power"))
		self.Background:SetVertexColor(unpack(self.config.Background))
		local playerDetails = playerButton.PlayerDetails
		if not playerDetails then return end
		if not playerDetails.PlayerClass then return end
		if not playerDetails.PlayerRole then return end

		if playerDetails.PlayerRole == "HEALER" or not self.config.OnlyShowForHealers then
			self:SetHeight(self.config.Height or 0.01)
		else
			self:SetHeight(0.01)
		end

		local powerToken

		local t = Data.Classes[playerDetails.PlayerClass]
		if t then
			if playerDetails.PlayerSpecName then
				t = t[playerDetails.PlayerSpecName]
			end
		end
		if t then powerToken = t.Ressource end


		self:CheckForNewPowerColor(powerToken)
	end
	return playerButton.Power
end