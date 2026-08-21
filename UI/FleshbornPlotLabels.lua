-- ============================================================================
-- The Fleshborn Chorus
-- Context-sensitive labels for stock map improvements used as art carriers
-- ============================================================================

print("FleshbornPlotLabels.lua loaded")

local CIV_FLESHBORN = GameInfoTypes.CIVILIZATION_FLESHBORN_CHORUS
local IMPROVEMENT_FARM = GameInfoTypes.IMPROVEMENT_FARM
local FARM_NAME = Locale.ConvertTextKey("TXT_KEY_IMPROVEMENT_FARM")
local FEEDING_FIELD_NAME = Locale.ConvertTextKey("TXT_KEY_IMPROVEMENT_FLESHBORN_FEEDING_FIELD")
local IMPROVEMENT_PREFIX = "[COLOR_POSITIVE_TEXT]"
    .. Locale.ConvertTextKey("TXT_KEY_IMPROVEMENT")
    .. "[ENDCOLOR] : "

local tipControls = {}
TTManager:GetTypeControlTable("HexDetails", tipControls)

local currentPlot = nil

local function EscapePattern(value)
    return string.gsub(value, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local FARM_LABEL_PATTERN = EscapePattern(IMPROVEMENT_PREFIX .. FARM_NAME)
local FEEDING_FIELD_LABEL = IMPROVEMENT_PREFIX .. FEEDING_FIELD_NAME

local function IsFleshbornFeedingField(plot)
    if plot == nil or IMPROVEMENT_FARM == nil
        or plot:GetImprovementType() ~= IMPROVEMENT_FARM then
        return false
    end

    local ownerID = plot:GetOwner()
    if ownerID == nil or ownerID < 0 then return false end
    local owner = Players[ownerID]
    return owner ~= nil
        and owner:IsAlive()
        and CIV_FLESHBORN ~= nil
        and owner:GetCivilizationType() == CIV_FLESHBORN
end

local function OnMouseOverHex(x, y)
    currentPlot = Map.GetPlot(x, y)
end
Events.SerialEventMouseOverHex.Add(OnMouseOverHex)

local function OnUpdate()
    -- PlotHelpManager owns the tooltip and can refresh it at either delay
    -- level.  Reading the shared HexDetails control each frame lets this small
    -- compatibility layer run after either refresh without replacing CP UI.
    if not IsFleshbornFeedingField(currentPlot)
        or tipControls.Text == nil then
        return
    end

    local text = tipControls.Text:GetText()
    if text == nil or text == ""
        or not string.find(text, FARM_LABEL_PATTERN) then
        return
    end

    local replaced, replacements = string.gsub(
        text,
        FARM_LABEL_PATTERN,
        function() return FEEDING_FIELD_LABEL end
    )
    if replacements > 0 and replaced ~= text then
        tipControls.Text:SetText(replaced)
        if tipControls.Grid ~= nil then tipControls.Grid:DoAutoSize() end
    end
end
ContextPtr:SetUpdate(OnUpdate)
