---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
---@type string
local AddonName = ...

-- Loaded on demand by WarLegendRaidTool (PvP.lua), usually after the login: PLAYER_LOGIN and the
-- PLAYER_ENTERING_WORLD of the battleground already happened, so run them once now. Not while the files
-- run: the saved settings (WarLegendRaidTool_PvPDB) are only there at this addon's ADDON_LOADED, which
-- LoadAddOn fires before it returns.
if IsLoggedIn() then
	local starter = CreateFrame("Frame")
	starter:RegisterEvent("ADDON_LOADED")
	starter:SetScript("OnEvent", function(self, _, name)
		if name ~= AddonName then return end
		self:UnregisterEvent("ADDON_LOADED")
		WarLegendPvP:PLAYER_LOGIN()
		WarLegendPvP:PLAYER_ENTERING_WORLD()
	end)
end
