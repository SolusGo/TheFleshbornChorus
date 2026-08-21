-- ============================================================================
-- The Fleshborn Chorus
-- Food economy, metabolic burden, army feeding, digestion, and CP hooks
-- ============================================================================

print("FleshbornCore.lua loaded")

local CIV_FLESHBORN = GameInfoTypes.CIVILIZATION_FLESHBORN_CHORUS
local UNIT_DEVOURER = GameInfoTypes.UNIT_FLESHBORN_DEVOURER
local UNIT_BUD = GameInfoTypes.UNIT_FLESHBORN_COLONY_BUD
local BUILDING_DIGESTIVE = GameInfoTypes.BUILDING_FLESHBORN_DIGESTIVE_CHAMBER
local BUILDING_METABOLISM = GameInfoTypes.BUILDING_FLESHBORN_METABOLISM
local BUILDING_FIELD_FOOD = GameInfoTypes.BUILDING_FLESHBORN_FIELD_FOOD
local BUILDING_EDIBLE_FOOD = GameInfoTypes.BUILDING_FLESHBORN_EDIBLE_FOOD
local BUILDING_MEMORY = GameInfoTypes.BUILDING_FLESHBORN_MEMORY
local BUILDING_MAINTENANCE = GameInfoTypes.BUILDING_FLESHBORN_MAINTENANCE
local BUILDING_BLOOM = GameInfoTypes.BUILDING_FLESHBORN_BLOOM
local IMPROVEMENT_FEEDING_FIELD = GameInfoTypes.IMPROVEMENT_FLESHBORN_FEEDING_FIELD
local IMPROVEMENT_PLANTATION = GameInfoTypes.IMPROVEMENT_PLANTATION
local PROCESS_GROWTH = GameInfoTypes.PROCESS_FLESHBORN_GROWTH
local BUILD_FARM = GameInfoTypes.BUILD_FARM
local BUILD_FEEDING_FIELD = GameInfoTypes.BUILD_FLESHBORN_FEEDING_FIELD
local BUILD_DIGEST_FOREST = GameInfoTypes.BUILD_FLESHBORN_DIGEST_FOREST
local BUILD_DIGEST_JUNGLE = GameInfoTypes.BUILD_FLESHBORN_DIGEST_JUNGLE
local BUILD_DIGEST_MARSH = GameInfoTypes.BUILD_FLESHBORN_DIGEST_MARSH

local FB_SAVE = Modding.OpenSaveData()
local FB_HUNGER_PROMOTIONS = {}
for i = 1, 10 do
    FB_HUNGER_PROMOTIONS[i] = GameInfoTypes["PROMOTION_FLESHBORN_HUNGER_" .. tostring(i)]
end

local FB_EDIBLE_RESOURCES = {}
for _, resourceType in ipairs({"RESOURCE_SUGAR", "RESOURCE_BANANA", "RESOURCE_CITRUS"}) do
    local resourceID = GameInfoTypes[resourceType]
    if resourceID ~= nil then
        FB_EDIBLE_RESOURCES[resourceID] = true
    end
end

local FB_DIGEST_FOOD = {}
if BUILD_DIGEST_FOREST ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_FOREST] = 20 end
if BUILD_DIGEST_JUNGLE ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_JUNGLE] = 15 end
if BUILD_DIGEST_MARSH ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_MARSH] = 12 end

local FB_BUILDING_MAINTENANCE = {}
for building in GameInfo.Buildings() do
    local maintenance = tonumber(building.GoldMaintenance) or 0
    if maintenance > 0 then
        table.insert(FB_BUILDING_MAINTENANCE, {id = building.ID, cost = maintenance})
    end
end

local FB_UNIT_ERA_FEED_X2 = {}
local FB_KILL_CACHE = {}

MapModData.FleshbornStatus = MapModData.FleshbornStatus or {}

local function FB_IsFleshbornPlayer(player)
    return player ~= nil
        and player:IsAlive()
        and CIV_FLESHBORN ~= nil
        and player:GetCivilizationType() == CIV_FLESHBORN
end

local function FB_GetSavedNumber(key, fallback)
    local value = FB_SAVE.GetValue(key)
    if value == nil then
        return fallback
    end
    return tonumber(value) or fallback
end

local function FB_SetSavedNumber(key, value)
    FB_SAVE.SetValue(key, value)
end

