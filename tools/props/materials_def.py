"""Material tables shared by the Blender toolkit and the Blender-free validator."""

# Tile size in metres of every tiling PBR material (docs/art/texture-catalog.md).
TILE = {"painted_metal": 1.0, "steel_bare": 1.0, "rusted_steel": 1.0, "diamond_plate": 1.0, "rubber_black": 0.5,
        "plastic_panel": 0.5, "vinyl_worn": 0.5, "duct_galvanized": 1.0, "concrete_rubble": 2.0, "paper_aged": 0.4}

# name -> (base colour rgb, emission rgb, emission strength). Parameter-only materials (no textures).
EMIT = {
    "emit_screen_cyan": ((0.0, 0.0, 0.0), (0.12, 0.71, 0.78), 1.6),
    "emit_led_green": ((0.0, 0.0, 0.0), (0.24, 0.83, 0.42), 2.5),
    "emit_led_amber": ((0.0, 0.0, 0.0), (0.91, 0.64, 0.11), 2.5),
    "emit_led_red": ((0.0, 0.0, 0.0), (0.85, 0.2, 0.12), 3.0),
    "emit_lamp_warm": ((0.0, 0.0, 0.0), (1.0, 0.62, 0.28), 3.0),
    "emit_lamp_cold": ((0.0, 0.0, 0.0), (0.75, 0.88, 1.0), 3.0),
    "crystal_core": ((0.35, 0.65, 0.95), (0.3, 0.6, 1.0), 2.0),
}
# name -> (rgb, roughness, metallic, alpha)
PLAIN = {"glass_dirty": ((0.08, 0.1, 0.11), 0.25, 0.0, 0.28), "chrome_dull": ((0.55, 0.56, 0.58), 0.35, 1.0, 1.0),
         "white_paint_worn": ((0.55, 0.55, 0.52), 0.7, 0.0, 1.0),
         "red_paint_worn": ((0.36, 0.07, 0.05), 0.65, 0.0, 1.0)}
# decal / atlas materials: name -> (texture path under loads/textures, blend?, emissive strength or 0)
ATLAS = {"signs_ru": ("decals/signs_ru.png", True, 0.0), "hazard_stripes": ("decals/hazard_stripes.png", True, 0.0),
         "panel_labels": ("decals/panel_labels.png", True, 0.0), "instrument_faces": ("decals/instrument_faces.png", True, 0.0),
         "screens": ("decals/screens.png", False, 1.4), "signs_lit": ("decals/signs_ru.png", False, 0.9), "grime_streaks": ("decals/grime_streaks.png", True, 0.0),
         "rust_bleed": ("decals/rust_bleed.png", True, 0.0), "scuffs": ("decals/scuffs.png", True, 0.0)}
