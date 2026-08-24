-- The Fleshborn Chorus - tabbed metabolism dashboard

include("IconSupport")

print("FleshbornStatusPanel.lua loaded")

local CIV_FLESHBORN = GameInfoTypes.CIVILIZATION_FLESHBORN_CHORUS
local PROCESS_GROWTH = GameInfoTypes.PROCESS_FLESHBORN_GROWTH
local panelOpen = false
local activeTab = "OVERVIEW"
local selectedCityID = nil
local cityDropdownEntries = {}
local FB_Refresh

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
    value = math.floor(tonumber(value) or 0)
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
    if remaining <= 0 then return "Completes now" end
    if rate <= 0 then return "Stalled: no free Food" end
    local turns = math.ceil(remaining / rate)
    return tostring(turns) .. (turns == 1 and " turn remaining" or " turns remaining")
end

local function FB_LiveOrder(city)
    local unitID = city:GetProductionUnit()
    if unitID ~= nil and unitID >= 0 then return "UNIT", unitID end
    local buildingID = city:GetProductionBuilding()
    if buildingID ~= nil and buildingID >= 0 then return "BUILDING", buildingID end
    local projectID = city:GetProductionProject()
    if projectID ~= nil and projectID >= 0 then return "PROJECT", projectID end
    local processID = city:GetProductionProcess()
    if processID ~= nil and processID >= 0 then
        if processID == PROCESS_GROWTH then return "GROWTH", processID end
        return "LEAGUE", processID
    end
    return "GROWTH", PROCESS_GROWTH or -1
end

local function FB_OrderRow(cityStatus)
    local kind = cityStatus.orderKind
    local id = cityStatus.orderID
    if kind == "UNIT" then
        return GameInfo.Units[id], "GROWING UNIT"
    elseif kind == "BUILDING" then
        return GameInfo.Buildings[id], "GROWING BUILDING"
    elseif kind == "PROJECT" then
        return GameInfo.Projects[id], "GROWING PROJECT"
    elseif kind == "LEAGUE" then
        return GameInfo.Processes[id], "WORLD CONGRESS CONTRIBUTION"
    end
    return GameInfo.Processes[id or PROCESS_GROWTH], "GROWING POPULATION"
end

local function FB_OrderName(cityStatus)
    if cityStatus.orderKind == "GROWTH" then return "Grow Population" end
    local row = FB_OrderRow(cityStatus)
    return row and Locale.ConvertTextKey(row.Description) or "Biological Growth"
end

local function FB_LiveFallback(player)
    local cities = {}
    for city in player:Cities() do
        local population = math.max(0, city:GetPopulation() or 0)
        local citizenConsumption = population * 2
        local grossFood = city:FoodDifference() or 0
        local baseFoodProduced = math.max(0, grossFood + citizenConsumption)
        local metabolicBurden = 3 + math.ceil(population * 0.5)
        local orderKind, orderID = FB_LiveOrder(city)
        local foodConsumed = citizenConsumption + metabolicBurden
        table.insert(cities, {
            id = city:GetID(),
            name = city:GetName(),
            population = population,
            storedFood = city:GetFood(),
            growthNeeded = city:GrowthThreshold(),
            grossFood = grossFood,
            injectedFood = 0,
            consumptionHarvestFood = 0,
            consumptionSourceFood = 0,
            foundingCoreFood = city:IsCapital() and 4 or 0,
            metabolicBurden = metabolicBurden,
            armyBurden = 0,
            netFood = grossFood - metabolicBurden,
            pendingFood = 0,
            orderKind = orderKind,
            orderID = orderID,
            foodSpent = 0,
            productionGain = 0,
            foodCost = 0,
            projectProgress = city:GetProduction(),
            projectNeeded = city:GetProductionNeeded(),
            digestive = false,
            neuralCluster = false,
            neuralScience = 0,
            neuralFoodConsumed = 0,
            baseFoodProduced = baseFoodProduced,
            foodProduced = baseFoodProduced,
            citizenConsumption = citizenConsumption,
            foodConsumed = foodConsumed,
            foodBalance = baseFoodProduced - foodConsumed
        })
    end
    return {
        turn = Game.GetGameTurn(),
        armyDemand = 0,
        armyFed = 0,
        hungerTier = 0,
        currencyFood = 0,
        consumptionHarvestFood = 0,
        maintenanceSuppressed = 0,
        cities = cities
    }
