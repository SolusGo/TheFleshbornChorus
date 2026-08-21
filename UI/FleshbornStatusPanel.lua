-- The Fleshborn Chorus - metabolism status panel

print("FleshbornStatusPanel.lua loaded")

local CIV_FLESHBORN = GameInfoTypes.CIVILIZATION_FLESHBORN_CHORUS
local panelOpen = false

local function FB_IsActivePlayerFleshborn()
    local player = Players[Game.GetActivePlayer()]
    return player ~= nil
        and player:IsAlive()
        and CIV_FLESHBORN ~= nil
        and player:GetCivilizationType() == CIV_FLESHBORN
end

local function FB_Color(text, color)
    return color .. tostring(text or "") .. "[ENDCOLOR]"
end

local function FB_OrderName(cityStatus)
    if cityStatus.orderKind == "GROWTH" then
        return "Grow Population"
    elseif cityStatus.orderKind == "UNIT" then
        local row = GameInfo.Units[cityStatus.orderID]
        return row and Locale.ConvertTextKey(row.Description) or "Grow Unit"
    elseif cityStatus.orderKind == "BUILDING" then
        local row = GameInfo.Buildings[cityStatus.orderID]
        return row and Locale.ConvertTextKey(row.Description) or "Grow Building"
    elseif cityStatus.orderKind == "PROJECT" then
        local row = GameInfo.Projects[cityStatus.orderID]
        return row and Locale.ConvertTextKey(row.Description) or "Grow Project"
    elseif cityStatus.orderKind == "LEAGUE" then
        local row = GameInfo.Processes[cityStatus.orderID]
        return row and Locale.ConvertTextKey(row.Description) or "World Congress Project"
    end
    return "Grow Population"
end

local function FB_FormatCity(cityStatus)
    local lines = {}
    local mode = FB_OrderName(cityStatus)
    local net = cityStatus.netFood or 0
    local netText = (net >= 0 and "+" or "") .. tostring(net)

    table.insert(lines, FB_Color(cityStatus.name .. "  //  POP " .. tostring(cityStatus.population), "[COLOR_YIELD_FOOD]"))
    table.insert(lines, string.format(
        "  Gross %+d [ICON_FOOD]  +  queued %d  -  metabolism %d  -  army %d  =  %s usable",
        cityStatus.grossFood or 0,
        cityStatus.injectedFood or 0,
        cityStatus.metabolicBurden or 0,
        cityStatus.armyBurden or 0,
        netText
    ))

    if cityStatus.orderKind == "UNIT" or cityStatus.orderKind == "BUILDING" or cityStatus.orderKind == "PROJECT" then
        local efficiency = cityStatus.digestive and "  [COLOR_POSITIVE_TEXT]Digestive Chamber -10%[ENDCOLOR]" or ""
        table.insert(lines, string.format(
            "  Growing: %s  //  %d/%d progress  //  about %d [ICON_FOOD] total%s",
            mode,
            cityStatus.projectProgress or 0,
            cityStatus.projectNeeded or 0,
            cityStatus.foodCost or 0,
            efficiency
        ))
        table.insert(lines, string.format(
            "  Last allocation: %d [ICON_FOOD] -> %d progress%s",
            cityStatus.foodSpent or 0,
            cityStatus.productionGain or 0,
            (cityStatus.pendingFood or 0) > 0 and ("  //  " .. tostring(cityStatus.pendingFood) .. " Food waiting") or ""
        ))
    elseif cityStatus.orderKind == "LEAGUE" then
        table.insert(lines, "  Contributing to: " .. mode .. "  //  1 Food becomes 1 Congress contribution")
        table.insert(lines, string.format(
            "  Last allocation: %d [ICON_FOOD] -> %d contribution",
            cityStatus.foodSpent or 0,
            cityStatus.productionGain or 0
        ))
    else
        table.insert(lines, "  Mode: [COLOR_POSITIVE_TEXT]Grow Population[ENDCOLOR]  //  usable Food remains in the growth store")
    end

    return table.concat(lines, "[NEWLINE]")
end

