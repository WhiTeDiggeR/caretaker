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
    "U-CONTROL": [-32.0, -13.0, -8.0, 14.5],
    "U-CENTRAL-CORE": [-7.75, -6.0, 7.75, 15.0],
    "U-ROUTE-A": [-61.5, -6.0, -47.5, 13.0],
    "U-DOMESTIC": [-57.0, -13.0, -33.0, 15.0],
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

CONTROL_CENTER_PORTAL_WIDTHS = {
    frozenset(("operator_hall", "access_vestibule")): 1.8,
    frozenset(("access_vestibule", "east_access")): 1.8,
    frozenset(("operator_hall", "fire_vestibule")): 1.8,
    frozenset(("fire_vestibule", "server_room")): 1.8,
    frozenset(("service_aisle", "east_access")): 1.5,
}

DOMESTIC_PORTAL_CENTERS = {
    frozenset(("canteen", "internal_circulation")): -6.72,
    frozenset(("kitchen", "internal_circulation")): -4.08,
    frozenset(("kitchen", "dry_store")): -39.24,
    frozenset(("kitchen", "cold_store")): -35.36,
    frozenset(("dry_store", "internal_circulation")): -0.16,
    frozenset(("staff_vestibule", "internal_circulation")): 6.08,
    frozenset(("staff_vestibule", "locker_room")): -40.64,
    frozenset(("staff_vestibule", "shower_room")): -37.68,
    frozenset(("staff_vestibule", "rest_room")): -34.64,
}

EAST_SUPPORT_PORTAL_WIDTHS = {
    frozenset(("support_corridor", "supply_store")): 1.5,
    frozenset(("support_corridor", "cleaning_room")): 1.5,
    frozenset(("support_corridor", "duty_room")): 1.5,
    frozenset(("support_corridor", "service_vestibule")): 1.5,
    frozenset(("emergency_stair", "fire_vestibule")): 1.8,
}

EAST_SUPPORT_PORTAL_CENTERS = {
    frozenset(("support_corridor", "supply_store")): -8.9,
    frozenset(("support_corridor", "cleaning_room")): -3.0,
    frozenset(("support_corridor", "duty_room")): 3.45,
    frozenset(("support_corridor", "service_vestibule")): 18.75,
    frozenset(("emergency_stair", "fire_vestibule")): 30.5,
}

MEDBAY_PORTAL_CENTERS = {
    frozenset(("clean_corridor", "procedure_room")): 9.215,
    frozenset(("clean_corridor", "observation_ward")): 13.031,
    frozenset(("clean_corridor", "clean_store")): 8.231,
    frozenset(("clean_corridor", "triage")): 10.856,
    frozenset(("clean_corridor", "medical_post")): 13.831,
    frozenset(("triage", "sanitary_airlock")): -89.032,
}

ROUTE_A_PORTAL_WIDTHS = {
    frozenset(("hall_access", "service_store")): 2.533,
    frozenset(("service_store", "ventilation_room")): 2.933,
    frozenset(("ventilation_room", "stair_landing")): 2.267,
}

ROUTE_A_PORTAL_CENTERS = {
    frozenset(("hall_access", "service_store")): 3.533,
    frozenset(("service_store", "ventilation_room")): 2.0,
    frozenset(("ventilation_room", "stair_landing")): -51.033,
}

LOWER_ROUTE_A_PORTAL_WIDTHS = {
    frozenset(("route_a_service_passage", "route_a_stair_lobby")): 1.8,
    frozenset(("route_a_stair_lobby", "route_a_stair")): 1.5,
}

LOWER_ROUTE_A_PORTAL_CENTERS = {
    frozenset(("route_a_service_passage", "route_a_stair_lobby")): 3.0,
    frozenset(("route_a_stair_lobby", "route_a_stair")): -53.6,
}

OLD_CORE_PORTAL_WIDTHS = {
    frozenset(("reserve_control", "relay_room")): 2.0,
    frozenset(("reserve_control", "senior_room")): 2.0,
    frozenset(("reserve_control", "control_access")): 3.667,
    frozenset(("control_access", "distribution_hall")): 3.667,
}

OLD_CORE_PORTAL_CENTERS = {
    frozenset(("reserve_control", "relay_room")): -9.667,
    frozenset(("reserve_control", "senior_room")): -4.0,
    frozenset(("reserve_control", "control_access")): -71.778,
    frozenset(("control_access", "distribution_hall")): -71.778,
}

FREIGHT_RECEPTION_PORTAL_WIDTHS = {
    frozenset(("isolation_bay", "inspection_lane")): 2.8,
    frozenset(("inspection_lane", "unloading_bay")): 4.5,
    frozenset(("unloading_bay", "freight_lift")): 5.4,
    frozenset(("isolation_bay", "service_walkway")): 1.5,
    frozenset(("operator_room", "service_walkway")): 1.5,
    frozenset(("freight_lift", "service_walkway")): 1.5,
}