end

local function FB_Aggregate(status)
    local totals = {
        baseSurplus = 0,
        queuedFood = 0,
        metabolicBurden = 0,
        armyBurden = 0,
        projectSpend = 0,
        usableFood = 0,
        availableFood = 0,
        storedFood = 0,
        strainedCities = 0,
        baseFoodProduced = 0,
        citizenConsumption = 0,
        foodProduced = 0,
        foodConsumed = 0,
        foodBalance = 0
    }

    for _, cityStatus in ipairs(status.cities or {}) do
        local population = math.max(0, cityStatus.population or 0)
        local citizenConsumption = cityStatus.citizenConsumption or (population * 2)
        local baseFoodProduced = cityStatus.baseFoodProduced
            or math.max(0, (cityStatus.grossFood or 0) + citizenConsumption)
        local foodProduced = cityStatus.foodProduced
            or (baseFoodProduced + (cityStatus.injectedFood or 0))
        local foodConsumed = cityStatus.foodConsumed
            or (citizenConsumption
                + (cityStatus.metabolicBurden or 0)
                + (cityStatus.armyBurden or 0)
                + (cityStatus.foodSpent or 0))
        local usable = math.max(0, cityStatus.netFood or 0)

        totals.baseSurplus = totals.baseSurplus + (cityStatus.grossFood or 0)
        totals.queuedFood = totals.queuedFood + (cityStatus.injectedFood or 0)
        totals.metabolicBurden = totals.metabolicBurden + (cityStatus.metabolicBurden or 0)
        totals.armyBurden = totals.armyBurden + (cityStatus.armyBurden or 0)
        totals.projectSpend = totals.projectSpend + (cityStatus.foodSpent or 0)
        totals.usableFood = totals.usableFood + usable
        totals.availableFood = totals.availableFood
            + math.max(0, usable - (cityStatus.foodSpent or 0))
        totals.storedFood = totals.storedFood + (cityStatus.storedFood or 0)
        totals.baseFoodProduced = totals.baseFoodProduced + baseFoodProduced
        totals.citizenConsumption = totals.citizenConsumption + citizenConsumption
        totals.foodProduced = totals.foodProduced + foodProduced
        totals.foodConsumed = totals.foodConsumed + foodConsumed
        if (cityStatus.netFood or 0) < 0 then
            totals.strainedCities = totals.strainedCities + 1
        end
    end
    totals.foodBalance = totals.foodProduced - totals.foodConsumed
    return totals
end

local function FB_EmpireState(status, totals)
    local hungerTier = status.hungerTier or 0
    local unmetArmy = math.max(0, (status.armyDemand or 0) - (status.armyFed or 0))
    if hungerTier > 0 then
        return "HUNGRY", "[COLOR_NEGATIVE_TEXT]",
            "The army lacks " .. tostring(unmetArmy) .. " Food. Military bioforms suffer -"
                .. tostring(hungerTier * 3) .. "% Combat Strength until feeding recovers."
    elseif totals.strainedCities > 0 then
        return "STRAINED", "[COLOR_WARNING_TEXT]",
            tostring(totals.strainedCities)
                .. (totals.strainedCities == 1 and " Brood Node has" or " Brood Nodes have")
                .. " a local Food deficit. Inspect the Brood Nodes tab to find it."
    elseif totals.availableFood <= 0 and totals.projectSpend > 0 then
        return "FULLY COMMITTED", "[COLOR_WARNING_TEXT]",
            "Every usable Food is committed to current growth projects."
    elseif totals.availableFood <= 0 then
        return "BALANCED", "[COLOR_WARNING_TEXT]",
            "All fixed costs are being met, but no Food remains for additional growth."
    end
    return "FED", "[COLOR_POSITIVE_TEXT]",
        tostring(totals.availableFood) .. " Food remains free after current commitments."
end

