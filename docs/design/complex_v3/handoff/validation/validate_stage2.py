#!/usr/bin/env python3
"""Validate complex v3 passports, exact geometry, portals and vertical handoff."""

from __future__ import annotations

import itertools
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def positive_overlap(a: list[float], b: list[float], epsilon: float = 1e-6) -> bool:
    return min(a[2], b[2]) - max(a[0], b[0]) > epsilon and min(a[3], b[3]) - max(a[1], b[1]) > epsilon


def point_on_boundary(point: list[float], bounds: list[float], epsilon: float = 1e-5) -> bool:
    x, z = point
    x0, z0, x1, z1 = bounds
    on_vertical = (abs(x - x0) <= epsilon or abs(x - x1) <= epsilon) and z0 - epsilon <= z <= z1 + epsilon
    on_horizontal = (abs(z - z0) <= epsilon or abs(z - z1) <= epsilon) and x0 - epsilon <= x <= x1 + epsilon
    return on_vertical or on_horizontal


def shared_boundary_segment(segment: list[list[float]], a: list[float], b: list[float]) -> bool:
    return all(point_on_boundary(point, a) and point_on_boundary(point, b) for point in segment)


def main() -> int:
    overview = load("overview/metric-overview.json")
    topology = load("overview/topology.json")
    passport_data = load("passports/sector-passports.json")
    geometry = load("geometry/complex-handoff.json")
    vertical = load("vertical/vertical-transitions.json")
    errors: list[str] = []

    passports = passport_data["passports"]
    passport_ids = {item["sector_id"] for item in passports}
    if len(passports) != 30 or len(passport_ids) != 30:
        errors.append(f"expected 30 unique passports, got {len(passports)} / {len(passport_ids)}")

    sectors = geometry["sectors"]
    sector_ids = {item["id"] for item in sectors}
    expected_physical = passport_ids - {"T-CIRCULATION"}
    if sector_ids != expected_physical:
        errors.append(f"physical sector mismatch: missing={sorted(expected_physical-sector_ids)} extra={sorted(sector_ids-expected_physical)}")

    spaces = geometry["spaces"]
    space_by_id = {item["id"]: item for item in spaces}
    if len(space_by_id) != len(spaces):
        errors.append("duplicate exact space IDs")
    for space in spaces:
        x0, z0, x1, z1 = space["bounds_xz"]
        if x1 <= x0 or z1 <= z0 or space["clear_height"] <= 0:
            errors.append(f"invalid room dimensions: {space['id']}")

    for a, b in itertools.combinations(spaces, 2):
        if a["floor_y"] == b["floor_y"] and positive_overlap(a["bounds_xz"], b["bounds_xz"]):
            errors.append(f"positive room overlap: {a['id']} <> {b['id']}")

    for portal in geometry["internal_portals"]:
        a_id, b_id = portal["between"]
        if a_id not in space_by_id or b_id not in space_by_id:
            errors.append(f"internal portal references unknown room: {portal['id']}")
            continue
        if not shared_boundary_segment(portal["segment_xz"], space_by_id[a_id]["bounds_xz"], space_by_id[b_id]["bounds_xz"]):
            errors.append(f"internal portal is not on a shared boundary: {portal['id']}")

    external_by_id = {item["id"]: item for item in geometry["external_portals"]}
    for portal in external_by_id.values():
        room = space_by_id.get(portal["space"])
        if room is None or not all(point_on_boundary(point, room["bounds_xz"]) for point in portal["segment_xz"]):
            errors.append(f"external portal is not on its room boundary: {portal['id']}")

    represented: set[str] = set()
    for corridor in geometry["connection_corridors"]:
        represented.add(corridor["connection_id"])
        related = [p for p in external_by_id.values() if p["connection_id"] == corridor["connection_id"]]
        portal_centers = {
            tuple(round((p["segment_xz"][0][axis] + p["segment_xz"][1][axis]) / 2, 3) for axis in (0, 1))
            for p in related
        }
        line_ends = {tuple(point) for point in (corridor["centerline_xz"][0], corridor["centerline_xz"][-1])}
        if not portal_centers.issubset(line_ends):
            errors.append(f"corridor does not terminate at all related portal centers: {corridor['id']}")
    for transition in geometry["controlled_technical_transitions"]:
        represented.update(transition["represents_connections"])

    topology_ids = {edge["id"] for edge in topology["connections"]}
    vertical_represented: set[str] = set()
    anchor_by_id = {item["id"]: item for item in overview["anchors"]}
    level_y = {item["id"]: item["floor_y"] for item in overview["levels"]}
    for item in vertical["transitions"]:
        vertical_represented.update(item.get("represents_connections", []))
        anchor = anchor_by_id[item["anchor"]]
        center = item.get("center_xz")
        if center and item.get("alignment_role") != "adjacent_component_of_main_core" and "position_xz" in anchor and math.dist(center, anchor["position_xz"]) > anchor.get("tolerance", 0.25):
            errors.append(f"vertical transition misses anchor: {item['id']}")
        connects = item.get("connects", [])
        if len(connects) == 2 and "rise" in item:
            expected_rise = abs(level_y[connects[0]] - level_y[connects[1]])
            if abs(item["rise"] - expected_rise) > 0.05:
                errors.append(f"vertical rise mismatch: {item['id']}")
        if item["kind"].endswith("stair") and (item["clear_width"] < 1.4 or item["clear_height"] < 2.3):
            errors.append(f"stair clearance below declared minimum: {item['id']}")
    old_incline = next(item for item in vertical["transitions"] if item["id"] == "VT-OLD-INCLINE")
    if old_incline["grade_percent"] > 16.0:
        errors.append("old inclined tunnel exceeds 16 percent grade")
    main_lift = next(item for item in vertical["transitions"] if item["id"] == "VT-MAIN-ELEVATOR")
    if "LV-T" in main_lift["stops"] or main_lift["technical_stop"]:
        errors.append("main passenger elevator must not stop on LV-T")

    covered = represented | vertical_represented
    if covered != topology_ids:
        errors.append(f"topology representation mismatch: missing={sorted(topology_ids-covered)} extra={sorted(covered-topology_ids)}")

    overview_anchor_ids = {item["id"] for item in overview["anchors"]}
    vertical_anchor_ids = {item["id"] for item in vertical["anchors"]}
    if overview_anchor_ids != vertical_anchor_ids:
        errors.append("vertical anchor set differs from approved overview")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print(
        "OK: stage-2 handoff is internally consistent: "
        f"30 passports, {len(spaces)} spaces, {len(geometry['internal_portals'])} internal portals, "
        f"{len(geometry['external_portals'])} external portals, {len(topology_ids)} represented topology edges"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
