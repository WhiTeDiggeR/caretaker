"""Writes scenes/sandbox/door_showcase.tscn: every door preset in one 0.3 m wall (issue #157 review scene).

Usage: python3 tools/props/make_door_showcase.py
"""

from pathlib import Path
repo = Path(__file__).resolve().parents[2]
doors = [("Hermetic", "hermetic_door", -7.0, 1.8, 2.8), ("Mechanical", "mechanical_door", -3.0, 1.8, 2.8),
         ("Gate", "access_gate", 1.0, 1.8, 2.8), ("Historic", "historic_door", 4.6, 1.4, 2.3), ("Service", "service_door", 7.6, 1.0, 2.1)]
ext = ['[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="player"]',
       '[ext_resource type="PackedScene" path="res://scenes/ui/opening_hud.tscn" id="hud"]',
       '[ext_resource type="Material" path="res://materials/lookdev/wall_concrete.tres" id="wall"]',
       '[ext_resource type="Material" path="res://materials/lookdev/floor.tres" id="floor"]']
for n, f, *_ in doors:
    ext.append(f'[ext_resource type="PackedScene" path="res://objects/doors/{f}.tscn" id="{f}"]')
sub = ['[sub_resource type="Environment" id="env"]', "background_mode = 1", "background_color = Color(0.02, 0.02, 0.025, 1)",
       "ambient_light_source = 2", "ambient_light_color = Color(0.3, 0.32, 0.36, 1)", "ambient_light_energy = 0.3",
       "tonemap_mode = 3", "tonemap_white = 6.0", "ssao_enabled = true", ""]
nodes = ['[node name="DoorShowcase" type="Node3D"]', "",
         '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("env")', "",
         '[node name="Floor" type="CSGBox3D" parent="."]', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)",
         "use_collision = true", "size = Vector3(24, 0.2, 14)", 'material = ExtResource("floor")', "",
         '[node name="Wall" type="CSGCombiner3D" parent="."]', "use_collision = true", "",
         '[node name="Slab" type="CSGBox3D" parent="Wall"]', "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.5, 1.75, 0)",
         "size = Vector3(21, 3.5, 0.3)", 'material = ExtResource("wall")', ""]
for n, f, x, w, h in doors:
    nodes += [f'[node name="Cut{n}" type="CSGBox3D" parent="Wall"]', "operation = 2",
              f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {(h + 0.2) / 2 - 0.01}, 0)",
              f"size = Vector3({w + 0.4 - 0.02}, {h + 0.2 + 0.02}, 0.4)", ""]
for n, f, x, w, h in doors:
    nodes += [f'[node name="{n}" parent="." instance=ExtResource("{f}")]', f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 0, 0)", ""]
for i, (x, z) in enumerate([(-6, 3), (-1, 3), (4, 3), (8, 3), (-4, -3), (3, -3)]):
    nodes += [f'[node name="Lamp{i}" type="OmniLight3D" parent="."]', f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 3.2, {z})",
              "light_color = Color(1, 0.86, 0.7, 1)", "light_energy = 2.2", "shadow_enabled = true", "omni_range = 9.0", ""]
nodes += ['[node name="Player" parent="." node_paths=PackedStringArray("interact_label", "hold_progress_bar") instance=ExtResource("player")]',
          "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 5)",
          'interact_label = NodePath("../OpeningHud/InteractLabel")', 'hold_progress_bar = NodePath("../OpeningHud/HoldProgress")', "",
          '[node name="OpeningHud" parent="." instance=ExtResource("hud")]', ""]
out = repo / "scenes/sandbox/door_showcase.tscn"
out.write_text("[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes), encoding="utf-8", newline="\n")
print(out)