local function FB_RefreshOverview(status, totals, empireState, empireColor, stateDetail)
    local armyDemand = status.armyDemand or 0
    local armyFed = status.armyFed or 0
    local hungerTier = status.hungerTier or 0
    local hungerPenalty = hungerTier * 3
    local armyCoverage = FB_Percent(armyFed, armyDemand)
    local addedFood = totals.foodProduced - totals.baseFoodProduced
    local projectNodes = 0
    for _, cityStatus in ipairs(status.cities or {}) do
        if cityStatus.orderKind ~= "GROWTH" then projectNodes = projectNodes + 1 end
    end

    Controls.OverviewProducedValue:SetText(FB_Color(
        FB_Signed(totals.foodProduced) .. " [ICON_FOOD]", "[COLOR_POSITIVE_TEXT]"))
    Controls.OverviewProducedDetail:SetText(
        "Cities " .. tostring(totals.baseFoodProduced) .. "   |   Added " .. tostring(addedFood))
    Controls.OverviewConsumedValue:SetText(FB_Color(
        "-" .. tostring(totals.foodConsumed) .. " [ICON_FOOD]", "[COLOR_WARNING_TEXT]"))
    Controls.OverviewConsumedDetail:SetText(
        "Citizens " .. tostring(totals.citizenConsumption)
        .. "   |   Metabolism " .. tostring(totals.metabolicBurden)
        .. "[NEWLINE]Army " .. tostring(totals.armyBurden)
        .. "   |   Projects " .. tostring(totals.projectSpend))

    local balanceColor = totals.foodBalance >= 0
        and "[COLOR_POSITIVE_TEXT]" or "[COLOR_NEGATIVE_TEXT]"
    Controls.OverviewNetValue:SetText(FB_Color(
        FB_Signed(totals.foodBalance) .. " [ICON_FOOD]", balanceColor))
    Controls.OverviewNetDetail:SetText(
        totals.availableFood > 0
            and (tostring(totals.availableFood) .. " Food is free to allocate")
            or "No Food remains free to allocate")

    Controls.OverviewStateValue:SetText(FB_Color(empireState, empireColor))
    Controls.OverviewStateDetail:SetText(stateDetail)

    if armyDemand <= 0 then
        Controls.ArmyStateLabel:SetText(FB_Color("NO ARMY BURDEN", "[COLOR_POSITIVE_TEXT]"))
    elseif armyFed < armyDemand then
        Controls.ArmyStateLabel:SetText(FB_Color(
            "HUNGER TIER " .. tostring(hungerTier), "[COLOR_NEGATIVE_TEXT]"))
    else
        Controls.ArmyStateLabel:SetText(FB_Color("FULLY FED", "[COLOR_POSITIVE_TEXT]"))
    end
    Controls.ArmyBudgetLabel:SetText(
        tostring(armyFed) .. " FED / " .. tostring(armyDemand)
        .. " REQUIRED   |   " .. tostring(armyCoverage) .. "%")
    Controls.ArmyCoverageFill:SetSizeX(math.max(1, math.floor(508 * armyCoverage / 100)))
    Controls.ArmyCoverageLabel:SetText(tostring(armyCoverage) .. "% SUPPLIED")
    Controls.HungerPenaltyLabel:SetText(hungerPenalty > 0
        and FB_Color("-" .. tostring(hungerPenalty) .. "% COMBAT STRENGTH", "[COLOR_NEGATIVE_TEXT]")
        or FB_Color("NO COMBAT PENALTY", "[COLOR_POSITIVE_TEXT]"))
    Controls.ArmyDemandDetail:SetText(
        armyDemand > 0
            and "Army feeding is distributed across the Brood Network before projects."
            or "No military organisms currently require Food.")

    Controls.HarvestValueLabel:SetText(
        "[ICON_FOOD] " .. tostring(status.consumptionHarvestFood or 0)
            .. " from consumed cities")
    Controls.CurrencyValueLabel:SetText(
        "[ICON_GOLD] " .. tostring(status.currencyFood or 0)
            .. " Food digested from currency")
    Controls.MaintenanceValueLabel:SetText(
        tostring(status.maintenanceSuppressed or 0) .. " Gold upkeep suppressed")
    Controls.InjectionNoteLabel:SetText(
        addedFood > 0
            and (tostring(addedFood) .. " added Food entered the network this turn.")
            or "No external Food entered the network this turn.")

    local cityCount = #(status.cities or {})
    Controls.NetworkNodesLabel:SetText(
        tostring(cityCount) .. (cityCount == 1 and " Brood Node" or " Brood Nodes")
            .. "   |   " .. tostring(totals.strainedCities) .. " strained")
    Controls.NetworkStoredLabel:SetText(
        tostring(totals.storedFood) .. " [ICON_FOOD] stored toward population")
    Controls.NetworkFreeLabel:SetText(
        tostring(totals.availableFood) .. " Food free after local commitments")