FREIGHT_RECEPTION_PORTAL_CENTERS = {
    frozenset(("isolation_bay", "inspection_lane")): 70.5,
    frozenset(("inspection_lane", "unloading_bay")): 70.5,
    frozenset(("unloading_bay", "freight_lift")): 72.0,
    frozenset(("isolation_bay", "service_walkway")): -10.75,
    frozenset(("operator_room", "service_walkway")): -1.0,
    frozenset(("freight_lift", "service_walkway")): 20.0,
}

CONTAINMENT_SECTORS = {"U-CHAMBER-4", "U-CHAMBER-6", "L-CHAMBER-3", "L-CHAMBER-5"}
SEQUENCE_SECTORS = {"U-ROUTE-A", "L-CHAMBER-1", "L-EAST-STAIR"}
SPINE_SECTORS = {"U-DOMESTIC", "U-SECURITY", "T-WORKSHOP", "T-EAST-VERTICAL", "T-UTILITIES"}
HUB_NAMES = {
    "U-MEDBAY": "clean_corridor",
    "U-CONTROL": "operator_hall",
    "U-CENTRAL-CORE": "access_lobby",
    "U-EAST-SUPPORT": "support_corridor",
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


def upper_containment_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the serial upper containment plan without stretching the entrance over the hall."""
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    passenger = next(name for name in names if "passenger_airlock" in name)
    chamber = next(name for name in names if "containment_chamber" in name)
    cargo = next(name for name in names if "cargo_airlock" in name)
    control = next(name for name in names if "control" in name)
    gallery = next(name for name in names if "gallery" in name)
    height = 5.0
    result = [
        room(sector_id, control, rect(x0, z0, x0 + 0.38 * w, z0 + 0.28 * d), height),
        room(sector_id, passenger, rect(x0 + 0.38 * w, z0, x0 + 0.68 * w, z0 + 0.28 * d), height, True, "airlock"),
        room(sector_id, gallery, rect(x0, z0 + 0.28 * d, x0 + 0.18 * w, z0 + 0.78 * d), height, True, "service_gallery"),
        room(sector_id, chamber, rect(x0 + 0.18 * w, z0 + 0.28 * d, x1, z0 + 0.78 * d), height, False, "containment"),
        room(sector_id, cargo, rect(x0 + 0.45 * w, z0 + 0.78 * d, x0 + 0.82 * w, z1), height, True, "airlock"),
    ]
    return result, [(control, passenger), (control, gallery), (passenger, chamber), (chamber, cargo)]


def chamber2_layout(sector_id: str, names: list[str], bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "control_post", rect(x0 + .2*w, z0, x0 + .45*w, z0 + .25*d), 4.5),
        room(sector_id, "passenger_airlock", rect(x0 + .45*w, z0, x0 + .75*w, z0 + .25*d), 4.5, True, "airlock"),
        room(sector_id, "gas_equipment_room", rect(x0, z0 + .35*d, x0 + .15*w, z0 + .65*d), 4.5),
        room(sector_id, "containment_chamber", rect(x0 + .15*w, z0 + .25*d, x0 + .85*w, z0 + .75*d), 4.5, False, "containment"),
        room(sector_id, "cargo_vestibule", rect(x0 + .35*w, z0 + .75*d, x0 + .65*w, z1), 4.5, True, "airlock"),
    ]
    return result, [
        ("control_post", "passenger_airlock"),
        ("passenger_airlock", "containment_chamber"),
        ("gas_equipment_room", "containment_chamber"),
        ("containment_chamber", "cargo_vestibule"),
    ]


def lower_chamber1_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "mechanical_cage", rect(x0, z0, x0 + .68*w, z1), 5.0, False, "containment"),
        room(sector_id, "combined_vestibule", rect(x0 + .68*w, z0, x1, z0 + .45*d), 5.0, True, "airlock"),
        room(sector_id, "control_post", rect(x0 + .68*w, z0 + .45*d, x1, z1), 5.0),
    ]
    return result, [("combined_vestibule", "control_post"), ("control_post", "mechanical_cage")]


def old_receiving_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "tunnel_landing", rect(x0 + .35*w, z0, x0 + .65*w, z0 + .2*d), 5.0, True, "circulation"),
        room(sector_id, "inspection_post", rect(x0 + .65*w, z0, x1, z0 + .2*d), 5.0),
        room(sector_id, "receiving_hall", rect(x0 + .2*w, z0 + .2*d, x1, z1), 5.0, True, "circulation"),
    ]
    return result, [("tunnel_landing", "receiving_hall"), ("inspection_post", "receiving_hall")]


def sleep_lab_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "neuro_monitoring", rect(x0, z0, x0 + .55*w, z0 + .55*d), 3.4),
        room(sector_id, "equipment_room", rect(x0 + .55*w, z0, x0 + .75*w, z0 + .55*d), 3.4),
        room(sector_id, "observation_room", rect(x0 + .75*w, z0, x1, z0 + .55*d), 3.4),
        room(sector_id, "preparation_room", rect(x0, z0 + .55*d, x0 + .4*w, z1), 3.4),
        room(sector_id, "internal_corridor", rect(x0 + .4*w, z0 + .55*d, x1, z1), 3.4, True, "circulation"),
    ]
    return result, [
        ("internal_corridor", "neuro_monitoring"),
        ("internal_corridor", "equipment_room"),
        ("internal_corridor", "observation_room"),
        ("internal_corridor", "preparation_room"),
    ]


def lower_chamber3_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "operator_gallery", rect(x0 + .2*w, z0, x0 + .45*w, z0 + .22*d), 5.0),
        room(sector_id, "passenger_airlock", rect(x0 + .45*w, z0, x0 + .7*w, z0 + .22*d), 5.0, True, "airlock"),
        room(sector_id, "containment_chamber", rect(x0 + .15*w, z0 + .22*d, x0 + .8*w, z0 + .78*d), 5.0, False, "containment"),
        room(sector_id, "diagnostics_room", rect(x0 + .8*w, z0 + .22*d, x1, z0 + .78*d), 5.0),
        room(sector_id, "cargo_airlock", rect(x0 + .35*w, z0 + .78*d, x0 + .65*w, z1), 5.0, True, "airlock"),
    ]
    return result, [
        ("operator_gallery", "passenger_airlock"),
        ("passenger_airlock", "containment_chamber"),
        ("containment_chamber", "diagnostics_room"),
        ("containment_chamber", "cargo_airlock"),
    ]


def service_interchange_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "service_lobby", rect(x0, z0, x1, z0 + .25*d), 3.8, True, "circulation"),
        room(sector_id, "service_stair", rect(x0, z0 + .25*d, x0 + .4*w, z1), 3.8, True, "stair"),
        room(sector_id, "double_airlock", rect(x0 + .4*w, z0 + .25*d, x0 + .7*w, z1), 3.8, True, "airlock"),
        room(sector_id, "electrical_room", rect(x0 + .7*w, z0 + .25*d, x1, z1), 3.8),
    ]
    return result, [
        ("service_lobby", "service_stair"),
        ("service_lobby", "double_airlock"),
        ("service_lobby", "electrical_room"),
        ("service_stair", "double_airlock"),
        ("double_airlock", "electrical_room"),
    ]


def east_stair_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    result = [
        room(sector_id, "fire_vestibule", rect(x0, z0, x0 + .35*w, z1), 3.8, True, "airlock"),
        room(sector_id, "emergency_stair", rect(x0 + .35*w, z0 + .35*d, x1, z1), 3.8, True, "stair"),
    ]
    return result, [("fire_vestibule", "emergency_stair")]


def lower_freight_service_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    x0, z0, x1, z1 = bounds
    w, d = x1 - x0, z1 - z0
    split = z0 + .75*d
    result = [
        room(sector_id, "ventilation_room", rect(x0, z0, x0 + .18*w, split), 5.0),
        room(sector_id, "electrical_room", rect(x0 + .18*w, z0, x0 + .32*w, split), 5.0),
        room(sector_id, "freight_platform", rect(x0 + .32*w, z0, x0 + .62*w, split), 5.0, True, "circulation"),
        room(sector_id, "freight_lift", rect(x0 + .62*w, z0, x0 + .85*w, split), 5.0, True, "elevator"),
        room(sector_id, "shaft_bypass", rect(x0 + .85*w, z0, x1, split), 5.0, True, "circulation"),
        room(sector_id, "service_zone", rect(x0, split, x1, z1), 5.0, True, "circulation"),
    ]
    return result, [
        ("service_zone", "ventilation_room"),
        ("service_zone", "electrical_room"),
        ("service_zone", "freight_platform"),
        ("service_zone", "freight_lift"),
        ("service_zone", "shaft_bypass"),
    ]


def emergency_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    _x0, _z0, x1, _z1 = bounds
    result = [
        room(sector_id, "capsule_hall", rect(-110.0, -13.0, -85.0, 6.0), 3.8),
        room(sector_id, "internal_technical_room", rect(-110.0, 6.0, -102.0, 14.0), 3.4),
        room(sector_id, "hermetic_vestibule", rect(-85.0, -3.5, -80.0, 1.5), 3.4, True, "airlock"),
        room(sector_id, "distribution_hall", rect(-80.0, -8.5, x1, 15.0), 3.8, True, "circulation"),
    ]
    return result, [("capsule_hall", "hermetic_vestibule"), ("hermetic_vestibule", "distribution_hall"), ("capsule_hall", "internal_technical_room")]


def medbay_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace all seven rooms and doors from the approved medbay SVG."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "procedure_room", rect(-102.0, 7.0, -94.632, 11.205), height),
        room(sector_id, "observation_ward", rect(-102.0, 11.205, -94.632, 15.0), height),
        room(sector_id, "clean_corridor", rect(-94.632, 7.0, -92.298, 15.0), height, True, "circulation"),
        room(sector_id, "clean_store", rect(-92.298, 7.0, -90.088, 9.667), height),
        room(sector_id, "sanitary_airlock", rect(-90.088, 7.0, -88.0, 9.667), height, True, "airlock"),
        room(sector_id, "triage", rect(-92.298, 9.667, -88.0, 12.744), height),
        room(sector_id, "medical_post", rect(-92.298, 12.744, -88.0, 15.0), height),
    ]
    return result, [
        ("clean_corridor", "procedure_room"),
        ("clean_corridor", "observation_ward"),
        ("clean_corridor", "clean_store"),
        ("clean_corridor", "triage"),
        ("clean_corridor", "medical_post"),
        ("triage", "sanitary_airlock"),
    ]


def route_a_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved 15 px/m Route A plan around A-ROUTE-A."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "hall_access", rect(-61.5, 1.533, -59.5, 5.533), height, True, "circulation"),
        room(sector_id, "service_store", rect(-59.5, -6.0, -53.5, 6.0), height),
        room(sector_id, "ventilation_room", rect(-53.5, -6.0, -47.5, 6.0), height),
        room(sector_id, "stair_landing", rect(-55.5, 6.0, -49.5, 13.0), height, True, "stair"),
    ]
    return result, [
        ("hall_access", "service_store"),
        ("service_store", "ventilation_room"),
        ("ventilation_room", "stair_landing"),
    ]


def lower_route_a_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Preserve the old archive shell while keeping the late Route A partition isolated."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "archive_main", rect(-61.0, -14.0, -41.0, 0.5), height),
        room(sector_id, "route_a_service_passage", rect(-61.0, 0.5, -55.5, 13.0), height, True, "circulation"),
        room(sector_id, "route_a_stair_lobby", rect(-55.5, 0.5, -49.5, 6.0), height, True, "circulation"),
        room(sector_id, "route_a_stair", rect(-55.5, 6.0, -49.5, 13.0), height, True, "stair"),
        room(sector_id, "route_a_partition", rect(-49.5, 0.5, -41.0, 15.0), height),
    ]
    return result, [
        ("route_a_service_passage", "route_a_stair_lobby"),
        ("route_a_stair_lobby", "route_a_stair"),
    ]


def old_core_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved old-core hub; service rooms remain branches, never transit."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "reserve_control", rect(-80.944, -14.0, -68.111, -1.667), height),
        room(sector_id, "relay_room", rect(-68.111, -14.0, -62.611, -7.333), height),
        room(sector_id, "senior_room", rect(-68.111, -7.333, -62.611, -1.667), height),
        room(sector_id, "control_access", rect(-74.833, -1.667, -68.722, 2.333), height, True, "circulation"),
        room(sector_id, "distribution_hall", rect(-84.0, 2.333, -62.0, 15.0), height, True, "circulation"),
    ]
    return result, [
        ("reserve_control", "relay_room"),
        ("reserve_control", "senior_room"),
        ("reserve_control", "control_access"),
        ("control_access", "distribution_hall"),
    ]


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


def control_center_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved control-center SVG at 24 px/m."""
    x0, z0, x1, z1 = bounds
    height = height_for(sector_id)
    result = [
        room(sector_id, "command_office", rect(-32.0, -13.0, -26.167, -8.417), height),
        room(sector_id, "coordination_room", rect(-26.167, -13.0, -20.333, -8.417), height),
        room(sector_id, "communications_room", rect(-20.333, -13.0, -10.75, -8.417), height),
        room(sector_id, "operator_hall", rect(-32.0, -8.417, -17.0, 4.083), height, True, "circulation"),
        room(sector_id, "access_buffer", rect(-17.0, -8.417, -10.75, -5.5), height),
        room(sector_id, "access_vestibule", rect(-17.0, -5.5, -10.75, -1.125), height, True, "airlock"),
        room(sector_id, "duty_support", rect(-17.0, -1.125, -10.75, 4.083), height),
        room(sector_id, "fire_vestibule", rect(-19.917, 4.083, -15.333, 5.333), height, True, "airlock"),
        room(sector_id, "power_buffer", rect(-32.0, 5.333, -26.375, 10.333), height),
        room(sector_id, "network_node", rect(-26.375, 5.333, -22.0, 10.333), height),
        room(sector_id, "server_room", rect(-22.0, 5.333, -10.75, 10.333), height),
        room(sector_id, "service_aisle", rect(-32.0, 10.333, -10.75, 11.583), height, True, "circulation"),
        room(sector_id, "east_access", rect(-10.75, -5.5, x1, z1), height, True, "circulation"),
    ]
    return result, [
        ("operator_hall", "command_office"),
        ("operator_hall", "coordination_room"),
        ("operator_hall", "communications_room"),
        ("operator_hall", "access_vestibule"),
        ("operator_hall", "duty_support"),
        ("access_vestibule", "east_access"),
        ("operator_hall", "fire_vestibule"),
        ("fire_vestibule", "server_room"),
        ("power_buffer", "service_aisle"),
        ("network_node", "service_aisle"),
        ("server_room", "service_aisle"),
        ("service_aisle", "east_access"),
    ]


def domestic_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved domestic-wing SVG at 25 px/m."""
    _x0, _z0, _x1, z1 = bounds
    height = height_for(sector_id)
    result = [
        room(sector_id, "canteen", rect(-57.0, -13.0, -45.0, -6.0), height),
        room(sector_id, "internal_circulation", rect(-45.0, -8.52, -42.0, z1), height, True, "circulation"),
        room(sector_id, "kitchen", rect(-42.0, -13.0, -33.0, -2.48), height),
        room(sector_id, "dry_store", rect(-42.0, -2.48, -37.4, 5.04), height),
        room(sector_id, "cold_store", rect(-37.4, -2.48, -33.0, 5.04), height),
        room(sector_id, "staff_vestibule", rect(-42.0, 5.04, -33.0, 6.8), height, True, "circulation"),
        room(sector_id, "locker_room", rect(-42.0, 6.8, -39.0, 13.0), height),
        room(sector_id, "shower_room", rect(-39.0, 6.8, -36.2, 13.0), height),
        room(sector_id, "rest_room", rect(-36.2, 6.8, -33.0, 13.0), height),
    ]
    return result, [
        ("canteen", "internal_circulation"),
        ("kitchen", "internal_circulation"),
        ("kitchen", "dry_store"),
        ("kitchen", "cold_store"),
        ("dry_store", "internal_circulation"),
        ("staff_vestibule", "internal_circulation"),
        ("staff_vestibule", "locker_room"),
        ("staff_vestibule", "shower_room"),
        ("staff_vestibule", "rest_room"),
    ]


def east_support_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved east-support plan, normalized to its metric labels and anchor."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "supply_store", rect(10.0, -13.0, 18.0, -5.9), height),
        room(sector_id, "cleaning_room", rect(10.0, -5.9, 18.0, 0.3), height),
        room(sector_id, "duty_room", rect(10.0, 0.3, 18.0, 7.0), height),
        room(sector_id, "support_corridor", rect(18.0, -13.0, 20.0, 7.0), height, True, "circulation"),
        room(sector_id, "service_vestibule", rect(14.0, 7.0, 19.5, 15.0), height, True, "airlock"),
        room(sector_id, "emergency_stair", rect(22.0, 5.5, 32.0, 11.0), height, True, "stair"),
        room(sector_id, "fire_vestibule", rect(22.0, 11.0, 32.0, 15.0), height, True, "airlock"),
    ]
    return result, [
        ("support_corridor", "supply_store"),
        ("support_corridor", "cleaning_room"),
        ("support_corridor", "duty_room"),
        ("support_corridor", "service_vestibule"),
        ("emergency_stair", "fire_vestibule"),
    ]


def freight_reception_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved freight reception at 20 px/m around A-FREIGHT-LIFT."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "isolation_bay", rect(-13.0, 68.0, -6.0, 76.0), height),
        room(sector_id, "inspection_lane", rect(-6.0, 68.0, 4.0, 73.0), height, True, "circulation"),
        room(sector_id, "operator_room", rect(-6.0, 73.0, 4.0, 76.0), height),
        room(sector_id, "unloading_bay", rect(4.0, 68.0, 13.5, 76.0), height, True, "circulation"),
        room(sector_id, "freight_lift", rect(13.5, 68.0, 26.5, 76.0), height, True, "elevator"),
        room(sector_id, "service_walkway", rect(-13.0, 76.0, 30.0, 78.0), height, True, "circulation"),
    ]
    return result, [
        ("isolation_bay", "inspection_lane"),
        ("inspection_lane", "unloading_bay"),
        ("unloading_bay", "freight_lift"),
        ("isolation_bay", "service_walkway"),
        ("operator_room", "service_walkway"),
        ("freight_lift", "service_walkway"),
    ]


def security_layout(sector_id: str, bounds: list[float]) -> tuple[list[dict], list[tuple[str, str]]]:
    """Trace the approved security post and keep its personnel checkpoint independent."""
    height = height_for(sector_id)
    result = [
        room(sector_id, "armory", rect(-32.0, 31.0, -23.2, 38.3), height),
        room(sector_id, "access_vestibule", rect(-23.2, 31.0, -13.0, 38.3), height),
        room(sector_id, "equipment_room", rect(-32.0, 38.3, -23.2, 46.5), height),
        room(sector_id, "duty_room", rect(-23.2, 38.3, -13.0, 46.5), height),
        room(sector_id, "internal_circulation", rect(-13.0, 34.0, -6.8, 38.3), height, True, "circulation"),
        room(sector_id, "two_gate_checkpoint", rect(-6.8, 31.0, -3.8, 52.0), height, True, "circulation"),
    ]
    return result, [
        ("two_gate_checkpoint", "internal_circulation"),
        ("internal_circulation", "access_vestibule"),
        ("access_vestibule", "duty_room"),
        ("duty_room", "equipment_room"),
        ("equipment_room", "armory"),
    ]


def make_layout(passport: dict[str, Any]) -> tuple[list[dict], list[tuple[str, str]]]:
    sector_id = passport["sector_id"]
    names = passport["allowed_internal_subdivision"]
    bounds = FINAL_BOUNDS_OVERRIDE.get(sector_id, passport["parent_boundary_xz"])
    if sector_id == "U-EMERGENCY":
        return emergency_layout(sector_id, bounds)
    if sector_id == "U-MEDBAY":
        return medbay_layout(sector_id, bounds)
    if sector_id == "U-ROUTE-A":
        return route_a_layout(sector_id, bounds)
    if sector_id == "L-ARCHIVE-A":
        return lower_route_a_layout(sector_id, bounds)
    if sector_id == "L-OLD-CORE":
        return old_core_layout(sector_id, bounds)
    if sector_id == "U-CONTROL":
        return control_center_layout(sector_id, bounds)
    if sector_id == "U-DOMESTIC":
        return domestic_layout(sector_id, bounds)
    if sector_id == "U-EAST-SUPPORT":
        return east_support_layout(sector_id, bounds)
    if sector_id == "U-FREIGHT":
        return freight_reception_layout(sector_id, bounds)
    if sector_id == "U-SECURITY":
        return security_layout(sector_id, bounds)
    if sector_id in {"U-CHAMBER-4", "U-CHAMBER-6"}:
        return upper_containment_layout(sector_id, names, bounds)
    if sector_id == "L-CHAMBER-1":
        return lower_chamber1_layout(sector_id, bounds)
    if sector_id == "L-OLD-RECEIVING":
        return old_receiving_layout(sector_id, bounds)
    if sector_id == "L-CHAMBER-2":
        return chamber2_layout(sector_id, names, bounds)
    if sector_id == "L-SLEEP-LAB":
        return sleep_lab_layout(sector_id, bounds)
    if sector_id == "L-CHAMBER-3":
        return lower_chamber3_layout(sector_id, bounds)
    if sector_id == "L-SERVICE-INTERCHANGE":
        return service_interchange_layout(sector_id, bounds)
    if sector_id == "L-EAST-STAIR":
        return east_stair_layout(sector_id, bounds)
    if sector_id == "L-CHAMBER-5":
        return upper_containment_layout(sector_id, names, bounds)
    if sector_id == "L-FREIGHT-SERVICE":
        return lower_freight_service_layout(sector_id, bounds)
    if sector_id in CENTRAL_CORE_SECTORS:
        return central_core_layout(sector_id, bounds)
    if sector_id in CONTAINMENT_SECTORS:
        return containment_layout(sector_id, names, bounds)
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
    stair_threshold = "stair" in {a.get("kind"), b.get("kind")}
    special_width = CENTRAL_CORE_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"]))) if sector_id in CENTRAL_CORE_SECTORS else None
    if sector_id == "U-CONTROL":
        special_width = CONTROL_CENTER_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    if sector_id == "U-EAST-SUPPORT":
        special_width = EAST_SUPPORT_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    if sector_id == "U-ROUTE-A":
        special_width = ROUTE_A_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    if sector_id == "L-ARCHIVE-A":
        special_width = LOWER_ROUTE_A_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    if sector_id == "L-OLD-CORE":
        special_width = OLD_CORE_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    if sector_id == "U-FREIGHT":
        special_width = FREIGHT_RECEPTION_PORTAL_WIDTHS.get(frozenset((a["name"], b["name"])), special_width)
    requested_width = special_width if special_width is not None else 4.5 if cargo_threshold else width
    if special_width is not None:
        actual_width = min(requested_width, max(0.9, span * 0.95))
    else:
        actual_width = min(requested_width, max(0.9, span * 0.85 if cargo_threshold else span * 0.6))
    center = (lo + hi) / 2
    if sector_id == "U-DOMESTIC":
        center = DOMESTIC_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "U-MEDBAY":
        center = MEDBAY_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "U-ROUTE-A":
        center = ROUTE_A_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "L-ARCHIVE-A":
        center = LOWER_ROUTE_A_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "L-OLD-CORE":
        center = OLD_CORE_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "U-EAST-SUPPORT":
        center = EAST_SUPPORT_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    if sector_id == "U-FREIGHT":
        center = FREIGHT_RECEPTION_PORTAL_CENTERS.get(frozenset((a["name"], b["name"])), center)
    segment = [[coordinate, center - actual_width / 2], [coordinate, center + actual_width / 2]] if axis == "x" else [[center - actual_width / 2, coordinate], [center + actual_width / 2, coordinate]]
    return {
        "id": f"P-{sector_id}-{index:02d}",
        "between": [a["id"], b["id"]],
        "segment_xz": [[round(v, 3) for v in point] for point in segment],
        "width": round(actual_width, 3),
        "height": 4.5 if cargo_threshold else height,
        "type": "cargo-hermetic" if cargo_threshold else "stair-threshold" if stair_threshold else "internal-door",
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
        ("U-CONTROL", "passenger"): "east_access",
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


def personnel_medbay_portal(edge: dict, sector_id: str, spaces: list[dict]) -> dict[str, Any]:
    """Place E-U02A on the plan-approved hall/triage walls, not the capsule hall."""
    entry_name = "distribution_hall" if sector_id == "U-EMERGENCY" else "triage"
    entry = next(space for space in spaces if space["name"] == entry_name)
    other = edge["to"] if edge["from"] == sector_id else edge["from"]
    x = -80.0 if sector_id == "U-EMERGENCY" else -88.0
    width = 1.2
    center_z = 11.65
    return {
        "id": f"PX-{edge['id']}-{sector_id}",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": other,
        "side": "west" if sector_id == "U-EMERGENCY" else "east",
        "segment_xz": [[x, center_z - width * 0.5], [x, center_z + width * 0.5]],
        "width": width,
        "height": 2.4,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def freight_reception_portal(edge: dict, spaces: list[dict]) -> dict[str, Any]:
    """Connect the heavy spine to the inspection gate shown on the approved plan."""
    entry = next(space for space in spaces if space["name"] == "inspection_lane")
    return {
        "id": f"PX-{edge['id']}-U-FREIGHT",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": "U-FRT",
        "side": "north",
        "segment_xz": [[-3.25, 68.0], [1.25, 68.0]],
        "width": 4.5,
        "height": 4.5,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def route_a_external_portal(edge: dict, spaces: list[dict]) -> dict[str, Any]:
    entry_name = "hall_access" if edge["id"] == "E-U02" else "stair_landing"
    entry = next(space for space in spaces if space["name"] == entry_name)
    if edge["id"] == "E-U02":
        segment = [[-61.5, 2.267], [-61.5, 4.8]]
        side = "west"
        width = 2.533
    else:
        segment = [[-53.25, 13.0], [-51.75, 13.0]]
        side = "south"
        width = 1.5
    return {
        "id": f"PX-{edge['id']}-U-ROUTE-A",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": edge["to"] if edge["from"] == "U-ROUTE-A" else edge["from"],
        "side": side,
        "segment_xz": segment,
        "width": width,
        "height": 2.4,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def security_external_portal(edge: dict, spaces: list[dict]) -> dict[str, Any]:
    checkpoint = next(space for space in spaces if space["name"] == "two_gate_checkpoint")
    north = edge["id"] == "E-U08"
    z = 31.0 if north else 52.0
    center = -5.3
    width = 1.8
    return {
        "id": f"PX-{edge['id']}-U-SECURITY",
        "connection_id": edge["id"],
        "space": checkpoint["id"],
        "neighbor": edge["from"] if edge["to"] == "U-SECURITY" else edge["to"],
        "side": "north" if north else "south",
        "segment_xz": [[round(center - width * 0.5, 3), z], [round(center + width * 0.5, 3), z]],
        "width": width,
        "height": 2.4,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def route_a_neighbor_portal(edge: dict, sector_id: str, spaces: list[dict]) -> dict[str, Any]:
    if edge["id"] == "E-U02":
        entry_name = "distribution_hall"
        segment = [[-62.0, 2.267], [-62.0, 4.8]]
        side = "east"
        width = 2.533
    elif sector_id == "L-OLD-CORE":
        entry_name = "distribution_hall"
        segment = [[-62.0, 7.0], [-62.0, 10.333]]
        side = "east"
        width = 3.333
    else:
        entry_name = "route_a_service_passage"
        segment = [[-61.0, 7.0], [-61.0, 10.333]]
        side = "west"
        width = 3.333
    entry = next(space for space in spaces if space["name"] == entry_name)
    other = edge["to"] if edge["from"] == sector_id else edge["from"]
    return {
        "id": f"PX-{edge['id']}-{sector_id}",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": other,
        "side": side,
        "segment_xz": segment,
        "width": width,
        "height": 2.4,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def old_core_chamber_1_portal(edge: dict, spaces: list[dict]) -> dict[str, Any]:
    entry = next(space for space in spaces if space["name"] == "distribution_hall")
    return {
        "id": f"PX-{edge['id']}-L-OLD-CORE",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": "L-CHAMBER-1",
        "side": "south",
        "segment_xz": [[-73.6, 15.0], [-72.4, 15.0]],
        "width": 1.2,
        "height": 2.4,
        "type": edge["kind"],
        "direction": "bidirectional",
        "state": edge.get("state", "openable"),
        "traversable": edge["traversable"],
        "status": "provisional-metric",
    }


def external_portal(edge: dict, sector_id: str, spaces: list[dict], sector_bounds: list[float]) -> dict[str, Any]:
    other = edge["to"] if edge["from"] == sector_id else edge["from"]
    if sector_id == "U-SECURITY" and edge["id"] in {"E-U08", "E-U09"}:
        return security_external_portal(edge, spaces)
    if edge["id"] == "E-U02" and sector_id == "U-EMERGENCY":
        return route_a_neighbor_portal(edge, sector_id, spaces)
    if edge["id"] == "E-L03" and sector_id in {"L-OLD-CORE", "L-ARCHIVE-A"}:
        return route_a_neighbor_portal(edge, sector_id, spaces)
    if edge["id"] == "E-L02" and sector_id == "L-OLD-CORE":
        return old_core_chamber_1_portal(edge, spaces)
    if edge["id"] == "E-U02A" and sector_id in {"U-EMERGENCY", "U-MEDBAY"}:
        return personnel_medbay_portal(edge, sector_id, spaces)
    if edge["id"] == "E-U13" and sector_id == "U-FREIGHT":
        return freight_reception_portal(edge, spaces)
    if sector_id == "U-ROUTE-A" and edge["id"] in {"E-U02", "E-X01"}:
        return route_a_external_portal(edge, spaces)
    if sector_id == "U-EAST-SUPPORT" and edge["id"] == "E-U06":
        entry = next(space for space in spaces if space["name"] == "service_vestibule")
    else:
        entry = select_space(sector_id, spaces, edge["kind"])
    side, coordinate, lo, hi = side_for(entry["bounds_xz"], sector_bounds, preferred_side(sector_id, other, edge["kind"], sector_bounds))
    heavy = "cargo" in edge["kind"] or "freight" in edge["kind"]
    central_entry = sector_id in CENTRAL_CORE_SECTORS and other in {"U-PAX", "L-PAX"}
    width = 4.5 if heavy or central_entry else 2.0 if sector_id == "U-EAST-SUPPORT" and edge["id"] == "E-U06" else 1.8 if "controlled" in edge["kind"] or "hermetic" in edge["kind"] else 1.2
    height = 4.5 if heavy else 2.8 if central_entry or "airlock" in entry["name"] or "hermetic" in edge["kind"] else 2.4
    actual_width = min(width, max(0.9, (hi - lo) * 0.6))
    center = 16.75 if sector_id == "U-EAST-SUPPORT" and edge["id"] == "E-U06" else (lo + hi) / 2
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


def east_support_fire_entry(edge: dict, spaces: list[dict]) -> dict[str, Any]:
    entry = next(space for space in spaces if space["name"] == "fire_vestibule")
    width = 2.9
    center = 27.0
    return {
        "id": "PX-E-U06-U-EAST-SUPPORT-FIRE",
        "connection_id": edge["id"],
        "space": entry["id"],
        "neighbor": "U-PAX",
        "side": "south",
        "segment_xz": [[round(center - width * 0.5, 3), 15.0], [round(center + width * 0.5, 3), 15.0]],
        "width": width,
        "height": 2.8,
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
            if sector_id == "U-EAST-SUPPORT" and edge["id"] == "E-U06":
                external_portals.append(east_support_fire_entry(edge, spaces_by_sector[sector_id]))
        if external_portals and endpoints:
            related = [portal for portal in external_portals if portal["connection_id"] == edge["id"]]
            if edge["id"] in {"E-U06", "E-L02"} and len(related) == 2:
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
            elif len(related) == 2:
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
