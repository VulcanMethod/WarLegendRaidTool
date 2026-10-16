---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

-- Loaded on demand by WarLegendRaidTool (PvP.lua), usually after the login: PLAYER_LOGIN and the
-- PLAYER_ENTERING_WORLD of the battleground already happened, so run them once now.
if IsLoggedIn() then
	WarLegendPvP:PLAYER_LOGIN()
	WarLegendPvP:PLAYER_ENTERING_WORLD()
end
