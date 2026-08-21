-- ============================================================================
-- The Fleshborn Chorus
-- Core database
-- Target: Civilization V BNW + Community Patch
-- ============================================================================

-- The Lua systems use these CP events.  Updating an absent option is harmless;
-- the Community Patch dependency in the modinfo ensures the rows normally exist.
CREATE TABLE IF NOT EXISTS CustomModOptions
(Name TEXT PRIMARY KEY, Value INTEGER DEFAULT 1, Class INTEGER DEFAULT 5, DbUpdates INTEGER DEFAULT 0);
UPDATE CustomModOptions
SET Value = 1
WHERE Name IN (
  'EVENTS_CITY',
  'EVENTS_FOUND_RELIGION',
  'EVENTS_GOODY_CHOICE',
  'EVENTS_LIBERATION',
  'EVENTS_MINORS_GIFTS',
  'EVENTS_MINORS_INTERACTION',
  'EVENTS_PLAYER_TURN',
  'EVENTS_PLOT',
  'EVENTS_TILE_IMPROVEMENTS',
  'EVENTS_TRADE_ROUTES',
  'EVENTS_UNIT_CAPTURE',
  'EVENTS_UNIT_PREKILL',
  'EVENTS_UNIT_UPGRADES'
);

-- --------------------------------------------------------------------------
-- Identity
-- Placeholder presentation deliberately reuses stock American/Washington art.
-- DawnOfManAudio is explicitly empty: this mod has no Dawn of Man sound.
-- --------------------------------------------------------------------------

INSERT OR REPLACE INTO Colors (Type, Red, Green, Blue, Alpha) VALUES
('COLOR_FLESHBORN_PRIMARY',   0.24, 0.035, 0.055, 1),
('COLOR_FLESHBORN_SECONDARY', 0.91, 0.72, 0.48,  1);

INSERT OR REPLACE INTO PlayerColors (Type, PrimaryColor, SecondaryColor, TextColor) VALUES
('PLAYERCOLOR_FLESHBORN', 'COLOR_FLESHBORN_PRIMARY', 'COLOR_FLESHBORN_SECONDARY', 'COLOR_PLAYER_WHITE_TEXT');

INSERT INTO Traits
(Type, Description, ShortDescription, CityUnhappinessModifier, PopulationUnhappinessModifier,
 LandUnitMaintenanceModifier, NavalUnitMaintenanceModifier, ImprovementMaintenanceModifier,
 WonderProductionModifier, WorkerSpeedModifier)
VALUES
('TRAIT_FLESHBORN_ALL_IS_SUSTENANCE',
 'TXT_KEY_TRAIT_FLESHBORN_ALL_IS_SUSTENANCE_HELP',
 'TXT_KEY_TRAIT_FLESHBORN_ALL_IS_SUSTENANCE_SHORT',
 -100, -100, -100, -100, -100, -100, 15);

-- A CP dummy policy supplies engine-level invariants which cannot safely be
-- emulated with yield refunds.  IsDummy keeps it out of the policy tree,
-- policy counts, score, and ideology prerequisites.  Lua grants it only to
-- the Chorus and also keeps automatic Faith purchasing disabled.
INSERT INTO Policies
(Type, Description, Civilopedia, Help, PolicyBranchType, CultureCost, GridX, GridY,
 IsDummy, BuildingGoldMaintenanceMod, UnitGoldMaintenanceMod,
 RouteGoldMaintenanceMod, UnitPurchaseCostModifier,
 BuildingPurchaseCostModifier, PlotGoldCostMod, FaithCostModifier,
 UnhappinessMod)
VALUES
('POLICY_FLESHBORN_INVARIANTS', 'TXT_KEY_TRAIT_FLESHBORN_ALL_IS_SUSTENANCE_SHORT',
 'TXT_KEY_TRAIT_FLESHBORN_ALL_IS_SUSTENANCE_HELP',
 'TXT_KEY_TRAIT_FLESHBORN_ALL_IS_SUSTENANCE_HELP', NULL, -1, -1, -1,
 1, -100, -100, 0, 100000, 100000, 100000, 100000, -100);

INSERT INTO Leaders
(Type, Description, Civilopedia, CivilopediaTag, ArtDefineTag,
 VictoryCompetitiveness, WonderCompetitiveness, MinorCivCompetitiveness,
 Boldness, DiploBalance, WarmongerHate, WorkAgainstWillingness,
 WorkWithWillingness, DenounceWillingness, DoFWillingness, Loyalty,
 Neediness, Forgiveness, Chattiness, Meanness, PortraitIndex, IconAtlas)
SELECT
 'LEADER_FLESHBORN_FIRST_MAW',
 'TXT_KEY_LEADER_FLESHBORN_FIRST_MAW',
 'TXT_KEY_LEADER_FLESHBORN_FIRST_MAW_PEDIA',
 'TXT_KEY_CIVILOPEDIA_LEADERS_FLESHBORN_FIRST_MAW',
 ArtDefineTag,
 9, 1, 8, 10, 3, 2, 9, 3, 8, 2, 9, 4, 2, 3, 9,
 PortraitIndex, IconAtlas
FROM Leaders WHERE Type = 'LEADER_WASHINGTON';

INSERT INTO Leader_Traits (LeaderType, TraitType) VALUES
('LEADER_FLESHBORN_FIRST_MAW', 'TRAIT_FLESHBORN_ALL_IS_SUSTENANCE');

INSERT INTO Leader_MajorCivApproachBiases
SELECT 'LEADER_FLESHBORN_FIRST_MAW', MajorCivApproachType, Bias
FROM Leader_MajorCivApproachBiases WHERE LeaderType = 'LEADER_ATTILA';

