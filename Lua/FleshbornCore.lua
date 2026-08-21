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
local BUILDING_FOUNDING_CORE = GameInfoTypes.BUILDING_FLESHBORN_FOUNDING_CORE
local BUILDING_FIELD_FOOD = GameInfoTypes.BUILDING_FLESHBORN_FIELD_FOOD
local BUILDING_EDIBLE_FOOD = GameInfoTypes.BUILDING_FLESHBORN_EDIBLE_FOOD
local BUILDING_MEMORY = GameInfoTypes.BUILDING_FLESHBORN_MEMORY
local BUILDING_PRODUCTION_SINK = GameInfoTypes.BUILDING_FLESHBORN_PRODUCTION_SINK
local BUILDING_BLOOM = GameInfoTypes.BUILDING_FLESHBORN_BLOOM
local POLICY_INVARIANTS = GameInfoTypes.POLICY_FLESHBORN_INVARIANTS
local IMPROVEMENT_FEEDING_FIELD_LEGACY = GameInfoTypes.IMPROVEMENT_FLESHBORN_FEEDING_FIELD
local IMPROVEMENT_FARM = GameInfoTypes.IMPROVEMENT_FARM
local IMPROVEMENT_PLANTATION = GameInfoTypes.IMPROVEMENT_PLANTATION
local PROCESS_GROWTH = GameInfoTypes.PROCESS_FLESHBORN_GROWTH
local BUILD_FARM = GameInfoTypes.BUILD_FARM
local BUILD_REMOVE_FOREST = GameInfoTypes.BUILD_REMOVE_FOREST
local BUILD_REMOVE_JUNGLE = GameInfoTypes.BUILD_REMOVE_JUNGLE
local BUILD_REMOVE_MARSH = GameInfoTypes.BUILD_REMOVE_MARSH
local MISSION_HURRY = GameInfoTypes.MISSION_HURRY
local BUILD_FEEDING_FIELD = GameInfoTypes.BUILD_FLESHBORN_FEEDING_FIELD
local BUILD_DIGEST_FOREST = GameInfoTypes.BUILD_FLESHBORN_DIGEST_FOREST
local BUILD_DIGEST_JUNGLE = GameInfoTypes.BUILD_FLESHBORN_DIGEST_JUNGLE
local BUILD_DIGEST_MARSH = GameInfoTypes.BUILD_FLESHBORN_DIGEST_MARSH
local YIELD_PRODUCTION = GameInfoTypes.YIELD_PRODUCTION
local TECH_CIVIL_SERVICE = GameInfoTypes.TECH_CIVIL_SERVICE
local TECH_FERTILIZER = GameInfoTypes.TECH_FERTILIZER
local TRADE_CONNECTION_FOOD = TradeConnectionTypes.TRADE_CONNECTION_FOOD
local FB_FOUNDING_CORE_FOOD = 4

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

-- Ruins must not bypass the one-resource economy. The CP goody-choice event
-- asks this handler before a reward is selected; returning true removes that
-- result from the eligible pool and lets the DLL choose another reward.
-- Build the set from reward fields instead of hard-coded IDs so compatible
-- goody mods and future CP rows receive the same protection.
local FB_BLOCKED_GOODIES = {}
for goody in GameInfo.GoodyHuts() do
    local grantsPopulation = (tonumber(goody.Population) or 0) > 0
    local grantsProduction = (tonumber(goody.Production) or 0) > 0
    local grantsSettler = goody.UnitClass == "UNITCLASS_SETTLER"
    if grantsPopulation or grantsProduction or grantsSettler then
        FB_BLOCKED_GOODIES[goody.ID] = true
    end
end

local FB_DIGEST_FOOD = {}
if BUILD_DIGEST_FOREST ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_FOREST] = 20 end
if BUILD_DIGEST_JUNGLE ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_JUNGLE] = 15 end
if BUILD_DIGEST_MARSH ~= nil then FB_DIGEST_FOOD[BUILD_DIGEST_MARSH] = 12 end

local FB_LEAGUE_PROCESSES = {}
for leagueProject in GameInfo.LeagueProjects() do
    local processID = GameInfoTypes[leagueProject.Process]
    if processID ~= nil then
        FB_LEAGUE_PROCESSES[processID] = leagueProject.ID
    end
end

local FB_UNIT_CLASS_OVERRIDES = {}
for override in GameInfo.Civilization_UnitClassOverrides{
    CivilizationType = "CIVILIZATION_FLESHBORN_CHORUS"
} do
    local classID = GameInfoTypes[override.UnitClassType]
    local unitID = GameInfoTypes[override.UnitType]
    if classID ~= nil and unitID ~= nil then
        FB_UNIT_CLASS_OVERRIDES[classID] = unitID
    end
end

local FB_BUILDING_REPLACEMENTS = {}
for override in GameInfo.Civilization_BuildingClassOverrides{
    CivilizationType = "CIVILIZATION_FLESHBORN_CHORUS"
} do
    local classInfo = GameInfo.BuildingClasses[override.BuildingClassType]
    local baseID = classInfo and GameInfoTypes[classInfo.DefaultBuilding] or nil
    local replacementID = override.BuildingType and GameInfoTypes[override.BuildingType] or nil
    if baseID ~= nil and replacementID ~= nil and baseID ~= replacementID then
        FB_BUILDING_REPLACEMENTS[baseID] = replacementID
    end
end