local function FB_CityKey(prefix, playerID, city)
    return "FB_" .. prefix .. "_" .. tostring(playerID) .. "_" .. tostring(city:GetID())
end

local function FB_OrderKey(prefix, playerID, city, signature)
    return FB_CityKey(prefix, playerID, city) .. "_" .. tostring(signature)
end

local function FB_HasBuilding(city, buildingID)
    if city == nil or buildingID == nil then
        return false
    end
    return city:GetNumRealBuilding(buildingID) > 0 or city:GetNumFreeBuilding(buildingID) > 0
end

local function FB_SetBuildingCount(city, buildingID, count)
    if city == nil or buildingID == nil then
        return
    end
    count = math.max(0, math.floor(count or 0))
    if city:GetNumRealBuilding(buildingID) ~= count then
        city:SetNumRealBuilding(buildingID, count)
    end
end

local function FB_SetFood(city, target)
    target = math.max(0, math.floor(target or 0))
    local current = city:GetFood()
    if current ~= target then
        city:ChangeFood(target - current)
    end
end

local function FB_SetProduction(city, target)
    target = math.max(0, math.floor(target or 0))
    local current = city:GetProduction()
    if current ~= target then
        city:SetProduction(target)
    end
end

local function FB_IsWorkedBy(city, plot)
    if city == nil or plot == nil then
        return false
    end
    local ok, result = pcall(function() return city:IsWorkingPlot(plot) end)
    if ok then
        return result == true
    end
    return plot:GetWorkingCity() == city
end

local function FB_CountAdjacentFeedingFields(plot)
    local count = 0
    for direction = 0, 5 do
        local adjacent = Map.PlotDirection(plot:GetX(), plot:GetY(), direction)
        if adjacent ~= nil
            and adjacent:GetImprovementType() == IMPROVEMENT_FEEDING_FIELD
            and not adjacent:IsImprovementPillaged() then
            count = count + 1
        end
    end
    return count
end

local function FB_CountSpecialists(city)
    local count = 0
    for specialist in GameInfo.Specialists() do
        count = count + (city:GetSpecialistCount(specialist.ID) or 0)
    end
    return count
end

local function FB_UpdateCityDummies(playerID, player, city)
    FB_SetBuildingCount(city, BUILDING_METABOLISM, 1)
    FB_SetBuildingCount(city, BUILDING_BLOOM, player:IsGoldenAge() and 1 or 0)
    FB_SetBuildingCount(city, BUILDING_MEMORY, 1 + math.floor(city:GetPopulation() / 5))

    local adjacencyFood = 0
    local edibleFood = 0

    for index = 0, city:GetNumCityPlots() - 1 do
        local plot = city:GetCityIndexPlot(index)
        if plot ~= nil
            and plot:GetOwner() == playerID
            and FB_IsWorkedBy(city, plot)
            and not plot:IsImprovementPillaged() then
            if plot:GetImprovementType() == IMPROVEMENT_FEEDING_FIELD
                and FB_CountAdjacentFeedingFields(plot) >= 3 then
                adjacencyFood = adjacencyFood + 1
            end

            if plot:GetImprovementType() == IMPROVEMENT_PLANTATION
                and FB_EDIBLE_RESOURCES[plot:GetResourceType(-1)] then
                edibleFood = edibleFood + 2
            end
        end
    end

    FB_SetBuildingCount(city, BUILDING_FIELD_FOOD, adjacencyFood)
    FB_SetBuildingCount(city, BUILDING_EDIBLE_FOOD, edibleFood)
end

local function FB_CalculateBuildingMaintenance(player)
    local total = 0
    for city in player:Cities() do
        for _, entry in ipairs(FB_BUILDING_MAINTENANCE) do
            if city:GetNumRealBuilding(entry.id) > 0 or city:GetNumFreeBuilding(entry.id) > 0 then
                total = total + entry.cost
            end
        end
    end
    return total
end

local function FB_UpdateMaintenanceRefund(player)
    local capital = player:GetCapitalCity()
    if capital == nil then
        return 0
    end

    local maintenance = FB_CalculateBuildingMaintenance(player)
    for city in player:Cities() do
        FB_SetBuildingCount(city, BUILDING_MAINTENANCE, city:GetID() == capital:GetID() and maintenance or 0)
    end
    return maintenance
end

