"""Apply the mod SQL to a scrubbed Civ V debug database and verify art wiring."""

from __future__ import annotations

import argparse
import re
import shutil
import sqlite3
import struct
import tempfile
from contextlib import closing
from pathlib import Path
from xml.etree import ElementTree


def quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def scrub_existing_fleshborn_data(database: sqlite3.Connection) -> None:
    tables = [
        row[0]
        for row in database.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
    ]
    for table in tables:
        columns = [row[1] for row in database.execute(f"PRAGMA table_info({quote_identifier(table)})")]
        if not columns:
            continue
        predicate = " OR ".join(
            f"CAST({quote_identifier(column)} AS TEXT) LIKE '%FLESHBORN%'" for column in columns
        )
        try:
            database.execute(f"DELETE FROM {quote_identifier(table)} WHERE {predicate}")
        except sqlite3.Error:
            # A few engine-owned virtual tables are not writable and are not
            # targets of the mod's database actions.
            continue
    database.commit()


def scalar(database: sqlite3.Connection, query: str) -> int:
    return int(database.execute(query).fetchone()[0])


def dds_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as texture:
        header = texture.read(20)
    if len(header) != 20 or header[:4] != b"DDS ":
        raise AssertionError(f"Invalid DDS header: {path}")
    height, width = struct.unpack_from("<II", header, 12)
    return width, height


def validate_status_panel(root: Path) -> None:
    panel_path = root / "UI" / "FleshbornStatusPanel.xml"
    panel_tree = ElementTree.parse(panel_path)
    controls = [element.attrib["ID"] for element in panel_tree.iter() if "ID" in element.attrib]
    control_ids = set(controls)
    assert len(controls) == len(control_ids), "Duplicate control ID in metabolism panel"

    supported_fonts = {
        "TwCenMT14",
        "TwCenMT16",
        "TwCenMT18",
        "TwCenMT20",
        "TwCenMT24",
    }
    used_fonts = {
        element.attrib["Font"] for element in panel_tree.iter() if "Font" in element.attrib
    }
    assert used_fonts <= supported_fonts, f"Unsupported panel fonts: {used_fonts - supported_fonts}"

    panel = next(
        element for element in panel_tree.iter() if element.attrib.get("ID") == "MetabolismPanel"
    )
    width, height = (int(value) for value in panel.attrib["Size"].split(","))
    assert width <= 960 and height <= 700, "Panel no longer fits the 1024x768-safe envelope"

    panel_lua = (root / "UI" / "FleshbornStatusPanel.lua").read_text(encoding="utf-8-sig")
    referenced_controls = set(re.findall(r"Controls\.([A-Za-z0-9_]+)", panel_lua))
    missing_controls = referenced_controls - control_ids
    assert not missing_controls, f"Lua references missing panel controls: {sorted(missing_controls)}"

    required_dashboard_controls = {
        "OverviewPage",
        "BroodPage",
        "OverviewTabButton",
        "BroodTabButton",
        "BroodCityPullDown",
        "OverviewProducedValue",
        "OverviewConsumedValue",
        "OverviewNetValue",
        "OverviewStateValue",
        "ArmyCoverageFill",
        "BroodOrderPortrait",
        "BroodProgressFill",
        "BroodProgressPercentLabel",
    }
    missing_dashboard_controls = required_dashboard_controls - control_ids
    assert not missing_dashboard_controls, (
        f"Metabolism dashboard is incomplete: {sorted(missing_dashboard_controls)}"
    )
    assert "FB_SetTab(\"OVERVIEW\")" in panel_lua, "Dashboard no longer opens on Overview"
    assert "SetSizeX" in panel_lua, "Dashboard progress bars are no longer dynamic"