local FB_UNIT_ERA_FEED_X2 = {}
local FB_KILL_CACHE = {}
local FB_KILL_CACHE_TURN = -1
local FB_POPULATION_ROLLBACK = false
local FB_UNIT_CONVERSION = false
local FB_BALANCE_VP = Game.IsCustomModOption ~= nil and Game.IsCustomModOption("BALANCE_VP")
local FB_CITY_DUMMIES = {}
for _, buildingType in ipairs({
    "BUILDING_FLESHBORN_METABOLISM",
    "BUILDING_FLESHBORN_FOUNDING_CORE",
    "BUILDING_FLESHBORN_FIELD_FOOD",
    "BUILDING_FLESHBORN_EDIBLE_FOOD",
    "BUILDING_FLESHBORN_MEMORY",
    "BUILDING_FLESHBORN_PRODUCTION_SINK",
    "BUILDING_FLESHBORN_BLOOM"
}) do
    local buildingID = GameInfoTypes[buildingType]
    if buildingID ~= nil then
        table.insert(FB_CITY_DUMMIES, buildingID)
    end
end

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
    -- Acquired turn and coordinates isolate the ledger when a captured city
    -- reuses an ID or a city is razed and a later city receives that ID.
    return "FB_" .. prefix
        .. "_" .. tostring(playerID)
        .. "_" .. tostring(city:GetID())
        .. "_" .. tostring(city:GetGameTurnAcquired())
        .. "_" .. tostring(city:GetX())
        .. "_" .. tostring(city:GetY())
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
    local freeCount = city:GetNumFreeBuilding(buildingID) or 0
    local realTarget = math.max(0, count - freeCount)
    if city:GetNumRealBuilding(buildingID) ~= realTarget then
        city:SetNumRealBuilding(buildingID, realTarget)
    end
end

local function FB_ClearCityDummies(city)
    if city == nil then return end
    for _, buildingID in ipairs(FB_CITY_DUMMIES) do
        if (city:GetNumRealBuilding(buildingID) or 0) > 0 then
            city:SetNumRealBuilding(buildingID, 0)
        end
        if (city:GetNumFreeBuilding(buildingID) or 0) > 0 then
            city:SetNumFreeBuilding(buildingID, 0)
        end
    end
end

local function FB_IsManualCity(player, city)
    -- Human puppets have no usable production chooser. Treat them like AI
    -- cities so they retain population growth while autonomously growing an
    -- order instead of spending their complete surplus every turn.
    return player ~= nil and city ~= nil and player:IsHuman() and not city:IsPuppet()
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

local function FB_IsFeedingField(plot)
    if plot == nil then return false end
    local improvementType = plot:GetImprovementType()
    return improvementType == IMPROVEMENT_FARM
        or improvementType == IMPROVEMENT_FEEDING_FIELD_LEGACY
end

local function FB_CountAdjacentFeedingFields(plot)
    local count = 0
    for direction = 0, 5 do
        local adjacent = Map.PlotDirection(plot:GetX(), plot:GetY(), direction)
        if adjacent ~= nil
            and FB_IsFeedingField(adjacent)
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

local function FB_NormalizeCityBuildings(city)
    for baseID, replacementID in pairs(FB_BUILDING_REPLACEMENTS) do
        local baseReal = city:GetNumRealBuilding(baseID) or 0
        local baseFree = city:GetNumFreeBuilding(baseID) or 0
        if baseReal > 0 or baseFree > 0 then
            local hasReplacement = (city:GetNumRealBuilding(replacementID) or 0) > 0
                or (city:GetNumFreeBuilding(replacementID) or 0) > 0
            city:SetNumRealBuilding(baseID, 0)
            city:SetNumFreeBuilding(baseID, 0)
            if not hasReplacement then
                if baseFree > 0 then
                    city:SetNumFreeBuilding(replacementID, 1)
                else
                    city:SetNumRealBuilding(replacementID, 1)
                end
            end
        end
    end
end

