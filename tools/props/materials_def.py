"""Material tables shared by the Blender toolkit and the Blender-free validator."""

# Tile size in metres of every tiling PBR material (docs/art/texture-catalog.md).
TILE = {"painted_metal": 1.0, "steel_bare": 1.0, "rusted_steel": 1.0, "diamond_plate": 1.0, "rubber_black": 0.5,
        "plastic_panel": 0.5, "vinyl_worn": 0.5, "duct_galvanized": 1.0, "concrete_rubble": 2.0, "paper_aged": 0.4, "wood_old": 1.0, "fabric_dark": 0.5}

# name -> (base colour rgb, emission rgb, emission strength). Parameter-only materials (no textures).
EMIT = {
    "emit_screen_cyan": ((0.0, 0.0, 0.0), (0.12, 0.71, 0.78), 1.6),
    "emit_led_green": ((0.0, 0.0, 0.0), (0.24, 0.83, 0.42), 2.5),
    "emit_led_amber": ((0.0, 0.0, 0.0), (0.91, 0.64, 0.11), 2.5),
    "emit_led_red": ((0.0, 0.0, 0.0), (0.85, 0.2, 0.12), 3.0),
    "emit_lamp_warm": ((0.0, 0.0, 0.0), (1.0, 0.62, 0.28), 3.0),
    "emit_lamp_cold": ((0.0, 0.0, 0.0), (0.75, 0.88, 1.0), 3.0),
    "emit_beacon_red": ((0.0, 0.0, 0.0), (0.9, 0.12, 0.06), 1.6),
    "crystal_core": ((0.35, 0.65, 0.95), (0.3, 0.6, 1.0), 2.0),
    "emit_cold_blue": ((0.0, 0.0, 0.0), (0.12, 0.4, 1.0), 1.3),
    "emit_haze_green": ((0.0, 0.0, 0.0), (0.25, 0.6, 0.3), 0.45),
    "emit_haze_blue": ((0.0, 0.0, 0.0), (0.15, 0.35, 0.8), 0.45),
    "emit_green_soft": ((0.0, 0.0, 0.0), (0.3, 0.85, 0.35), 1.2),
    "emit_eye_white": ((0.0, 0.0, 0.0), (0.95, 0.97, 1.0), 4.0),
}
# name -> (rgb, roughness, metallic, alpha)
PLAIN = {"glass_dirty": ((0.08, 0.1, 0.11), 0.25, 0.0, 0.28), "chrome_dull": ((0.55, 0.56, 0.58), 0.35, 1.0, 1.0),
         "white_paint_worn": ((0.55, 0.55, 0.52), 0.7, 0.0, 1.0),
         "red_paint_worn": ((0.36, 0.07, 0.05), 0.65, 0.0, 1.0),
         # prisoner capsules (#130): tinted observation glass and the sleepers inside
         "glass_green": ((0.5, 0.62, 0.52), 0.06, 0.0, 0.1), "glass_blue": ((0.5, 0.56, 0.66), 0.06, 0.0, 0.1),
         # object No. 4 sleeper (#162): saturated so the figure reads through the green glass
         "skin_yellow": ((0.8, 0.58, 0.14), 0.62, 0.0, 1.0), "shell_green": ((0.1, 0.42, 0.12), 0.38, 0.0, 1.0),
         "horn_bone": ((0.86, 0.8, 0.64), 0.5, 0.0, 1.0), "hair_red": ((0.78, 0.16, 0.05), 0.75, 0.0, 1.0),
         "belly_cream": ((0.9, 0.78, 0.5), 0.6, 0.0, 1.0), "collar_black": ((0.03, 0.03, 0.035), 0.4, 0.0, 1.0),
         "cloth_teal": ((0.06, 0.32, 0.36), 0.85, 0.0, 1.0), "cloth_navy": ((0.12, 0.1, 0.36), 0.85, 0.0, 1.0),
         "skin_tan": ((0.46, 0.33, 0.24), 0.75, 0.0, 1.0)}
# decal / atlas materials: name -> (texture path under loads/textures, blend?, emissive strength or 0)
ATLAS = {"signs_ru": ("decals/signs_ru.png", True, 0.0), "hazard_stripes": ("decals/hazard_stripes.png", True, 0.0),
         "panel_labels": ("decals/panel_labels.png", True, 0.0), "instrument_faces": ("decals/instrument_faces.png", True, 0.0),
         "screens": ("decals/screens.png", False, 1.4), "signs_lit": ("decals/signs_ru.png", False, 0.9), "grime_streaks": ("decals/grime_streaks.png", True, 0.0),
         "rust_bleed": ("decals/rust_bleed.png", True, 0.0), "scuffs": ("decals/scuffs.png", True, 0.0),
         "floor_markings": ("decals/floor_markings.png", True, 0.0),
         "capsule_screens": ("decals/capsule_screens.png", False, 1.5),
         # blocky sleeper skin (#162): faintly self-lit so the figure reads inside the dim capsule
         "sleeper_skins": ("decals/sleeper_skins.png", False, 0.3)}


# Materials replaced by downloaded scans (import_textures.py) carry their real-world tile size.
import json as _json  # noqa: E402
from pathlib import Path as _Path  # noqa: E402

_SOURCED = _Path(__file__).with_name("sourced_tiles.json")
SOURCED = set()
if _SOURCED.exists():
    for _name, _tile in _json.loads(_SOURCED.read_text(encoding="utf-8")).items():
        TILE[_name] = _tile
        SOURCED.add(_name)