INSERT INTO Leader_MinorCivApproachBiases
SELECT 'LEADER_FLESHBORN_FIRST_MAW', MinorCivApproachType, Bias
FROM Leader_MinorCivApproachBiases WHERE LeaderType = 'LEADER_ATTILA';

INSERT INTO Leader_Flavors
SELECT 'LEADER_FLESHBORN_FIRST_MAW', FlavorType, Flavor
FROM Leader_Flavors WHERE LeaderType = 'LEADER_ATTILA';

UPDATE Leader_Flavors SET Flavor = 10
WHERE LeaderType = 'LEADER_FLESHBORN_FIRST_MAW'
  AND FlavorType IN ('FLAVOR_GROWTH', 'FLAVOR_EXPANSION', 'FLAVOR_OFFENSE');
UPDATE Leader_Flavors SET Flavor = 8
WHERE LeaderType = 'LEADER_FLESHBORN_FIRST_MAW'
  AND FlavorType IN ('FLAVOR_SCIENCE', 'FLAVOR_TILE_IMPROVEMENT', 'FLAVOR_MOBILE');
UPDATE Leader_Flavors SET Flavor = 0
WHERE LeaderType = 'LEADER_FLESHBORN_FIRST_MAW' AND FlavorType = 'FLAVOR_WONDER';

INSERT INTO Civilizations
(Type, Description, Civilopedia, CivilopediaTag, Strategy, Playable, AIPlayable,
 ShortDescription, Adjective, DefaultPlayerColor, ArtDefineTag, ArtStyleType,
 ArtStyleSuffix, ArtStylePrefix, PortraitIndex, IconAtlas, AlphaIconAtlas,
 MapImage, DawnOfManQuote, DawnOfManImage, DawnOfManAudio, SoundtrackTag)
SELECT
 'CIVILIZATION_FLESHBORN_CHORUS',
 'TXT_KEY_CIV_FLESHBORN_DESC',
 'TXT_KEY_CIV_FLESHBORN_PEDIA',
 'TXT_KEY_CIV5_FLESHBORN',
 'TXT_KEY_CIV_FLESHBORN_STRATEGY',
 1, 1,
 'TXT_KEY_CIV_FLESHBORN_SHORT_DESC',
 'TXT_KEY_CIV_FLESHBORN_ADJECTIVE',
 'PLAYERCOLOR_FLESHBORN',
 ArtDefineTag, ArtStyleType, ArtStyleSuffix, ArtStylePrefix,
 PortraitIndex, IconAtlas, AlphaIconAtlas, MapImage,
 'TXT_KEY_CIV5_DOM_FLESHBORN_TEXT', DawnOfManImage, '', SoundtrackTag
FROM Civilizations WHERE Type = 'CIVILIZATION_AMERICA';

INSERT INTO Civilization_Leaders VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'LEADER_FLESHBORN_FIRST_MAW');
INSERT INTO Civilization_FreeBuildingClasses VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'BUILDINGCLASS_PALACE');
INSERT INTO Civilization_FreeTechs VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'TECH_AGRICULTURE');
INSERT INTO Civilization_FreeUnits (CivilizationType, UnitClassType, UnitAIType, Count) VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'UNITCLASS_SETTLER', 'UNITAI_SETTLE', 1),
('CIVILIZATION_FLESHBORN_CHORUS', 'UNITCLASS_WORKER', 'UNITAI_WORKER', 1);
INSERT INTO Civilization_Start_Region_Priority VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'REGION_GRASS');

INSERT INTO Civilization_CityNames VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_FIRST_STOMACH'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_ANTERIOR_NODE'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_BROOD_BASIN'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_FEEDING_ORGAN'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_DEEP_GUT'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_NEURAL_CAVITY'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_WESTERN_MAW'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_VENTRAL_COLONY'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_SPAWN_CHAMBER'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_HUNGER_BEYOND'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_RED_FOLD'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_THIRD_LIVER'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_HOLLOW_TONGUE'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_BONE_GARDEN'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_WARM_VAULT'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_CRAWLING_ROOT'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_PALE_SINEW'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_GREAT_THROAT'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_MEMORY_SAC'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_CITY_FLESHBORN_LAST_APPETITE');

INSERT INTO Civilization_SpyNames VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_SPY_FLESHBORN_TASTE'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_SPY_FLESHBORN_SCENT'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_SPY_FLESHBORN_WHISPER'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_SPY_FLESHBORN_TREMOR'),
('CIVILIZATION_FLESHBORN_CHORUS', 'TXT_KEY_SPY_FLESHBORN_ECHO');

-- --------------------------------------------------------------------------
-- Unique units
-- Temporary SELECT * copies preserve the exact active BNW/CP unit schema and
-- stock placeholder art, avoiding fragile assumptions about optional columns.
-- --------------------------------------------------------------------------

CREATE TEMP TABLE Fleshborn_DevourerCopy AS
SELECT * FROM Units WHERE Type = 'UNIT_SWORDSMAN';
UPDATE Fleshborn_DevourerCopy SET
 ID = NULL,
 Type = 'UNIT_FLESHBORN_DEVOURER',
 Description = 'TXT_KEY_UNIT_FLESHBORN_DEVOURER',
 Civilopedia = 'TXT_KEY_UNIT_FLESHBORN_DEVOURER_PEDIA',
 Strategy = 'TXT_KEY_UNIT_FLESHBORN_DEVOURER_STRATEGY',
 Help = 'TXT_KEY_UNIT_FLESHBORN_DEVOURER_HELP',
 Food = 0,
 FaithCost = -1,
 RequiresFaithPurchaseEnabled = 0,
 HurryCostModifier = -1,
 PrereqResources = 0,
 NoMaintenance = 1,
 ExtraMaintenanceCost = 0;
