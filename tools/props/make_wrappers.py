#!/usr/bin/env python3
"""Writes objects/art/<id>.tscn for every prop: StaticBody3D root + the glTF model + simple collision (standard §5).

Usage: python3 tools/props/make_wrappers.py [prop_id ...]
The root keeps the model's origin, so replacing a placeholder with the art model does not move it. Collision is the
bounding box unless overridden below; decorative hanging items get none. Interaction components are added by the
gameplay tasks, not here.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_props import REPO, analyse  # noqa: E402

NO_COLLISION = {"chain_hanging", "cable_hang", "document_sheet", "personal_key",
                "sleeper_herobrine", "sleeper_bowser"}  # sleepers sit behind the capsule glass
NO_COLLISION_PREFIXES = ("ph_electric_cables__",)  # loose cable runs
# id -> list of (centre, size, rotation_z_degrees); replaces the bounding-box collision
OVERRIDES = {
    # tilted duct body (3.4 m long, 0.5 x 0.6 section) hanging from x = -1.7 at y = 2.55, sagging 18 degrees
    "fallen_duct": [((-0.083, 2.025, 0.0), (3.4, 0.5, 0.6), -18.0)],
    # frame only: posts and lintel; the bent bars are intentionally not solid (level design decides the passage)
    "chamber1_gate": [((-2.55, 2.25, 0.0), (0.5, 4.5, 0.6), 0.0), ((2.55, 2.25, 0.0), (0.5, 4.5, 0.6), 0.0),
                      ((0.0, 4.225, 0.0), (5.6, 0.55, 0.7), 0.0)],
}

# id -> footstep surface of the walkable prop (`surface` meta, objects/feel/first_person_feel.gd, #209)
SURFACES = {"floor_grate": "grate"}


def pascal(pid: str) -> str:
    return "".join(p.capitalize() for p in pid.replace("__", "_").split("_"))


def write(pid: str):
    rel = SPECS[pid].get("gltf", f"{pid}/{pid}.gltf")
    gltf = REPO / "loads" / "props" / rel
    _, lo, hi, _ = analyse(gltf)
    shapes = OVERRIDES.get(pid)
    if shapes is None and pid not in NO_COLLISION and not pid.startswith(NO_COLLISION_PREFIXES):
        size = [hi[i] - lo[i] for i in range(3)]
        centre = [(hi[i] + lo[i]) / 2 for i in range(3)]
        shapes = [(tuple(round(c, 4) for c in centre), tuple(round(s, 4) for s in size), 0.0)]
    lines = ["[gd_scene format=3]", "",
             f'[ext_resource type="PackedScene" path="res://loads/props/{rel}" id="1_model"]', ""]
    for i, (_, size, _) in enumerate(shapes or []):
        lines += [f'[sub_resource type="BoxShape3D" id="Shape{i}"]', f"size = Vector3({size[0]}, {size[1]}, {size[2]})", ""]
    lines.append(f'[node name="{pascal(pid)}" type="StaticBody3D"]')
    if pid in SURFACES:
        lines.append(f'metadata/surface = "{SURFACES[pid]}"')
    lines += ["", '[node name="Model" parent="." instance=ExtResource("1_model")]', ""]
    for i, (centre, _, rz) in enumerate(shapes or []):
        name = "Collision" if len(shapes) == 1 else f"Collision{i + 1}"
        lines += [f'[node name="{name}" type="CollisionShape3D" parent="."]']
        if rz:
            a = math.radians(rz)
            c, s = math.cos(a), math.sin(a)
            lines.append(f"transform = Transform3D({c:.6f}, {s:.6f}, 0, {-s:.6f}, {c:.6f}, 0, 0, 0, 1, {centre[0]}, {centre[1]}, {centre[2]})")
        else:
            lines.append(f"position = Vector3({centre[0]}, {centre[1]}, {centre[2]})")
        lines += [f'shape = SubResource("Shape{i}")', ""]
    out = REPO / "objects" / "art" / f"{pid}.tscn"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return out


SPECS = json.loads((Path(__file__).with_name("specs.json")).read_text(encoding="utf-8"))


def main() -> int:
    for pid in sys.argv[1:] or SPECS:
        print(write(pid).relative_to(REPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