local function FB_GetUnitFeedX2(unitInfo)
    if unitInfo == nil then
        return 0
    end

    local cached = FB_UNIT_ERA_FEED_X2[unitInfo.ID]
    if cached ~= nil then
        return cached
    end

    if tonumber(unitInfo.MilitarySupport) ~= 1
        and (tonumber(unitInfo.Combat) or 0) <= 0
        and (tonumber(unitInfo.RangedCombat) or 0) <= 0 then
        FB_UNIT_ERA_FEED_X2[unitInfo.ID] = 0
        return 0
    end

    local eraID = 0
    if unitInfo.PrereqTech ~= nil then
        local tech = GameInfo.Technologies[unitInfo.PrereqTech]
        if tech ~= nil and tech.Era ~= nil then
            local era = GameInfo.Eras[tech.Era]
            if era ~= nil then eraID = era.ID end
        end
    end

    local costByEra = {1, 1, 2, 2, 3, 4, 5, 6}
    local result = costByEra[eraID + 1] or 6
    FB_UNIT_ERA_FEED_X2[unitInfo.ID] = result
    return result
end

local function FB_IsMilitaryUnitType(unitType)
    local unitInfo = GameInfo.Units[unitType]
    return unitInfo ~= nil and FB_GetUnitFeedX2(unitInfo) > 0
end

local function FB_GetArmyDemandX2(player)
    local demand = 0
    for unit in player:Units() do
        demand = demand + FB_GetUnitFeedX2(GameInfo.Units[unit:GetUnitType()])
    end
    return demand
end

local function FB_GetGrossFood(city)
    local ok, value = pcall(function() return city:FoodDifference() end)
    if ok and value ~= nil then
        return math.floor(value)
    end
    return 0
end

local function FB_GetMetabolicBurden(city)
    return 3 + math.ceil(city:GetPopulation() * 0.5) + FB_CountSpecialists(city)
end

local function FB_GetOrder(city)
    local unitType = city:GetProductionUnit()
    if unitType ~= nil and unitType >= 0 then
        return {kind = "UNIT", id = unitType, signature = "U" .. tostring(unitType)}
    end

    local buildingType = city:GetProductionBuilding()
    if buildingType ~= nil and buildingType >= 0 then
        return {kind = "BUILDING", id = buildingType, signature = "B" .. tostring(buildingType)}
    end

    local projectType = city:GetProductionProject()
    if projectType ~= nil and projectType >= 0 then
        return {kind = "PROJECT", id = projectType, signature = "P" .. tostring(projectType)}
    end

    local processType = city:GetProductionProcess()
    if processType ~= nil and processType >= 0 then
        if processType == PROCESS_GROWTH then
            return {kind = "GROWTH", id = processType, signature = "GROWTH"}
        end
        return {kind = "PROCESS", id = processType, signature = "X" .. tostring(processType)}
    end

    return {kind = "GROWTH", id = -1, signature = "GROWTH"}
end

local function FB_GetFoodMultiplier(city, order)
    local multiplier = 1000
    if order.kind == "BUILDING" or order.kind == "PROJECT" then
        multiplier = 1250
    elseif order.kind == "UNIT" and order.id == UNIT_BUD then
        multiplier = 1200
    end

    if FB_HasBuilding(city, BUILDING_DIGESTIVE) then
        multiplier = math.floor((multiplier * 900 + 500) / 1000)
    end
    return multiplier
end

local function FB_GetPendingFood(playerID, city)
    return FB_GetSavedNumber(FB_CityKey("PENDING", playerID, city), 0)
end

local function FB_SetPendingFood(playerID, city, amount)
    FB_SetSavedNumber(FB_CityKey("PENDING", playerID, city), math.max(0, math.floor(amount or 0)))
end

local function FB_QueueCityFood(playerID, city, amount)
    if city == nil or amount == nil or amount <= 0 then
        return
    end
    FB_SetPendingFood(playerID, city, FB_GetPendingFood(playerID, city) + math.floor(amount))
end

local function FB_FindNearestCity(player, x, y)
    local nearest = nil
    local bestDistance = 999999
    for city in player:Cities() do
        local distance = Map.PlotDistance(x, y, city:GetX(), city:GetY())
        if distance < bestDistance then
            nearest = city
            bestDistance = distance
        end
    end
    return nearest
end