INSERT INTO Units SELECT * FROM Fleshborn_DevourerCopy;
DROP TABLE Fleshborn_DevourerCopy;

INSERT INTO Unit_AITypes SELECT 'UNIT_FLESHBORN_DEVOURER', UnitAIType FROM Unit_AITypes WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_ClassUpgrades SELECT 'UNIT_FLESHBORN_DEVOURER', UnitClassType FROM Unit_ClassUpgrades WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_Flavors SELECT 'UNIT_FLESHBORN_DEVOURER', FlavorType, Flavor FROM Unit_Flavors WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_FreePromotions SELECT 'UNIT_FLESHBORN_DEVOURER', PromotionType FROM Unit_FreePromotions WHERE UnitType = 'UNIT_SWORDSMAN';

CREATE TEMP TABLE Fleshborn_HarvesterCopy AS
SELECT * FROM Units WHERE Type = 'UNIT_WORKER';
UPDATE Fleshborn_HarvesterCopy SET
 ID = NULL,
 Type = 'UNIT_FLESHBORN_HARVESTER',
 Description = 'TXT_KEY_UNIT_FLESHBORN_HARVESTER',
 Civilopedia = 'TXT_KEY_UNIT_FLESHBORN_HARVESTER_PEDIA',
 Strategy = 'TXT_KEY_UNIT_FLESHBORN_HARVESTER_STRATEGY',
 Help = 'TXT_KEY_UNIT_FLESHBORN_HARVESTER_HELP',
 FaithCost = -1,
 RequiresFaithPurchaseEnabled = 0,
 HurryCostModifier = -1,
 NoMaintenance = 1,
 ExtraMaintenanceCost = 0;
INSERT INTO Units SELECT * FROM Fleshborn_HarvesterCopy;
DROP TABLE Fleshborn_HarvesterCopy;

INSERT INTO Unit_AITypes SELECT 'UNIT_FLESHBORN_HARVESTER', UnitAIType FROM Unit_AITypes WHERE UnitType = 'UNIT_WORKER';
INSERT INTO Unit_Flavors SELECT 'UNIT_FLESHBORN_HARVESTER', FlavorType, Flavor FROM Unit_Flavors WHERE UnitType = 'UNIT_WORKER';

CREATE TEMP TABLE Fleshborn_BudCopy AS
SELECT * FROM Units WHERE Type = 'UNIT_SETTLER';
UPDATE Fleshborn_BudCopy SET
 ID = NULL,
 Type = 'UNIT_FLESHBORN_COLONY_BUD',
 Description = 'TXT_KEY_UNIT_FLESHBORN_COLONY_BUD',
 Civilopedia = 'TXT_KEY_UNIT_FLESHBORN_COLONY_BUD_PEDIA',
 Strategy = 'TXT_KEY_UNIT_FLESHBORN_COLONY_BUD_STRATEGY',
 Help = 'TXT_KEY_UNIT_FLESHBORN_COLONY_BUD_HELP',
 Food = 0,
 FaithCost = -1,
 RequiresFaithPurchaseEnabled = 0,
 HurryCostModifier = -1,
 NoMaintenance = 1,
 ExtraMaintenanceCost = 0;
INSERT INTO Units SELECT * FROM Fleshborn_BudCopy;
DROP TABLE Fleshborn_BudCopy;

INSERT INTO Unit_AITypes SELECT 'UNIT_FLESHBORN_COLONY_BUD', UnitAIType FROM Unit_AITypes WHERE UnitType = 'UNIT_SETTLER';
INSERT INTO Unit_Flavors SELECT 'UNIT_FLESHBORN_COLONY_BUD', FlavorType, Flavor FROM Unit_Flavors WHERE UnitType = 'UNIT_SETTLER';

INSERT INTO Civilization_UnitClassOverrides VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'UNITCLASS_SWORDSMAN', 'UNIT_FLESHBORN_DEVOURER'),
('CIVILIZATION_FLESHBORN_CHORUS', 'UNITCLASS_WORKER', 'UNIT_FLESHBORN_HARVESTER'),
('CIVILIZATION_FLESHBORN_CHORUS', 'UNITCLASS_SETTLER', 'UNIT_FLESHBORN_COLONY_BUD');

-- Every stock unit class whose default unit requires a strategic resource gets
-- a civ-specific, maintenance-free biological copy.  This adapts automatically
-- to the active CP roster, including late-game air/naval units and spaceship
-- parts, while retaining stock placeholder models, flags, icons, and upgrades.
CREATE TEMP TABLE Fleshborn_ResourceRoster AS
SELECT
 U.Type AS OldUnitType,
 'UNIT_FLESHBORN_BIO_' || SUBSTR(U.Type, 6) AS NewUnitType,
 U.Class AS UnitClassType
FROM Units U
JOIN UnitClasses UC ON UC.DefaultUnit = U.Type
WHERE U.Type <> 'UNIT_SWORDSMAN'
  AND EXISTS (
    SELECT 1 FROM Unit_ResourceQuantityRequirements R WHERE R.UnitType = U.Type
  );

CREATE TEMP TABLE Fleshborn_ResourceUnitCopies AS
SELECT U.*
FROM Units U
JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = U.Type;

UPDATE Fleshborn_ResourceUnitCopies SET
 ID = NULL,
 Type = (SELECT R.NewUnitType FROM Fleshborn_ResourceRoster R WHERE R.OldUnitType = Fleshborn_ResourceUnitCopies.Type),
 Food = 0,
 FaithCost = -1,
 RequiresFaithPurchaseEnabled = 0,
 HurryCostModifier = -1,
 PrereqResources = 0,
 NoMaintenance = 1,
 ExtraMaintenanceCost = 0;

