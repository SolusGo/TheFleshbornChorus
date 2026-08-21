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

local function FB_Signed(value)
    value = tonumber(value) or 0
    return (value >= 0 and "+" or "") .. tostring(value)
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
    local usable = math.max(0, net)
    local spent = cityStatus.foodSpent or 0
    local remaining = math.max(0, usable - spent)
    local netText = FB_Signed(net)

    table.insert(lines, FB_Color(cityStatus.name .. "  //  POP " .. tostring(cityStatus.population) .. "  //  " .. string.upper(mode), "[COLOR_YIELD_FOOD]"))
    table.insert(lines, string.format(
        "  Budget:  base %+d [ICON_FOOD]  +  queued %d  -  metabolism %d  -  army %d  =  %s usable",
        cityStatus.grossFood or 0,
        cityStatus.injectedFood or 0,
        cityStatus.metabolicBurden or 0,
        cityStatus.armyBurden or 0,
        netText
    ))
    if (cityStatus.foundingCoreFood or 0) > 0 then
        table.insert(lines, string.format(
            "  [COLOR_POSITIVE_TEXT]Founding Core: +%d [ICON_FOOD] is already included in base surplus[ENDCOLOR]",
            cityStatus.foundingCoreFood
        ))
    end

    if cityStatus.orderKind == "UNIT" or cityStatus.orderKind == "BUILDING" or cityStatus.orderKind == "PROJECT" then
        local efficiency = cityStatus.digestive and "  [COLOR_POSITIVE_TEXT]Digestive Chamber -10%[ENDCOLOR]" or ""
        table.insert(lines, string.format(
            "  Project: %d/%d progress  //  about %d [ICON_FOOD] total%s",
            cityStatus.projectProgress or 0,
            cityStatus.projectNeeded or 0,
            cityStatus.foodCost or 0,
            efficiency
        ))
        table.insert(lines, string.format(
            "  This turn: %d [ICON_FOOD] spent -> %d progress  //  %d [ICON_FOOD] remains%s",
            spent,
            cityStatus.productionGain or 0,
            remaining,
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
        table.insert(lines, string.format(
            "  Population growth: %d/%d stored  //  %d [ICON_FOOD] available this turn",
            cityStatus.storedFood or 0,
            cityStatus.growthNeeded or 0,
            remaining
        ))
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
            growthNeeded = city:GrowthThreshold(),
            grossFood = city:FoodDifference(),
            injectedFood = 0,
            foundingCoreFood = city:IsCapital() and 4 or 0,
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


local function FB_Aggregate(status)
    local totals = {
        baseSurplus = status.baseSurplus or 0,
        queuedFood = status.queuedFood or 0,
        metabolicBurden = status.metabolicBurden or 0,
        armyBurden = status.armyBurden or 0,
        projectSpend = status.projectSpend or 0,
        usableFood = status.usableFood or 0,
        availableFood = status.availableFood or 0,
        storedFood = status.storedFood or 0,
        strainedCities = status.strainedCities or 0
    }
    if status.baseSurplus ~= nil then return totals end

    for _, cityStatus in ipairs(status.cities or {}) do
        local usable = math.max(0, cityStatus.netFood or 0)
        totals.baseSurplus = totals.baseSurplus + (cityStatus.grossFood or 0)
        totals.queuedFood = totals.queuedFood + (cityStatus.injectedFood or 0)
        totals.metabolicBurden = totals.metabolicBurden + (cityStatus.metabolicBurden or 0)
        totals.armyBurden = totals.armyBurden + (cityStatus.armyBurden or 0)
        totals.projectSpend = totals.projectSpend + (cityStatus.foodSpent or 0)
        totals.usableFood = totals.usableFood + usable
        totals.availableFood = totals.availableFood + math.max(0, usable - (cityStatus.foodSpent or 0))
        totals.storedFood = totals.storedFood + (cityStatus.storedFood or 0)
        if (cityStatus.netFood or 0) < 0 then totals.strainedCities = totals.strainedCities + 1 end
    end
    return totals
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
    local totals = FB_Aggregate(status)
    local armyDemand = status.armyDemand or 0
    local armyFed = status.armyFed or 0
    local unmetArmy = math.max(0, armyDemand - armyFed)

    Controls.AvailableFoodLabel:SetText(FB_Color(FB_Signed(totals.availableFood) .. " [ICON_FOOD]", totals.availableFood > 0 and "[COLOR_POSITIVE_TEXT]" or "[COLOR_WARNING_TEXT]"))
    Controls.BaseSurplusLabel:SetText(FB_Signed(totals.baseSurplus) .. " [ICON_FOOD]")
    Controls.QueuedFoodLabel:SetText(FB_Signed(totals.queuedFood) .. " [ICON_FOOD]")
    Controls.MetabolismCostLabel:SetText("-" .. tostring(totals.metabolicBurden) .. " [ICON_FOOD]")
    Controls.ArmyBudgetLabel:SetText(tostring(armyFed) .. " / " .. tostring(armyDemand))
    Controls.ProjectSpendLabel:SetText("-" .. tostring(totals.projectSpend) .. " [ICON_FOOD]")
    Controls.BudgetEquationLabel:SetText(string.format(
        "%d [ICON_FOOD] usable after fixed costs  -  %d spent on projects  =  %s [ICON_FOOD] available",
        totals.usableFood,
        totals.projectSpend,
        FB_Signed(totals.availableFood)
    ))

    if hungerTier <= 0 then
        Controls.MetabolismButtonLabel:SetText("[ICON_FOOD] " .. FB_Signed(totals.availableFood) .. " AVAILABLE")
    else
        Controls.MetabolismButtonLabel:SetText("[ICON_FOOD] HUNGER " .. tostring(hungerTier))
    end

    local riskParts = {}
    if unmetArmy > 0 then
        table.insert(riskParts, FB_Color("Army shortfall: " .. tostring(unmetArmy) .. " Food // Hunger tier " .. tostring(hungerTier), "[COLOR_NEGATIVE_TEXT]"))
    else
        table.insert(riskParts, FB_Color("Army fully fed", "[COLOR_POSITIVE_TEXT]"))
    end
    if totals.strainedCities > 0 then
        table.insert(riskParts, FB_Color(tostring(totals.strainedCities) .. " Brood Node(s) have a negative local budget", "[COLOR_WARNING_TEXT]"))
    else
        table.insert(riskParts, "no Brood Nodes are locally strained")
    end
    if (status.currencyFood or 0) > 0 then
        table.insert(riskParts, tostring(status.currencyFood) .. " Food digested from Gold/Faith")
    end
    Controls.RiskLabel:SetText(table.concat(riskParts, "  //  "))

    local cityBlocks = {}
    for _, cityStatus in ipairs(status.cities or {}) do
        table.insert(cityBlocks, FB_FormatCity(cityStatus))
    end
    if #cityBlocks == 0 then
        table.insert(cityBlocks, "No living Brood Nodes remain.")
    end

    Controls.CityStatusLabel:SetText(table.concat(cityBlocks, "[NEWLINE][NEWLINE]------------------------------------------------------------[NEWLINE][NEWLINE]"))
    Controls.CityScrollPanel:CalculateInternalSize()
    Controls.FooterLabel:SetText(
        "Stored population growth: " .. tostring(totals.storedFood) .. " Food  //  4 Gold = 1 Food  //  3 Faith = 1 Food"
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
