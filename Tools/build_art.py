"""Build Civilization V DDS atlases and presentation screens from source PNGs."""

from __future__ import annotations

import argparse
import shutil
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


SOURCE_FILES = {
    "civilization": "Fleshborn_Chorus_Civilization_Icon.png",
    "map": "Dawn_of_Man_Map.png",
    "leader_civ5": "Leader_Icon_Civ5_Style.png",
    "colony_bud_v1": "Colony_Bud_v1.png",
    "digestive_chamber": "Digestive_Chamber.png",
    "behemoth": "Behemoth.png",
    "harvester": "Harvester.png",
    "hunger": "The_Hunger_Promotion.png",
    "leader_v1": "Leader_Icon_v1.png",
    "leviathan": "Leviathan.png",
    "skyhunter": "Skyhunter.png",
    "feeding_field": "Feeding_Field.png",
    "spinecaster": "Spinecaster.png",
    "spitter": "Spitter_Form.png",
    "infographic": "Fleshborn_Chorus_Concept_Infographic.png",
    "ripper": "Ripper_Form.png",
    "blightwing": "Blightwing.png",
    "dom_civ5": "Dawn_of_Man_Civ5_Style.png",
    "hunter": "Hunter_Form.png",
    "dom_v1": "Dawn_of_Man_v1.png",
    "warform": "Warform.png",
    "colony_bud_v2": "Colony_Bud_v2.png",
}

IMPORT_NAMES = {
    name: source_name for name, source_name in {
        "civilization": "Fleshborn_Chorus_Civilization_Icon (3).png",
        "map": "Dawn_of_Man_Map (3).png",
        "leader_civ5": "Leader_Icon_Civ5_Style (3).png",
        "colony_bud_v1": "Colony_Bud_v1 (3).png",
        "digestive_chamber": "Digestive_Chamber (3).png",
        "behemoth": "Behemoth (3).png",
        "harvester": "Harvester (3).png",
        "hunger": "The_Hunger_Promotion (3).png",
        "leader_v1": "Leader_Icon_v1 (3).png",
        "leviathan": "Leviathan (3).png",
        "skyhunter": "Skyhunter (3).png",
        "feeding_field": "Feeding_Field (3).png",
        "spinecaster": "Spinecaster (3).png",
        "spitter": "Spitter_Form (3).png",
        "infographic": "Fleshborn_Chorus_Concept_Infographic (3).png",
        "ripper": "Ripper_Form (3).png",
        "blightwing": "Blightwing (3).png",
        "dom_civ5": "Dawn_of_Man_Civ5_Style (3).png",
        "hunter": "Hunter_Form (3).png",
        "dom_v1": "Dawn_of_Man_v1 (3).png",
        "warform": "Warform (3).png",
        "colony_bud_v2": "Colony_Bud_v2 (3).png",
    }.items()
}

ICON_ORDER = (
    "hunter",
    "spitter",
    "ripper",
    "spinecaster",
    "warform",
    "behemoth",
    "skyhunter",
    "blightwing",
    "leviathan",
    "harvester",
    "colony_bud_v2",
    "digestive_chamber",
    "feeding_field",
    "hunger",
    "colony_bud_v1",
)


def import_sources(import_dir: Path, source_dir: Path) -> None:
    source_dir.mkdir(parents=True, exist_ok=True)
    for key, clean_name in SOURCE_FILES.items():
        incoming = import_dir / IMPORT_NAMES[key]
        if not incoming.is_file():
            raise FileNotFoundError(incoming)
        shutil.copy2(incoming, source_dir / clean_name)