UPDATE Fleshborn_ResourceUnitCopies SET Description =
 CASE Type
  WHEN 'UNIT_FLESHBORN_BIO_CHARIOT_ARCHER' THEN 'TXT_KEY_UNIT_FLESHBORN_SPINE_RUNNER'
  WHEN 'UNIT_FLESHBORN_BIO_HORSEMAN' THEN 'TXT_KEY_UNIT_FLESHBORN_HUNTER_BEAST'
  WHEN 'UNIT_FLESHBORN_BIO_KNIGHT' THEN 'TXT_KEY_UNIT_FLESHBORN_RAVAGER'
  WHEN 'UNIT_FLESHBORN_BIO_LONGSWORDSMAN' THEN 'TXT_KEY_UNIT_FLESHBORN_RIPPER'
  WHEN 'UNIT_FLESHBORN_BIO_LANCER' THEN 'TXT_KEY_UNIT_FLESHBORN_PIERCER'
  WHEN 'UNIT_FLESHBORN_BIO_CAVALRY' THEN 'TXT_KEY_UNIT_FLESHBORN_GREATER_RAVAGER'
  WHEN 'UNIT_FLESHBORN_BIO_WWI_TANK' THEN 'TXT_KEY_UNIT_FLESHBORN_YOUNG_BEHEMOTH'
  WHEN 'UNIT_FLESHBORN_BIO_TANK' THEN 'TXT_KEY_UNIT_FLESHBORN_BEHEMOTH'
  WHEN 'UNIT_FLESHBORN_BIO_MODERN_ARMOR' THEN 'TXT_KEY_UNIT_FLESHBORN_APEX_BEHEMOTH'
  WHEN 'UNIT_FLESHBORN_BIO_IRONCLAD' THEN 'TXT_KEY_UNIT_FLESHBORN_SHELLBACK'
  WHEN 'UNIT_FLESHBORN_BIO_FRIGATE' THEN 'TXT_KEY_UNIT_FLESHBORN_SPINE_SHIP'
  WHEN 'UNIT_FLESHBORN_BIO_BATTLESHIP' THEN 'TXT_KEY_UNIT_FLESHBORN_LEVIATHAN'
  WHEN 'UNIT_FLESHBORN_BIO_TRIPLANE' THEN 'TXT_KEY_UNIT_FLESHBORN_SKYHUNTER'
  WHEN 'UNIT_FLESHBORN_BIO_FIGHTER' THEN 'TXT_KEY_UNIT_FLESHBORN_SKYHUNTER'
  WHEN 'UNIT_FLESHBORN_BIO_JET_FIGHTER' THEN 'TXT_KEY_UNIT_FLESHBORN_APEX_SKYHUNTER'
  WHEN 'UNIT_FLESHBORN_BIO_WWI_BOMBER' THEN 'TXT_KEY_UNIT_FLESHBORN_BLIGHTWING'
  WHEN 'UNIT_FLESHBORN_BIO_BOMBER' THEN 'TXT_KEY_UNIT_FLESHBORN_BLIGHTWING'
  WHEN 'UNIT_FLESHBORN_BIO_STEALTH_BOMBER' THEN 'TXT_KEY_UNIT_FLESHBORN_NIGHT_BLIGHTWING'
  WHEN 'UNIT_FLESHBORN_BIO_HELICOPTER_GUNSHIP' THEN 'TXT_KEY_UNIT_FLESHBORN_HOVERMAW'
  WHEN 'UNIT_FLESHBORN_BIO_ROCKET_ARTILLERY' THEN 'TXT_KEY_UNIT_FLESHBORN_BILE_CATHEDRAL'
  WHEN 'UNIT_FLESHBORN_BIO_MECH' THEN 'TXT_KEY_UNIT_FLESHBORN_APEX_WARFORM'
  WHEN 'UNIT_FLESHBORN_BIO_ATOMIC_BOMB' THEN 'TXT_KEY_UNIT_FLESHBORN_PLAGUE_SEED'
  WHEN 'UNIT_FLESHBORN_BIO_NUCLEAR_MISSILE' THEN 'TXT_KEY_UNIT_FLESHBORN_EXTINCTION_CYST'
  WHEN 'UNIT_FLESHBORN_BIO_SS_STASIS_CHAMBER' THEN 'TXT_KEY_UNIT_FLESHBORN_STAR_WOMB'
  WHEN 'UNIT_FLESHBORN_BIO_SS_ENGINE' THEN 'TXT_KEY_UNIT_FLESHBORN_VOID_HEART'
  WHEN 'UNIT_FLESHBORN_BIO_SS_COCKPIT' THEN 'TXT_KEY_UNIT_FLESHBORN_STAR_BRAIN'
  WHEN 'UNIT_FLESHBORN_BIO_SS_BOOSTER' THEN 'TXT_KEY_UNIT_FLESHBORN_ASCENT_SAC'
  ELSE Description
 END;

INSERT INTO Units SELECT * FROM Fleshborn_ResourceUnitCopies;

INSERT INTO Civilization_UnitClassOverrides
SELECT 'CIVILIZATION_FLESHBORN_CHORUS', UnitClassType, NewUnitType
FROM Fleshborn_ResourceRoster;

