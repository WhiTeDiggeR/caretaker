#!/usr/bin/env python3
"""Writes the look-dev scene scenes/sandbox/lookdev_rooms.tscn (#131) and its architecture materials.

Two contrasting rooms joined by a short corridor with a mechanical door:
  * West — operator post («пост управления», upper floor, walls 5.0 m, D-46): cold fluorescent light, screens, a
    failing tube, painted lower wall band, consoles facing the mnemonic board, ducts and cables under the ceiling.
  * East — machine hall («машинный зал», technical floor, walls 4.5 m): warm hanging lamps, pipes with a valve,
    generator panel, fan unit, barrels and gas bottles, workshop corner, a collapse in the corner.
Architecture is plain boxes with the project's concrete scans (world triplanar); props are objects/art wrappers.
Usage: python3 tools/props/make_lookdev.py   (generated, do not edit the scene by hand)
"""
from __future__ import annotations

import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "scenes" / "sandbox" / "lookdev_rooms.tscn"
MAT_DIR = REPO / "materials" / "lookdev"
SPECS = json.loads((HERE / "specs.json").read_text(encoding="utf-8"))

# architecture materials: name -> (texture base path, tint, triplanar scale (1/tile metres), roughness multiplier)
ARCH = {
    "wall_concrete": ("res://loads/concrete_slab_wall_02/textures/concrete_slab_wall_02", (0.42, 0.43, 0.45), 0.33),
    "wall_layers": ("res://loads/concrete_layers/textures/concrete_layers", (0.4, 0.38, 0.36), 0.3),
    "ceiling": ("res://loads/cracked_concrete/textures/cracked_concrete", (0.3, 0.31, 0.33), 0.33),
    "floor": ("res://loads/floor_hangar/textures/hangar_concrete_floor", (0.38, 0.38, 0.4), 0.25),
}


def write_materials():
    MAT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (base, tint, scale) in ARCH.items():
        (MAT_DIR / f"{name}.tres").write_text(f'''[gd_resource type="ORMMaterial3D" format=3]

[ext_resource type="Texture2D" path="{base}_diff_4k.jpg" id="1"]
[ext_resource type="Texture2D" path="{base}_arm_4k.jpg" id="2"]
[ext_resource type="Texture2D" path="{base}_nor_gl_4k.jpg" id="3"]

[resource]
resource_name = "{name}"
albedo_color = Color({tint[0]}, {tint[1]}, {tint[2]}, 1)
albedo_texture = ExtResource("1")
orm_texture = ExtResource("2")
normal_enabled = true
normal_texture = ExtResource("3")
uv1_scale = Vector3({scale}, {scale}, {scale})
uv1_triplanar = true
uv1_world_triplanar = true
''', encoding="utf-8", newline="\n")
    t = "res://loads/textures/arch_paint_band/arch_paint_band"
    (MAT_DIR / "paint_band.tres").write_text(f'''[gd_resource type="ORMMaterial3D" format=3]

[ext_resource type="Texture2D" path="{t}_albedo.jpg" id="1"]
[ext_resource type="Texture2D" path="{t}_orm.jpg" id="2"]
[ext_resource type="Texture2D" path="{t}_normal.png" id="3"]

[resource]
resource_name = "paint_band"
albedo_texture = ExtResource("1")
orm_texture = ExtResource("2")
normal_enabled = true
normal_texture = ExtResource("3")
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
uv1_world_triplanar = true
''', encoding="utf-8", newline="\n")