end

local function FB_FindCityStatus(status, cityID)
    for _, cityStatus in ipairs(status.cities or {}) do
        if cityStatus.id == cityID then return cityStatus end
    end
    return nil
end

local function FB_RebuildCityDropdown(status)
    local cities = status.cities or {}
    local selected = FB_FindCityStatus(status, selectedCityID)
    if selected == nil and #cities > 0 then
        selectedCityID = cities[1].id
        selected = cities[1]
    end

    Controls.BroodCityPullDown:ClearEntries()
    cityDropdownEntries = {}
    for index, cityStatus in ipairs(cities) do
        local cityName = cityStatus.name
        local population = cityStatus.population or 0
        local entry = {}
        Controls.BroodCityPullDown:BuildEntry("InstanceOne", entry)
        entry.Button:SetText(cityName .. "   •   Population " .. tostring(population))
        entry.Button:SetVoid1(index)
        cityDropdownEntries[index] = cityStatus.id
    end
    Controls.BroodCityPullDown:CalculateInternals()
    Controls.BroodCityPullDown:GetButton():SetText(
        selected and selected.name or "NO LIVING BROOD NODES")
    return selected
end

local function FB_SetOrderPortrait(cityStatus)
    local row = FB_OrderRow(cityStatus)
    local hooked = false
    if row ~= nil and row.IconAtlas ~= nil then
        local ok, result = pcall(function()
            return IconHookup(row.PortraitIndex or 0, 128, row.IconAtlas, Controls.BroodOrderPortrait)
        end)
        hooked = ok and result ~= false
    end
    if not hooked then
        local ok, result = pcall(function()
            return IconHookup(0, 128, "FLESHBORN_CIV_ATLAS", Controls.BroodOrderPortrait)
        end)
        hooked = ok and result ~= false
    end
    Controls.BroodOrderPortrait:SetHide(not hooked)
    Controls.BroodOrderIconFallback:SetHide(hooked)
end

local function FB_NodeState(cityStatus)
    local net = cityStatus.netFood or 0
    local usable = math.max(0, net)
    local spent = cityStatus.foodSpent or 0
    local remaining = math.max(0, usable - spent)
    if net < 0 then return "LOCAL DEFICIT", "[COLOR_NEGATIVE_TEXT]", remaining end
    if spent > 0 and remaining <= 0 then
        return "FULLY COMMITTED", "[COLOR_WARNING_TEXT]", remaining
    end
    if remaining <= 0 then return "NO FREE FOOD", "[COLOR_WARNING_TEXT]", remaining end
    return "FED", "[COLOR_POSITIVE_TEXT]", remaining
end