INSERT INTO Unit_AITypes
SELECT R.NewUnitType, X.UnitAIType FROM Unit_AITypes X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_NotAITypes
SELECT R.NewUnitType, X.UnitAIType FROM Unit_NotAITypes X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_ClassUpgrades
SELECT R.NewUnitType, X.UnitClassType FROM Unit_ClassUpgrades X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_Flavors
SELECT R.NewUnitType, X.FlavorType, X.Flavor FROM Unit_Flavors X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_FreePromotions
SELECT R.NewUnitType, X.PromotionType FROM Unit_FreePromotions X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_BuildingClassRequireds
SELECT R.NewUnitType, X.BuildingClassType FROM Unit_BuildingClassRequireds X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_Buildings
SELECT R.NewUnitType, X.BuildingType FROM Unit_Buildings X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_ProductionModifierBuildings
SELECT R.NewUnitType, X.BuildingType, X.ProductionModifier FROM Unit_ProductionModifierBuildings X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_ProductionTraits
SELECT R.NewUnitType, X.TraitType, X.Trait FROM Unit_ProductionTraits X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_TechTypes
SELECT R.NewUnitType, X.TechType FROM Unit_TechTypes X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO Unit_YieldFromKills
SELECT R.NewUnitType, X.YieldType, X.Yield FROM Unit_YieldFromKills X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;
INSERT INTO UnitGameplay2DScripts
SELECT R.NewUnitType, X.SelectionSound, X.FirstSelectionSound FROM UnitGameplay2DScripts X JOIN Fleshborn_ResourceRoster R ON R.OldUnitType = X.UnitType;

DROP TABLE Fleshborn_ResourceUnitCopies;
DROP TABLE Fleshborn_ResourceRoster;

-- --------------------------------------------------------------------------
-- Buildings and hidden metabolic state
-- --------------------------------------------------------------------------

-- Resource-consuming default buildings receive the same treatment as units:
-- a civ-specific biological copy with stock placeholder art and no strategic
-- requirement.  The active CP row is copied so balance changes remain intact.
CREATE TEMP TABLE Fleshborn_ResourceBuildingRoster AS
SELECT
 B.Type AS OldBuildingType,
 'BUILDING_FLESHBORN_BIO_' || SUBSTR(B.Type, 10) AS NewBuildingType,
 B.BuildingClass AS BuildingClassType
FROM Buildings B
JOIN BuildingClasses BC ON BC.DefaultBuilding = B.Type
WHERE EXISTS (
  SELECT 1 FROM Building_ResourceQuantityRequirements R WHERE R.BuildingType = B.Type
);

CREATE TEMP TABLE Fleshborn_ResourceBuildingCopies AS
SELECT B.*
FROM Buildings B
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = B.Type;

UPDATE Fleshborn_ResourceBuildingCopies SET
 ID = NULL,
 Type = (SELECT R.NewBuildingType FROM Fleshborn_ResourceBuildingRoster R
         WHERE R.OldBuildingType = Fleshborn_ResourceBuildingCopies.Type),
 GoldMaintenance = 0,
 FaithCost = -1,
 HurryCostModifier = -1;

UPDATE Fleshborn_ResourceBuildingCopies SET
 Description = CASE Type
  WHEN 'BUILDING_FLESHBORN_BIO_FACTORY' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_FACTORY'
  WHEN 'BUILDING_FLESHBORN_BIO_HYDRO_PLANT' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_HYDRO_PLANT'
  WHEN 'BUILDING_FLESHBORN_BIO_NUCLEAR_PLANT' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_NUCLEAR_PLANT'
  WHEN 'BUILDING_FLESHBORN_BIO_SPACESHIP_FACTORY' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_SPACESHIP_FACTORY'
  ELSE Description
 END,
 Help = CASE Type
  WHEN 'BUILDING_FLESHBORN_BIO_FACTORY' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_FACTORY_HELP'
  WHEN 'BUILDING_FLESHBORN_BIO_HYDRO_PLANT' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_HYDRO_PLANT_HELP'
  WHEN 'BUILDING_FLESHBORN_BIO_NUCLEAR_PLANT' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_NUCLEAR_PLANT_HELP'
  WHEN 'BUILDING_FLESHBORN_BIO_SPACESHIP_FACTORY' THEN 'TXT_KEY_BUILDING_FLESHBORN_BIO_SPACESHIP_FACTORY_HELP'
  ELSE Help
 END;

INSERT INTO Buildings SELECT * FROM Fleshborn_ResourceBuildingCopies;

INSERT INTO Civilization_BuildingClassOverrides
SELECT 'CIVILIZATION_FLESHBORN_CHORUS', BuildingClassType, NewBuildingType
FROM Fleshborn_ResourceBuildingRoster;

INSERT INTO Building_ClassesNeededInCity (BuildingType, BuildingClassType)
SELECT R.NewBuildingType, X.BuildingClassType
FROM Building_ClassesNeededInCity X
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = X.BuildingType;
INSERT INTO Building_Flavors (BuildingType, FlavorType, Flavor)
SELECT R.NewBuildingType, X.FlavorType, X.Flavor
FROM Building_Flavors X
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = X.BuildingType;
INSERT INTO Building_RiverPlotYieldChanges (BuildingType, YieldType, Yield)
SELECT R.NewBuildingType, X.YieldType, X.Yield
FROM Building_RiverPlotYieldChanges X
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = X.BuildingType;
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
SELECT R.NewBuildingType, X.YieldType, X.Yield
FROM Building_YieldChanges X
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = X.BuildingType;
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield)
SELECT R.NewBuildingType, X.YieldType, X.Yield
FROM Building_YieldModifiers X
JOIN Fleshborn_ResourceBuildingRoster R ON R.OldBuildingType = X.BuildingType;

DROP TABLE Fleshborn_ResourceBuildingCopies;
DROP TABLE Fleshborn_ResourceBuildingRoster;

