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
    frame_ids: set[str] = set()
    wall_mount_count = 0
    chamber_wall_mount_count = 0
    control_plan_prop_count = 0
    domestic_plan_prop_count = 0
    east_support_plan_prop_count = 0
    medbay_plan_prop_count = 0
    route_a_plan_prop_count = 0
    lower_route_a_plan_prop_count = 0
    old_core_plan_prop_count = 0
    minimum_service_clearance = float("inf")
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
                if placement["space_id"].startswith("U-CONTROL/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"U-CONTROL prop is not plan-aligned: {placement['id']}")
                    else:
                        control_plan_prop_count += 1
                if placement["space_id"].startswith("U-DOMESTIC/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"U-DOMESTIC prop is not plan-aligned: {placement['id']}")
                    else:
                        domestic_plan_prop_count += 1
                if placement["space_id"].startswith("U-EAST-SUPPORT/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"U-EAST-SUPPORT prop is not plan-aligned: {placement['id']}")
                    else:
                        east_support_plan_prop_count += 1
                if placement["space_id"].startswith("U-MEDBAY/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"U-MEDBAY prop is not plan-aligned: {placement['id']}")
                    else:
                        medbay_plan_prop_count += 1
                if placement["space_id"].startswith("U-ROUTE-A/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"U-ROUTE-A prop is not plan-aligned: {placement['id']}")
                    else:
                        route_a_plan_prop_count += 1
                if placement["space_id"].startswith("L-ARCHIVE-A/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"L-ARCHIVE-A prop is not plan-aligned: {placement['id']}")
                    else:
                        lower_route_a_plan_prop_count += 1
                if placement["space_id"].startswith("L-OLD-CORE/"):
                    if not placement.get("plan_aligned", False):
                        errors.append(f"L-OLD-CORE prop is not plan-aligned: {placement['id']}")
                    else:
                        old_core_plan_prop_count += 1
                is_chamber_beacon = (
                    "CHAMBER" in placement["space_id"]
                    and placement["scene"].endswith("wall_beacon.tscn")
                )
                if is_chamber_beacon and "wall_mount_depth" not in placement:
                    errors.append(f"chamber wall beacon is not wall-mounted: {placement['id']}")
                if placement["space_id"]:
                    space = spaces[placement["space_id"]]
                    x, _, z = placement["position"]
                    sx, sz = placement["footprint_xz"]
                    sz = float(placement.get("wall_mount_depth", sz))
                    x0, z0, x1, z1 = map(float, space["bounds_xz"])
                    if "wall_mount_depth" in placement:
                        wall_mount_count += 1
                        if is_chamber_beacon:
                            chamber_wall_mount_count += 1
                        rotation = float(placement.get("rotation_y", 0.0))
                        extent_x = abs(math.cos(rotation)) * sx * 0.5 + abs(math.sin(rotation)) * sz * 0.5
                        extent_z = abs(math.sin(rotation)) * sx * 0.5 + abs(math.cos(rotation)) * sz * 0.5
                    else:
                        extent_x = sx * 0.5
                        extent_z = sz * 0.5
                    if not (x0 - 0.001 <= x - extent_x and x + extent_x <= x1 + 0.001 and z0 - 0.001 <= z - extent_z and z + extent_z <= z1 + 0.001):
                        errors.append(f"prop footprint outside {placement['space_id']}: {placement['id']}")
                    center_x = (x0 + x1) * 0.5
                    center_z = (z0 + z1) * 0.5
                    if not placement.get("plan_aligned", False) and not (math.isclose(x, center_x, abs_tol=0.01) or math.isclose(z, center_z, abs_tol=0.01)):
                        errors.append(f"prop is not wall-centered in {placement['space_id']}: {placement['id']}")
                    expected_offset = 2.65 if placement["scene"].endswith("security_camera.tscn") else 2.35 if placement["scene"].endswith("wall_beacon.tscn") else 1.2 if placement["scene"].endswith("wall_terminal.tscn") else 0.0
                    if not math.isclose(float(placement["position"][1]), float(space["floor_y"]) + expected_offset, abs_tol=0.01):
                        errors.append(f"invalid vertical placement: {placement['id']}")
                    if "wall_mount_depth" in placement:
                        half_wall = float(space.get("wall_thickness", 0.3)) * 0.5
                        center_offset = float(placement.get("wall_mount_center_offset", 0.0))
                        expected_centers = {
                            "west": x0 + half_wall + center_offset,
                            "east": x1 - half_wall - center_offset,
                            "north": z0 + half_wall + center_offset,
                            "south": z1 - half_wall - center_offset,
                        }
                        side = str(placement.get("wall_mount_side", ""))
                        center_coordinate = x if side in {"west", "east"} else z
                        wall_gap = abs(center_coordinate - expected_centers.get(side, float("inf")))
                        if wall_gap > 0.01:
                            errors.append(f"wall-mounted prop is detached from inner wall face: {placement['id']} gap={wall_gap:.3f}")
                    if placement["id"].endswith("service_access::wall_terminal"):
                        wall_thickness = float(space.get("wall_thickness", 0.3))
                        depth = float(placement.get("wall_mount_depth", sz))
                        center_offset = float(placement.get("wall_mount_center_offset", 0.0))
                        clear_width = (x1 - x0) - wall_thickness - (depth * 0.5 + center_offset)
                        minimum_service_clearance = min(minimum_service_clearance, clear_width)
                        if clear_width < 1.5:
                            errors.append(f"central service corridor blocked by terminal: {placement['id']} clear_width={clear_width:.3f}")
            else:
                frame_count += 1
                frame_ids.add(str(placement["id"]))
                if placement.get("scale", [1])[0] <= 0:
                    errors.append(f"invalid frame scale: {placement['id']}")
    expected_frames = len(handoff["internal_portals"]) + len(handoff["external_portals"]) - 1
    if frame_count != expected_frames:
        errors.append(f"portal frame count {frame_count}, expected {expected_frames}")
    if "PX-E-U02-U-ROUTE-A" not in frame_ids or "PX-E-U02-U-EMERGENCY" in frame_ids:
        errors.append("shared-wall E-U02 doorway must have exactly one frame owned by U-ROUTE-A")
    if len(manifest["sectors"]) != 30:
        errors.append(f"sector count {len(manifest['sectors'])}, expected 30")
    if chamber_wall_mount_count != 15:
        errors.append(f"chamber wall mount count {chamber_wall_mount_count}, expected 15")
    if control_plan_prop_count != 21:
        errors.append(f"U-CONTROL plan-aligned prop count {control_plan_prop_count}, expected 21")
    if domestic_plan_prop_count != 23:
        errors.append(f"U-DOMESTIC plan-aligned prop count {domestic_plan_prop_count}, expected 23")
    if east_support_plan_prop_count != 6:
        errors.append(f"U-EAST-SUPPORT plan-aligned prop count {east_support_plan_prop_count}, expected 6")
    if medbay_plan_prop_count != 12:
        errors.append(f"U-MEDBAY plan-aligned prop count {medbay_plan_prop_count}, expected 12")
    if route_a_plan_prop_count != 5:
        errors.append(f"U-ROUTE-A plan-aligned prop count {route_a_plan_prop_count}, expected 5")
    if lower_route_a_plan_prop_count != 7:
        errors.append(f"L-ARCHIVE-A plan-aligned prop count {lower_route_a_plan_prop_count}, expected 7")
    if old_core_plan_prop_count != 6:
        errors.append(f"L-OLD-CORE plan-aligned prop count {old_core_plan_prop_count}, expected 6")
    cargo_portals = [portal for portal in handoff["internal_portals"] if any("/cargo_airlock" in space_id or "/cargo_vestibule" in space_id for space_id in portal["between"])]
    if len(cargo_portals) != 5 or any(float(portal["width"]) < 4.5 or float(portal["height"]) < 4.5 for portal in cargo_portals):
        errors.append("five internal cargo thresholds must preserve 4.5 x 4.5 m clearance")
    if errors:
        raise SystemExit("Set-dressing validation failed:\n- " + "\n- ".join(errors))
    print(f"Set-dressing validation passed: 30 sectors, {prop_count} props, {frame_count} open portal frames, {wall_mount_count} wall mounts ({chamber_wall_mount_count} chamber beacons), {control_plan_prop_count} U-CONTROL plan props, {domestic_plan_prop_count} U-DOMESTIC plan props, {east_support_plan_prop_count} U-EAST-SUPPORT plan props, {medbay_plan_prop_count} U-MEDBAY plan props, {route_a_plan_prop_count} U-ROUTE-A plan props, {lower_route_a_plan_prop_count} L-ARCHIVE-A plan props, {old_core_plan_prop_count} L-OLD-CORE plan props, minimum service clearance {minimum_service_clearance:.2f} m")


if __name__ == "__main__":
    main()