local function FB_RefreshBrood(cityStatus)
    if cityStatus == nil then
        Controls.BroodLocalStateLabel:SetText(FB_Color("NO LIVING BROOD NODES", "[COLOR_NEGATIVE_TEXT]"))
        Controls.BroodPopulationValue:SetText("0 [ICON_CITIZEN]")
        Controls.BroodPopulationDetail:SetText("No population remains")
        Controls.BroodProducedValue:SetText("+0 [ICON_FOOD]")
        Controls.BroodProducedDetail:SetText("No city output")
        Controls.BroodConsumedValue:SetText("-0 [ICON_FOOD]")
        Controls.BroodConsumedDetail:SetText("No local consumption")
        Controls.BroodNetValue:SetText("+0 [ICON_FOOD]")
        Controls.BroodNetDetail:SetText("No Food remains")
        Controls.BroodOrderNameLabel:SetText("No biological order")
        Controls.BroodOrderKindLabel:SetText("BROOD NETWORK LOST")
        Controls.BroodOrderEtaLabel:SetText("No active city")
        Controls.BroodAllocationLabel:SetText("0 [ICON_FOOD] allocated this turn")
        Controls.BroodOrderNoteLabel:SetText("A living Brood Node is required to grow.")
        Controls.BroodCitizenCostLabel:SetText("Citizens consume 0 [ICON_FOOD]")
        Controls.BroodMetabolismCostLabel:SetText("Node metabolism consumes 0 [ICON_FOOD]")
        Controls.BroodArmyCostLabel:SetText("Army share consumes 0 [ICON_FOOD]")
        Controls.BroodProjectCostLabel:SetText("Current order consumes 0 [ICON_FOOD]")
        Controls.BroodDigestiveLabel:SetText("Digestive Chamber not present")
        Controls.BroodNeuralLabel:SetText("Neural Cluster not present")
        Controls.BroodEventLabel:SetText("No Brood Node events are available.")
        Controls.BroodProgressSection:SetHide(true)
        Controls.BroodOrderPortrait:SetHide(true)
        Controls.BroodOrderIconFallback:SetHide(false)
        return
    end

    local population = cityStatus.population or 0
    local citizenConsumption = cityStatus.citizenConsumption or (population * 2)
    local baseFoodProduced = cityStatus.baseFoodProduced
        or math.max(0, (cityStatus.grossFood or 0) + citizenConsumption)
    local foodProduced = cityStatus.foodProduced
        or (baseFoodProduced + (cityStatus.injectedFood or 0))
    local foodConsumed = cityStatus.foodConsumed
        or (citizenConsumption
            + (cityStatus.metabolicBurden or 0)
            + (cityStatus.armyBurden or 0)
            + (cityStatus.foodSpent or 0))
    local foodBalance = foodProduced - foodConsumed
    local nodeState, nodeColor, remaining = FB_NodeState(cityStatus)

    Controls.BroodLocalStateLabel:SetText(FB_Color(
        nodeState .. "   •   " .. tostring(remaining) .. " FREE", nodeColor))
    Controls.BroodPopulationValue:SetText(tostring(population) .. " [ICON_CITIZEN]")
    Controls.BroodPopulationDetail:SetText(
        tostring(cityStatus.storedFood or 0) .. " / " .. tostring(cityStatus.growthNeeded or 0)
            .. " Food stored for growth")
    Controls.BroodProducedValue:SetText(FB_Color(
        FB_Signed(foodProduced) .. " [ICON_FOOD]", "[COLOR_POSITIVE_TEXT]"))
    Controls.BroodProducedDetail:SetText(
        "City output " .. tostring(baseFoodProduced)
            .. "   |   Added " .. tostring(cityStatus.injectedFood or 0))
    Controls.BroodConsumedValue:SetText(FB_Color(
        "-" .. tostring(foodConsumed) .. " [ICON_FOOD]", "[COLOR_WARNING_TEXT]"))
    Controls.BroodConsumedDetail:SetText(
        "Fixed " .. tostring(citizenConsumption
            + (cityStatus.metabolicBurden or 0)
            + (cityStatus.armyBurden or 0))
            .. "   |   Project " .. tostring(cityStatus.foodSpent or 0))
    Controls.BroodNetValue:SetText(FB_Color(
        FB_Signed(foodBalance) .. " [ICON_FOOD]",
        foodBalance >= 0 and "[COLOR_POSITIVE_TEXT]" or "[COLOR_NEGATIVE_TEXT]"))
    Controls.BroodNetDetail:SetText(tostring(remaining) .. " Food remains uncommitted")

    local row, kindLabel = FB_OrderRow(cityStatus)
    local orderName = FB_OrderName(cityStatus)
    Controls.BroodOrderKindLabel:SetText(kindLabel)
    Controls.BroodOrderNameLabel:SetText(orderName)
    FB_SetOrderPortrait(cityStatus)

    local progress = 0
    local needed = 0
    local rate = 0
    local allocation = cityStatus.foodSpent or 0
    local progressNote = ""
    local showProgress = cityStatus.orderKind ~= "LEAGUE"
    if cityStatus.orderKind == "GROWTH" then
        progress = math.max(0, cityStatus.storedFood or 0)
        needed = math.max(0, cityStatus.growthNeeded or 0)
        rate = remaining
        allocation = remaining
        progressNote = "Free Food remains in this city and advances population growth."
    elseif showProgress then
        progress = math.max(0, cityStatus.projectProgress or 0)
        needed = math.max(0, cityStatus.projectNeeded or 0)
        rate = math.max(0, cityStatus.productionGain or 0)
        progressNote = cityStatus.digestive
            and "Digestive Chamber reduces this biological project's Food cost by 10%."
            or "Only this Brood Node's usable Food advances the project."
    else
        progressNote = "Each allocated Food becomes one World Congress contribution."
    end

    Controls.BroodProgressSection:SetHide(not showProgress)
    if showProgress then
        local percent = FB_Percent(progress, needed)
        Controls.BroodProgressFill:SetSizeX(math.max(1, math.floor(664 * percent / 100)))
        Controls.BroodProgressPercentLabel:SetText(tostring(percent) .. "%")
        Controls.BroodProgressNumbersLabel:SetText(
            tostring(progress) .. " / " .. tostring(needed) .. " progress")
        Controls.BroodOrderEtaLabel:SetText(FB_EstimateTurns(needed - progress, rate))
    else
        Controls.BroodOrderEtaLabel:SetText(
            tostring(cityStatus.productionGain or 0) .. " contribution this turn")
    end
    Controls.BroodAllocationLabel:SetText(
        tostring(allocation) .. " [ICON_FOOD] allocated this turn   |   "
            .. tostring(remaining) .. " remains free")
    Controls.BroodOrderNoteLabel:SetText(progressNote)

    Controls.BroodCitizenCostLabel:SetText(
        "Citizens consume " .. tostring(citizenConsumption) .. " [ICON_FOOD]")
    Controls.BroodMetabolismCostLabel:SetText(
        "Node metabolism consumes " .. tostring(cityStatus.metabolicBurden or 0) .. " [ICON_FOOD]")
    Controls.BroodArmyCostLabel:SetText(
        "Army share consumes " .. tostring(cityStatus.armyBurden or 0) .. " [ICON_FOOD]")
    Controls.BroodProjectCostLabel:SetText(
        "Current order consumes " .. tostring(cityStatus.foodSpent or 0) .. " [ICON_FOOD]")

    Controls.BroodDigestiveLabel:SetText(cityStatus.digestive
        and FB_Color("DIGESTIVE CHAMBER ACTIVE   •   -10% project Food cost", "[COLOR_POSITIVE_TEXT]")
        or "Digestive Chamber not present")
    Controls.BroodNeuralLabel:SetText(cityStatus.neuralCluster
        and FB_Color(
            "NEURAL CLUSTER ACTIVE   •   " .. tostring(cityStatus.neuralFoodConsumed or 0)
                .. " Food feeding creates " .. tostring(cityStatus.neuralScience or 0)
                .. " [ICON_RESEARCH]", "[COLOR_CYAN]")
        or "Neural Cluster not present")

    local eventParts = {}
    if (cityStatus.foundingCoreFood or 0) > 0 then
        table.insert(eventParts, "Founding Core provides "
            .. tostring(cityStatus.foundingCoreFood) .. " Food")
    end
    if (cityStatus.consumptionHarvestFood or 0) > 0 then
        table.insert(eventParts, tostring(cityStatus.consumptionHarvestFood)
            .. " Food arrived from a consumed city")
    end
    if (cityStatus.consumptionSourceFood or 0) > 0 then
        table.insert(eventParts, "This city is being consumed; "
            .. tostring(cityStatus.consumptionSourceFood) .. " Food was harvested")
    end
    if (cityStatus.pendingFood or 0) > 0 then
        table.insert(eventParts, tostring(cityStatus.pendingFood) .. " Food is queued")
    end
    Controls.BroodEventLabel:SetText(#eventParts > 0
        and table.concat(eventParts, ".  ") .. "."
        or "No special Food events affected this Brood Node this turn.")