CREATE TEMP TABLE Fleshborn_DigestiveCopy AS
SELECT * FROM Buildings WHERE Type = 'BUILDING_GRANARY';
UPDATE Fleshborn_DigestiveCopy SET
 ID = NULL,
 Type = 'BUILDING_FLESHBORN_DIGESTIVE_CHAMBER',
 Description = 'TXT_KEY_BUILDING_FLESHBORN_DIGESTIVE_CHAMBER',
 Civilopedia = 'TXT_KEY_BUILDING_FLESHBORN_DIGESTIVE_CHAMBER_PEDIA',
 Strategy = 'TXT_KEY_BUILDING_FLESHBORN_DIGESTIVE_CHAMBER_STRATEGY',
 Help = 'TXT_KEY_BUILDING_FLESHBORN_DIGESTIVE_CHAMBER_HELP',
 GoldMaintenance = 0,
 FaithCost = -1,
 HurryCostModifier = -1,
 FoodKept = FoodKept + 15;
INSERT INTO Buildings SELECT * FROM Fleshborn_DigestiveCopy;
DROP TABLE Fleshborn_DigestiveCopy;

INSERT INTO Building_Flavors
SELECT 'BUILDING_FLESHBORN_DIGESTIVE_CHAMBER', FlavorType, Flavor + 5
FROM Building_Flavors WHERE BuildingType = 'BUILDING_GRANARY';
INSERT INTO Building_ResourceYieldChanges
SELECT 'BUILDING_FLESHBORN_DIGESTIVE_CHAMBER', ResourceType, YieldType, Yield
FROM Building_ResourceYieldChanges WHERE BuildingType = 'BUILDING_GRANARY';
INSERT INTO Building_YieldChanges
SELECT 'BUILDING_FLESHBORN_DIGESTIVE_CHAMBER', YieldType, Yield
FROM Building_YieldChanges WHERE BuildingType = 'BUILDING_GRANARY';
INSERT INTO Civilization_BuildingClassOverrides VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'BUILDINGCLASS_GRANARY', 'BUILDING_FLESHBORN_DIGESTIVE_CHAMBER');