local function FB_DigestCurrency(playerID, player, cities)
    local food = 0
    local gold = player:GetGold()
    if gold ~= nil and gold > 0 then
        local converted = math.floor(gold / 4)
        if converted > 0 then
            player:ChangeGold(-(converted * 4))
            food = food + converted
        end
    elseif gold ~= nil and gold < 0 then
        player:ChangeGold(-gold)
    end

    local faith = player:GetFaith()
    if faith ~= nil and faith > 0 then
        local converted = math.floor(faith / 3)
        if converted > 0 then
            player:ChangeFaith(-(converted * 3))
            food = food + converted
        end
    end

    if food <= 0 or #cities == 0 then
        return 0
    end

    local each = math.floor(food / #cities)
    local remainder = food - (each * #cities)
    for index, city in ipairs(cities) do
        FB_QueueCityFood(playerID, city, each + (index <= remainder and 1 or 0))
    end
    return food
end

local function FB_IsPlayerAtWar(player)
    local team = Teams[player:GetTeam()]
    if team == nil then return false end
    local ok, count = pcall(function() return team:GetAtWarCount(true) end)
    return ok and count ~= nil and count > 0
end

local function FB_SuppressHappinessGoldenAge(player)
    -- Luxuries may still appear in the stock Happiness UI, but that number is
    -- not allowed to become a second economy.  Removing the per-turn excess
    -- contribution preserves Golden Age points granted by policies, wonders,
    -- and Great People while making luxury Happiness economically inert.
    if player:IsGoldenAge() then return end
    local excess = player:GetExcessHappiness()
    if excess ~= nil and excess > 0 then
        player:ChangeGoldenAgeProgressMeter(-excess)
    end
end

local function FB_ApplyFoodProject(playerID, player, city, order, availableFood, hungerTier)
    if availableFood <= 0 then
        return 0, 0, FB_GetFoodMultiplier(city, order)
    end

    if hungerTier >= 7 and order.kind == "UNIT" and FB_IsMilitaryUnitType(order.id) then
        return 0, 0, FB_GetFoodMultiplier(city, order)
    end

    local foodToSpend = availableFood
    if not player:IsHuman() then
        local ratio = 0.40
        if order.kind == "UNIT" and order.id == UNIT_BUD then
            ratio = 0.60
        elseif FB_IsPlayerAtWar(player) and order.kind == "UNIT" and FB_IsMilitaryUnitType(order.id) then
            ratio = 0.70
        end
        foodToSpend = math.floor(availableFood * ratio)
        if availableFood > 0 and foodToSpend < 1 then foodToSpend = 1 end
    end

    local multiplier = FB_GetFoodMultiplier(city, order)
    local progressKey = FB_OrderKey("PROGRESS", playerID, city, order.signature)
    local creditKey = FB_OrderKey("CREDIT", playerID, city, order.signature)
    local storedProgress = FB_GetSavedNumber(progressKey, 0)
    local credit = FB_GetSavedNumber(creditKey, 0)

    -- Remove every point the normal Production engine may have contributed.
    -- Only the per-order progress saved by this food system is restored.
    FB_SetProduction(city, storedProgress)

    credit = credit + (foodToSpend * 1000)
    local productionGain = math.floor(credit / multiplier)
    credit = credit - (productionGain * multiplier)

    if productionGain > 0 then
        city:ChangeProduction(productionGain)
    end

    local currentOrder = FB_GetOrder(city)
    if currentOrder.signature == order.signature then
        FB_SetSavedNumber(progressKey, city:GetProduction())
        FB_SetSavedNumber(creditKey, credit)
    else
        FB_SetSavedNumber(progressKey, 0)
        FB_SetSavedNumber(creditKey, 0)
    end

    return foodToSpend, productionGain, multiplier
end

local function FB_ApplyHungerPromotions(player, tier)
    for unit in player:Units() do
        local military = FB_IsMilitaryUnitType(unit:GetUnitType())
        for index = 1, 10 do
            local promotionID = FB_HUNGER_PROMOTIONS[index]
            if promotionID ~= nil then
                local desired = military and index == tier
                if unit:IsHasPromotion(promotionID) ~= desired then
                    unit:SetHasPromotion(promotionID, desired)
                end
            end
        end
    end
end

local function FB_GetHungerTier(demandFood, supplyFood)
    if demandFood <= 0 or supplyFood >= demandFood then
        return 0
    end
    local unmet = demandFood - supplyFood
    return math.max(1, math.min(10, math.ceil((unmet * 10) / demandFood)))
end

local function FB_NotifyHungerChange(playerID, player, oldTier, newTier)
    if playerID ~= Game.GetActivePlayer() or oldTier == newTier then
        return
    end

    if newTier == 0 then
        player:AddNotification(
            NotificationTypes.NOTIFICATION_GENERIC,
            "The army is fully fed. The Hunger has ended.",
            "The Chorus Is Fed"
        )
    else
        player:AddNotification(
            NotificationTypes.NOTIFICATION_GENERIC,
            "Army feeding deficit has reached tier " .. tostring(newTier) .. ". Bioforms suffer -" .. tostring(newTier * 3) .. "% Combat Strength.",
            "The Hunger"
        )
    end
end

local function FB_ProcessPlayerTurn(playerID)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then
        return
    end

    local cities = {}
    local cityData = {}
    local totalPreArmySupply = 0

    for city in player:Cities() do
        table.insert(cities, city)
        FB_UpdateCityDummies(playerID, player, city)
    end

    local maintenanceRefund = FB_UpdateMaintenanceRefund(player)
    local currencyFood = FB_DigestCurrency(playerID, player, cities)
    FB_SuppressHappinessGoldenAge(player)

    for _, city in ipairs(cities) do
        local gross = FB_GetGrossFood(city)
        local metabolic = FB_GetMetabolicBurden(city)
        local preArmy = math.max(0, gross - metabolic)
        totalPreArmySupply = totalPreArmySupply + preArmy
        table.insert(cityData, {
            city = city,
            gross = gross,
            metabolic = metabolic,
            preArmy = preArmy,
            army = 0
        })
    end

    local armyDemandX2 = FB_GetArmyDemandX2(player)
    local armyDemand = math.ceil(armyDemandX2 / 2)
    local armyFed = math.min(armyDemand, totalPreArmySupply)
    local hungerTier = FB_GetHungerTier(armyDemand, totalPreArmySupply)

    local remainingArmy = armyFed
    local remainingSupply = totalPreArmySupply
    for index, data in ipairs(cityData) do
        if remainingArmy > 0 and data.preArmy > 0 then
            local share
            if index == #cityData or remainingSupply <= data.preArmy then
                share = math.min(data.preArmy, remainingArmy)
            else
                share = math.min(data.preArmy, math.floor((remainingArmy * data.preArmy) / remainingSupply))
                if share == 0 then share = 1 end
            end
            data.army = share
            remainingArmy = remainingArmy - share
        end
        remainingSupply = math.max(0, remainingSupply - data.preArmy)
    end

    local statusCities = {}
    for _, data in ipairs(cityData) do
        local city = data.city
        local order = FB_GetOrder(city)
        local pending = FB_GetPendingFood(playerID, city)
        local usable = math.max(0, data.gross - data.metabolic - data.army)
        local net = data.gross - data.metabolic - data.army
        local foodSpent = 0
        local productionGain = 0
        local multiplier = 0

        if order.kind == "UNIT" or order.kind == "BUILDING" or order.kind == "PROJECT" then
            if player:IsHuman() then
                local frozenKey = FB_CityKey("FROZEN", playerID, city)
                local frozen = FB_GetSavedNumber(frozenKey, -1)
                if frozen < 0 then frozen = city:GetFood() end
                if net < 0 then frozen = math.max(0, frozen + net) end
                FB_SetFood(city, frozen)
                FB_SetSavedNumber(frozenKey, frozen)
            else
                -- AI support follows the design allocation: roughly 40% to
                -- projects at peace, 60% to Colony Buds, and 70% to wartime
                -- military.  The remainder is left for population growth.
                city:ChangeFood(-(data.metabolic + data.army))
            end

            foodSpent, productionGain, multiplier = FB_ApplyFoodProject(
                playerID, player, city, order, usable + pending, hungerTier
            )

            if player:IsHuman() then
                if foodSpent < pending then
                    FB_SetPendingFood(playerID, city, pending - foodSpent)
                else
                    FB_SetPendingFood(playerID, city, 0)
                end
            else
                -- Gross city Food is applied by the engine.  Subtract only the
                -- biological burdens and the AI allocation sent to the order;
                -- pending digestion is an external injection and is added here.
                city:ChangeFood(pending - foodSpent)
                FB_SetPendingFood(playerID, city, 0)
            end
        else
            local frozenKey = FB_CityKey("FROZEN", playerID, city)
            local frozen = FB_GetSavedNumber(frozenKey, -1)
            if player:IsHuman() and frozen >= 0 then
                -- Remove the final normal Food tick from the project turn
                -- before returning the city to genuine population growth.
                FB_SetFood(city, frozen)
            end
            FB_SetSavedNumber(frozenKey, -1)
            city:ChangeFood(pending - data.metabolic - data.army)
            FB_SetPendingFood(playerID, city, 0)
        end

        local foodCost = 0
        if multiplier > 0 then
            foodCost = math.ceil((city:GetProductionNeeded() * multiplier) / 1000)
        end

        table.insert(statusCities, {
            id = city:GetID(),
            name = city:GetName(),
            population = city:GetPopulation(),
            storedFood = city:GetFood(),
            grossFood = data.gross,
            metabolicBurden = data.metabolic,
            armyBurden = data.army,
            netFood = net,
            pendingFood = FB_GetPendingFood(playerID, city),
            orderKind = order.kind,
            orderID = order.id,
            foodSpent = foodSpent,
            productionGain = productionGain,
            foodCost = foodCost,
            projectProgress = city:GetProduction(),
            projectNeeded = city:GetProductionNeeded(),
            digestive = FB_HasBuilding(city, BUILDING_DIGESTIVE)
        })
    end

    local oldTier = FB_GetSavedNumber("FB_HUNGER_TIER_" .. tostring(playerID), 0)
    FB_SetSavedNumber("FB_HUNGER_TIER_" .. tostring(playerID), hungerTier)
    FB_ApplyHungerPromotions(player, hungerTier)
    FB_NotifyHungerChange(playerID, player, oldTier, hungerTier)

    MapModData.FleshbornStatus[playerID] = {
        turn = Game.GetGameTurn(),
        armyDemand = armyDemand,
        armyFed = armyFed,
        preArmySupply = totalPreArmySupply,
        hungerTier = hungerTier,
        currencyFood = currencyFood,
        maintenanceRefund = maintenanceRefund,
        cities = statusCities
    }

    if LuaEvents.FleshbornStatusUpdated ~= nil then
        LuaEvents.FleshbornStatusUpdated(playerID)
    end
end

-- --------------------------------------------------------------------------
-- Rules and completion hooks
-- --------------------------------------------------------------------------

local function FB_CityCanConstruct(playerID, cityID, buildingType)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return true end

    local building = GameInfo.Buildings[buildingType]
    if building == nil then return true end
    local class = GameInfo.BuildingClasses[building.BuildingClass]
    if class ~= nil and (tonumber(class.MaxGlobalInstances) or -1) > 0 then
        return false
    end
    return true
end

local function FB_CityCanTrain(playerID, cityID, unitType)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return true end

    local city = player:GetCityByID(cityID)
    if unitType == UNIT_BUD and city ~= nil and city:GetPopulation() <= 1 then
        return false
    end

    local hungerTier = FB_GetSavedNumber("FB_HUNGER_TIER_" .. tostring(playerID), 0)
    if hungerTier >= 7 and FB_IsMilitaryUnitType(unitType) then
        return false
    end
    return true
end

local function FB_CityCanMaintain(playerID, cityID, processType)
    local player = Players[playerID]
    if FB_IsFleshbornPlayer(player) then
        return processType == PROCESS_GROWTH
    end
    return processType ~= PROCESS_GROWTH
end

local function FB_PlayerCanFoundPantheon(playerID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_PlayerCanFoundReligion(playerID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_PlayerCanBuild(playerID, unitID, x, y, buildType)
    local fleshborn = FB_IsFleshbornPlayer(Players[playerID])
    if fleshborn and buildType == BUILD_FARM then
        return false
    end

    if not fleshborn and (buildType == BUILD_FEEDING_FIELD
        or buildType == BUILD_DIGEST_FOREST
        or buildType == BUILD_DIGEST_JUNGLE
        or buildType == BUILD_DIGEST_MARSH) then
        return false
    end
    return true
end

local function FB_ClearUnitProgress(playerID, city, unitType)
    if city == nil or unitType == nil then return end
    local signature = "U" .. tostring(unitType)
    FB_SetSavedNumber(FB_OrderKey("PROGRESS", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("CREDIT", playerID, city, signature), 0)
end

local function FB_ClearBuildingProgress(playerID, city, buildingType)
    if city == nil or buildingType == nil then return end
    local signature = "B" .. tostring(buildingType)
    FB_SetSavedNumber(FB_OrderKey("PROGRESS", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("CREDIT", playerID, city, signature), 0)
end

local function FB_OnCityTrained(playerID, cityID, unitID)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    local city = player:GetCityByID(cityID)
    local unit = player:GetUnitByID(unitID)
    if city == nil or unit == nil then return end

    local unitType = unit:GetUnitType()
    FB_ClearUnitProgress(playerID, city, unitType)
    if unitType == UNIT_BUD and city:GetPopulation() > 1 then
        city:ChangePopulation(-1, true)
    end
end

local function FB_OnCityConstructed(playerID, cityID, buildingType)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    FB_ClearBuildingProgress(playerID, player:GetCityByID(cityID), buildingType)
end

local function FB_OnPlayerBuilt(playerID, unitID, x, y, buildType)
    local food = FB_DIGEST_FOOD[buildType]
    if food == nil then return end
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    local city = FB_FindNearestCity(player, x, y)
    FB_QueueCityFood(playerID, city, food)
end

local function FB_OnUnitPrekill(killedPlayerID, killedUnitID, killedUnitType, x, y, delay, killerPlayerID)
    if killerPlayerID == nil or killerPlayerID < 0 then return end
    local killer = Players[killerPlayerID]
    if not FB_IsFleshbornPlayer(killer) then return end

    local cacheKey = tostring(Game.GetGameTurn()) .. ":" .. tostring(killedPlayerID) .. ":" .. tostring(killedUnitID)
    if FB_KILL_CACHE[cacheKey] then return end

    local victimInfo = GameInfo.Units[killedUnitType]
    if victimInfo == nil or FB_GetUnitFeedX2(victimInfo) <= 0 then return end

    local devourerAdjacent = false
    for direction = 0, 5 do
        local plot = Map.PlotDirection(x, y, direction)
        if plot ~= nil then
            for index = 0, plot:GetNumUnits() - 1 do
                local unit = plot:GetUnit(index)
                if unit ~= nil and unit:GetOwner() == killerPlayerID and unit:GetUnitType() == UNIT_DEVOURER then
                    devourerAdjacent = true
                    break
                end
            end
        end
        if devourerAdjacent then break end
    end

    if not devourerAdjacent then return end
    FB_KILL_CACHE[cacheKey] = true

    local strength = math.max(tonumber(victimInfo.Combat) or 0, tonumber(victimInfo.RangedCombat) or 0)
    local food = math.floor(strength * 0.25)
    if food > 0 then
        FB_QueueCityFood(killerPlayerID, FB_FindNearestCity(killer, x, y), food)
    end
end

GameEvents.PlayerDoTurn.Add(FB_ProcessPlayerTurn)
GameEvents.CityCanConstruct.Add(FB_CityCanConstruct)
GameEvents.CityCanTrain.Add(FB_CityCanTrain)

if GameEvents.CityCanMaintain ~= nil then
    GameEvents.CityCanMaintain.Add(FB_CityCanMaintain)
end
if GameEvents.PlayerCanFoundPantheon ~= nil then
    GameEvents.PlayerCanFoundPantheon.Add(FB_PlayerCanFoundPantheon)
end
if GameEvents.PlayerCanFoundReligion ~= nil then
    GameEvents.PlayerCanFoundReligion.Add(FB_PlayerCanFoundReligion)
end
if GameEvents.PlayerCanBuild ~= nil then
    GameEvents.PlayerCanBuild.Add(FB_PlayerCanBuild)
end
if GameEvents.CityTrained ~= nil then
    GameEvents.CityTrained.Add(FB_OnCityTrained)
end
if GameEvents.CityConstructed ~= nil then
    GameEvents.CityConstructed.Add(FB_OnCityConstructed)
end
if GameEvents.PlayerBuilt ~= nil then
    GameEvents.PlayerBuilt.Add(FB_OnPlayerBuilt)
end
if GameEvents.UnitPrekill ~= nil then
    GameEvents.UnitPrekill.Add(FB_OnUnitPrekill)
end

-- Make the production suppression and visible city yields correct immediately
-- after a save loads; project conversion itself waits for PlayerDoTurn.
local function FB_Initialize()
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local player = Players[playerID]
        if FB_IsFleshbornPlayer(player) then
            for city in player:Cities() do
                FB_UpdateCityDummies(playerID, player, city)
            end
            FB_UpdateMaintenanceRefund(player)
        end
    end
end

if Events.LoadScreenClose ~= nil then
    Events.LoadScreenClose.Add(FB_Initialize)
end
