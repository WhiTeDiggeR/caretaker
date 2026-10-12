#!/usr/bin/env python3
"""Writes objects/containment/prisoner_capsule_<name>.tscn (#162): a prisoner capsule with its sleeper and interior light.

The capsule (objects/art/capsule_<name>.tscn) and the sleeper (objects/art/sleeper_<name>.tscn) stay separate props:
the `Sleeper` node is an instance placed at the capsule's socket, so another figure can replace it by swapping that
one instance (or the sleeper glTF). `RoomLinkL` / `RoomLinkR` mark the flanges at the back of the plinth where a room
connects its own cables and pipes. Generated: do not edit the scenes by hand, rerun this script.
Usage: python3 tools/props/make_capsule_assemblies.py
"""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "objects" / "containment"

# name -> (socket = Capsule.socket in props_capsules.py, room links = outer flange faces of room_links(), light
# colour, light energy). Keep in step with props_capsules.py when the capsule dimensions change.
CAPSULES = {
    "herobrine": ((0.0, 1.7, 0.0), [(-0.9, 0.14, -1.55), (0.9, 0.14, -1.55)], "0.85, 0.92, 1", 1.8),
    "bowser": ((0.0, 1.9, 0.0), [(-0.9, 0.14, -1.7), (0.9, 0.14, -1.7)], "1, 0.95, 0.85", 1.5),
}


def pos(p) -> str:
    return f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {p[0]}, {p[1]}, {p[2]})"


def write(name: str) -> Path:
    socket, links, light, energy = CAPSULES[name]
    pascal = name.capitalize()
    lines = ["[gd_scene format=3]", "",
             f'[ext_resource type="PackedScene" path="res://objects/art/capsule_{name}.tscn" id="1_capsule"]',
             f'[ext_resource type="PackedScene" path="res://objects/art/sleeper_{name}.tscn" id="2_sleeper"]', "",
             f'[node name="PrisonerCapsule{pascal}" type="Node3D"]', "",
             '[node name="Capsule" parent="." instance=ExtResource("1_capsule")]', "",
             '[node name="Sleeper" parent="." instance=ExtResource("2_sleeper")]', f"transform = {pos(socket)}", "",
             '[node name="InteriorLight" type="OmniLight3D" parent="."]',
             f"transform = {pos((socket[0], socket[1] + 0.45, socket[2] + 0.75))}",
             f"light_color = Color({light}, 1)", f"light_energy = {energy}", "omni_range = 2.8", "omni_attenuation = 0.8", ""]
    for side, p in zip(("L", "R"), links):
        lines += [f'[node name="RoomLink{side}" type="Marker3D" parent="."]', f"transform = {pos(p)}", ""]
    out = OUT / f"prisoner_capsule_{name}.tscn"
    out.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return out


def main() -> int:
    for name in CAPSULES:
        print(write(name).relative_to(REPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