INSERT INTO BuildingClasses
(Type, DefaultBuilding, Description, MaxGlobalInstances, MaxTeamInstances, MaxPlayerInstances) VALUES
('BUILDINGCLASS_FLESHBORN_METABOLISM', 'BUILDING_FLESHBORN_METABOLISM', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_FOUNDING_CORE', 'BUILDING_FLESHBORN_FOUNDING_CORE', 'TXT_KEY_BUILDING_FLESHBORN_FOUNDING_CORE', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_FIELD_FOOD', 'BUILDING_FLESHBORN_FIELD_FOOD', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_EDIBLE_FOOD', 'BUILDING_FLESHBORN_EDIBLE_FOOD', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_MEMORY', 'BUILDING_FLESHBORN_MEMORY', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_PRODUCTION_SINK', 'BUILDING_FLESHBORN_PRODUCTION_SINK', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1),
('BUILDINGCLASS_FLESHBORN_BLOOM', 'BUILDING_FLESHBORN_BLOOM', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', -1, -1, -1);

INSERT INTO Buildings
(Type, BuildingClass, Description, Help, Cost, FaithCost, GoldMaintenance,
 PrereqTech, NeverCapture, NukeImmune, ConquestProb, GreatWorkCount,
 NoOccupiedUnhappiness, UnhappinessModifier, PortraitIndex, IconAtlas) VALUES
('BUILDING_FLESHBORN_METABOLISM', 'BUILDINGCLASS_FLESHBORN_METABOLISM', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM_HELP', -1, -1, 0, NULL, 1, 1, 0, -1, 1, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_FOUNDING_CORE', 'BUILDINGCLASS_FLESHBORN_FOUNDING_CORE', 'TXT_KEY_BUILDING_FLESHBORN_FOUNDING_CORE', 'TXT_KEY_BUILDING_FLESHBORN_FOUNDING_CORE_HELP', -1, -1, 0, NULL, 1, 1, 0, -1, 1, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_FIELD_FOOD', 'BUILDINGCLASS_FLESHBORN_FIELD_FOOD', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', NULL, -1, -1, 0, NULL, 1, 1, 0, -1, 0, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_EDIBLE_FOOD', 'BUILDINGCLASS_FLESHBORN_EDIBLE_FOOD', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', NULL, -1, -1, 0, NULL, 1, 1, 0, -1, 0, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_MEMORY', 'BUILDINGCLASS_FLESHBORN_MEMORY', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', NULL, -1, -1, 0, NULL, 1, 1, 0, -1, 0, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_PRODUCTION_SINK', 'BUILDINGCLASS_FLESHBORN_PRODUCTION_SINK', 'TXT_KEY_BUILDING_FLESHBORN_METABOLISM', NULL, -1, -1, 0, NULL, 1, 1, 0, -1, 0, 0, 0, 'BW_ATLAS_1'),
('BUILDING_FLESHBORN_BLOOM', 'BUILDINGCLASS_FLESHBORN_BLOOM', 'TXT_KEY_BUILDING_FLESHBORN_BLOOM', 'TXT_KEY_BUILDING_FLESHBORN_BLOOM_HELP', -1, -1, 0, NULL, 1, 1, 0, -1, 0, 0, 0, 'BW_ATLAS_1');

UPDATE Buildings SET IsDummy = 1 WHERE Type IN (
 'BUILDING_FLESHBORN_METABOLISM',
 'BUILDING_FLESHBORN_FOUNDING_CORE',
 'BUILDING_FLESHBORN_FIELD_FOOD',
 'BUILDING_FLESHBORN_EDIBLE_FOOD',
 'BUILDING_FLESHBORN_MEMORY',
 'BUILDING_FLESHBORN_PRODUCTION_SINK',
 'BUILDING_FLESHBORN_BLOOM'
);

INSERT INTO Building_YieldModifiers VALUES
('BUILDING_FLESHBORN_METABOLISM', 'YIELD_PRODUCTION', -100),
('BUILDING_FLESHBORN_BLOOM', 'YIELD_FOOD', 10);
INSERT INTO Building_YieldChanges VALUES
('BUILDING_FLESHBORN_FOUNDING_CORE', 'YIELD_FOOD', 4),
('BUILDING_FLESHBORN_FIELD_FOOD', 'YIELD_FOOD', 1),
('BUILDING_FLESHBORN_EDIBLE_FOOD', 'YIELD_FOOD', 1),
('BUILDING_FLESHBORN_MEMORY', 'YIELD_CULTURE', 1),
('BUILDING_FLESHBORN_PRODUCTION_SINK', 'YIELD_PRODUCTION', -1);

INSERT INTO Civilization_FreeBuildingClasses VALUES
('CIVILIZATION_FLESHBORN_CHORUS', 'BUILDINGCLASS_FLESHBORN_METABOLISM');

-- The Growth process is the explicit "grow population" queue choice.  It has
-- no Production conversion and is restricted to the Chorus by Lua.
INSERT INTO Processes
(Type, Description, Help, Strategy, TechPrereq, PortraitIndex, IconAtlas) VALUES
('PROCESS_FLESHBORN_GROWTH', 'TXT_KEY_PROCESS_FLESHBORN_GROWTH',
 'TXT_KEY_PROCESS_FLESHBORN_GROWTH_HELP', 'TXT_KEY_PROCESS_FLESHBORN_GROWTH_STRATEGY',
 NULL, 0, 'CITIZEN_ATLAS');
INSERT INTO Process_Flavors VALUES
('PROCESS_FLESHBORN_GROWTH', 'FLAVOR_GROWTH', 20),
('PROCESS_FLESHBORN_GROWTH', 'FLAVOR_EXPANSION', 12);

-- --------------------------------------------------------------------------
-- Feeding Field and Harvester build actions
-- --------------------------------------------------------------------------

-- A distinct art tag is required for the engine to register the new
-- improvement reliably. Clone the active Farm definitions so this remains
-- compatible with CP art changes while using only stock placeholder assets.
INSERT INTO ArtDefine_LandmarkTypes
(Type, LandmarkType, FriendlyName) VALUES
('ART_DEF_IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'Improvement', 'Fleshborn Feeding Field');

INSERT INTO ArtDefine_Landmarks
(Era, State, Scale, ImprovementType, LayoutHandler, ResourceType, Model, TerrainContour, Tech)
SELECT Era, State, Scale,
 'ART_DEF_IMPROVEMENT_FLESHBORN_FEEDING_FIELD',
 LayoutHandler, ResourceType, Model, TerrainContour, Tech
FROM ArtDefine_Landmarks
WHERE ImprovementType = 'ART_DEF_IMPROVEMENT_FARM';

INSERT INTO ArtDefine_StrategicView
(StrategicViewType, TileType, Asset)
SELECT 'ART_DEF_IMPROVEMENT_FLESHBORN_FEEDING_FIELD', TileType, Asset
FROM ArtDefine_StrategicView
WHERE StrategicViewType = 'ART_DEF_IMPROVEMENT_FARM';

CREATE TEMP TABLE Fleshborn_FeedingFieldCopy AS
SELECT * FROM Improvements WHERE Type = 'IMPROVEMENT_FARM';
UPDATE Fleshborn_FeedingFieldCopy SET
 ID = NULL,
 Type = 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD',
 Description = 'TXT_KEY_IMPROVEMENT_FLESHBORN_FEEDING_FIELD',
 Civilopedia = 'TXT_KEY_IMPROVEMENT_FLESHBORN_FEEDING_FIELD_PEDIA',
 Help = 'TXT_KEY_IMPROVEMENT_FLESHBORN_FEEDING_FIELD_HELP',
 ArtDefineTag = 'ART_DEF_IMPROVEMENT_FLESHBORN_FEEDING_FIELD',
 SpecificCivRequired = 1,
 CivilizationType = 'CIVILIZATION_FLESHBORN_CHORUS',
 BuildableOnResources = 1,
 FreshWaterMakesValid = 1;
INSERT INTO Improvements SELECT * FROM Fleshborn_FeedingFieldCopy;
DROP TABLE Fleshborn_FeedingFieldCopy;

INSERT INTO Improvement_ValidTerrains
SELECT 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD', TerrainType
FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_FARM';
INSERT INTO Improvement_ValidFeatures VALUES
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'FEATURE_MARSH');
INSERT INTO Improvement_ResourceTypes
SELECT 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD', ResourceType, ResourceMakesValid, ResourceTrade, DiscoveryRand, QuantityRequirement
FROM Improvement_ResourceTypes WHERE ImprovementType = 'IMPROVEMENT_FARM';
INSERT INTO Improvement_Yields VALUES
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'YIELD_FOOD', 1);
INSERT INTO Improvement_FreshWaterYields VALUES
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'YIELD_FOOD', 1);
INSERT INTO Improvement_TechYieldChanges VALUES
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'TECH_CIVIL_SERVICE', 'YIELD_FOOD', 1),
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'TECH_FERTILIZER', 'YIELD_FOOD', 1);
INSERT INTO Improvement_Flavors VALUES
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'FLAVOR_GROWTH', 20),
('IMPROVEMENT_FLESHBORN_FEEDING_FIELD', 'FLAVOR_TILE_IMPROVEMENT', 10);

CREATE TEMP TABLE Fleshborn_FeedingBuildCopy AS
SELECT * FROM Builds WHERE Type = 'BUILD_FARM';
UPDATE Fleshborn_FeedingBuildCopy SET
 ID = NULL,
 Type = 'BUILD_FLESHBORN_FEEDING_FIELD',
 Description = 'TXT_KEY_BUILD_FLESHBORN_FEEDING_FIELD',
 Help = 'TXT_KEY_BUILD_FLESHBORN_FEEDING_FIELD_HELP',
 Recommendation = 'TXT_KEY_BUILD_FLESHBORN_FEEDING_FIELD_REC',
 ImprovementType = 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD';