def validate_building_atlas_packaging(root: Path) -> None:
    expected = {
        f"Art/Atlases/Fleshborn_Buildings_{size}.dds"
        for size in (256, 128, 80, 64, 45, 32)
    }
    expected.update(
        f"Art/Atlases/Fleshborn_Neural_{size}.dds"
        for size in (256, 128, 80, 64, 45, 32)
    )

    modinfo = ElementTree.parse(root / "The Fleshborn Chorus (v 1).modinfo")
    modinfo_files = {
        (element.text or "").replace("\\", "/")
        for element in modinfo.iter("File")
    }
    assert expected <= modinfo_files, "Building atlas is missing from the modinfo package"

    project = ElementTree.parse(root / "TheFleshbornChorus.civ5proj")
    project_files = {
        element.attrib["Include"].replace("\\", "/")
        for element in project.iter("{http://schemas.microsoft.com/developer/msbuild/2003}Content")
        if "Include" in element.attrib
    }
    assert expected <= project_files, "Building atlas is missing from the ModBuddy project"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("debug_database", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    root = args.project_root.resolve()
    validate_status_panel(root)
    validate_building_atlas_packaging(root)
    with tempfile.TemporaryDirectory(prefix="fleshborn-db-") as temporary:
        validation_database = Path(temporary) / "Civ5DebugDatabase.db"
        shutil.copy2(args.debug_database, validation_database)
        with closing(sqlite3.connect(validation_database)) as database:
            database.execute("PRAGMA foreign_keys = OFF")
            scrub_existing_fleshborn_data(database)
            database.executescript((root / "SQL" / "00_Fleshborn_Core.sql").read_text(encoding="utf-8-sig"))
            # The debug gameplay cache does not attach Civ V's localization
            # database, so provide the table shape needed to syntax-check text.
            database.execute("CREATE TABLE IF NOT EXISTS Language_en_US (Tag TEXT PRIMARY KEY, Text TEXT)")
            database.executescript((root / "SQL" / "10_Fleshborn_Text.sql").read_text(encoding="utf-8-sig"))
            database.commit()

            assert scalar(database, "SELECT COUNT(*) FROM IconTextureAtlases WHERE Atlas LIKE 'FLESHBORN_%'") == 33
            assert scalar(
                database,
                """SELECT COUNT(*) FROM IconTextureAtlases
                   WHERE Atlas = 'FLESHBORN_BUILDING_ATLAS'
                   AND IconsPerRow = 4 AND IconsPerColumn = 2""",
            ) == 6
            assert scalar(
                database,
                """SELECT COUNT(*) FROM IconTextureAtlases
                   WHERE Atlas = 'FLESHBORN_NEURAL_ATLAS'
                   AND IconSize != 45
                   AND IconsPerRow = 1 AND IconsPerColumn = 1""",
            ) == 5
            assert scalar(
                database,
                """SELECT COUNT(*) FROM IconTextureAtlases
                   WHERE Atlas = 'FLESHBORN_NEURAL_ATLAS'
                   AND IconSize = 45
                   AND IconsPerRow = 4 AND IconsPerColumn = 4""",
            ) == 1
            for filename, icon_size, columns, rows in database.execute(
                """SELECT Filename, IconSize, IconsPerRow, IconsPerColumn
                   FROM IconTextureAtlases WHERE Atlas LIKE 'FLESHBORN_%'"""
            ):
                texture = root / "Art" / "Atlases" / filename
                assert texture.is_file(), f"Missing atlas texture: {texture}"
                expected = (int(icon_size) * int(columns), int(icon_size) * int(rows))
                actual = dds_dimensions(texture)
                assert actual == expected, f"{filename}: declared {expected}, actual {actual}"

            expected_screens = {
                "Fleshborn_DOM.dds": (1024, 768),
                "Fleshborn_Map.dds": (360, 412),
                "Fleshborn_Diplomacy.dds": (1600, 900),
            }
            for filename, expected in expected_screens.items():
                texture = root / "Art" / "Screens" / filename
                assert dds_dimensions(texture) == expected, f"Unexpected screen size: {filename}"
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Improvements
                   WHERE Type = 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD'
                   AND ArtDefineTag = 'ART_DEF_IMPROVEMENT_FARM'""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM ArtDefine_Landmarks
                   WHERE ImprovementType = 'ART_DEF_IMPROVEMENT_FLESHBORN_FEEDING_FIELD'""",
            ) == 0
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Builds
                   WHERE Type = 'BUILD_FLESHBORN_FEEDING_FIELD'
                   AND ImprovementType = 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD'""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Improvement_ResourceTypes
                   WHERE ImprovementType = 'IMPROVEMENT_FLESHBORN_FEEDING_FIELD'
                   AND ResourceType IN (
                       'RESOURCE_WHEAT', 'RESOURCE_BANANA', 'RESOURCE_COW',
                       'RESOURCE_SHEEP', 'RESOURCE_DEER', 'RESOURCE_SUGAR',
                       'RESOURCE_CITRUS'
                   )
                   AND ResourceMakesValid = 1 AND ResourceTrade = 0""",
            ) == 7
            core_lua = (root / "Lua" / "FleshbornCore.lua").read_text(encoding="utf-8-sig")
            assert "if buildType == BUILD_FEEDING_FIELD then" in core_lua
            assert "FB_MakeFeedingFieldVisible(plot)" in core_lua
            assert 'plot:SetImprovementType(IMPROVEMENT_FARM)' in core_lua
            required_balance_rules = {
                "return 5 + math.ceil(city:GetPopulation() * 0.75)": "city metabolism",
                "local costByEra = {13, 13, 26, 26, 39, 52, 65, 78}": "army feeding",
                "local multiplier = 1150": "unit growth cost",
                "multiplier = 1350": "building/project growth cost",
                "multiplier = 1300": "Colony Bud growth cost",
                "multiplier * 950": "Digestive Chamber discount",
                "FB_CountAdjacentFeedingFields(plot) >= 4": "Feeding Field adjacency",
            }
            for snippet, rule_name in required_balance_rules.items():
                assert snippet in core_lua, f"Missing revised {rule_name} rule"
            fleshborn_icon_capacity = scalar(
                database,
                """SELECT MAX(IconsPerRow * IconsPerColumn)
                   FROM IconTextureAtlases WHERE Atlas = 'FLESHBORN_ICON_ATLAS'""",
            )
            portrait_tables = (
                ("Units", "PortraitIndex"),
                ("Buildings", "PortraitIndex"),
                ("Improvements", "PortraitIndex"),
                ("UnitPromotions", "PortraitIndex"),
                ("Builds", "IconIndex"),
            )
            for table, index_column in portrait_tables:
                invalid = scalar(
                    database,
                    f"""SELECT COUNT(*) FROM {table}
                        WHERE IconAtlas = 'FLESHBORN_ICON_ATLAS'
                        AND ({index_column} < 0 OR {index_column} >= {fleshborn_icon_capacity})""",
                )
                assert invalid == 0, f"Out-of-range Fleshborn icon index in {table}"
            assert scalar(
            database,
            """SELECT COUNT(*) FROM Units WHERE Type IN (
                'UNIT_FLESHBORN_HUNTER_FORM', 'UNIT_FLESHBORN_SPITTER_FORM',
                'UNIT_FLESHBORN_SPINECASTER', 'UNIT_FLESHBORN_WARFORM'
            ) AND IconAtlas = 'FLESHBORN_ICON_ATLAS'""",
            ) == 4
            assert scalar(
            database,
            """SELECT COUNT(*) FROM Units
               WHERE Type LIKE 'UNIT_FLESHBORN_%'
               AND EXISTS (SELECT 1 FROM Unit_ResourceQuantityRequirements R WHERE R.UnitType = Units.Type)""",
            ) == 0
            assert scalar(
            database,
            """SELECT COUNT(*) FROM Civilizations
               WHERE Type = 'CIVILIZATION_FLESHBORN_CHORUS'
               AND IconAtlas = 'FLESHBORN_CIV_ATLAS'
               AND AlphaIconAtlas = 'FLESHBORN_CIV_ALPHA_ATLAS'
               AND MapImage = 'Fleshborn_Map.dds'
               AND DawnOfManImage = 'Fleshborn_DOM.dds'
               AND DawnOfManAudio = ''""",
            ) == 1
            assert scalar(
            database,
            """SELECT COUNT(*) FROM Leaders
               WHERE Type = 'LEADER_FLESHBORN_FIRST_MAW'
               AND ArtDefineTag = 'Fleshborn_LeaderScene.xml'
               AND IconAtlas = 'FLESHBORN_LEADER_ATLAS'""",
            ) == 1
            assert scalar(
            database,
            """SELECT COUNT(*) FROM UnitPromotions
               WHERE Type LIKE 'PROMOTION_FLESHBORN_HUNGER_%'
               AND IconAtlas = 'FLESHBORN_ICON_ATLAS' AND PortraitIndex = 13""",
            ) == 10
            assert scalar(
            database,
            """SELECT COUNT(*) FROM Civilization_UnitClassOverrides
               WHERE CivilizationType = 'CIVILIZATION_FLESHBORN_CHORUS'
               AND UnitType IN ('UNIT_FLESHBORN_HUNTER_FORM', 'UNIT_FLESHBORN_SPITTER_FORM',
                                'UNIT_FLESHBORN_SPINECASTER', 'UNIT_FLESHBORN_WARFORM')""",
            ) == 4
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Civilization_BuildingClassOverrides
                   WHERE CivilizationType = 'CIVILIZATION_FLESHBORN_CHORUS'
                   AND BuildingClassType = 'BUILDINGCLASS_LIBRARY'
                   AND BuildingType = 'BUILDING_FLESHBORN_NEURAL_CLUSTER'""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Buildings WHERE
                   (Type = 'BUILDING_FLESHBORN_BIO_FACTORY'
                    AND IconAtlas = 'FLESHBORN_BUILDING_ATLAS' AND PortraitIndex = 1)
                   OR (Type = 'BUILDING_FLESHBORN_BIO_HYDRO_PLANT'
                    AND IconAtlas = 'FLESHBORN_BUILDING_ATLAS' AND PortraitIndex = 2)
                   OR (Type = 'BUILDING_FLESHBORN_BIO_NUCLEAR_PLANT'
                    AND IconAtlas = 'FLESHBORN_BUILDING_ATLAS' AND PortraitIndex = 3)
                   OR (Type = 'BUILDING_FLESHBORN_BIO_SPACESHIP_FACTORY'
                    AND IconAtlas = 'FLESHBORN_BUILDING_ATLAS' AND PortraitIndex = 4)""",
            ) == 4
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Buildings
                   WHERE Type = 'BUILDING_FLESHBORN_NEURAL_CLUSTER'
                   AND IconAtlas = 'FLESHBORN_NEURAL_ATLAS'
                   AND PortraitIndex = 0""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Buildings
                   WHERE Type = 'BUILDING_FLESHBORN_NEURAL_CLUSTER'
                   AND BuildingClass = 'BUILDINGCLASS_LIBRARY'
                   AND GoldMaintenance = 0""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Building_YieldChangesPerPop
                   WHERE BuildingType = 'BUILDING_FLESHBORN_NEURAL_CLUSTER'""",
            ) == 0
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Building_YieldChanges
                   WHERE BuildingType = 'BUILDING_FLESHBORN_NEURAL_SCIENCE'
                   AND YieldType = 'YIELD_SCIENCE' AND Yield = 1""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Buildings
                   WHERE Type = 'BUILDING_FLESHBORN_FOUNDING_CORE'
                   AND BuildingClass = 'BUILDINGCLASS_FLESHBORN_FOUNDING_CORE'
                   AND IsDummy = 1 AND UnmoddedHappiness = 1
                   AND Cost = -1 AND GoldMaintenance = 0
                   AND NeverCapture = 1""",
            ) == 1
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Buildings
                   WHERE Type = 'BUILDING_FLESHBORN_PUBLIC_OPINION_BUFFER'""",
            ) == 0
            assert scalar(
                database,
                """SELECT COUNT(*) FROM BuildingClasses
                   WHERE Type = 'BUILDINGCLASS_FLESHBORN_PUBLIC_OPINION_BUFFER'""",
            ) == 0
            assert scalar(
                database,
                """SELECT COUNT(*) FROM Building_YieldChanges
                   WHERE BuildingType = 'BUILDING_FLESHBORN_FOUNDING_CORE'""",
            ) == 0
            assert "FB_SyncPublicOpinionImmunity(player)" in core_lua
            assert "FB_BALANCE_VP and 0 or FB_GetPublicOpinionUnhappiness(player)" in core_lua
            assert "local foundingCoreFood = city:IsCapital() and FB_FOUNDING_CORE_FOOD or 0" in core_lua
            assert "city:ChangeFood(data.foundingCoreFood + pending - data.metabolic - data.army)" in core_lua

    print("Validation passed: database, art, presentation, unit overrides, and metabolism UI are coherent.")


if __name__ == "__main__":
    main()
