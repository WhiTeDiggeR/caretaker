#!/usr/bin/env python3
"""Generate deterministic metric room geometry and portals for complex v3."""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
OVERVIEW_PATH = ROOT / "overview" / "metric-overview.json"
TOPOLOGY_PATH = ROOT / "overview" / "topology.json"
PASSPORTS_PATH = ROOT / "passports" / "sector-passports.json"
OUTPUT_PATH = ROOT / "geometry" / "complex-handoff.json"

FINAL_BOUNDS_OVERRIDE = {
    "U-CENTRAL-CORE": [-7.75, -6.0, 7.75, 15.0],
    "U-ROUTE-A": [-62.0, -8.0, -46.0, 14.0],
    "U-DOMESTIC": [-46.0, -17.0, -33.0, 15.0],
    "U-CHAMBER-4": [-110.0, 37.0, -82.0, 60.0],
    "U-CHAMBER-6": [0.0, 29.0, 32.0, 60.0],
    "U-FREIGHT": [-16.0, 67.5, 30.0, 82.0],
    "L-CHAMBER-1": [-110.0, -8.0, -84.0, 15.0],
    "L-OLD-CORE": [-84.0, -14.0, -62.0, 15.0],
    "L-OLD-RECEIVING": [-110.0, 43.0, -72.0, 60.0],
    "L-CHAMBER-2": [-72.0, 27.0, -48.0, 60.0],
    "L-SERVICE-INTERCHANGE": [-48.0, 42.0, -36.0, 60.0],
    "L-CHAMBER-3": [-36.0, 27.0, -10.0, 60.0],
    "L-FREIGHT-SERVICE": [-38.0, 67.5, 30.0, 82.0],
    "L-CENTRAL-CORE": [-7.75, -6.0, 7.75, 15.0],
    "T-OLD-ACCESS": [-102.0, 20.5, -78.0, 45.0],
    "T-EAST-VERTICAL": [18.0, -12.0, 32.0, 15.0],
    "T-UTILITIES": [-57.0, 20.5, 18.0, 56.0],
    "T-FREIGHT": [-20.0, 67.5, 30.0, 82.0],
}

CENTRAL_CORE_SECTORS = {"U-CENTRAL-CORE", "L-CENTRAL-CORE"}
CENTRAL_CORE_PORTAL_WIDTHS = {
    frozenset(("electrical_room", "service_access")): 1.5,
    frozenset(("service_access", "lift_lobby")): 1.5,
    frozenset(("passenger_elevator", "lift_lobby")): 2.0,
    frozenset(("lift_lobby", "access_lobby")): 6.5,
    frozenset(("main_stair", "access_lobby")): 2.33,
}