INSERT INTO Builds SELECT * FROM Fleshborn_FeedingBuildCopy;
DROP TABLE Fleshborn_FeedingBuildCopy;

-- A Feeding Field may coexist with Marsh.  Forest/Jungle are digested first.
INSERT INTO BuildFeatures
(BuildType, FeatureType, PrereqTech, Time, Production, Cost, Remove) VALUES
('BUILD_FLESHBORN_FEEDING_FIELD', 'FEATURE_MARSH', 'TECH_MASONRY', 700, 0, 0, 0);

CREATE TEMP TABLE Fleshborn_DigestBuildCopies AS
SELECT * FROM Builds WHERE Type IN ('BUILD_REMOVE_FOREST', 'BUILD_REMOVE_JUNGLE', 'BUILD_REMOVE_MARSH');
UPDATE Fleshborn_DigestBuildCopies SET
 ID = NULL,
 Type = CASE Type
  WHEN 'BUILD_REMOVE_FOREST' THEN 'BUILD_FLESHBORN_DIGEST_FOREST'
  WHEN 'BUILD_REMOVE_JUNGLE' THEN 'BUILD_FLESHBORN_DIGEST_JUNGLE'
  WHEN 'BUILD_REMOVE_MARSH' THEN 'BUILD_FLESHBORN_DIGEST_MARSH'
 END,
 Description = CASE Type
  WHEN 'BUILD_REMOVE_FOREST' THEN 'TXT_KEY_BUILD_FLESHBORN_DIGEST_FOREST'
  WHEN 'BUILD_REMOVE_JUNGLE' THEN 'TXT_KEY_BUILD_FLESHBORN_DIGEST_JUNGLE'
  WHEN 'BUILD_REMOVE_MARSH' THEN 'TXT_KEY_BUILD_FLESHBORN_DIGEST_MARSH'
 END,
 Help = 'TXT_KEY_BUILD_FLESHBORN_DIGEST_HELP';
INSERT INTO Builds SELECT * FROM Fleshborn_DigestBuildCopies;
DROP TABLE Fleshborn_DigestBuildCopies;

INSERT INTO BuildFeatures
(BuildType, FeatureType, PrereqTech, Time, Production, Cost, Remove)
SELECT
 CASE BuildType
  WHEN 'BUILD_REMOVE_FOREST' THEN 'BUILD_FLESHBORN_DIGEST_FOREST'
  WHEN 'BUILD_REMOVE_JUNGLE' THEN 'BUILD_FLESHBORN_DIGEST_JUNGLE'
  WHEN 'BUILD_REMOVE_MARSH' THEN 'BUILD_FLESHBORN_DIGEST_MARSH'
 END,
 FeatureType, PrereqTech, Time, 0, Cost, Remove
FROM BuildFeatures
WHERE BuildType IN ('BUILD_REMOVE_FOREST', 'BUILD_REMOVE_JUNGLE', 'BUILD_REMOVE_MARSH');

INSERT INTO Unit_Builds
SELECT 'UNIT_FLESHBORN_HARVESTER', BuildType
FROM Unit_Builds
WHERE UnitType = 'UNIT_WORKER'
  AND BuildType NOT IN ('BUILD_FARM', 'BUILD_REMOVE_FOREST', 'BUILD_REMOVE_JUNGLE', 'BUILD_REMOVE_MARSH');
INSERT INTO Unit_Builds VALUES
('UNIT_FLESHBORN_HARVESTER', 'BUILD_FLESHBORN_FEEDING_FIELD'),
('UNIT_FLESHBORN_HARVESTER', 'BUILD_FLESHBORN_DIGEST_FOREST'),
('UNIT_FLESHBORN_HARVESTER', 'BUILD_FLESHBORN_DIGEST_JUNGLE'),
('UNIT_FLESHBORN_HARVESTER', 'BUILD_FLESHBORN_DIGEST_MARSH');

-- --------------------------------------------------------------------------
-- Hunger promotions: one mutually managed tier is applied by Lua.
-- --------------------------------------------------------------------------

INSERT INTO UnitPromotions
(Type, Description, Help, CannotBeChosen, LostWithUpgrade, CombatPercent,
 EnemyHealChange, NeutralHealChange, FriendlyHealChange,
 PortraitIndex, IconAtlas, PediaType, PediaEntry) VALUES
('PROMOTION_FLESHBORN_HUNGER_1', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_1_HELP', 1, 0, -3,  -2,  -2,  -2,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_2', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_2_HELP', 1, 0, -6,  -3,  -3,  -3,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_3', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_3_HELP', 1, 0, -9,  -5,  -5,  -5,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_4', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_4_HELP', 1, 0, -12, -6,  -6,  -6,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_5', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_5_HELP', 1, 0, -15, -8,  -8,  -8,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_6', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_6_HELP', 1, 0, -18, -9,  -9,  -9,  14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_7', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_7_HELP', 1, 0, -21, -11, -11, -11, 14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_8', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_8_HELP', 1, 0, -24, -12, -12, -12, 14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_9', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_9_HELP', 1, 0, -27, -14, -14, -14, 14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER'),
('PROMOTION_FLESHBORN_HUNGER_10','TXT_KEY_PROMOTION_FLESHBORN_HUNGER', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER_10_HELP',1, 0, -30, -15, -15, -15, 14, 'PROMOTION_ATLAS', 'PEDIA_SHARED', 'TXT_KEY_PROMOTION_FLESHBORN_HUNGER');