class Scene:
    def __init__(self):
        self.ext, self.sub, self.nodes = [], [], []
        self._ext_ids, self._box_ids = {}, {}

    def ext_res(self, kind: str, path: str) -> str:
        if path not in self._ext_ids:
            rid = f"e{len(self._ext_ids) + 1}"
            self._ext_ids[path] = rid
            self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        return self._ext_ids[path]

    def box_mesh(self, size, mat: str) -> tuple[str, str]:
        key = (tuple(round(s, 3) for s in size), mat)
        if key not in self._box_ids:
            i = len(self._box_ids) + 1
            mid = self.ext_res("Material", f"res://materials/lookdev/{mat}.tres")
            self.sub += [f'[sub_resource type="BoxMesh" id="bm{i}"]', f'material = ExtResource("{mid}")',
                         f"size = Vector3({key[0][0]}, {key[0][1]}, {key[0][2]})", "",
                         f'[sub_resource type="BoxShape3D" id="bs{i}"]', f"size = Vector3({key[0][0]}, {key[0][1]}, {key[0][2]})", ""]
            self._box_ids[key] = (f"bm{i}", f"bs{i}")
        return self._box_ids[key]

    def block(self, name: str, lo, hi, mat: str, collide=True):
        """Axis-aligned architectural block between corners lo and hi."""
        size = [hi[i] - lo[i] for i in range(3)]
        c = [(hi[i] + lo[i]) / 2 for i in range(3)]
        mesh, shape = self.box_mesh(size, mat)
        self.nodes += [f'[node name="{name}" type="MeshInstance3D" parent="Architecture"]',
                       f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f})", f'mesh = SubResource("{mesh}")', ""]
        if collide:
            self.nodes += [f'[node name="{name}_col" type="CollisionShape3D" parent="Architecture/Body"]',
                           f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f})", f'shape = SubResource("{shape}")', ""]

    def prop(self, name: str, pid: str, pos, yaw: float = 0.0, parent: str = "Props"):
        rid = self.ext_res("PackedScene", f"res://objects/art/{pid}.tscn")
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        self.nodes += [f'[node name="{name}" parent="{parent}" instance=ExtResource("{rid}")]',
                       f"transform = Transform3D({c:.6f}, 0, {-s:.6f}, 0, 1, 0, {s:.6f}, 0, {c:.6f}, {pos[0]:.3f}, {pos[1]:.3f}, {pos[2]:.3f})", ""]

    def light(self, name: str, kind: str, pos, color, energy, rng, shadow=False, extra=(), basis="1, 0, 0, 0, 1, 0, 0, 0, 1"):
        attr = "omni_range" if kind == "OmniLight3D" else "spot_range"
        self.nodes += [f'[node name="{name}" type="{kind}" parent="Lights"]',
                       f"transform = Transform3D({basis}, {pos[0]:.3f}, {pos[1]:.3f}, {pos[2]:.3f})",
                       f"light_color = Color({color[0]}, {color[1]}, {color[2]}, 1)", f"light_energy = {energy}",
                       f"{attr} = {rng}", f"shadow_enabled = {'true' if shadow else 'false'}", *extra, ""]


def size(pid):
    return SPECS[pid]["size"]


