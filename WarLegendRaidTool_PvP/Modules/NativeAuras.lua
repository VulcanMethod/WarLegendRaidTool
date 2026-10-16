
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

-- WarLegend: Blizzard's aura container (CreateFrame("AuraContainer"), WoW Forever / 12.1 aura system, as used by
-- BetterBlizzFrames and MiniAuras for Forever). The client itself finds, filters ("HARMFUL|RAID_PLAYER_DISPELLABLE",
-- "HARMFUL|CROWD_CONTROL"...), sorts and draws the auras, also those it keeps secret from addons: nothing is read
-- here. NA.Available() is false on a client without it, the modules then use their old way.

local NA = {}
WarLegendPvP.NativeAuras = NA

local available
function NA.Available()
	if available ~= nil then return available end
	available = false
	if AuraContainerSortMethod and AuraContainerSortDirection then
		local ok, test = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		if ok and test and test.AddAuraGroup and test.SetUnit then
			available = true
			test:Hide()
		end
	end
	return available
end

local function Try(obj, method, ...)
	if obj and obj[method] then return pcall(obj[method], obj, ...) end
end

-- the dispel type textures (border of each icon, and an optional texture around the whole unit frame)
local function AddDispelTexture(button, texture)
	local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	if not (styles and button.AddDispelTypeTexture) then return end
	pcall(button.AddDispelTypeTexture, button, texture, {
		style = styles.Border,
		showWhenHarmful = true,
		showWhenHelpful = false,
		showWithoutDispelType = false,
	})
end

local function InitButton(button, group, glowParent)
	local size = (group.sizeFn and group.sizeFn()) or group.size or 20
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Try(button, "SetIcon", icon)
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(not group.timer)
	Try(cooldown, "SetMinimumCountdownDuration", 0)
	Try(cooldown, "SetUsingParentLevel", true)
	Try(button, "SetDurationCooldown", cooldown)
	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
	Try(button, "SetApplicationCount", count)
	if group.dispelBorder then
		local border = button:CreateTexture(nil, "OVERLAY")
		border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
		AddDispelTexture(button, border)
	end
	if group.frameGlow and glowParent then
		-- colored by the client with the dispel type, drawn around the whole unit frame
		local glow = glowParent:CreateTexture(nil, "OVERLAY")
		glow:SetPoint("TOPLEFT", glowParent, "TOPLEFT", -3, 3)
		glow:SetPoint("BOTTOMRIGHT", glowParent, "BOTTOMRIGHT", 3, -3)
		AddDispelTexture(button, glow)
	end
	if Try(button, "SetMouseMotionEnabled", false) == nil then button:EnableMouse(false) end
end

-- groups: { { key, filter, max, size, timer, dispelBorder, frameGlow }, ... } shown left to right
-- glowParent: the frame a "frameGlow" group colors (the unit frame)
function NA.Create(parent, groups, glowParent)
	if not NA.Available() then return nil end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if not ok or not container then return nil end
	container:SetSize(1, 1)
	container:SetPoint("LEFT", parent, "LEFT")
	if AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection then
		Try(container, "SetFlowLayoutAxis", AnchorUtil.FlowLayoutAxis.Horizontal)
		Try(container, "SetFlowLayoutAnchorPoint", "LEFT")
		Try(container, "SetFlowLayoutGrowthDirection", AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
		Try(container, "SetFlowLayoutPadding", 0, 0, 0, 0)
	end
	for _, g in ipairs(groups) do
		local added = pcall(container.AddAuraGroup, container, g.key, g.filter, {
			maxFrameCount = 0,
			sortMethod = AuraContainerSortMethod.ExpirationOnly,
			sortDirection = AuraContainerSortDirection.Reverse,
			layout = { elementSpacing = 2, lineSpacing = 2 },
			initializeFrame = function(button) InitButton(button, g, glowParent) end,
		})
		if added then Try(container, "SetAuraGroupMaxFrameCount", g.key, g.max or 4) end
	end
	Try(container, "SetEnabled", false)
	container:Hide()
	return container
end

-- unit nil: hidden
function NA.SetUnit(container, unit)
	if not container then return end
	if unit and UnitExists(unit) then
		Try(container, "SetUnit", unit)
		Try(container, "SetEnabled", true)
		container:Show()
		Try(container, "UpdateAllAuras")
	else
		Try(container, "SetEnabled", false)
		container:Hide()
	end
end