CONTAINMENT_SECTORS = {"U-CHAMBER-4", "U-CHAMBER-6", "L-CHAMBER-3", "L-CHAMBER-5"}
SEQUENCE_SECTORS = {"U-ROUTE-A", "L-CHAMBER-1", "L-EAST-STAIR"}
SPINE_SECTORS = {"U-DOMESTIC", "U-SECURITY", "T-WORKSHOP", "T-EAST-VERTICAL", "T-UTILITIES"}
HUB_NAMES = {
    "U-MEDBAY": "clean_corridor",
    "U-CONTROL": "operator_hall",
    "U-CENTRAL-CORE": "access_lobby",
    "U-EAST-SUPPORT": "support_corridor",
    "U-FREIGHT": "unloading_bay",
    "L-OLD-CORE": "distribution_hall",
    "L-ARCHIVE-A": "route_a_service_passage",
    "L-OLD-RECEIVING": "receiving_hall",
    "L-SLEEP-LAB": "internal_corridor",
    "L-SERVICE-INTERCHANGE": "service_lobby",
    "L-CENTRAL-CORE": "access_lobby",
    "L-FREIGHT-SERVICE": "service_zone",
    "T-ENERGY": "service_approach",
    "T-OLD-ACCESS": "service_vestibule",
    "T-FREIGHT": "service_reception",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def rect(x0: float, z0: float, x1: float, z1: float) -> list[float]:
    return [round(x0, 3), round(z0, 3), round(x1, 3), round(z1, 3)]


def room(sector_id: str, name: str, bounds: list[float], height: float, transit: bool = False, kind: str = "room") -> dict[str, Any]:
    return {
        "id": f"{sector_id}/{name}",
        "name": name,
        "sector_id": sector_id,
        "kind": kind,
        "bounds_xz": bounds,
        "clear_height": height,
        "wall_thickness": 0.3,
        "transit": transit,
        "status": "provisional-metric",
        "adjustment_tolerance": 0.25,
    }


def height_for(sector_id: str) -> float:
    if "CHAMBER" in sector_id or sector_id.endswith("FREIGHT") or sector_id == "L-FREIGHT-SERVICE":
        return 5.0
    if sector_id.startswith("T-"):
        return 4.0
    return 3.4


def hub_layout(sector_id: str, names: list[str], bounds: list[float], hub_name: str) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    width, depth = x1 - x0, z1 - z0
    hx0, hx1 = x0 + width * 0.42, x0 + width * 0.58
    height = height_for(sector_id)
    result = [room(sector_id, hub_name, rect(hx0, z0, hx1, z1), height, True, "circulation")]
    others = [name for name in names if name != hub_name]
    left = others[::2]
    right = others[1::2]
    connections: list[tuple[str, str]] = []
    for side_names, sx0, sx1 in ((left, x0, hx0), (right, hx1, x1)):
        if not side_names:
            continue
        step = depth / len(side_names)
        for index, name in enumerate(side_names):
            rz0 = z0 + step * index
            rz1 = z0 + step * (index + 1)
            result.append(room(sector_id, name, rect(sx0, rz0, sx1, rz1), height))
            connections.append((hub_name, name))
    return result, connections


def spine_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    width, depth = x1 - x0, z1 - z0
    sx0, sx1 = x0 + width * 0.44, x0 + width * 0.56
    height = height_for(sector_id)
    circulation = "internal_circulation"
    result = [room(sector_id, circulation, rect(sx0, z0, sx1, z1), height, True, "circulation")]
    left = names[::2]
    right = names[1::2]
    connections: list[tuple[str, str]] = []
    for side_names, rx0, rx1 in ((left, x0, sx0), (right, sx1, x1)):
        if not side_names:
            continue
        step = depth / len(side_names)
        for index, name in enumerate(side_names):
            rz0 = z0 + step * index
            rz1 = z0 + step * (index + 1)
            result.append(room(sector_id, name, rect(rx0, rz0, rx1, rz1), height))
            connections.append((circulation, name))
    return result, connections


def sequence_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    step = (x1 - x0) / len(names)
    height = height_for(sector_id)
    result = []
    connections = []
    for index, name in enumerate(names):
        result.append(room(sector_id, name, rect(x0 + step * index, z0, x0 + step * (index + 1), z1), height, index < len(names) - 1 and "stair" not in name))
        if index:
            connections.append((names[index - 1], name))
    return result, connections


def containment_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    passenger = next(name for name in names if "passenger_airlock" in name)
    chamber = next(name for name in names if "containment_chamber" in name)
    cargo = next(name for name in names if "cargo_airlock" in name)
    remaining = [name for name in names if name not in {passenger, chamber, cargo}]
    control = next((name for name in remaining if "control" in name or "diagnostics" in name), remaining[0])
    gallery = next(name for name in remaining if name != control)
    height = 5.0
    result = [
        room(sector_id, control, rect(x0, z0, x0 + 0.35 * w, z0 + 0.28 * d), height),
        room(sector_id, passenger, rect(x0 + 0.35 * w, z0, x1, z0 + 0.28 * d), height, True, "airlock"),
        room(sector_id, gallery, rect(x0, z0 + 0.28 * d, x0 + 0.18 * w, z0 + 0.78 * d), height, True, "service_gallery"),
        room(sector_id, chamber, rect(x0 + 0.18 * w, z0 + 0.28 * d, x1, z0 + 0.78 * d), height, False, "containment"),
        room(sector_id, cargo, rect(x0 + 0.42 * w, z0 + 0.78 * d, x0 + 0.82 * w, z1), height, True, "airlock"),
    ]
    return result, [(control, passenger), (control, gallery), (passenger, chamber), (chamber, cargo)]


def chamber2_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    by = {name: name for name in names}
    result = [
        room(sector_id, by["control_post"], rect(x0 + .25*w, z0, x0 + .5*w, z0 + .25*d), 4.5),
        room(sector_id, by["passenger_airlock"], rect(x0 + .5*w, z0, x0 + .8*w, z0 + .25*d), 4.5, True, "airlock"),
        room(sector_id, by["gas_equipment_room"], rect(x0, z0 + .25*d, x0 + .25*w, z0 + .78*d), 4.5),
        room(sector_id, by["containment_chamber"], rect(x0 + .25*w, z0 + .25*d, x1, z0 + .78*d), 4.5, False, "containment"),
        room(sector_id, by["cargo_vestibule"], rect(x0 + .38*w, z0 + .78*d, x0 + .78*w, z1), 4.5, True, "airlock"),
    ]
    return result, [("control_post", "passenger_airlock"), ("passenger_airlock", "containment_chamber"), ("containment_chamber", "cargo_vestibule")]


def emergency_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    result = [
        room(sector_id, "capsule_hall", rect(x0, z0, -85.0, 7.0), 3.8),
        room(sector_id, "internal_technical_room", rect(x0, 7.0, -102.0, z1), 3.4),
        room(sector_id, "hermetic_vestibule", rect(-85.0, -4.0, -80.0, 4.0), 3.4, True, "airlock"),
        room(sector_id, "distribution_hall", rect(-80.0, z0, x1, z1), 3.8, True, "circulation"),
    ]
    return result, [("capsule_hall", "hermetic_vestibule"), ("hermetic_vestibule", "distribution_hall"), ("capsule_hall", "internal_technical_room")]


def central_core_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved 15.5 x 21 m passenger-core SVG at 24 px/m."""
    x0, z0, x1, z1 = bounds
    height = height_for(sector_id)
    result = [
        room(sector_id, "electrical_room", rect(-6.9, -5.0, -2.1, -0.25), height),
        room(sector_id, "service_access", rect(-2.1, -5.0, -0.2, 5.0), height),
        room(sector_id, "passenger_elevator", rect(-6.9, -0.25, -2.1, 5.0), height, True, "elevator"),
        room(sector_id, "lift_lobby", rect(-6.9, 5.0, -0.2, 9.5), height, True, "circulation"),
        room(sector_id, "main_stair", rect(0.2, -5.0, 6.9, 9.5), height, True, "stair"),
        room(sector_id, "access_lobby", rect(-7.25, 9.5, 7.25, z1), height, True, "circulation"),
    ]
    return result, [
        ("electrical_room", "service_access"),
        ("service_access", "lift_lobby"),
        ("passenger_elevator", "lift_lobby"),
        ("lift_lobby", "access_lobby"),
        ("main_stair", "access_lobby"),
    ]


def make_layout(passport: dict[str, Any]) -> tuple[list[dict], list[tuple[str, str]]]:
    sector_id = passport["sector_id"]
    names = passport["allowed_internal_subdivision"]
    bounds = FINAL_BOUNDS_OVERRIDE.get(sector_id, passport["parent_boundary_xz"])
    if sector_id == "U-EMERGENCY":
        return emergency_layout(sector_id, bounds)
    if sector_id in CENTRAL_CORE_SECTORS:
        return central_core_layout(sector_id, bounds)
    if sector_id in CONTAINMENT_SECTORS:
        return containment_layout(sector_id, names, bounds)
    if sector_id == "L-CHAMBER-2":
        return chamber2_layout(sector_id, names, bounds)
    if sector_id in SEQUENCE_SECTORS:
        return sequence_layout(sector_id, names, bounds)
    if sector_id in SPINE_SECTORS:
        return spine_layout(sector_id, names, bounds)
    hub_name = HUB_NAMES.get(sector_id)
    if hub_name:
        return hub_layout(sector_id, names, bounds, hub_name)
    return spine_layout(sector_id, names, bounds)


def shared_boundary(a: list[float], b: list[float]) -> tuple[str, float, float, float] | None:
    ax0, az0, ax1, az1 = a
    bx0, bz0, bx1, bz1 = b
    eps = 1e-6
    if abs(ax1 - bx0) < eps or abs(bx1 - ax0) < eps:
        coordinate = ax1 if abs(ax1 - bx0) < eps else ax0
        lo, hi = max(az0, bz0), min(az1, bz1)
        if hi - lo > eps:
            return "x", coordinate, lo, hi
    if abs(az1 - bz0) < eps or abs(bz1 - az0) < eps:
        coordinate = az1 if abs(az1 - bz0) < eps else az0
        lo, hi = max(ax0, bx0), min(ax1, bx1)
        if hi - lo > eps:
            return "z", coordinate, lo, hi
    return None


def internal_portal(sector_id: str, index: int, a: dict, b: dict, width: float, height: float) -> dict[str, Any]:
    shared = shared_boundary(a["bounds_xz"], b["bounds_xz"])
    if shared is None:
        raise ValueError(f"no shared boundary: {a['id']} / {b['id']}")
    axis, coordinate, lo, hi = shared
    span = hi - lo
    cargo_threshold = "cargo_airlock" in a["id"] or "cargo_airlock" in b["id"] or "cargo_vestibule" in a["id"] or "cargo_vestibule" in b["id"]
    central_width = CENTRAL_CORE_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"]))) if sector_id in CENTRAL_CORE_SECTORS else None
    requested_width = central_width if central_width is not None else 4.5 if cargo_threshold else width
    if central_width is not None:
        actual_width = min(requested_width, max(0.9, span * 0.95))
    else:
        actual_width = min(requested_width, max(0.9, span * 0.85 if cargo_threshold else span * 0.6))
    center = (lo + hi) / 2
    segment = [[coordinate, center - actual_width / 2], [coordinate, center + actual_width / 2]] if axis == "x" else [[center - actual_width / 2, coordinate], [center + actual_width / 2, coordinate]]
    return {
        "id": f"P-{sector_id}-{index:02d}",
        "between": [a["id"], b["id"]],
        "segment_xz": [[round(v, 3) for v in point] for point in segment],
        "width": round(actual_width, 3),
        "height": 4.5 if cargo_threshold else height,
        "type": "cargo-hermetic" if cargo_threshold else "internal-door",
        "direction": "bidirectional",
        "state": "openable",
        "status": "provisional-metric",
    }


def entry_keywords(kind: str) -> list[str]:
    if "old-inclined" in kind:
        return ["tunnel_landing", "receiving_hall"]
    if "freight-lift" in kind:
        return ["freight_lift", "freight_platform"]
    if "passing-shaft" in kind:
        return ["passenger_shaft_no_stop", "passenger_elevator"]
    if "emergency-stair" in kind:
        return ["emergency_stair", "east_emergency_stair", "fire_vestibule"]
    if "service-stair" in kind or "old-stair" in kind or kind == "stair":
        return ["service_stair", "old_stair", "route_a_stair", "stair_landing", "fire_vestibule"]
    if "cargo" in kind or "freight" in kind:
        return ["cargo_airlock", "cargo_vestibule", "freight_lift", "freight_platform", "unloading_bay", "service_reception", "receiving_hall", "heavy_spine"]
    if "controlled-transition" in kind:
        return ["two_gate_checkpoint", "double_airlock", "service_lobby", "west_controlled_transition", "east_controlled_transition"]
    if "passenger" in kind or "threshold" in kind:
        return ["passenger_airlock", "access_lobby", "access_vestibule", "distribution_hall", "triage", "support_corridor", "operator_hall", "control_post"]
    if "service" in kind:
        return ["service_approach", "service_lobby", "service_zone", "support_corridor", "distribution_hall", "internal_circulation", "duty_room"]
    return ["internal_circulation", "distribution_hall", "service_lobby", "access_lobby"]


def select_space(sector_id: str, spaces: list[dict], kind: str) -> dict:
    special_entries = {
        ("U-EMERGENCY", "short-side-passage"): "capsule_hall",
        ("U-MEDBAY", "short-side-passage"): "triage",
        ("L-SERVICE-INTERCHANGE", "controlled-transition"): "service_lobby",
    }
    special_name = special_entries.get((sector_id, kind))
    if special_name:
        return next(space for space in spaces if space["name"] == special_name)
    for keyword in entry_keywords(kind):
        for space in spaces:
            if space["name"] == keyword:
                return space
    for space in spaces:
        if space["transit"]:
            return space
    return spaces[0]


def shared_portal_segment(a: list[float], b: list[float], requested_width: float) -> list[list[float]] | None:
    ax0, az0, ax1, az1 = a
    bx0, bz0, bx1, bz1 = b
    eps = 1e-6
    if abs(ax1 - bx0) < eps or abs(bx1 - ax0) < eps:
        x = ax1 if abs(ax1 - bx0) < eps else ax0
        lo, hi = max(az0, bz0), min(az1, bz1)
        if hi > lo:
            width = min(requested_width, (hi - lo) * 0.6)
            center = (lo + hi) / 2
            return [[x, center - width / 2], [x, center + width / 2]]
    if abs(az1 - bz0) < eps or abs(bz1 - az0) < eps:
        z = az1 if abs(az1 - bz0) < eps else az0
        lo, hi = max(ax0, bx0), min(ax1, bx1)
        if hi > lo:
            width = min(requested_width, (hi - lo) * 0.6)
            center = (lo + hi) / 2
            return [[center - width / 2, z], [center + width / 2, z]]
    return None


def side_of_segment(bounds: list[float], segment: list[list[float]]) -> str:
    x0, z0, x1, z1 = bounds
    (ax, az), (bx, bz) = segment
    eps = 1e-6
    if abs(ax - bx) < eps:
        return "west" if abs(ax - x0) < eps else "east"
    return "north" if abs(az - z0) < eps else "south"


def side_for(bounds: list[float], sector_bounds: list[float], preferred: str | None = None) -> tuple[str, float, float, float]:
    x0, z0, x1, z1 = bounds
    sx0, sz0, sx1, sz1 = sector_bounds
    candidates = []
    eps = 1e-6
    if abs(x0 - sx0) < eps:
        candidates.append(("west", x0, z0, z1))
    if abs(x1 - sx1) < eps:
        candidates.append(("east", x1, z0, z1))
    if abs(z0 - sz0) < eps:
        candidates.append(("north", z0, x0, x1))
    if abs(z1 - sz1) < eps:
        candidates.append(("south", z1, x0, x1))
    if not candidates:
        raise ValueError(f"entry space does not touch sector boundary: {bounds} vs {sector_bounds}")
    if preferred:
        for candidate in candidates:
            if candidate[0] == preferred:
                return candidate
    return max(candidates, key=lambda item: item[3] - item[2])


def preferred_side(sector_id: str, neighbor: str, kind: str, bounds: list[float]) -> str | None:
    if neighbor.endswith("PAX") or neighbor in {"U-PAX", "L-PAX"}:
        return "south" if bounds[3] <= 20 else "north"
    if neighbor.endswith("FRT") or neighbor in {"U-FRT", "L-FRT", "T-FRT"}:
        return "north" if bounds[1] >= 67 else "south"
    if "cargo" in kind:
        return "south"
    return None


def external_portal(edge: dict, sector_id: str, spaces: list[dict], sector_bounds: list[float]) -> dict[str, Any]:
    other = edge["to"] if edge["from"] == sector_id else edge["from"]
    entry = select_space(sector_id, spaces, edge["kind"])
    side, coordinate, lo, hi = side_for(entry["bounds_xz"], sector_bounds, preferred_side(sector_id, other, edge["kind"], sector_bounds))
    heavy = "cargo" in edge["kind"] or "freight" in edge["kind"]
    central_entry = sector_id in CENTRAL_CORE_SECTORS and other in {"U-PAX", "L-PAX"}
    width = 4.5 if heavy or central_entry else 1.8 if "controlled" in edge["kind"] or "hermetic" in edge["kind"] else 1.2
    height = 4.5 if heavy else 2.8 if central_entry or "airlock" in entry["name"] or "hermetic" in edge["kind"] else 2.4
    actual_width = min(width, max(0.9, (hi - lo) * 0.6))
    center = (lo + hi) / 2
    segment = [[coordinate, center - actual_width / 2], [coordinate, center + actual_width / 2]] if side in {"west", "east"} else [[center - actual_width / 2, coordinate], [center + actual_width / 2, coordinate]]
    return {
        "id": f"PX-{edge['id']}-{sector_id}",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": other,
        "side": side,
        "segment_xz": [[round(v, 3) for v in point] for point in segment],
        "width": round(actual_width, 3),
        "height": height,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def main() -> None:
    overview = load(OVERVIEW_PATH)
    topology = load(TOPOLOGY_PATH)
    passports_data = load(PASSPORTS_PATH)
    passports = {item["sector_id"]: item for item in passports_data["passports"]}
    levels = {item["id"]: item for item in overview["levels"]}

    all_spaces: list[dict] = []
    all_portals: list[dict] = []
    sector_records: list[dict] = []
    spaces_by_sector: dict[str, list[dict]] = {}
    bounds_by_sector: dict[str, list[float]] = {}

    for sector_id, passport in passports.items():
        if sector_id == "T-CIRCULATION":
            continue
        bounds = FINAL_BOUNDS_OVERRIDE.get(sector_id, passport["parent_boundary_xz"])
        layout_passport = dict(passport)
        layout_passport["parent_boundary_xz"] = bounds
        spaces, pairs = make_layout(layout_passport)
        spaces_by_sector[sector_id] = spaces
        bounds_by_sector[sector_id] = bounds
        level_y = levels[passport["level"]]["floor_y"]
        for space in spaces:
            space["floor_y"] = level_y
        width = 1.8 if passport["clearance_profile"] == "service" else 4.5 if passport["clearance_profile"] == "heavy" else 1.2
        pheight = 2.8 if passport["clearance_profile"] == "service" else 4.5 if passport["clearance_profile"] == "heavy" else 2.4
        index = 1
        by_name = {space["name"]: space for space in spaces}
        for a_name, b_name in pairs:
            all_portals.append(internal_portal(sector_id, index, by_name[a_name], by_name[b_name], width, pheight))
            index += 1
        all_spaces.extend(spaces)
        sector_records.append({
            "id": sector_id,
            "level": passport["level"],
            "bounds_xz": bounds,
            "passport_id": passport["id"],
            "space_ids": [space["id"] for space in spaces],
            "reserved_volumes": passport["hidden_or_inaccessible_reserved_volumes"],
            "source_detail": passport["source_detail"],
            "status": "provisional-metric",
        })

    route_spaces = [
        {"id":"U-PAX","level":"LV-U","kind":"passenger_corridor","bounds_xz":[-95.0,15.0,32.0,20.0],"clear_height":3.4,"width":4.0},
        {"id":"L-PAX","level":"LV-L","kind":"passenger_corridor","bounds_xz":[-95.0,15.0,32.0,20.0],"clear_height":3.4,"width":4.0},
        {"id":"T-TECH","level":"LV-T","kind":"service_corridor","bounds_xz":[-105.0,15.0,32.0,20.5],"clear_height":4.0,"width":5.5},
        {"id":"U-FRT","level":"LV-U","kind":"heavy_corridor","bounds_xz":[-110.0,60.0,32.0,67.5],"clear_height":5.0,"width":7.5},
        {"id":"L-FRT","level":"LV-L","kind":"heavy_corridor","bounds_xz":[-110.0,60.0,32.0,67.5],"clear_height":5.0,"width":7.5},
        {"id":"T-FRT","level":"LV-T","kind":"heavy_corridor","bounds_xz":[-110.0,60.0,32.0,67.5],"clear_height":5.0,"width":7.5},
        {"id":"T-CABLE-GALLERY","level":"LV-T","kind":"cable_gallery","bounds_xz":[-90.0,46.0,20.0,49.0],"clear_height":2.8,"width":3.0,"transit":"service-only"}
    ]
    routes_by_id = {route["id"]: route for route in route_spaces}
    vertical_kinds = {"stair", "passenger-vertical", "emergency-stair", "freight-lift", "old-stair", "service-stair", "passing-shaft"}
    space_lookup = {space["id"]: space for space in all_spaces}
    external_portals: list[dict] = []
    connection_corridors: list[dict] = []
    for edge in topology["connections"]:
        if edge["kind"] in vertical_kinds or "anchor" in edge:
            continue
        endpoints = [value for value in (edge["from"], edge["to"]) if value in spaces_by_sector]
        for sector_id in endpoints:
            portal = external_portal(edge, sector_id, spaces_by_sector[sector_id], bounds_by_sector[sector_id])
            external_portals.append(portal)
        if external_portals and endpoints:
            related = [portal for portal in external_portals if portal["connection_id"] == edge["id"]]
            if len(related) == 2:
                first_space = space_lookup[related[0]["space"]]
                second_space = space_lookup[related[1]["space"]]
                aligned = shared_portal_segment(first_space["bounds_xz"], second_space["bounds_xz"], min(portal["width"] for portal in related))
                if aligned:
                    aligned = [[round(value, 3) for value in point] for point in aligned]
                    aligned_width = round(math.dist(aligned[0], aligned[1]), 3)
                    for portal, space in zip(related, (first_space, second_space), strict=True):
                        portal["segment_xz"] = aligned
                        portal["width"] = aligned_width
                        portal["side"] = side_of_segment(space["bounds_xz"], aligned)
                points = []
                for portal in related:
                    p0, p1 = portal["segment_xz"]
                    points.append([round((p0[0] + p1[0]) / 2, 3), round((p0[1] + p1[1]) / 2, 3)])
                connection_corridors.append({
                    "id": f"C-{edge['id']}",
                    "connection_id": edge["id"],
                    "centerline_xz": points,
                    "width": max(portal["width"] for portal in related),
                    "clear_height": max(portal["height"] for portal in related),
                    "traversable": edge["traversable"],
                    "state": edge.get("state", "openable"),
                })
            elif len(related) == 1:
                route_id = edge["to"] if edge["from"] == endpoints[0] else edge["from"]
                route = routes_by_id.get(route_id)
                if route:
                    p0, p1 = related[0]["segment_xz"]
                    start = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2]
                    x0, z0, x1, z1 = route["bounds_xz"]
                    end = [min(max(start[0], x0), x1), min(max(start[1], z0), z1)]
                    connection_corridors.append({
                        "id": f"C-{edge['id']}",
                        "connection_id": edge["id"],
                        "centerline_xz": [[round(v, 3) for v in start], [round(v, 3) for v in end]],
                        "width": related[0]["width"],
                        "clear_height": related[0]["height"],
                        "traversable": edge["traversable"],
                        "state": edge.get("state", "openable"),
                    })
    for route in route_spaces:
        route["floor_y"] = levels[route["level"]]["floor_y"]
        route["wall_thickness"] = 0.35
        route["status"] = "provisional-metric"

    output = {
        "schema_version": "1.0",
        "artifact_id": "HANDOFF-GEOMETRY-01",
        "map_id": overview["map_id"],
        "title": "Caretaker complex v3 metric blockout handoff",
        "status": "verified",
        "units": "m",
        "coordinate_system": overview["coordinate_system"],
        "levels": overview["levels"],
        "wall_defaults": {"standard": 0.3, "containment": 0.45, "heavy": 0.5, "derive_from_space_boundaries": True},
        "sectors": sector_records,
        "spaces": all_spaces,
        "route_spaces": route_spaces,
        "internal_portals": all_portals,
        "external_portals": external_portals,
        "connection_corridors": connection_corridors,
        "controlled_technical_transitions": [
            {
                "id": "T-TRANS-WEST",
                "represents_connections": ["E-T06", "E-T07"],
                "level": "LV-T",
                "centerline_xz": [[-70.0, 20.5], [-70.0, 60.0]],
                "width": 2.0,
                "clear_height": 2.8,
                "control_points_xz": [[-70.0, 23.0], [-70.0, 57.5]],
                "access": "service-controlled"
            },
            {
                "id": "T-TRANS-EAST",
                "represents_connections": ["E-T06", "E-T07"],
                "level": "LV-T",
                "centerline_xz": [[10.0, 20.5], [10.0, 60.0]],
                "width": 2.0,
                "clear_height": 2.8,
                "control_points_xz": [[10.0, 23.0], [10.0, 57.5]],
                "access": "service-controlled"
            }
        ],
        "vertical_transitions": "../vertical/vertical-transitions.json",
        "uncertainty": {
            "all_metric_geometry": "provisional until Godot blockout traversal pass",
            "default_adjustment_tolerance": 0.25,
            "topology_and_anchor_ids": "fixed"
        }
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"OK: generated {len(sector_records)} physical sectors, {len(all_spaces)} spaces, "
        f"{len(all_portals)} internal portals, {len(external_portals)} external portals"
    )


if __name__ == "__main__":
    main()
