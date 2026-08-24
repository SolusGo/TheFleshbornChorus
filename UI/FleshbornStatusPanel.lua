-- The Fleshborn Chorus - metabolism status panel

print("FleshbornStatusPanel.lua loaded")

local CIV_FLESHBORN = GameInfoTypes.CIVILIZATION_FLESHBORN_CHORUS
local panelOpen = false

local function FB_IsActivePlayerFleshborn()
    local playerID = Game.GetActivePlayer()
    if playerID == nil or playerID < 0 then return false end
    local player = Players[playerID]
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

local function FB_Percent(current, required)
    current = math.max(0, tonumber(current) or 0)
    required = math.max(0, tonumber(required) or 0)
    if required <= 0 then return 100 end
    return math.max(0, math.min(100, math.floor((current * 100) / required)))
end

local function FB_EstimateTurns(remaining, rate)
    remaining = math.max(0, tonumber(remaining) or 0)
    rate = math.max(0, tonumber(rate) or 0)
    if remaining <= 0 then return "ready" end
    if rate <= 0 then return "stalled" end
    return "about " .. tostring(math.ceil(remaining / rate)) .. " turns"
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
    local nodeState = "FED"
    local nodeColor = "[COLOR_POSITIVE_TEXT]"
    if net < 0 then
        nodeState = "DEFICIT"
        nodeColor = "[COLOR_NEGATIVE_TEXT]"
    elseif spent > 0 and remaining <= 0 then
        nodeState = "FULLY COMMITTED"
        nodeColor = "[COLOR_WARNING_TEXT]"
    elseif remaining <= 0 then
        nodeState = "NO FREE FOOD"
        nodeColor = "[COLOR_WARNING_TEXT]"
    end

    table.insert(lines,
        FB_Color(cityStatus.name .. "  //  POP " .. tostring(cityStatus.population), "[COLOR_YIELD_FOOD]")
        .. "  //  " .. FB_Color(nodeState, nodeColor)
    )
    table.insert(lines, string.format(
        "  Flow: %s base  +  %d added  -  %d metabolism  -  %d army  =  %s [ICON_FOOD] usable",
        FB_Signed(cityStatus.grossFood or 0),
        cityStatus.injectedFood or 0,
        cityStatus.metabolicBurden or 0,
        cityStatus.armyBurden or 0,
        netText
    ))
    if (cityStatus.foundingCoreFood or 0) > 0 then
        table.insert(lines, string.format(
            "  [COLOR_POSITIVE_TEXT]Founding Core +%d [ICON_FOOD] is already included in base[ENDCOLOR]",
            cityStatus.foundingCoreFood
        ))
    end
    if (cityStatus.consumptionHarvestFood or 0) > 0 then
        table.insert(lines, string.format(
            "  [COLOR_POSITIVE_TEXT]Consumption Harvest +%d [ICON_FOOD] routed here[ENDCOLOR]",
            cityStatus.consumptionHarvestFood
        ))
    end
    if (cityStatus.consumptionSourceFood or 0) > 0 then
        table.insert(lines, string.format(
            "  [COLOR_WARNING_TEXT]CONSUMING CITY // +%d [ICON_FOOD] routed to the nearest surviving Brood Node[ENDCOLOR]",
            cityStatus.consumptionSourceFood
        ))
    end
    if cityStatus.neuralCluster then
        table.insert(lines, string.format(
            "  [COLOR_CYAN]Neural Cluster: %d [ICON_FOOD] population feeding -> +%d [ICON_RESEARCH] Science[ENDCOLOR]",
            cityStatus.neuralFoodConsumed or 0,
            cityStatus.neuralScience or 0
        ))
    end

    if cityStatus.orderKind == "UNIT" or cityStatus.orderKind == "BUILDING" or cityStatus.orderKind == "PROJECT" then
        local needed = math.max(0, cityStatus.projectNeeded or 0)
        local progress = math.max(0, cityStatus.projectProgress or 0)
        local percent = FB_Percent(progress, needed)
        local eta = FB_EstimateTurns(needed - progress, cityStatus.productionGain or 0)
        local efficiency = cityStatus.digestive
            and " // [COLOR_POSITIVE_TEXT]Digestive Chamber -10% Food cost[ENDCOLOR]" or ""
        table.insert(lines, string.format(
            "  Mode: %s  //  %d/%d progress (%d%%)  //  %s%s",
            string.upper(mode),
            progress,
            needed,
            percent,
            eta,
            efficiency
        ))
        table.insert(lines, string.format(
            "  Allocation: %d [ICON_FOOD] -> %d progress  //  %d [ICON_FOOD] free%s",
            spent,
            cityStatus.productionGain or 0,
            remaining,
            (cityStatus.pendingFood or 0) > 0
                and ("  //  " .. tostring(cityStatus.pendingFood) .. " Food queued") or ""
        ))
    elseif cityStatus.orderKind == "LEAGUE" then
        table.insert(lines, "  Mode: " .. string.upper(mode) .. "  //  1 Food becomes 1 Congress contribution")
        table.insert(lines, string.format(
            "  Allocation: %d [ICON_FOOD] -> %d contribution  //  %d [ICON_FOOD] free",
            cityStatus.foodSpent or 0,
            cityStatus.productionGain or 0,
            remaining
        ))
    else
        local growthNeeded = math.max(0, cityStatus.growthNeeded or 0)
        local storedFood = math.max(0, cityStatus.storedFood or 0)
        local eta = FB_EstimateTurns(growthNeeded - storedFood, remaining)
        table.insert(lines, string.format(
            "  Mode: GROW POPULATION  //  %d/%d stored  //  %d [ICON_FOOD] this turn  //  %s",
            storedFood,
            growthNeeded,
            remaining,
            eta
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
            consumptionHarvestFood = 0,
            consumptionSourceFood = 0,
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
            digestive = false,
            neuralCluster = false,
            neuralScience = 0,
            neuralFoodConsumed = 0
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
    if not FB_IsActivePlayerFleshborn() then
        Controls.MetabolismButton:SetHide(true)
        Controls.MetabolismPanel:SetHide(true)
        panelOpen = false
        return
    end

    local player = Players[playerID]
    Controls.MetabolismButton:SetHide(false)
    local status = MapModData.FleshbornStatus and MapModData.FleshbornStatus[playerID]
    if status == nil then status = FB_LiveFallback(player) end

    local hungerTier = status.hungerTier or 0
    local totals = FB_Aggregate(status)
    local armyDemand = status.armyDemand or 0
    local armyFed = status.armyFed or 0
    local unmetArmy = math.max(0, armyDemand - armyFed)
    local armyCoverage = FB_Percent(armyFed, armyDemand)
    local hungerPenalty = math.max(0, hungerTier * 3)
    local incomeTotal = totals.baseSurplus + totals.queuedFood
    local fixedCosts = totals.metabolicBurden + totals.armyBurden
    local cityCount = #(status.cities or {})
    local projectNodes = 0
    for _, cityStatus in ipairs(status.cities or {}) do
        if cityStatus.orderKind ~= "GROWTH" then projectNodes = projectNodes + 1 end
    end

    local turn = status.turn or Game.GetGameTurn()
    Controls.TurnLabel:SetText("TURN " .. tostring(turn))
    Controls.IncomeTotalLabel:SetText(FB_Color(
        FB_Signed(incomeTotal) .. " [ICON_FOOD]",
        incomeTotal > 0 and "[COLOR_POSITIVE_TEXT]" or "[COLOR_WARNING_TEXT]"
    ))
    Controls.IncomeBreakdownLabel:SetText(
        "Base " .. FB_Signed(totals.baseSurplus)
        .. " // Added " .. FB_Signed(totals.queuedFood)
    )
    Controls.FixedCostTotalLabel:SetText(FB_Color(
        "-" .. tostring(fixedCosts) .. " [ICON_FOOD]",
        fixedCosts > 0 and "[COLOR_WARNING_TEXT]" or "[COLOR_POSITIVE_TEXT]"
    ))
    Controls.FixedBreakdownLabel:SetText(
        "Cities -" .. tostring(totals.metabolicBurden)
        .. " // Army -" .. tostring(totals.armyBurden)
    )
    Controls.ProjectSpendLabel:SetText(
        "-" .. tostring(totals.projectSpend) .. " [ICON_FOOD]"
    )
    Controls.ProjectDetailLabel:SetText(
        tostring(projectNodes) .. (projectNodes == 1 and " node allocating" or " nodes allocating")
    )
    Controls.AvailableFoodLabel:SetText(FB_Color(
        FB_Signed(totals.availableFood) .. " [ICON_FOOD]",
        totals.availableFood > 0 and "[COLOR_POSITIVE_TEXT]" or "[COLOR_WARNING_TEXT]"
    ))
    Controls.AvailableDetailLabel:SetText(
        totals.availableFood > 0 and "Uncommitted this turn" or "No Food remains free"
    )
    Controls.BudgetEquationLabel:SetText(string.format(
        "%d [ICON_FOOD] usable after local fixed costs  -  %d project allocation  =  %s [ICON_FOOD] free",
        totals.usableFood,
        totals.projectSpend,
        FB_Signed(totals.availableFood)
    ))

    local empireState = "FED"
    local empireColor = "[COLOR_POSITIVE_TEXT]"
    local stateDetail = tostring(totals.availableFood)
        .. " Food remains after current growth and project decisions."
    if hungerTier > 0 then
        empireState = "HUNGRY"
        empireColor = "[COLOR_NEGATIVE_TEXT]"
        stateDetail = "The army lacks " .. tostring(unmetArmy) .. " Food. Military bioforms suffer -"
            .. tostring(hungerPenalty) .. "% Combat Strength until feeding recovers."
    elseif totals.strainedCities > 0 then
        empireState = "STRAINED"
        empireColor = "[COLOR_WARNING_TEXT]"
        stateDetail = tostring(totals.strainedCities)
            .. (totals.strainedCities == 1 and " Brood Node has" or " Brood Nodes have")
            .. " a negative local Food budget. Inspect the ledger below."
    elseif totals.availableFood <= 0 and totals.projectSpend > 0 then
        empireState = "FULLY COMMITTED"
        empireColor = "[COLOR_WARNING_TEXT]"
        stateDetail = "Every usable Food is committed to current projects; none remains for population growth."
    elseif totals.availableFood <= 0 then
        empireState = "BALANCED"
        empireColor = "[COLOR_WARNING_TEXT]"
        stateDetail = "The organism is meeting fixed costs, but no Food remains for additional growth."
    end
    Controls.StateLabel:SetText(FB_Color(empireState, empireColor))
    Controls.StateDetailLabel:SetText(stateDetail)

    if hungerTier > 0 then
        Controls.MetabolismButtonLabel:SetText(
            "[ICON_FOOD] HUNGER " .. tostring(hungerTier) .. " // -" .. tostring(hungerPenalty) .. "%"
        )
    elseif totals.strainedCities > 0 then
        Controls.MetabolismButtonLabel:SetText(
            "[ICON_FOOD] " .. tostring(totals.strainedCities) .. " STRAINED // "
            .. FB_Signed(totals.availableFood) .. " FREE"
        )
    else
        local buttonState = empireState == "FULLY COMMITTED" and "COMMITTED" or empireState
        Controls.MetabolismButtonLabel:SetText(
            "[ICON_FOOD] " .. FB_Signed(totals.availableFood) .. " FREE // " .. buttonState
        )
    end
    Controls.MetabolismButton:SetToolTipString(
        empireState .. "[NEWLINE]"
        .. tostring(totals.availableFood) .. " Food free after current commitments.[NEWLINE]"
        .. tostring(armyFed) .. " of " .. tostring(armyDemand) .. " army Food supplied.[NEWLINE][NEWLINE]"
        .. "Click to open the metabolism ledger."
    )

    local riskParts = {}
    if armyDemand <= 0 then
        Controls.ArmyStateLabel:SetText(FB_Color("NO ARMY BURDEN", "[COLOR_POSITIVE_TEXT]"))
    elseif unmetArmy > 0 then
        Controls.ArmyStateLabel:SetText(FB_Color(
            "HUNGER TIER " .. tostring(hungerTier),
            "[COLOR_NEGATIVE_TEXT]"
        ))
    else
        Controls.ArmyStateLabel:SetText(FB_Color("FULLY FED", "[COLOR_POSITIVE_TEXT]"))
    end
    Controls.ArmyBudgetLabel:SetText(
        tostring(armyFed) .. " FED / " .. tostring(armyDemand)
        .. " REQUIRED // " .. tostring(armyCoverage) .. "%"
    )
    if hungerPenalty > 0 then
        Controls.HungerPenaltyLabel:SetText(FB_Color(
            "-" .. tostring(hungerPenalty) .. "% COMBAT STRENGTH",
            "[COLOR_NEGATIVE_TEXT]"
        ))
    else
        Controls.HungerPenaltyLabel:SetText(FB_Color(
            "NO COMBAT PENALTY",
            "[COLOR_POSITIVE_TEXT]"
        ))
    end

    if totals.strainedCities > 0 then
        table.insert(riskParts, FB_Color(
            tostring(totals.strainedCities) .. " local node deficit",
            "[COLOR_WARNING_TEXT]"
        ))
    else
        table.insert(riskParts, "No local node deficits")
    end
    if (status.currencyFood or 0) > 0 then
        table.insert(riskParts, tostring(status.currencyFood) .. " Food digested from currency")
    end
    if (status.consumptionHarvestFood or 0) > 0 then
        table.insert(riskParts,
            tostring(status.consumptionHarvestFood) .. " Food harvested from consumed cities"
        )
    end
    if (status.maintenanceSuppressed or 0) > 0 then
        table.insert(riskParts, tostring(status.maintenanceSuppressed) .. " Gold upkeep suppressed")
    end
    Controls.RiskLabel:SetText(table.concat(riskParts, " // "))

    local cityBlocks = {}
    for _, cityStatus in ipairs(status.cities or {}) do
        table.insert(cityBlocks, FB_FormatCity(cityStatus))
    end
    if #cityBlocks == 0 then
        table.insert(cityBlocks, "No living Brood Nodes remain.")
    end

    Controls.CityStatusLabel:SetText(table.concat(cityBlocks, "[NEWLINE][NEWLINE]------------------------------------------------------------[NEWLINE][NEWLINE]"))
    Controls.CityScrollPanel:CalculateInternalSize()
    Controls.CitySummaryLabel:SetText(
        "BROOD NODES // " .. tostring(cityCount)
        .. (cityCount == 1 and " CITY" or " CITIES")
        .. " // " .. tostring(totals.strainedCities) .. " STRAINED"
        .. " // " .. tostring(totals.storedFood) .. " [ICON_FOOD] STORED GROWTH"
    )
    Controls.FooterLabel:SetText(
        "4 Gold = 1 Food // 3 Faith = 1 Food // Snapshot shows this turn's completed allocations"
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