def build() -> Scene:
    s = Scene()
    T = 0.3                    # wall thickness
    # ------------------------------------------------------------ architecture
    # West room (operator post): x -11..-2, z -4.5..4.5, h 5.0
    ax0, ax1, az, ah = -11.0, -2.0, 4.5, 5.0
    # Corridor: x -2..3, z -1.6..1.6, h 3.2 ; door partition at x = 0.5
    cz, ch = 1.6, 3.2
    # East room (machine hall): x 3..14, z -5.5..5.5, h 4.5
    bx0, bx1, bz, bh = 3.0, 14.0, 5.5, 4.5
    s.block("FloorA", (ax0, -0.2, -az), (ax1, 0.0, az), "floor")
    s.block("FloorCorr", (ax1, -0.2, -cz), (bx0, 0.0, cz), "floor")
    s.block("FloorB", (bx0, -0.2, -bz), (bx1, 0.0, bz), "floor")
    s.block("CeilA", (ax0, ah, -az), (ax1, ah + 0.3, az), "ceiling")
    s.block("CeilCorr", (ax1, ch, -cz), (bx0, ch + 0.3, cz), "ceiling")
    s.block("CeilB", (bx0, bh, -bz), (bx1, bh + 0.3, bz), "ceiling")
    # west room walls
    s.block("A_N", (ax0 - T, 0, -az - T), (ax1 + T, ah, -az), "wall_concrete")
    s.block("A_S", (ax0 - T, 0, az), (ax1 + T, ah, az + T), "wall_concrete")
    s.block("A_W", (ax0 - T, 0, -az), (ax0, ah, az), "wall_concrete")
    s.block("A_E1", (ax1, 0, -az), (ax1 + T, ah, -cz), "wall_concrete")
    s.block("A_E2", (ax1, 0, cz), (ax1 + T, ah, az), "wall_concrete")
    s.block("A_E3", (ax1, ch, -cz), (ax1 + T, ah, cz), "wall_concrete")
    # painted lower band (1.3 m) on the west room walls
    pb, pt = 1.3, 0.015
    s.block("A_N_band", (ax0, 0, -az), (ax1, pb, -az + pt), "paint_band", collide=False)
    s.block("A_S_band", (ax0, 0, az - pt), (ax1, pb, az), "paint_band", collide=False)
    s.block("A_W_band", (ax0, 0, -az), (ax0 + pt, pb, az), "paint_band", collide=False)
    s.block("A_E1_band", (ax1 - pt, 0, -az), (ax1, pb, -cz), "paint_band", collide=False)
    s.block("A_E2_band", (ax1 - pt, 0, cz), (ax1, pb, az), "paint_band", collide=False)
    # corridor walls and the door partition (opening 1.8 x 2.8)
    s.block("C_N", (ax1, 0, -cz - T), (bx0, ch, -cz), "wall_concrete")
    s.block("C_S", (ax1, 0, cz), (bx0, ch, cz + T), "wall_concrete")
    s.block("C_N_band", (ax1 + T, 0, -cz), (bx0, pb, -cz + pt), "paint_band", collide=False)
    s.block("C_S_band", (ax1 + T, 0, cz - pt), (bx0, pb, cz), "paint_band", collide=False)
    px = 0.5  # as thick as the door frame (FacilityDoor.FRAME_DEPTH), so its controls sit on the wall face
    s.block("Door_N", (px - 0.15, 0, -cz), (px + 0.15, ch, -0.9), "wall_concrete")
    s.block("Door_S", (px - 0.15, 0, 0.9), (px + 0.15, ch, cz), "wall_concrete")
    s.block("Door_Top", (px - 0.15, 2.8, -0.9), (px + 0.15, ch, 0.9), "wall_concrete")
    # east room walls
    s.block("B_N", (bx0 - T, 0, -bz - T), (bx1 + T, bh, -bz), "wall_layers")
    s.block("B_S", (bx0 - T, 0, bz), (bx1 + T, bh, bz + T), "wall_layers")
    s.block("B_E", (bx1, 0, -bz), (bx1 + T, bh, bz), "wall_layers")
    s.block("B_W1", (bx0 - T, 0, -bz), (bx0, bh, -cz), "wall_layers")
    s.block("B_W2", (bx0 - T, 0, cz), (bx0, bh, bz), "wall_layers")
    s.block("B_W3", (bx0 - T, ch, -cz), (bx0, bh, cz), "wall_layers")
    # ------------------------------------------------------------ west room: operator post
    s.prop("Mnemonic", "mnemonic_panel", (-6.5, 1.25, -az), 0)
    s.prop("DeskL", "control_desk", (-7.6, 0, -1.8), 0)
    s.prop("DeskR", "control_desk", (-5.2, 0, -1.8), 0)
    s.prop("ChairL", "ph_metal_chair", (-7.6, 0, -0.9), 180)
    s.prop("ChairR", "ph_metal_chair", (-5.0, 0, -0.8), 165)
    s.prop("Terminal", "terminal_console", (-10.3, 0, 1.8), 90)
    s.prop("OfficeDesk", "ph_office_desk", (-9.2, 0, 3.75), 180)
    s.prop("CRT", "ph_crt_television", (-9.8, 0.79, 3.85), 160)
    s.prop("Clipboard", "ph_clipboard", (-8.7, 0.81, 3.6), 20)
    s.prop("Papers", "document_sheet", (-8.3, 0.79, 3.75), -10)
    s.prop("Stool", "ph_metal_stool", (-9.0, 0, 2.9), 0)
    s.prop("Cabinet1", "file_cabinet", (-6.4, 0, az - 0.27), 180)
    s.prop("Cabinet2", "file_cabinet", (-5.85, 0, az - 0.27), 180)
    s.prop("Locker1", "locker_tall", (-4.6, 0, az - 0.3), 180)
    s.prop("Locker2", "locker_tall", (-4.05, 0, az - 0.3), 180)
    s.prop("FirstAid", "emergency_cabinet", (-3.2, 0, -az + 0.23), 0)
    s.prop("ExitSign", "evac_sign", (ax1, 3.35, 0), -90)
    s.prop("BeaconA", "emergency_beacon", (ax1, 3.0, -2.2), -90)
    s.prop("Breaker", "wall_breaker", (ax1, 1.25, 2.2), -90)
    s.prop("Camera", "ph_security_camera", (ax0 + 0.4, 4.3, -az + 0.4), 45)
    for i, x in enumerate((-9.5, -7.0, -4.5)):
        s.prop(f"TubeA{i}", "fluorescent_light", (x, ah, 0.6), 0)
    # duct run along the north side under the ceiling (pieces are 0.6 m along their own Z; yaw 90 runs them along X)
    x = -10.5
    for i, piece in enumerate(["tripple_01", "double_01", "single_01", "vent_01", "tripple_01", "double_01", "tripple_01"]):
        pid = f"ph_airduct_rect__{piece}"
        if piece.startswith("vent"):
            s.prop(f"DuctA{i}", pid, (x - 0.3, 4.05, -3.5), 0)
            continue
        ln = size(pid)[2]
        s.prop(f"DuctA{i}", pid, (x + ln / 2, 4.3, -3.6), 90)
        x += ln
    for i, z in enumerate((-3.0, -1.0, 1.0, 3.0)):
        s.prop(f"CableA{i}", "ph_electric_cables__cable_straight_long", (ax0 + 0.03, 2.6, z), 90)
    # ------------------------------------------------------------ corridor
    s.prop("TubeC", "fluorescent_light", (-0.9, ch, 0), 90)
    # ceiling-hung trays: the anchor plates touch the ceiling 0.55 m above the tray origin
    s.prop("TrayC1", "cable_tray_straight", (-1.7, ch - 0.55, -cz + 0.3), 0)
    s.prop("TrayC2", "cable_tray_straight", (0.8, ch - 0.55, -cz + 0.3), 0)
    s.prop("TrayW", "cable_tray_wall", (0.3, 2.35, cz), 180)
    s.prop("ExitSignC", "evac_sign", (bx0 - 0.05, 2.9, cz - 0.6), -90)
    # ------------------------------------------------------------ east room: machine hall
    s.prop("GenPanel", "generator_panel", (bx0 + 0.25, 0, -3.6), 90)
    s.prop("StartLever", "start_lever", (bx0 + 1.4, 0, -3.6), 90)
    s.prop("Fan", "ventilation_unit", (bx1 - 1.2, 0, -bz + 0.7), 0)
    s.prop("PowerBox", "ph_power_box", (7.5, 1.3, -bz), 0)
    s.prop("PowerBox2", "ph_power_box", (8.2, 1.3, -bz), 0)
    s.prop("Gauge", "pressure_gauge", (9.6, 1.55, -bz), 0)
    for i, x in enumerate((5.0, 7.0, 9.0, 11.0)):                       # pipe run along the north wall
        s.prop(f"PipeN{i}", "pipe_straight", (x, 2.6, -bz + 0.25), 0)
    s.prop("Valve", "valve_wheel", (8.5, 1.6, -bz + 0.4), 0)
    for i, (piece, x) in enumerate((("pipe02", 13.6), ("pipe08", 13.6), ("pipe02", 12.9))):   # vertical risers, east wall
        pid = f"ph_industrial_pipes__{piece}"
        h = size(pid)[1]
        y = h / 2 if piece == "pipe02" else 1.0
        s.prop(f"Riser{i}", pid, (x, y, 1.5 + (i == 1) * 0.0 + (i == 2) * 0.9), -90)
    s.prop("Barrel1", "ph_barrel_oil", (13.2, 0, 4.7), 0)
    s.prop("Barrel2", "ph_barrel_oil", (12.5, 0, 4.85), 40)
    s.prop("Barrel3", "ph_barrel_fuel", (13.25, 0, 3.95), 10)
    s.prop("Propane1", "ph_propane_tank", (11.6, 0, 4.9), 0)
    s.prop("Propane2", "ph_lpg_tank", (11.1, 0, 4.85), 0)
    s.prop("Welding", "ph_welding_cart", (9.4, 0, 4.6), 200)
    s.prop("ToolCart", "ph_tool_cart", (5.2, 0, 4.5), 180)
    s.prop("DrillPress", "ph_drill_press", (6.8, 0, 4.85), 180)
    s.prop("Rack", "ph_metal_rack", (bx0 + 0.35, 0, 3.6), 90)
    s.prop("Toolbox", "ph_toolbox", (bx0 + 0.35, 0.95, 3.4), 80)
    s.prop("Box", "ph_cardboard_box", (bx0 + 0.35, 1.48, 3.8), 95)
    s.prop("OilTin", "ph_oil_tin", (bx0 + 0.35, 0.45, 3.9), 0)
    s.prop("Rubble", "rubble_set", (11.8, 0, -1.2), 90)
    s.prop("ChainB", "chain_hanging", (7.0, bh, 0.5), 0)
    s.prop("CablesB", "cable_hang", (10.2, bh, 2.0), 30)
    s.prop("BeaconB", "emergency_beacon", (bx0, 3.2, 2.3), 90)
    for i, (gx, gz) in enumerate(((6.0, 0.0), (7.0, 0.0), (8.0, 0.0))):
        s.prop(f"Grate{i}", "floor_grate", (gx, 0, gz), 0)
    for i, (lx, lz) in enumerate(((5.5, -1.5), (9.0, -2.0), (8.0, 2.5))):
        s.prop(f"Lamp{i}", "ph_hanging_lamp", (lx, bh, lz), 0)
    # ------------------------------------------------------------ lights
    cold, warm, red = (0.78, 0.88, 1.0), (1.0, 0.68, 0.42), (1.0, 0.18, 0.1)
    s.light("TubeLightA0", "OmniLight3D", (-9.5, ah - 0.25, 0.6), cold, 4.5, 11.0, shadow=True)
    s.light("TubeLightA1", "OmniLight3D", (-7.0, ah - 0.25, 0.6), cold, 4.0, 11.0, shadow=True,
            extra=['script = ExtResource("flicker")'])
    # TubeA2 is dead: no light at the third fixture
    s.light("ScreenGlow", "OmniLight3D", (-6.5, 1.9, -3.7), (0.2, 0.75, 0.85), 1.2, 4.5)
    s.light("DeskGlow", "OmniLight3D", (-6.4, 1.2, -1.6), (0.3, 0.9, 0.6), 0.25, 2.0)
    s.light("BeaconLightA", "OmniLight3D", (-2.3, 3.0, -2.2), red, 0.6, 3.5)
    s.light("CorrLight", "OmniLight3D", (-0.9, 3.0, 0), cold, 1.6, 6.0, shadow=True)
    s.light("ExitGlow", "OmniLight3D", (2.7, 2.8, 1.0), (0.3, 0.9, 0.45), 0.35, 2.5)
    for i, (lx, lz) in enumerate(((5.5, -1.5), (9.0, -2.0), (8.0, 2.5))):
        s.light(f"LampLight{i}", "OmniLight3D", (lx, bh - 1.45, lz), warm, 4.5, 10.0, shadow=i != 2)
    s.light("BeaconLightB", "OmniLight3D", (bx0 + 0.3, 3.2, 2.3), red, 0.7, 4.0)
    s.light("FanGlow", "OmniLight3D", (bx1 - 1.2, 0.8, -bz + 1.6), (1.0, 0.5, 0.25), 0.3, 2.5)
    s.ext.insert(0, '[ext_resource type="Script" path="res://scenes/sandbox/lookdev_flicker.gd" id="flicker"]')
    return s


