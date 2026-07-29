#!/usr/bin/env python3
"""Validate generated set dressing against the canonical handoff."""

from __future__ import annotations

import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
MANIFEST = ROOT / "scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"


def main() -> None:
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    spaces = {space["id"]: space for space in handoff["spaces"]}
    errors = []
    prop_count = 0
    frame_count = 0
    for sector in manifest["sectors"]:
        scene_path = ROOT / sector["dressing_scene"].removeprefix("res://")
        if not scene_path.is_file():
            errors.append(f"missing dressing scene: {scene_path}")
        if not sector["placements"]:
            errors.append(f"empty sector: {sector['sector_id']}")
        for placement in sector["placements"]:
            asset_path = ROOT / placement["scene"].removeprefix("res://")
            if not asset_path.is_file():
                errors.append(f"missing asset: {placement['scene']}")
            if placement["kind"] == "prop":
                prop_count += 1
                if placement["space_id"]:
                    space = spaces[placement["space_id"]]
                    x, _, z = placement["position"]
                    sx, sz = placement["footprint_xz"]
                    x0, z0, x1, z1 = map(float, space["bounds_xz"])
                    if not (x0 <= x - sx * 0.5 and x + sx * 0.5 <= x1 and z0 <= z - sz * 0.5 and z + sz * 0.5 <= z1):
                        errors.append(f"prop footprint outside {placement['space_id']}: {placement['id']}")
                    center_x = (x0 + x1) * 0.5
                    center_z = (z0 + z1) * 0.5
                    if not (math.isclose(x, center_x, abs_tol=0.01) or math.isclose(z, center_z, abs_tol=0.01)):
                        errors.append(f"prop is not wall-centered in {placement['space_id']}: {placement['id']}")
                    expected_offset = 2.65 if placement["scene"].endswith("security_camera.tscn") else 2.35 if placement["scene"].endswith("wall_beacon.tscn") else 1.2 if placement["scene"].endswith("wall_terminal.tscn") else 0.0
                    if not math.isclose(float(placement["position"][1]), float(space["floor_y"]) + expected_offset, abs_tol=0.01):
                        errors.append(f"invalid vertical placement: {placement['id']}")
            else:
                frame_count += 1
                if placement.get("scale", [1])[0] <= 0:
                    errors.append(f"invalid frame scale: {placement['id']}")
    expected_frames = len(handoff["internal_portals"]) + len(handoff["external_portals"])
    if frame_count != expected_frames:
        errors.append(f"portal frame count {frame_count}, expected {expected_frames}")
    if len(manifest["sectors"]) != 30:
        errors.append(f"sector count {len(manifest['sectors'])}, expected 30")
    cargo_portals = [portal for portal in handoff["internal_portals"] if any("/cargo_airlock" in space_id or "/cargo_vestibule" in space_id for space_id in portal["between"])]
    if len(cargo_portals) != 5 or any(float(portal["width"]) < 4.5 or float(portal["height"]) < 4.5 for portal in cargo_portals):
        errors.append("five internal cargo thresholds must preserve 4.5 x 4.5 m clearance")
    if errors:
        raise SystemExit("Set-dressing validation failed:\n- " + "\n- ".join(errors))
    print(f"Set-dressing validation passed: 30 sectors, {prop_count} props, {frame_count} open portal frames")


if __name__ == "__main__":
    main()