def edge_black_transparency(image: Image.Image, threshold: int = 30) -> Image.Image:
    """Remove only near-black pixels connected to an image edge."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    outside = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def eligible(x: int, y: int) -> bool:
        red, green, blue, _ = pixels[x, y]
        return max(red, green, blue) <= threshold

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if not outside[index] and eligible(x, y):
            outside[index] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    alpha = Image.new("L", image.size, 255)
    alpha_pixels = alpha.load()
    for y in range(height):
        for x in range(width):
            if outside[y * width + x]:
                brightness = max(pixels[x, y][:3])
                alpha_pixels[x, y] = max(0, min(255, brightness * 255 // threshold))
    image.putalpha(alpha)
    return image


def cover(image: Image.Image, target: tuple[int, int], focus_x: float = 0.5) -> Image.Image:
    target_width, target_height = target
    ratio = max(target_width / image.width, target_height / image.height)
    resized = image.resize(
        (round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS
    )
    left = round((resized.width - target_width) * focus_x)
    top = (resized.height - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def save_dds(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path, pixel_format="DXT5")


def build_one_cell_atlas(source: Path, sizes: tuple[int, ...], output: Path, stem: str) -> None:
    icon = edge_black_transparency(Image.open(source))
    for size in sizes:
        save_dds(icon.resize((size, size), Image.Resampling.LANCZOS), output / f"{stem}_{size}.dds")


def build_shared_atlas(source_dir: Path, output: Path) -> None:
    icons = [edge_black_transparency(Image.open(source_dir / SOURCE_FILES[key])) for key in ICON_ORDER]
    for size in (256, 128, 80, 64, 45, 32):
        atlas = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
        for index, icon in enumerate(icons):
            tile = icon.resize((size, size), Image.Resampling.LANCZOS)
            atlas.alpha_composite(tile, ((index % 4) * size, (index // 4) * size))
        save_dds(atlas, output / f"Fleshborn_Icons_{size}.dds")


def build_alpha_atlas(source: Path, sizes: tuple[int, ...], output: Path) -> None:
    icon = edge_black_transparency(Image.open(source))
    grayscale = icon.convert("L")
    alpha = icon.getchannel("A")
    icon = Image.merge("RGBA", (grayscale, grayscale, grayscale, alpha))
    for size in sizes:
        save_dds(icon.resize((size, size), Image.Resampling.LANCZOS), output / f"Fleshborn_Civ_Alpha_{size}.dds")


def build_screens(source_dir: Path, output: Path) -> None:
    dom = cover(Image.open(source_dir / SOURCE_FILES["dom_civ5"]).convert("RGB"), (1024, 768), 0.48)
    save_dds(dom, output / "Fleshborn_DOM.dds")

    map_image = cover(Image.open(source_dir / SOURCE_FILES["map"]).convert("RGB"), (360, 412), 0.50)
    save_dds(map_image, output / "Fleshborn_Map.dds")

    diplomacy = cover(Image.open(source_dir / SOURCE_FILES["dom_v1"]).convert("RGB"), (1600, 900), 0.50)
    diplomacy = diplomacy.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=4))
    save_dds(diplomacy, output / "Fleshborn_Diplomacy.dds")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--import-dir", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    root = args.project_root.resolve()
    source_dir = root / "Art" / "Source"
    atlas_dir = root / "Art" / "Atlases"
    screen_dir = root / "Art" / "Screens"

    if args.import_dir:
        import_sources(args.import_dir.resolve(), source_dir)

    missing = [path for path in SOURCE_FILES.values() if not (source_dir / path).is_file()]
    if missing:
        raise FileNotFoundError("Missing source art: " + ", ".join(missing))

    build_shared_atlas(source_dir, atlas_dir)
    build_one_cell_atlas(
        source_dir / SOURCE_FILES["civilization"],
        (256, 128, 80, 64, 45, 32),
        atlas_dir,
        "Fleshborn_Civ",
    )
    build_alpha_atlas(
        source_dir / SOURCE_FILES["civilization"],
        (128, 64, 48, 32, 24, 16),
        atlas_dir,
    )
    build_one_cell_atlas(
        source_dir / SOURCE_FILES["leader_civ5"],
        (256, 128, 64),
        atlas_dir,
        "Fleshborn_Leader",
    )
    build_screens(source_dir, screen_dir)


if __name__ == "__main__":
    main()