end

local function FB_SetTab(tab)
    activeTab = tab == "BROOD" and "BROOD" or "OVERVIEW"
    Controls.OverviewPage:SetHide(activeTab ~= "OVERVIEW")
    Controls.BroodPage:SetHide(activeTab ~= "BROOD")
    Controls.OverviewTabAccent:SetHide(activeTab ~= "OVERVIEW")
    Controls.BroodTabAccent:SetHide(activeTab ~= "BROOD")
    Controls.FooterLabel:SetText(activeTab == "OVERVIEW"
        and "Food is local to each Brood Node. Army feeding is distributed empire-wide."
        or "Select a Brood Node above to inspect its local Food and current biological order.")
    if panelOpen and FB_Refresh ~= nil then FB_Refresh() end
end

FB_Refresh = function()
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
    local totals = FB_Aggregate(status)
    local empireState, empireColor, stateDetail = FB_EmpireState(status, totals)

    Controls.TurnLabel:SetText("TURN " .. tostring(status.turn or Game.GetGameTurn()))
    Controls.MetabolismButtonLabel:SetText(
        "[ICON_FOOD] " .. FB_Signed(totals.foodBalance) .. " NET   •   " .. empireState)
    Controls.MetabolismButton:SetToolTipString(
        "THE FLESHBORN CHORUS[NEWLINE]"
        .. tostring(totals.foodProduced) .. " Food produced[NEWLINE]"
        .. tostring(totals.foodConsumed) .. " Food consumed[NEWLINE]"
        .. FB_Signed(totals.foodBalance) .. " net Food[NEWLINE]"
        .. tostring(status.armyFed or 0) .. " of " .. tostring(status.armyDemand or 0)
            .. " army Food supplied[NEWLINE][NEWLINE]Click to open the metabolism dashboard.")

    FB_RefreshOverview(status, totals, empireState, empireColor, stateDetail)
    local selected = FB_RebuildCityDropdown(status)
    FB_RefreshBrood(selected)