local function FB_UpdateCityDummies(playerID, player, city)
    -- Captured and gifted cities can retain the previous civilization's
    -- default building type. Normalize overrides before resource consumption,
    -- maintenance, or city yields are evaluated.
    FB_NormalizeCityBuildings(city)
    FB_SetBuildingCount(city, BUILDING_METABOLISM, 1)
    -- The First Stomach must be able to establish its initial Feeding Fields
    -- before the full metabolism can otherwise deadlock a size-one capital.
    -- Only the current capital receives this core yield; later Brood Nodes pay
    -- the complete expansion burden described by the civilization design.
    FB_SetBuildingCount(city, BUILDING_FOUNDING_CORE, city:IsCapital() and 1 or 0)
    FB_SetBuildingCount(city, BUILDING_BLOOM, player:IsGoldenAge() and 1 or 0)
    FB_SetBuildingCount(city, BUILDING_MEMORY, 1 + math.floor(city:GetPopulation() / 5))

    -- Remove the previous sink, measure the city's whole raw hammer yield, and
    -- cancel it.  The Food ledger below separately restores its exact saved
    -- progress, including the engine's hundredth-hammer rounding.
    FB_SetBuildingCount(city, BUILDING_PRODUCTION_SINK, 0)
    FB_SetBuildingCount(
        city,
        BUILDING_PRODUCTION_SINK,
        math.max(0, city:GetBaseYieldRate(YIELD_PRODUCTION))
    )

    local adjacencyFood = 0
    local fieldRuleFood = 0
    local edibleFood = 0
    local team = Teams[player:GetTeam()]
    local hasCivilService = team ~= nil and TECH_CIVIL_SERVICE ~= nil
        and team:IsHasTech(TECH_CIVIL_SERVICE)
    local hasFertilizer = team ~= nil and TECH_FERTILIZER ~= nil
        and team:IsHasTech(TECH_FERTILIZER)

    for index = 0, city:GetNumCityPlots() - 1 do
        local plot = city:GetCityIndexPlot(index)
        if plot ~= nil
            and plot:GetOwner() == playerID
            and FB_IsWorkedBy(city, plot)
            and not plot:IsImprovementPillaged() then
            if FB_IsFeedingField(plot) then
                local freshWater = plot:IsFreshWater()

                -- The stock CP Farm already supplies its base Food, the Civil
                -- Service bonus on fresh water, and the Fertilizer bonus away
                -- from fresh water.  Add only the missing halves of the
                -- Feeding Field rules so the city still receives +1 for fresh
                -- water and both technology bonuses on every worked field.
                if freshWater then fieldRuleFood = fieldRuleFood + 1 end
                if hasCivilService and not freshWater then
                    fieldRuleFood = fieldRuleFood + 1
                end
                if hasFertilizer and freshWater then
                    fieldRuleFood = fieldRuleFood + 1
                end

                if FB_CountAdjacentFeedingFields(plot) >= 3 then
                    adjacencyFood = adjacencyFood + 1
                end
            end

            if plot:GetImprovementType() == IMPROVEMENT_PLANTATION
                and FB_EDIBLE_RESOURCES[plot:GetResourceType(-1)] then
                edibleFood = edibleFood + 2
            end
        end
    end

    FB_SetBuildingCount(city, BUILDING_FIELD_FOOD, fieldRuleFood + adjacencyFood)
    FB_SetBuildingCount(city, BUILDING_EDIBLE_FOOD, edibleFood)
end

local function FB_MigrateLegacyFeedingFields()
    if IMPROVEMENT_FEEDING_FIELD_LEGACY == nil
        or IMPROVEMENT_FARM == nil
        or IMPROVEMENT_FEEDING_FIELD_LEGACY == IMPROVEMENT_FARM then
        return
    end

    local migrated = 0
    for plotIndex = 0, Map.GetNumPlots() - 1 do
        local plot = Map.GetPlotByIndex(plotIndex)
        if plot ~= nil
            and plot:GetImprovementType() == IMPROVEMENT_FEEDING_FIELD_LEGACY then
            local pillaged = plot:IsImprovementPillaged()
            plot:SetImprovementType(IMPROVEMENT_FARM)
            if pillaged and plot.SetImprovementPillaged ~= nil then
                plot:SetImprovementPillaged(true)
            end
            migrated = migrated + 1
        end
    end

    if migrated > 0 then
        print("Fleshborn: migrated " .. tostring(migrated)
            .. " legacy Feeding Fields to visible stock Farms")
    end
end

local function FB_EnsurePlayerInvariants(player)
    if POLICY_INVARIANTS ~= nil and not player:HasPolicy(POLICY_INVARIANTS) then
        player:SetHasPolicy(POLICY_INVARIANTS, true)
    end

    -- Prevent automatic Great Person/religious purchases from firing before
    -- the next currency digestion pass.  Manual purchases are made
    -- unaffordable by the dummy policy and checked again by completion hooks.
    if player.SetDisableAutomaticFaithPurchase ~= nil then
        player:SetDisableAutomaticFaithPurchase(true)
    end

    local ok, baseMaintenance = pcall(function()
        return player:GetBaseBuildingMaintenance()
    end)
    -- The DLL setter clamps the real treasury base to zero.  This is exact
    -- accounting: free buildings, captured buildings, and maintenance
    -- modifiers cannot turn a nominal Lua refund into profit.
    player:SetBaseBuildingGoldMaintenance(0)
    return ok and math.max(0, tonumber(baseMaintenance) or 0) or 0
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
        if FB_LEAGUE_PROCESSES[processType] then
            return {kind = "LEAGUE", id = processType, signature = "L" .. tostring(processType)}
        end
        return {kind = "PROCESS", id = processType, signature = "X" .. tostring(processType)}
    end

    return {kind = "GROWTH", id = -1, signature = "GROWTH"}
end

