#!/usr/bin/env python3
"""Writes scenes/sandbox/capsule_compare.tscn (#130): the prisoner capsules in three variants side by side.

Rows: Bowser (object No. 4), Herobrine (object No. 3). Columns: original text-to-3d GLB (scaled x5 like
scenes/*_pod.tscn), the light copy from lighten_capsules.py (same scale), and the scripted v2 assembly (capsule + separate sleeper,
objects/containment/prisoner_capsule_*.tscn, #162).
Each capsule gets the same interior light, so the comparison is fair. Generated: do not edit the scene by hand.
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "scenes" / "sandbox" / "capsule_compare.tscn"


def mb(path: Path) -> float:
    files = [path] if path.is_file() else [p for p in path.iterdir() if p.is_file() and p.suffix != ".import"]
    return sum(p.stat().st_size for p in files) / 1e6


def tris_of(gltf: Path) -> int:
    data = json.loads(gltf.read_text(encoding="utf-8"))
    return sum(data["accessors"][p["indices"]]["count"] // 3 for m in data["meshes"] for p in m["primitives"])


ROWS = [
    # name, original glb, centre height at x5, light colour, light copy, scripted wrapper, scripted gltf dir
    ("Боузер · объект №4", "res://loads/bowser_capsule/Hitem3d-1782155776080.glb", 1.525, "0.4, 1, 0.45",
     "loads/bowser_capsule/lod/bowser_capsule_lod.gltf", "capsule_bowser", 0.0),
    ("Херобрин · объект №3", "res://loads/herobrine_capsule/Hitem3d-1782239593585.glb", 1.22, "0.35, 0.6, 1",
     "loads/herobrine_capsule/lod/herobrine_capsule_lod.gltf", "capsule_herobrine", -8.0),
]
COLS = (-7.5, 0.0, 7.5)


def main() -> int:
    ext = ['[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="player"]',
           '[ext_resource type="PackedScene" path="res://scenes/ui/opening_hud.tscn" id="hud"]',
           '[ext_resource type="Material" path="res://materials/hangar_concrete_floor.tres" id="floor_mat"]']
    sub = ['[sub_resource type="Environment" id="env"]', "background_mode = 1", "background_color = Color(0.02, 0.022, 0.026, 1)",
           "ambient_light_source = 2", "ambient_light_color = Color(0.32, 0.34, 0.38, 1)", "ambient_light_energy = 0.4",
           "tonemap_mode = 2", "glow_enabled = true", "",
           '[sub_resource type="PlaneMesh" id="floor_mesh"]', 'material = ExtResource("floor_mat")', "size = Vector2(60, 40)", "",
           '[sub_resource type="BoxShape3D" id="floor_shape"]', "size = Vector3(60, 0.2, 40)", ""]
    nodes = ['[node name="CapsuleCompare" type="Node3D"]', "",
             '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("env")', "",
             '[node name="Floor" type="StaticBody3D" parent="."]', "",
             '[node name="Mesh" type="MeshInstance3D" parent="Floor"]', 'mesh = SubResource("floor_mesh")', "",
             '[node name="Collision" type="CollisionShape3D" parent="Floor"]', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)",
             'shape = SubResource("floor_shape")', ""]
    for r, (title, glb, cy, light, light_copy, scripted, z) in enumerate(ROWS):
        orig_path = REPO / glb.replace("res://", "")
        light_path = REPO / light_copy
        script_dir = REPO / "loads" / "props" / scripted
        variants = [
            ("Исходник (text-to-3d)", f'[ext_resource type="PackedScene" path="{glb}" id="o{r}"]', f"o{r}", 5.0, cy,
             f"≈ 2 млн треугольников · {mb(orig_path.parent):.0f} МБ"),
            ("Облегчённая копия", f'[ext_resource type="PackedScene" path="res://{light_copy}" id="l{r}"]', f"l{r}", 5.0, cy,
             f"{tris_of(light_path) // 1000} тыс. треугольников · {mb(light_path.parent):.1f} МБ"),
            ("Скриптовая модель v2", f'[ext_resource type="PackedScene" path="res://objects/containment/prisoner_{scripted}.tscn" id="s{r}"]', f"s{r}", 1.0, 0.0,
             f"{tris_of(script_dir / (scripted + '.gltf')) // 1000} тыс. треугольников · {mb(script_dir):.1f} МБ"),
        ]
        nodes += [f'[node name="RowTitle{r}" type="Label3D" parent="."]',
                  f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12.5, 2.0, {z:.2f})", f'text = "{title}"',
                  "font_size = 110", "outline_size = 14", "modulate = Color(1, 0.85, 0.45, 1)", ""]
        for c, (label, res, rid, scale, y, stats) in enumerate(variants):
            x = COLS[c]
            ext.append(res)
            name = f"R{r}C{c}"
            nodes += [f'[node name="{name}" parent="." instance=ExtResource("{rid}")]',
                      f"transform = Transform3D({scale}, 0, 0, 0, {scale}, 0, 0, 0, {scale}, {x}, {y:.3f}, {z:.2f})", "",
                      f'[node name="{name}_label" type="Label3D" parent="."]',
                      f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 3.9, {z + 1.0:.2f})",
                      f'text = "{label}\\n{stats}"', "font_size = 56", "outline_size = 10", "billboard = 1", ""]
            if c < 2:  # the scripted assembly carries its own interior light
                nodes += [f'[node name="{name}_inside" type="OmniLight3D" parent="."]',
                          f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 1.7, {z + 0.2:.2f})",
                          f"light_color = Color({light}, 1)", "light_energy = 1.2", "omni_range = 2.2", ""]
            nodes += [f'[node name="{name}_key" type="SpotLight3D" parent="."]',
                      f"transform = Transform3D(1, 0, 0, 0, 0.5, 0.866025, 0, -0.866025, 0.5, {x}, 5.5, {z + 4.0:.2f})",
                      "light_color = Color(1, 0.86, 0.72, 1)", "light_energy = 6.0", "spot_range = 12.0", "spot_angle = 38.0",
                      "shadow_enabled = true", ""]
    nodes += ['[node name="Player" parent="." node_paths=PackedStringArray("interact_label", "hold_progress_bar") instance=ExtResource("player")]',
              "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 7)",
              'interact_label = NodePath("../OpeningHud/InteractLabel")', 'hold_progress_bar = NodePath("../OpeningHud/HoldProgress")', "",
              '[node name="OpeningHud" parent="." instance=ExtResource("hud")]', ""]
    OUT.write_text("[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes), encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(REPO)} written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