end

local function FB_SetPanelOpen(open)
    panelOpen = open == true and FB_IsActivePlayerFleshborn()
    Controls.MetabolismPanel:SetHide(not panelOpen)
    if panelOpen then
        -- Every open begins on the readable empire overview by design.
        FB_SetTab("OVERVIEW")
    end
end

Controls.MetabolismButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetPanelOpen(not panelOpen)
end)
Controls.OverviewTabButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetTab("OVERVIEW")
end)
Controls.BroodTabButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetTab("BROOD")
end)
Controls.BroodCityPullDown:RegisterSelectionCallback(function(index)
    if cityDropdownEntries[index] ~= nil then
        selectedCityID = cityDropdownEntries[index]
        if FB_Refresh ~= nil then FB_Refresh() end
    end
end)
Controls.CloseButton:RegisterCallback(Mouse.eLClick, function()
    FB_SetPanelOpen(false)
end)
Controls.RefreshButton:RegisterCallback(Mouse.eLClick, function()
    if FB_Refresh ~= nil then FB_Refresh() end
end)

ContextPtr:SetInputHandler(function(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE and panelOpen then
        FB_SetPanelOpen(false)
        return true
    end
    return false
end)

if LuaEvents.FleshbornStatusUpdated ~= nil then
    LuaEvents.FleshbornStatusUpdated.Add(function(playerID)
        if playerID == Game.GetActivePlayer() and FB_Refresh ~= nil then FB_Refresh() end
    end)
end
if Events.ActivePlayerTurnStart ~= nil then
    Events.ActivePlayerTurnStart.Add(function()
        if FB_Refresh ~= nil then FB_Refresh() end
    end)
end
if Events.GameplaySetActivePlayer ~= nil then
    Events.GameplaySetActivePlayer.Add(function()
        selectedCityID = nil
        if FB_Refresh ~= nil then FB_Refresh() end
    end)
end
if Events.SerialEventGameDataDirty ~= nil then
    Events.SerialEventGameDataDirty.Add(function()
        if panelOpen and FB_Refresh ~= nil then FB_Refresh() end
    end)
end

FB_SetTab("OVERVIEW")
FB_Refresh()
