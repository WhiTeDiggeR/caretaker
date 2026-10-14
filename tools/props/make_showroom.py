#!/usr/bin/env python3
"""Writes scenes/sandbox/art_showroom.tscn: every prop wrapper of objects/art in labelled rows, a wall of material
swatches, dim complex-like lighting and the player, so the art can be walked around in Godot.

Usage: python3 tools/props/make_showroom.py   (re-run after adding props; the scene is generated, do not edit it by hand)
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "scenes" / "sandbox" / "art_showroom.tscn"
GAP = 1.2           # free space between props in a row, metres
ROW_GAP = 2.5       # free space between rows
ROW_WIDTH = 34.0    # wrap rows after this length
# debug labels (#207): small type wrapped to the prop's slot, every other label raised so neighbours do not overlap,
# faded out beyond LABEL_RANGE; F1 hides them all (scenes/sandbox/art_showroom.gd)
LABEL_GROUP = "showroom_labels"
LABEL_PIXEL = 0.003      # metres per font pixel
LABEL_FONT = 32
LABEL_STAGGER = 0.22     # extra height of every other label in a row, metres
LABEL_RANGE = 9.0        # labels fade out beyond this distance, metres
LABEL_FADE = 1.5


def rows_for(specs: dict):
    """Groups props: procedural (ours), Poly Haven singles, Poly Haven kit pieces."""
    ours = sorted(k for k, s in specs.items() if not s.get("external"))
    ph = sorted(k for k, s in specs.items() if s.get("external") and "__" not in k)
    kits = sorted(k for k, s in specs.items() if s.get("external") and "__" in k)
    return [("Скрипт (tools/props)", ours), ("Poly Haven", ph), ("Poly Haven: модульные наборы", kits)]


def main() -> int:
    specs = json.loads((HERE / "specs.json").read_text(encoding="utf-8"))
    materials = json.loads((HERE / "sourced_tiles.json").read_text(encoding="utf-8"))
    import sys
    sys.path.insert(0, str(HERE))
    from materials_def import TILE

    ext, sub, nodes = [], [], []
    ext.append('[ext_resource type="Script" path="res://scenes/sandbox/art_showroom.gd" id="showroom_script"]')
    ext.append('[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="player"]')
    ext.append('[ext_resource type="PackedScene" path="res://scenes/ui/opening_hud.tscn" id="hud"]')
    ext.append('[ext_resource type="Material" path="res://materials/hangar_concrete_floor.tres" id="floor_mat"]')

    sub += ['[sub_resource type="Environment" id="env"]', "background_mode = 1", "background_color = Color(0.02, 0.022, 0.026, 1)",
            "ambient_light_source = 2", "ambient_light_color = Color(0.32, 0.34, 0.38, 1)", "ambient_light_energy = 0.35",
            "tonemap_mode = 2", "glow_enabled = true", "fog_enabled = true", "fog_light_color = Color(0.05, 0.055, 0.06, 1)",
            "fog_density = 0.008", "",
            '[sub_resource type="PlaneMesh" id="floor_mesh"]', 'material = ExtResource("floor_mat")', "size = Vector2(120, 120)", "",
            '[sub_resource type="BoxShape3D" id="floor_shape"]', "size = Vector3(120, 0.2, 120)", "",
            '[sub_resource type="BoxMesh" id="swatch_mesh"]', "size = Vector3(1, 1, 0.1)", ""]

    fade = [f"visibility_range_end = {LABEL_RANGE}", f"visibility_range_end_margin = {LABEL_FADE}", "visibility_range_fade_mode = 1"]
    nodes += ['[node name="ArtShowroom" type="Node3D"]', 'script = ExtResource("showroom_script")', "",
              '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("env")', "",
              '[node name="Moon" type="DirectionalLight3D" parent="."]',
              "transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 12, 0)",
              "light_color = Color(0.75, 0.82, 0.95, 1)", "light_energy = 0.35", "shadow_enabled = true", "",
              '[node name="Floor" type="StaticBody3D" parent="."]', "",
              '[node name="Mesh" type="MeshInstance3D" parent="Floor"]', 'mesh = SubResource("floor_mesh")', "",
              '[node name="Collision" type="CollisionShape3D" parent="Floor"]', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)",
              'shape = SubResource("floor_shape")', "",
              '[node name="Props" type="Node3D" parent="."]', ""]

    z = 0.0
    light_i = 0
    for title, ids in rows_for(specs):
        if not ids:
            continue
        nodes += [f'[node name="Title{light_i}" type="Label3D" parent="Props" groups=["{LABEL_GROUP}"]]',
                  f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 3.2, {z:.2f})", f'text = "{title}"',
                  "font_size = 96", "outline_size = 12", "modulate = Color(1, 0.85, 0.45, 1)", ""]
        x, row_depth, in_row = 0.0, 0.0, 0
        for pid in ids:
            s = specs[pid]
            w, h, d = s["size"]
            if x > 0 and x + w > ROW_WIDTH:
                z += row_depth + ROW_GAP
                x, row_depth, in_row = 0.0, 0.0, 0
            cx = x + w / 2
            y = 0.0
            if s["anchor"] == "ceiling":
                y = h + 0.4          # hang it at a reachable height
            elif s["anchor"] == "free" and "__" not in pid:
                y = h / 2 + 0.75     # small free items float at table height
            elif s["anchor"] == "free":
                y = h / 2 + 0.05
            idx = len(ext) + 1
            wrapper = f"objects/art/{pid}.tscn"
            if not (REPO / wrapper).exists():   # dream kit modules have no wrapper: show the bare model
                wrapper = f"loads/props/{s.get('gltf', f'{pid}/{pid}.gltf')}"
            ext.append(f'[ext_resource type="PackedScene" path="res://{wrapper}" id="p{idx}"]')
            name = pid.replace("__", "_")
            nodes += [f'[node name="{name}" parent="Props" instance=ExtResource("p{idx}")]',
                      f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx:.3f}, {y:.3f}, {z:.3f})", "",
                      f'[node name="{name}_label" type="Label3D" parent="Props" groups=["{LABEL_GROUP}"]]',
                      f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx:.3f}, "
                      f"{max(y + h + 0.2, 0.4) + LABEL_STAGGER * (in_row % 2):.3f}, {z + d / 2 + 0.05:.3f})",
                      *fade, f"pixel_size = {LABEL_PIXEL}", "billboard = 1", "modulate = Color(0.85, 0.88, 0.9, 1)",
                      f'text = "{pid}\\n{s["catalog"]}  {w:.2f}×{h:.2f}×{d:.2f}"', f"font_size = {LABEL_FONT}", "outline_size = 6",
                      "autowrap_mode = 1", f"width = {int((w + GAP) * 0.9 / LABEL_PIXEL)}", ""]
            in_row += 1
            if light_i % 3 == 0:
                warm = (light_i // 3) % 2 == 0
                nodes += [f'[node name="Lamp{light_i}" type="OmniLight3D" parent="Props"]',
                          f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx:.3f}, 3.2, {z + 1.2:.3f})",
                          f"light_color = Color({'1, 0.72, 0.45' if warm else '0.72, 0.85, 1'}, 1)", "light_energy = 1.6",
                          "omni_range = 7.0", f"shadow_enabled = {'true' if light_i % 9 == 0 else 'false'}", ""]
            light_i += 1
            x += w + GAP
            row_depth = max(row_depth, d)
        z += row_depth + ROW_GAP * 1.6

    # material swatches: one ORM material per tiling texture, on a wall behind the start
    for i, mat in enumerate(sorted(TILE)):
        base = f"res://loads/textures/{mat}/{mat}"
        a, n, o = len(ext) + 1, len(ext) + 2, len(ext) + 3
        ext += [f'[ext_resource type="Texture2D" path="{base}_albedo.jpg" id="t{a}"]',
                f'[ext_resource type="Texture2D" path="{base}_normal.png" id="t{n}"]',
                f'[ext_resource type="Texture2D" path="{base}_orm.jpg" id="t{o}"]']
        sub += [f'[sub_resource type="ORMMaterial3D" id="m_{mat}"]', f'albedo_texture = ExtResource("t{a}")',
                f'orm_texture = ExtResource("t{o}")', "normal_enabled = true", f'normal_texture = ExtResource("t{n}")',
                f"uv1_scale = Vector3({1 / TILE[mat]:.3f}, {1 / TILE[mat]:.3f}, 1)", ""]
        sx = -4.0 - (i % 7) * 1.5
        sy = 0.8 + (i // 7) * 1.4
        nodes += [f'[node name="Swatch_{mat}" type="MeshInstance3D" parent="."]',
                  f"transform = Transform3D(1.2, 0, 0, 0, 1.2, 0, 0, 0, 1, {sx:.2f}, {sy:.2f}, -3)",
                  'mesh = SubResource("swatch_mesh")', f'surface_material_override/0 = SubResource("m_{mat}")', "",
                  f'[node name="Swatch_{mat}_label" type="Label3D" parent="." groups=["{LABEL_GROUP}"]]',
                  f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {sx:.2f}, {sy - 0.72:.2f}, -2.9)", *fade,
                  f"pixel_size = {LABEL_PIXEL}", f'text = "{mat}{" (Poly Haven)" if mat in materials else ""}"',
                  f"font_size = {LABEL_FONT}", "outline_size = 6", "autowrap_mode = 1", f"width = {int(1.4 / LABEL_PIXEL)}", ""]
    nodes += ['[node name="SwatchLight" type="OmniLight3D" parent="."]',
              "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -8.5, 2.5, -1)", "light_energy = 1.4", "omni_range = 8.0", ""]

    nodes += ['[node name="Player" parent="." node_paths=PackedStringArray("interact_label", "hold_progress_bar") instance=ExtResource("player")]',
              "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 1, 2)",
              'interact_label = NodePath("../OpeningHud/InteractLabel")', 'hold_progress_bar = NodePath("../OpeningHud/HoldProgress")', "",
              '[node name="OpeningHud" parent="." instance=ExtResource("hud")]', ""]
    text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(REPO)}: {len(specs)} props, {len(TILE)} material swatches")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