local function FB_GetFoodMultiplier(city, order)
    if order.kind == "LEAGUE" then
        return 1000
    end

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
    if #cities == 0 then
        return 0
    end

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

    if food <= 0 then
        return 0
    end

    local each = math.floor(food / #cities)
    local remainder = food - (each * #cities)
    for index, city in ipairs(cities) do
        FB_QueueCityFood(playerID, city, each + (index <= remainder and 1 or 0))
    end
    return food
end

local function FB_DigestAvailableCurrency(playerID)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return 0 end
    local cities = {}
    for city in player:Cities() do
        table.insert(cities, city)
    end
    return FB_DigestCurrency(playerID, player, cities)
end

local function FB_IsPlayerAtWar(player)
    local team = Teams[player:GetTeam()]
    if team == nil then return false end
    local ok, count = pcall(function() return team:GetAtWarCount(true) end)
    return ok and count ~= nil and count > 0
end

local function FB_SuppressHappinessGoldenAge(playerID, player)
    -- PlayerDoTurn fires after the DLL processes Golden Age progress.  Keep a
    -- one-turn reservation equal to the DLL's Happiness-for-GAP value: the next DLL tick pays
    -- that reservation back, while points from policies, wonders, events, and
    -- Great People remain untouched.  This also prevents a Happiness tick from
    -- crossing the threshold before Lua can repair it.
    local reserveKey = "FB_GA_RESERVE_" .. tostring(playerID)
    local reserve = FB_GetSavedNumber(reserveKey, 0)
    local happinessPoints = tonumber(player:GetHappinessForGAP()) or 0
    local meterRuns = FB_BALANCE_VP or not player:IsGoldenAge()
    local happinessApplied = meterRuns and happinessPoints or 0
    local correction = reserve - happinessApplied
    if correction ~= 0 then
        player:ChangeGoldenAgeProgressMeter(correction)
    end

    local nextReserve = 0
    if meterRuns then
        if happinessPoints > 0 then
            nextReserve = math.min(happinessPoints, math.max(0, player:GetGoldenAgeProgressMeter()))
        else
            nextReserve = happinessPoints
        end
        if nextReserve ~= 0 then
            player:ChangeGoldenAgeProgressMeter(-nextReserve)
        end
    end
    FB_SetSavedNumber(reserveKey, nextReserve)
end

local function FB_GetFoodToSpend(player, city, order, availableFood)
    local foodToSpend = availableFood
    if not FB_IsManualCity(player, city) then
        local ratio = 0.40
        if order.kind == "UNIT" and order.id == UNIT_BUD then
            ratio = 0.60
        elseif FB_IsPlayerAtWar(player) and order.kind == "UNIT" and FB_IsMilitaryUnitType(order.id) then
            ratio = 0.70
        end
        foodToSpend = math.floor(availableFood * ratio)
        if availableFood > 0 and foodToSpend < 1 then foodToSpend = 1 end
    end
    return math.max(0, foodToSpend)
end

local function FB_ApplyFoodProject(playerID, player, city, order, availableFood, hungerTier)
    if availableFood <= 0 then
        return 0, 0, FB_GetFoodMultiplier(city, order)
    end

    if hungerTier >= 7 and order.kind == "UNIT" and FB_IsMilitaryUnitType(order.id) then
        return 0, 0, FB_GetFoodMultiplier(city, order)
    end

    local foodToSpend = FB_GetFoodToSpend(player, city, order, availableFood)

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
        if storedProgress + productionGain >= city:GetProductionNeeded() then
            FB_SetSavedNumber(
                FB_OrderKey("AUTH", playerID, city, order.signature),
                Game.GetGameTurn() + 1
            )
        end
        city:ChangeProduction(productionGain)
    end

    local currentOrder = FB_GetOrder(city)
    if currentOrder.signature == order.signature then
        FB_SetSavedNumber(progressKey, city:GetProduction())
        FB_SetSavedNumber(creditKey, credit)
    else
        FB_SetSavedNumber(progressKey, 0)
        FB_SetSavedNumber(creditKey, 0)
        FB_SetSavedNumber(FB_OrderKey("AUTH", playerID, city, order.signature), 0)
    end

    return foodToSpend, productionGain, multiplier
end

local function FB_ApplyLeagueProcess(playerID, player, city, order, availableFood)
    local league = Game.GetActiveLeague()
    local leagueProjectID = FB_LEAGUE_PROCESSES[order.id]
    if league == nil or leagueProjectID == nil
        or not league:IsProjectActive(leagueProjectID)
        or league:IsProjectComplete(leagueProjectID) then
        city:SetOverflowProduction(0)
        city:SetFeatureProduction(0)
        return 0, 0, 1000
    end

    local foodToSpend = FB_GetFoodToSpend(player, city, order, availableFood)

    -- CP counts World Congress work as city Production plus overflow during
    -- the following global League update.  Track hundredth-hammer credit so
    -- fractional native yield and legacy Production-route residue are charged
    -- against Food rather than becoming free Congress contribution.
    local creditKey = FB_OrderKey("LEAGUE_CREDIT", playerID, city, order.signature)
    local creditX100 = FB_GetSavedNumber(creditKey, 0) + (foodToSpend * 100)
    local nativeX100 = city:GetYieldRateTimes100(YIELD_PRODUCTION)
    local overflow = math.max(0, math.floor((creditX100 - nativeX100) / 100))
    local contributionX100 = nativeX100 + (overflow * 100)
    if contributionX100 < 0 then
        overflow = math.max(0, math.ceil((-nativeX100) / 100))
        contributionX100 = nativeX100 + (overflow * 100)
    end

    city:SetFeatureProduction(0)
    city:SetOverflowProduction(overflow)
    FB_SetSavedNumber(creditKey, creditX100 - contributionX100)
    return foodToSpend, math.max(0, math.floor(contributionX100 / 100)), 1000
end

local function FB_ClearLeagueOverflow(city)
    if city:GetOverflowProduction() ~= 0 then
        city:SetOverflowProduction(0)
    end
    if city:GetFeatureProduction() ~= 0 then
        city:SetFeatureProduction(0)
    end
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

local function FB_GetFleshbornUnitForClass(unitType)
    local unitInfo = GameInfo.Units[unitType]
    if unitInfo == nil or unitInfo.Class == nil then
        return nil
    end
    return FB_UNIT_CLASS_OVERRIDES[GameInfoTypes[unitInfo.Class]]
end

local function FB_NormalizeUnits(player)
    if FB_UNIT_CONVERSION then return end

    local units = {}
    for unit in player:Units() do
        table.insert(units, unit)
    end

    FB_UNIT_CONVERSION = true
    for _, unit in ipairs(units) do
        local current = player:GetUnitByID(unit:GetID())
        if current ~= nil then
            local currentType = current:GetUnitType()
            local targetType = FB_GetFleshbornUnitForClass(currentType)
            if targetType ~= nil and targetType ~= currentType then
                local replacement = player:InitUnit(
                    targetType,
                    current:GetX(),
                    current:GetY(),
                    current:GetUnitAIType(),
                    current:GetFacingDirection()
                )
                if replacement ~= nil then
                    replacement:Convert(current, false, false)
                end
            end
        end
    end
    FB_UNIT_CONVERSION = false
end

local function FB_ProcessPlayerTurn(playerID)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then
        -- NeverCapture normally removes these state buildings during conquest,
        -- but peaceful city trades and some liberation paths do not use the
        -- ordinary conquest cleanup. Scrub them from every non-Chorus owner.
        if player ~= nil and player:IsAlive() then
            for city in player:Cities() do
                FB_ClearCityDummies(city)
            end
        end
        return
    end

    local cities = {}
    local cityData = {}
    local totalPreArmySupply = 0

    local maintenanceSuppressed = FB_EnsurePlayerInvariants(player)
    FB_NormalizeUnits(player)

    for city in player:Cities() do
        table.insert(cities, city)
        FB_UpdateCityDummies(playerID, player, city)
    end

    local currencyFood = FB_DigestCurrency(playerID, player, cities)
    FB_SuppressHappinessGoldenAge(playerID, player)

    for _, city in ipairs(cities) do
        local gross = FB_GetGrossFood(city)
        local metabolic = FB_GetMetabolicBurden(city)
        local pending = FB_GetPendingFood(playerID, city)
        local preArmy = math.max(0, gross + pending - metabolic)
        totalPreArmySupply = totalPreArmySupply + preArmy
        table.insert(cityData, {
            city = city,
            gross = gross,
            metabolic = metabolic,
            pending = pending,
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
        local pending = data.pending
        local usable = math.max(0, data.preArmy - data.army)
        local net = data.gross + pending - data.metabolic - data.army
        local nativeSurplus = math.max(0, data.gross - data.metabolic)
        local pendingAfterMetabolism = math.max(0, pending - math.max(0, data.metabolic - data.gross))
        local pendingForProject = math.max(0, pendingAfterMetabolism - math.max(0, data.army - nativeSurplus))
        local foodSpent = 0
        local productionGain = 0
        local multiplier = 0
        local manualCity = FB_IsManualCity(player, city)

        if order.kind == "UNIT" or order.kind == "BUILDING" or order.kind == "PROJECT" or order.kind == "LEAGUE" then
            if manualCity then
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

            if order.kind == "LEAGUE" then
                foodSpent, productionGain, multiplier = FB_ApplyLeagueProcess(
                    playerID, player, city, order, usable
                )
            else
                FB_ClearLeagueOverflow(city)
                foodSpent, productionGain, multiplier = FB_ApplyFoodProject(
                    playerID, player, city, order, usable, hungerTier
                )
            end

            if manualCity then
                FB_SetPendingFood(playerID, city, math.max(0, pendingForProject - foodSpent))
            else
                -- Gross city Food is applied by the engine.  Subtract only the
                -- biological burdens and the AI allocation sent to the order;
                -- pending digestion is an external injection and is added here.
                city:ChangeFood(pending - foodSpent)
                FB_SetPendingFood(playerID, city, 0)
            end
        else
            FB_ClearLeagueOverflow(city)
            local frozenKey = FB_CityKey("FROZEN", playerID, city)
            local frozen = FB_GetSavedNumber(frozenKey, -1)
            if manualCity and frozen >= 0 then
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
            if order.kind ~= "LEAGUE" then
                foodCost = math.ceil((city:GetProductionNeeded() * multiplier) / 1000)
            end
        end

        table.insert(statusCities, {
            id = city:GetID(),
            name = city:GetName(),
            population = city:GetPopulation(),
            storedFood = city:GetFood(),
            growthNeeded = city:GrowthThreshold(),
            grossFood = data.gross,
            injectedFood = data.pending,
            foundingCoreFood = FB_HasBuilding(city, BUILDING_FOUNDING_CORE) and FB_FOUNDING_CORE_FOOD or 0,
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
        FB_SetSavedNumber(FB_CityKey("BASE_FOOD", playerID, city), city:GetFood())
    end

    local oldTier = FB_GetSavedNumber("FB_HUNGER_TIER_" .. tostring(playerID), 0)
    FB_SetSavedNumber("FB_HUNGER_TIER_" .. tostring(playerID), hungerTier)
    FB_ApplyHungerPromotions(player, hungerTier)
    FB_NotifyHungerChange(playerID, player, oldTier, hungerTier)

    local totalBaseSurplus = 0
    local totalQueuedFood = 0
    local totalMetabolism = 0
    local totalArmyBurden = 0
    local totalProjectSpend = 0
    local totalUsableFood = 0
    local totalAvailable = 0
    local totalStoredFood = 0
    local strainedCities = 0
    for _, cityStatus in ipairs(statusCities) do
        local usable = math.max(0, cityStatus.netFood or 0)
        totalBaseSurplus = totalBaseSurplus + (cityStatus.grossFood or 0)
        totalQueuedFood = totalQueuedFood + (cityStatus.injectedFood or 0)
        totalMetabolism = totalMetabolism + (cityStatus.metabolicBurden or 0)
        totalArmyBurden = totalArmyBurden + (cityStatus.armyBurden or 0)
        totalProjectSpend = totalProjectSpend + (cityStatus.foodSpent or 0)
        totalUsableFood = totalUsableFood + usable
        totalAvailable = totalAvailable + math.max(0, usable - (cityStatus.foodSpent or 0))
        totalStoredFood = totalStoredFood + (cityStatus.storedFood or 0)
        if (cityStatus.netFood or 0) < 0 then strainedCities = strainedCities + 1 end
    end

    MapModData.FleshbornStatus[playerID] = {
        turn = Game.GetGameTurn(),
        armyDemand = armyDemand,
        armyFed = armyFed,
        preArmySupply = totalPreArmySupply,
        hungerTier = hungerTier,
        currencyFood = currencyFood,
        maintenanceSuppressed = maintenanceSuppressed,
        baseSurplus = totalBaseSurplus,
        queuedFood = totalQueuedFood,
        metabolicBurden = totalMetabolism,
        armyBurden = totalArmyBurden,
        projectSpend = totalProjectSpend,
        usableFood = totalUsableFood,
        availableFood = totalAvailable,
        storedFood = totalStoredFood,
        strainedCities = strainedCities,
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
        return processType == PROCESS_GROWTH or FB_LEAGUE_PROCESSES[processType] ~= nil
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
    if fleshborn and (buildType == BUILD_FARM
        or buildType == BUILD_REMOVE_FOREST
        or buildType == BUILD_REMOVE_JUNGLE
        or buildType == BUILD_REMOVE_MARSH) then
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
    FB_SetSavedNumber(FB_OrderKey("AUTH", playerID, city, signature), 0)
end

local function FB_ClearBuildingProgress(playerID, city, buildingType)
    if city == nil or buildingType == nil then return end
    local signature = "B" .. tostring(buildingType)
    FB_SetSavedNumber(FB_OrderKey("PROGRESS", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("CREDIT", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("AUTH", playerID, city, signature), 0)
end

local function FB_ClearProjectProgress(playerID, city, projectType)
    if city == nil or projectType == nil then return end
    local signature = "P" .. tostring(projectType)
    FB_SetSavedNumber(FB_OrderKey("PROGRESS", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("CREDIT", playerID, city, signature), 0)
    FB_SetSavedNumber(FB_OrderKey("AUTH", playerID, city, signature), 0)
end

local function FB_ConsumeCompletionAuthorization(playerID, city, signature)
    local key = FB_OrderKey("AUTH", playerID, city, signature)
    local expiryTurn = FB_GetSavedNumber(key, -1)
    local savedProgress = FB_GetSavedNumber(FB_OrderKey("PROGRESS", playerID, city, signature), 0)
    FB_SetSavedNumber(key, 0)
    -- Dynamic costs can fall between turns (for example when an instance-cost
    -- unit dies).  Saved ledger progress at or above the current requirement
    -- is still entirely Food-grown and must remain valid after the token ages.
    return expiryTurn >= Game.GetGameTurn() or savedProgress >= city:GetProductionNeeded()
end

local function FB_NotifyRejectedCompletion(playerID, player, description)
    if playerID ~= Game.GetActivePlayer() then return end
    player:AddNotification(
        NotificationTypes.NOTIFICATION_GENERIC,
        tostring(description) .. " was rejected: the Chorus can complete orders only through Food growth.",
        "All Is Sustenance"
    )
end

local function FB_OnCityTrained(playerID, cityID, unitID, bGold, bFaith)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    local city = player:GetCityByID(cityID)
    local unit = player:GetUnitByID(unitID)
    if city == nil or unit == nil then return end

    local unitType = unit:GetUnitType()
    local authorized = not bGold and not bFaith
        and FB_ConsumeCompletionAuthorization(playerID, city, "U" .. tostring(unitType))
    if not authorized then
        local unitInfo = GameInfo.Units[unitType]
        unit:Kill(true, -1)
        FB_NotifyRejectedCompletion(playerID, player, unitInfo and Locale.ConvertTextKey(unitInfo.Description) or "Unit")
        return
    end

    FB_ClearUnitProgress(playerID, city, unitType)
    if unitType == UNIT_BUD and city:GetPopulation() > 1 then
        city:ChangePopulation(-1, true)
    end
end

local function FB_OnCityConstructed(playerID, cityID, buildingType, bGold, bFaith)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    local city = player:GetCityByID(cityID)
    if city == nil then return end

    local authorized = not bGold and not bFaith
        and FB_ConsumeCompletionAuthorization(playerID, city, "B" .. tostring(buildingType))
    if not authorized then
        local realCount = city:GetNumRealBuilding(buildingType)
        if realCount > 0 then
            city:SetNumRealBuilding(buildingType, realCount - 1)
        end
        local buildingInfo = GameInfo.Buildings[buildingType]
        FB_NotifyRejectedCompletion(playerID, player, buildingInfo and Locale.ConvertTextKey(buildingInfo.Description) or "Building")
        return
    end

    FB_ClearBuildingProgress(playerID, city, buildingType)
end

local function FB_OnCityCreated(playerID, cityID, projectType, bGold, bFaith)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    local city = player:GetCityByID(cityID)
    if city == nil then return end

    local authorized = not bGold and not bFaith
        and FB_ConsumeCompletionAuthorization(playerID, city, "P" .. tostring(projectType))
    if not authorized then
        local team = Teams[player:GetTeam()]
        if team ~= nil and team:GetProjectCount(projectType) > 0 then
            team:ChangeProjectCount(projectType, -1)
        end
        local projectInfo = GameInfo.Projects[projectType]
        FB_NotifyRejectedCompletion(playerID, player, projectInfo and Locale.ConvertTextKey(projectInfo.Description) or "Project")
        return
    end

    FB_ClearProjectProgress(playerID, city, projectType)
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
    local gameTurn = Game.GetGameTurn()
    if gameTurn ~= FB_KILL_CACHE_TURN then
        FB_KILL_CACHE = {}
        FB_KILL_CACHE_TURN = gameTurn
    end

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

local function FB_OnSetPopulation(x, y, oldPopulation, newPopulation)
    if FB_POPULATION_ROLLBACK or newPopulation <= oldPopulation then return end

    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if city == nil then return end
    local playerID = city:GetOwner()
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end
    if not FB_IsManualCity(player, city) then return end

    local order = FB_GetOrder(city)
    if order.kind == "GROWTH" then return end

    local frozenKey = FB_CityKey("FROZEN", playerID, city)
    local frozen = FB_GetSavedNumber(frozenKey, -1)
    if frozen < 0 then
        frozen = FB_GetSavedNumber(FB_CityKey("BASE_FOOD", playerID, city), city:GetFood())
    end

    -- Use ChangePopulation rather than SetPopulation so the outer DLL growth
    -- call and this rollback also cancel their religion population deltas.
    FB_POPULATION_ROLLBACK = true
    city:ChangePopulation(oldPopulation - newPopulation, true)
    FB_POPULATION_ROLLBACK = false
    FB_SetFood(city, frozen)
    FB_SetSavedNumber(frozenKey, frozen)
    FB_SetSavedNumber(FB_CityKey("BASE_FOOD", playerID, city), frozen)
end

local function FB_OnPlayerDoneTurn(playerID)
    local player = Players[playerID]
    if not FB_IsFleshbornPlayer(player) then return end

    FB_EnsurePlayerInvariants(player)
    for city in player:Cities() do
        FB_UpdateCityDummies(playerID, player, city)
        local order = FB_GetOrder(city)
        local manualCity = FB_IsManualCity(player, city)
        if manualCity and order.kind ~= "GROWTH" then
            FB_SetSavedNumber(FB_CityKey("FROZEN", playerID, city), city:GetFood())
        elseif manualCity then
            FB_SetSavedNumber(FB_CityKey("FROZEN", playerID, city), -1)
        end
        if order.kind ~= "LEAGUE" then
            FB_ClearLeagueOverflow(city)
        end
        FB_SetSavedNumber(FB_CityKey("BASE_FOOD", playerID, city), city:GetFood())
    end
end

local function FB_CityCanBuyAnyPlot(playerID, cityID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_CityCanBuyPlot(playerID, cityID, x, y)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_UnitCanUpgrade(playerID, unitID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_PlayerCanGiftGold(playerID, minorID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_PlayerCanGiftImprovement(playerID, minorID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_PlayerCanBuyOut(playerID, minorID)
    return not FB_IsFleshbornPlayer(Players[playerID])
end

local function FB_CanStartMission(playerID, unitID, missionType)
    if FB_IsFleshbornPlayer(Players[playerID]) and missionType == MISSION_HURRY then
        return false
    end
    return true
end

local function FB_PlayerCanCreateTradeRoute(fromPlayerID, fromCityID, toPlayerID, toCityID, domainType, connectionType)
    if FB_IsFleshbornPlayer(Players[fromPlayerID]) and fromPlayerID == toPlayerID then
        return connectionType == TRADE_CONNECTION_FOOD
    end
    return true
end

local function FB_GoodyHutCanNotReceive(playerID, unitID, goodyType, bPick)
    return FB_IsFleshbornPlayer(Players[playerID])
        and FB_BLOCKED_GOODIES[goodyType] == true
end

local function FB_OnUnitCaptureType(playerID, unitID, unitType, byCivilization)
    if byCivilization ~= CIV_FLESHBORN then return unitType end
    return FB_GetFleshbornUnitForClass(unitType) or unitType
end

local function FB_OnMinorGift(minorID, majorID, data2, data3, flags, option1, option2, giftType)
    if not FB_IsFleshbornPlayer(Players[majorID]) then return end
    -- First-contact gifts are already applied when this hook fires. Digest any
    -- Gold/Faith immediately, and normalize a possible militaristic unit.
    FB_DigestAvailableCurrency(majorID)
    FB_NormalizeUnits(Players[majorID])
end

local function FB_OnMinorGiftUnit(minorID, majorID, unitType)
    if FB_IsFleshbornPlayer(Players[majorID]) then
        FB_NormalizeUnits(Players[majorID])
    end
end

local function FB_OnPlayerBullied(playerID, minorID, gold, unitType, x, y, yieldType)
    if not FB_IsFleshbornPlayer(Players[playerID]) then return end
    -- Tribute is awarded before this hook. It therefore cannot become a
    -- same-turn city-state or tile-improvement spending window.
    if (tonumber(gold) or -1) > 0 then
        FB_DigestAvailableCurrency(playerID)
    end
    if (tonumber(unitType) or -1) >= 0 then
        FB_NormalizeUnits(Players[playerID])
    end
end

local function FB_OnCityCaptureComplete(oldOwnerID, isCapital, x, y, newOwnerID)
    local player = Players[newOwnerID]
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if city == nil or city:GetOwner() ~= newOwnerID then return end

    if not FB_IsFleshbornPlayer(player) then
        FB_ClearCityDummies(city)
        return
    end

    FB_EnsurePlayerInvariants(player)
    FB_UpdateCityDummies(newOwnerID, player, city)
    FB_SetProduction(city, 0)
    FB_ClearLeagueOverflow(city)
    FB_SetSavedNumber(FB_CityKey("FROZEN", newOwnerID, city), -1)
    FB_SetSavedNumber(FB_CityKey("BASE_FOOD", newOwnerID, city), city:GetFood())
end

local function FB_OnPlayerLiberated(liberatorID, restoredPlayerID, cityID)
    local player = Players[restoredPlayerID]
    local city = player and player:GetCityByID(cityID) or nil
    if city == nil then return end

    if FB_IsFleshbornPlayer(player) then
        FB_EnsurePlayerInvariants(player)
        FB_UpdateCityDummies(restoredPlayerID, player, city)
        FB_SetProduction(city, 0)
        FB_ClearLeagueOverflow(city)
        FB_SetSavedNumber(FB_CityKey("FROZEN", restoredPlayerID, city), -1)
        FB_SetSavedNumber(FB_CityKey("BASE_FOOD", restoredPlayerID, city), city:GetFood())
    else
        FB_ClearCityDummies(city)
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
if GameEvents.CityCreated ~= nil then
    GameEvents.CityCreated.Add(FB_OnCityCreated)
end
if GameEvents.PlayerBuilt ~= nil then
    GameEvents.PlayerBuilt.Add(FB_OnPlayerBuilt)
end
if GameEvents.UnitPrekill ~= nil then
    GameEvents.UnitPrekill.Add(FB_OnUnitPrekill)
end
if GameEvents.SetPopulation ~= nil then
    GameEvents.SetPopulation.Add(FB_OnSetPopulation)
end
if GameEvents.PlayerDoneTurn ~= nil then
    GameEvents.PlayerDoneTurn.Add(FB_OnPlayerDoneTurn)
end
if GameEvents.CityCanBuyAnyPlot ~= nil then
    GameEvents.CityCanBuyAnyPlot.Add(FB_CityCanBuyAnyPlot)
end
if GameEvents.CityCanBuyPlot ~= nil then
    GameEvents.CityCanBuyPlot.Add(FB_CityCanBuyPlot)
end
if GameEvents.CanHaveAnyUpgrade ~= nil then
    GameEvents.CanHaveAnyUpgrade.Add(FB_UnitCanUpgrade)
end
if GameEvents.UnitCanHaveAnyUpgrade ~= nil then
    GameEvents.UnitCanHaveAnyUpgrade.Add(FB_UnitCanUpgrade)
end
if GameEvents.CanHaveUpgrade ~= nil then
    GameEvents.CanHaveUpgrade.Add(FB_UnitCanUpgrade)
end
if GameEvents.UnitCanHaveUpgrade ~= nil then
    GameEvents.UnitCanHaveUpgrade.Add(FB_UnitCanUpgrade)
end
if GameEvents.PlayerCanGiftGold ~= nil then
    GameEvents.PlayerCanGiftGold.Add(FB_PlayerCanGiftGold)
end
if GameEvents.PlayerCanGiftImprovement ~= nil then
    GameEvents.PlayerCanGiftImprovement.Add(FB_PlayerCanGiftImprovement)
end
if GameEvents.PlayerCanBuyOut ~= nil then
    GameEvents.PlayerCanBuyOut.Add(FB_PlayerCanBuyOut)
end
if GameEvents.CanStartMission ~= nil then
    GameEvents.CanStartMission.Add(FB_CanStartMission)
end
if GameEvents.PlayerCanCreateTradeRoute ~= nil then
    GameEvents.PlayerCanCreateTradeRoute.Add(FB_PlayerCanCreateTradeRoute)
end
if GameEvents.GoodyHutCanNotReceive ~= nil then
    GameEvents.GoodyHutCanNotReceive.Add(FB_GoodyHutCanNotReceive)
end
if GameEvents.UnitCaptureType ~= nil then
    GameEvents.UnitCaptureType.Add(FB_OnUnitCaptureType)
end
if GameEvents.MinorGift ~= nil then
    GameEvents.MinorGift.Add(FB_OnMinorGift)
end
if GameEvents.MinorGiftUnit ~= nil then
    GameEvents.MinorGiftUnit.Add(FB_OnMinorGiftUnit)
end
if GameEvents.PlayerBullied ~= nil then
    GameEvents.PlayerBullied.Add(FB_OnPlayerBullied)
end
if GameEvents.CityCaptureComplete ~= nil then
    GameEvents.CityCaptureComplete.Add(FB_OnCityCaptureComplete)
end
if GameEvents.PlayerLiberated ~= nil then
    GameEvents.PlayerLiberated.Add(FB_OnPlayerLiberated)
end

-- Make the production suppression and visible city yields correct immediately
-- after a save loads; project conversion itself waits for PlayerDoTurn.
local function FB_Initialize()
    -- Existing saves may contain the distinct, invisible improvement used by
    -- earlier versions.  Convert it before city yields are calculated; new
    -- Harvester builds already place the real Farm type directly.
    FB_MigrateLegacyFeedingFields()
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local player = Players[playerID]
        if FB_IsFleshbornPlayer(player) then
            FB_EnsurePlayerInvariants(player)
            FB_NormalizeUnits(player)
            for city in player:Cities() do
                FB_UpdateCityDummies(playerID, player, city)
                FB_SetSavedNumber(FB_CityKey("BASE_FOOD", playerID, city), city:GetFood())
            end
        end
    end
end

if Events.LoadScreenClose ~= nil then
    Events.LoadScreenClose.Add(FB_Initialize)
end
