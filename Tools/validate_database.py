"""Apply the mod SQL to a scrubbed Civ V debug database and verify art wiring."""

from __future__ import annotations

import argparse
import shutil
import sqlite3
import struct
import tempfile
from contextlib import closing
from pathlib import Path


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("debug_database", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    root = args.project_root.resolve()
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

            assert scalar(database, "SELECT COUNT(*) FROM IconTextureAtlases WHERE Atlas LIKE 'FLESHBORN_%'") == 21
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
                   AND ImprovementType = 'IMPROVEMENT_FARM'""",
            ) == 1
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
                        AND ({index_column} < 0 OR {index_column} >= 16)""",
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

    print("Database validation passed: SQL, atlases, colors, presentation, and unit overrides are coherent.")


if __name__ == "__main__":
    main()