def main() -> int:
    write_materials()
    s = build()
    ext = list(s.ext) + ['[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="player"]',
                         '[ext_resource type="PackedScene" path="res://scenes/ui/opening_hud.tscn" id="hud"]']
    sub = ['[sub_resource type="Environment" id="env"]', "background_mode = 1", "background_color = Color(0.01, 0.011, 0.013, 1)",
           "ambient_light_source = 2", "ambient_light_color = Color(0.3, 0.32, 0.36, 1)", "ambient_light_energy = 0.25",
           "tonemap_mode = 3", "tonemap_white = 6.0", "ssao_enabled = true", "ssao_radius = 1.2", "ssao_intensity = 2.5",
           "ssil_enabled = true", "glow_enabled = true", "glow_intensity = 0.6", "glow_bloom = 0.05",
           "volumetric_fog_enabled = true", "volumetric_fog_density = 0.006", "volumetric_fog_albedo = Color(0.7, 0.72, 0.75, 1)",
           "volumetric_fog_emission = Color(0, 0, 0, 1)", "volumetric_fog_length = 32.0", ""] + s.sub
    head = ['[node name="LookdevRooms" type="Node3D"]', "",
            '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("env")', "",
            '[node name="Architecture" type="Node3D" parent="."]', "",
            '[node name="Body" type="StaticBody3D" parent="Architecture"]', "",
            '[node name="Props" type="Node3D" parent="."]', "",
            '[node name="Lights" type="Node3D" parent="."]', "",
            '[node name="Door" parent="." instance=ExtResource("door")]',
            "transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 0.5, 0, 0)", "starts_open = true", ""]
    ext.append('[ext_resource type="PackedScene" path="res://objects/doors/mechanical_door.tscn" id="door"]')
    tail = ['[node name="Player" parent="." node_paths=PackedStringArray("interact_label", "hold_progress_bar") instance=ExtResource("player")]',
            "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -6.4, 1, 2.6)",
            'interact_label = NodePath("../OpeningHud/InteractLabel")', 'hold_progress_bar = NodePath("../OpeningHud/HoldProgress")', "",
            '[node name="OpeningHud" parent="." instance=ExtResource("hud")]', ""]
    OUT.write_text("[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(head + s.nodes + tail),
                   encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(REPO)}: {sum(1 for n in s.nodes if n.startswith('[node') and 'instance=' in n)} props, "
          f"{sum(1 for n in s.nodes if 'parent=\"Lights\"' in n)} lights")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