local function FB_LiveFallback(player)
    local cities = {}
    for city in player:Cities() do
        table.insert(cities, {
            name = city:GetName(),
            population = city:GetPopulation(),
            storedFood = city:GetFood(),
            grossFood = city:FoodDifference(),
            injectedFood = 0,
            metabolicBurden = 3 + math.ceil(city:GetPopulation() * 0.5),
            armyBurden = 0,
            netFood = city:FoodDifference() - 3 - math.ceil(city:GetPopulation() * 0.5),
            pendingFood = 0,
            orderKind = "GROWTH",
            orderID = -1,
            foodSpent = 0,
            productionGain = 0,
            foodCost = 0,
            projectProgress = city:GetProduction(),
            projectNeeded = city:GetProductionNeeded(),
            digestive = false
        })
    end
    return {
        armyDemand = 0,
        armyFed = 0,
        hungerTier = 0,
        currencyFood = 0,
        maintenanceSuppressed = 0,
        cities = cities
    }
end

local function FB_Refresh()
    local playerID = Game.GetActivePlayer()
    local player = Players[playerID]
    if not FB_IsActivePlayerFleshborn() then
        Controls.MetabolismButton:SetHide(true)
        Controls.MetabolismPanel:SetHide(true)
        panelOpen = false
        return
    end

    Controls.MetabolismButton:SetHide(false)
    local status = MapModData.FleshbornStatus and MapModData.FleshbornStatus[playerID]
    if status == nil then status = FB_LiveFallback(player) end

    local hungerTier = status.hungerTier or 0
    Controls.ArmyDemandLabel:SetText(tostring(status.armyDemand or 0) .. " [ICON_FOOD]")
    Controls.ArmyFedLabel:SetText(tostring(status.armyFed or 0) .. " [ICON_FOOD]")
    Controls.DigestedLabel:SetText(tostring(status.currencyFood or 0) .. " [ICON_FOOD]")

    if hungerTier <= 0 then
        Controls.HungerLabel:SetText("[COLOR_POSITIVE_TEXT]FED[ENDCOLOR]")
        Controls.MetabolismButtonLabel:SetText("[ICON_FOOD] CHORUS FED")
    else
        Controls.HungerLabel:SetText("[COLOR_NEGATIVE_TEXT]TIER " .. tostring(hungerTier) .. "[ENDCOLOR]")
        Controls.MetabolismButtonLabel:SetText("[ICON_FOOD] HUNGER " .. tostring(hungerTier))
    end

    local cityBlocks = {}
    for _, cityStatus in ipairs(status.cities or {}) do
        table.insert(cityBlocks, FB_FormatCity(cityStatus))
    end
    if #cityBlocks == 0 then
        table.insert(cityBlocks, "No living Brood Nodes remain.")
    end

    Controls.CityStatusLabel:SetText(table.concat(cityBlocks, "[NEWLINE][NEWLINE]------------------------------------------------------------[NEWLINE][NEWLINE]"))
    Controls.CityStatusLabel:CalculateSize()
    Controls.CityScrollPanel:CalculateInternalSize()
    Controls.FooterLabel:SetText(
        "4 Gold = 1 Food  //  3 Faith = 1 Food  //  building maintenance clamped to 0"
    )
end

local function FB_SetPanelOpen(open)
    panelOpen = open == true and FB_IsActivePlayerFleshborn()
    Controls.MetabolismPanel:SetHide(not panelOpen)
    if panelOpen then FB_Refresh() end
end

Controls.MetabolismButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetPanelOpen(not panelOpen)
end)
Controls.CloseButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetPanelOpen(false)
end)
Controls.RefreshButton:RegisterCallback(Mouse.eLClick, FB_Refresh)

ContextPtr:SetInputHandler(function(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE and panelOpen then
        FB_SetPanelOpen(false)
        return true
    end
    return false
end)

if LuaEvents.FleshbornStatusUpdated ~= nil then
    LuaEvents.FleshbornStatusUpdated.Add(function(playerID)
        if playerID == Game.GetActivePlayer() then FB_Refresh() end
    end)
end
if Events.ActivePlayerTurnStart ~= nil then
    Events.ActivePlayerTurnStart.Add(FB_Refresh)
end
if Events.GameplaySetActivePlayer ~= nil then
    Events.GameplaySetActivePlayer.Add(function() FB_Refresh() end)
end
if Events.SerialEventGameDataDirty ~= nil then
    Events.SerialEventGameDataDirty.Add(function()
        if panelOpen then FB_Refresh() end
    end)
end

FB_Refresh()
