#!/usr/bin/env python3
"""Validate complex v3 passports, exact geometry, portals and vertical handoff."""

from __future__ import annotations

import itertools
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

CONTROL_CENTER_BOUNDS = {
    "U-CONTROL/command_office": [-32.0, -13.0, -26.167, -8.417],
    "U-CONTROL/coordination_room": [-26.167, -13.0, -20.333, -8.417],
    "U-CONTROL/communications_room": [-20.333, -13.0, -10.75, -8.417],
    "U-CONTROL/operator_hall": [-32.0, -8.417, -17.0, 4.083],
    "U-CONTROL/access_buffer": [-17.0, -8.417, -10.75, -5.5],
    "U-CONTROL/access_vestibule": [-17.0, -5.5, -10.75, -1.125],
    "U-CONTROL/duty_support": [-17.0, -1.125, -10.75, 4.083],
    "U-CONTROL/fire_vestibule": [-19.917, 4.083, -15.333, 5.333],
    "U-CONTROL/power_buffer": [-32.0, 5.333, -26.375, 10.333],
    "U-CONTROL/network_node": [-26.375, 5.333, -22.0, 10.333],
    "U-CONTROL/server_room": [-22.0, 5.333, -10.75, 10.333],
    "U-CONTROL/service_aisle": [-32.0, 10.333, -10.75, 11.583],
    "U-CONTROL/east_access": [-10.75, -5.5, -8.0, 14.5],
}

CONTROL_CENTER_CONNECTIONS = {
    frozenset(("operator_hall", "command_office")),
    frozenset(("operator_hall", "coordination_room")),
    frozenset(("operator_hall", "communications_room")),
    frozenset(("operator_hall", "access_vestibule")),
    frozenset(("operator_hall", "duty_support")),
    frozenset(("access_vestibule", "east_access")),
    frozenset(("operator_hall", "fire_vestibule")),
    frozenset(("fire_vestibule", "server_room")),
    frozenset(("power_buffer", "service_aisle")),
    frozenset(("network_node", "service_aisle")),
    frozenset(("server_room", "service_aisle")),
    frozenset(("service_aisle", "east_access")),
}

DOMESTIC_BOUNDS = {
    "U-DOMESTIC/canteen": [-57.0, -13.0, -45.0, -6.0],
    "U-DOMESTIC/internal_circulation": [-45.0, -8.52, -42.0, 15.0],
    "U-DOMESTIC/kitchen": [-42.0, -13.0, -33.0, -2.48],
    "U-DOMESTIC/dry_store": [-42.0, -2.48, -37.4, 5.04],
    "U-DOMESTIC/cold_store": [-37.4, -2.48, -33.0, 5.04],
    "U-DOMESTIC/staff_vestibule": [-42.0, 5.04, -33.0, 6.8],
    "U-DOMESTIC/locker_room": [-42.0, 6.8, -39.0, 13.0],
    "U-DOMESTIC/shower_room": [-39.0, 6.8, -36.2, 13.0],
    "U-DOMESTIC/rest_room": [-36.2, 6.8, -33.0, 13.0],
}

DOMESTIC_CONNECTIONS = {
    frozenset(("canteen", "internal_circulation")),
    frozenset(("kitchen", "internal_circulation")),
    frozenset(("kitchen", "dry_store")),
    frozenset(("kitchen", "cold_store")),
    frozenset(("dry_store", "internal_circulation")),
    frozenset(("staff_vestibule", "internal_circulation")),
    frozenset(("staff_vestibule", "locker_room")),
    frozenset(("staff_vestibule", "shower_room")),
    frozenset(("staff_vestibule", "rest_room")),
}

EAST_SUPPORT_BOUNDS = {
    "U-EAST-SUPPORT/supply_store": [10.0, -13.0, 18.0, -5.9],
    "U-EAST-SUPPORT/cleaning_room": [10.0, -5.9, 18.0, 0.3],
    "U-EAST-SUPPORT/duty_room": [10.0, 0.3, 18.0, 7.0],
    "U-EAST-SUPPORT/support_corridor": [18.0, -13.0, 20.0, 7.0],
    "U-EAST-SUPPORT/service_vestibule": [14.0, 7.0, 19.5, 15.0],
    "U-EAST-SUPPORT/emergency_stair": [22.0, 5.5, 32.0, 11.0],
    "U-EAST-SUPPORT/fire_vestibule": [22.0, 11.0, 32.0, 15.0],
}

EAST_SUPPORT_CONNECTIONS = {
    frozenset(("support_corridor", "supply_store")),
    frozenset(("support_corridor", "cleaning_room")),
    frozenset(("support_corridor", "duty_room")),
    frozenset(("support_corridor", "service_vestibule")),
    frozenset(("emergency_stair", "fire_vestibule")),
}

MEDBAY_BOUNDS = {
    "U-MEDBAY/procedure_room": [-94.0, 7.0, -86.632, 11.205],
    "U-MEDBAY/observation_ward": [-94.0, 11.205, -86.632, 15.0],
    "U-MEDBAY/clean_corridor": [-86.632, 7.0, -84.298, 15.0],
    "U-MEDBAY/clean_store": [-84.298, 7.0, -82.088, 9.667],
    "U-MEDBAY/sanitary_airlock": [-82.088, 7.0, -80.0, 9.667],
    "U-MEDBAY/triage": [-84.298, 9.667, -80.0, 12.744],
    "U-MEDBAY/medical_post": [-84.298, 12.744, -80.0, 15.0],
}

MEDBAY_CONNECTIONS = {
    frozenset(("clean_corridor", "procedure_room")),
    frozenset(("clean_corridor", "observation_ward")),
    frozenset(("clean_corridor", "clean_store")),
    frozenset(("clean_corridor", "triage")),
    frozenset(("clean_corridor", "medical_post")),
    frozenset(("triage", "sanitary_airlock")),
}

ROUTE_A_BOUNDS = {
    "U-ROUTE-A/hall_access": [-61.75, 1.533, -59.5, 5.533],
    "U-ROUTE-A/service_store": [-59.5, -6.0, -53.5, 6.0],
    "U-ROUTE-A/ventilation_room": [-53.5, -6.0, -47.5, 6.0],
    "U-ROUTE-A/stair_landing": [-55.5, 6.0, -49.5, 13.0],
}

ROUTE_A_CONNECTIONS = {
    frozenset(("hall_access", "service_store")),
    frozenset(("service_store", "ventilation_room")),
    frozenset(("ventilation_room", "stair_landing")),
}

ROUTE_A_EXTERNAL_SEGMENTS = {
    "PX-E-U02-U-EMERGENCY": [[-61.75, 2.933], [-61.75, 4.133]],
    "PX-E-U02-U-ROUTE-A": [[-61.75, 2.933], [-61.75, 4.133]],
    "PX-E-L03-L-OLD-CORE": [[-62.0, 7.0], [-62.0, 10.333]],
    "PX-E-L03-L-ARCHIVE-A": [[-61.0, 7.0], [-61.0, 10.333]],
}

LOWER_ROUTE_A_BOUNDS = {
    "L-ARCHIVE-A/archive_main": [-61.0, -14.0, -41.0, 0.5],
    "L-ARCHIVE-A/route_a_service_passage": [-61.0, 0.5, -55.5, 13.0],
    "L-ARCHIVE-A/route_a_stair_lobby": [-55.5, 0.5, -49.5, 6.0],
    "L-ARCHIVE-A/route_a_stair": [-55.5, 6.0, -49.5, 13.0],
    "L-ARCHIVE-A/route_a_partition": [-49.5, 0.5, -41.0, 15.0],
}

LOWER_ROUTE_A_CONNECTIONS = {
    frozenset(("route_a_service_passage", "route_a_stair_lobby")),
    frozenset(("route_a_stair_lobby", "route_a_stair")),
}

OLD_CORE_BOUNDS = {
    "L-OLD-CORE/reserve_control": [-80.944, -14.0, -68.111, -1.667],
    "L-OLD-CORE/relay_room": [-68.111, -14.0, -62.611, -7.333],
    "L-OLD-CORE/senior_room": [-68.111, -7.333, -62.611, -1.667],
    "L-OLD-CORE/control_access": [-74.833, -1.667, -68.722, 2.333],
    "L-OLD-CORE/distribution_hall": [-84.0, 2.333, -62.0, 15.0],
}

OLD_CORE_CONNECTIONS = {
    frozenset(("reserve_control", "relay_room")),
    frozenset(("reserve_control", "senior_room")),
    frozenset(("reserve_control", "control_access")),
    frozenset(("control_access", "distribution_hall")),
}

PERSONNEL_MEDBAY_SEGMENTS = {
    "PX-E-U02A-U-EMERGENCY": [[-80.0, 11.05], [-80.0, 12.25]],
    "PX-E-U02A-U-MEDBAY": [[-80.0, 11.05], [-80.0, 12.25]],
}

FREIGHT_RECEPTION_BOUNDS = {
    "U-FREIGHT/isolation_bay": [-13.0, 68.0, -6.0, 76.0],
    "U-FREIGHT/inspection_lane": [-6.0, 68.0, 4.0, 73.0],
    "U-FREIGHT/operator_room": [-6.0, 73.0, 4.0, 76.0],
    "U-FREIGHT/unloading_bay": [4.0, 68.0, 13.5, 76.0],
    "U-FREIGHT/freight_lift": [13.5, 68.0, 26.5, 76.0],
    "U-FREIGHT/service_walkway": [-13.0, 76.0, 30.0, 78.0],
}

FREIGHT_RECEPTION_CONNECTIONS = {
    frozenset(("isolation_bay", "inspection_lane")),
    frozenset(("inspection_lane", "unloading_bay")),
    frozenset(("unloading_bay", "freight_lift")),
    frozenset(("isolation_bay", "service_walkway")),
    frozenset(("operator_room", "service_walkway")),
    frozenset(("freight_lift", "service_walkway")),
}

SECURITY_BOUNDS = {
    "U-SECURITY/armory": [-32.0, 31.0, -23.2, 38.3],
    "U-SECURITY/access_vestibule": [-23.2, 31.0, -13.0, 38.3],
    "U-SECURITY/equipment_room": [-32.0, 38.3, -23.2, 46.5],
    "U-SECURITY/duty_room": [-23.2, 38.3, -13.0, 46.5],
    "U-SECURITY/internal_circulation": [-13.0, 34.0, -6.8, 38.3],
    "U-SECURITY/two_gate_checkpoint": [-6.8, 31.0, -3.8, 52.0],
}

SECURITY_CONNECTIONS = {
    frozenset(("two_gate_checkpoint", "internal_circulation")),
    frozenset(("internal_circulation", "access_vestibule")),
    frozenset(("access_vestibule", "duty_room")),
    frozenset(("duty_room", "equipment_room")),
    frozenset(("equipment_room", "armory")),
}

SECURITY_EXTERNAL_SEGMENTS = {
    "PX-E-U08-U-SECURITY": [[-6.2, 31.0], [-4.4, 31.0]],
    "PX-E-U09-U-SECURITY": [[-6.2, 52.0], [-4.4, 52.0]],
}


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

    actual_control_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in CONTROL_CENTER_BOUNDS
        if space_id in space_by_id
    }
    if actual_control_bounds != CONTROL_CENTER_BOUNDS:
        errors.append(f"U-CONTROL no longer traces the approved 24 px/m SVG: {actual_control_bounds}")

    actual_domestic_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in DOMESTIC_BOUNDS
        if space_id in space_by_id
    }
    if actual_domestic_bounds != DOMESTIC_BOUNDS:
        errors.append(f"U-DOMESTIC no longer traces the approved 25 px/m SVG: {actual_domestic_bounds}")

    actual_east_support_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in EAST_SUPPORT_BOUNDS
        if space_id in space_by_id
    }
    if actual_east_support_bounds != EAST_SUPPORT_BOUNDS:
        errors.append(f"U-EAST-SUPPORT no longer traces the approved normalized SVG: {actual_east_support_bounds}")

    actual_medbay_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in MEDBAY_BOUNDS
        if space_id in space_by_id
    }
    if actual_medbay_bounds != MEDBAY_BOUNDS:
        errors.append(f"U-MEDBAY no longer preserves the approved room bands: {actual_medbay_bounds}")

    actual_route_a_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in ROUTE_A_BOUNDS
        if space_id in space_by_id
    }
    if actual_route_a_bounds != ROUTE_A_BOUNDS:
        errors.append(f"U-ROUTE-A no longer traces the approved 15 px/m plan: {actual_route_a_bounds}")

    actual_lower_route_a_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in LOWER_ROUTE_A_BOUNDS
        if space_id in space_by_id
    }
    if actual_lower_route_a_bounds != LOWER_ROUTE_A_BOUNDS:
        errors.append(f"L-ARCHIVE-A no longer preserves the archive shell and anchor-aligned Route A stair: {actual_lower_route_a_bounds}")

    actual_old_core_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in OLD_CORE_BOUNDS
        if space_id in space_by_id
    }
    if actual_old_core_bounds != OLD_CORE_BOUNDS:
        errors.append(f"L-OLD-CORE no longer traces the approved old-core hub plan: {actual_old_core_bounds}")

    actual_freight_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in FREIGHT_RECEPTION_BOUNDS
        if space_id in space_by_id
    }
    if actual_freight_bounds != FREIGHT_RECEPTION_BOUNDS:
        errors.append(f"U-FREIGHT no longer traces the approved 20 px/m reception plan: {actual_freight_bounds}")
    freight_lift_bounds = actual_freight_bounds.get("U-FREIGHT/freight_lift", [])
    if freight_lift_bounds:
        lift_center = [(freight_lift_bounds[0] + freight_lift_bounds[2]) / 2, (freight_lift_bounds[1] + freight_lift_bounds[3]) / 2]
        if lift_center != [20.0, 72.0]:
            errors.append(f"U-FREIGHT lift misses A-FREIGHT-LIFT: {lift_center}")

    actual_security_bounds = {
        space_id: space_by_id[space_id]["bounds_xz"]
        for space_id in SECURITY_BOUNDS
        if space_id in space_by_id
    }
    if actual_security_bounds != SECURITY_BOUNDS:
        errors.append(f"U-SECURITY no longer traces the approved security-post plan: {actual_security_bounds}")

    for a, b in itertools.combinations(spaces, 2):
        if a["floor_y"] == b["floor_y"] and positive_overlap(a["bounds_xz"], b["bounds_xz"]):
            errors.append(f"positive room overlap: {a['id']} <> {b['id']}")

    physical_routes = [item for item in geometry["route_spaces"] if item["kind"] != "cable_gallery"]
    for space in spaces:
        for route in physical_routes:
            if space["floor_y"] == route["floor_y"] and positive_overlap(space["bounds_xz"], route["bounds_xz"]):
                errors.append(f"room overlaps physical route: {space['id']} <> {route['id']}")

    for portal in geometry["internal_portals"]:
        a_id, b_id = portal["between"]
        if a_id not in space_by_id or b_id not in space_by_id:
            errors.append(f"internal portal references unknown room: {portal['id']}")
            continue
        if not shared_boundary_segment(portal["segment_xz"], space_by_id[a_id]["bounds_xz"], space_by_id[b_id]["bounds_xz"]):
            errors.append(f"internal portal is not on a shared boundary: {portal['id']}")

    actual_control_connections = {
        frozenset(space_id.removeprefix("U-CONTROL/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-CONTROL-")
    }
    if actual_control_connections != CONTROL_CENTER_CONNECTIONS:
        errors.append("U-CONTROL internal connections differ from the approved plan")

    actual_domestic_connections = {
        frozenset(space_id.removeprefix("U-DOMESTIC/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-DOMESTIC-")
    }
    if actual_domestic_connections != DOMESTIC_CONNECTIONS:
        errors.append("U-DOMESTIC internal connections differ from the approved plan")

    actual_east_support_connections = {
        frozenset(space_id.removeprefix("U-EAST-SUPPORT/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-EAST-SUPPORT-")
    }
    if actual_east_support_connections != EAST_SUPPORT_CONNECTIONS:
        errors.append("U-EAST-SUPPORT internal connections differ from the approved plan")

    actual_medbay_connections = {
        frozenset(space_id.removeprefix("U-MEDBAY/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-MEDBAY-")
    }
    if actual_medbay_connections != MEDBAY_CONNECTIONS:
        errors.append("U-MEDBAY internal connections differ from the approved plan")

    actual_route_a_connections = {
        frozenset(space_id.removeprefix("U-ROUTE-A/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-ROUTE-A-")
    }
    if actual_route_a_connections != ROUTE_A_CONNECTIONS:
        errors.append("U-ROUTE-A internal connections differ from the approved plan")

    actual_security_connections = {
        frozenset(space_id.removeprefix("U-SECURITY/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-SECURITY-")
    }
    if actual_security_connections != SECURITY_CONNECTIONS:
        errors.append("U-SECURITY internal connections differ from the approved plan")

    actual_lower_route_a_connections = {
        frozenset(space_id.removeprefix("L-ARCHIVE-A/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-L-ARCHIVE-A-")
    }
    if actual_lower_route_a_connections != LOWER_ROUTE_A_CONNECTIONS:
        errors.append("L-ARCHIVE-A must keep the old archive isolated and connect only the Route A passage to its stair")

    actual_old_core_connections = {
        frozenset(space_id.removeprefix("L-OLD-CORE/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-L-OLD-CORE-")
    }
    if actual_old_core_connections != OLD_CORE_CONNECTIONS:
        errors.append("L-OLD-CORE service rooms must remain branches off the distribution hall")

    actual_freight_connections = {
        frozenset(space_id.removeprefix("U-FREIGHT/") for space_id in portal["between"])
        for portal in geometry["internal_portals"]
        if portal["id"].startswith("P-U-FREIGHT-")
    }
    if actual_freight_connections != FREIGHT_RECEPTION_CONNECTIONS:
        errors.append("U-FREIGHT internal connections differ from the approved plan")

    external_by_id = {item["id"]: item for item in geometry["external_portals"]}
    for portal in external_by_id.values():
        room = space_by_id.get(portal["space"])
        if room is None or not all(point_on_boundary(point, room["bounds_xz"]) for point in portal["segment_xz"]):
            errors.append(f"external portal is not on its room boundary: {portal['id']}")
    control_entry = external_by_id.get("PX-E-U04-U-CONTROL", {})
    if control_entry.get("space") != "U-CONTROL/east_access" or control_entry.get("side") != "south":
        errors.append("U-CONTROL passenger entry must use the south end of east_access")
    domestic_entry = external_by_id.get("PX-E-U03-U-DOMESTIC", {})
    if domestic_entry.get("space") != "U-DOMESTIC/internal_circulation" or domestic_entry.get("side") != "south":
        errors.append("U-DOMESTIC passenger entry must use the south end of internal_circulation")
    east_support_entries = {
        portal.get("space")
        for portal in external_by_id.values()
        if portal.get("connection_id") == "E-U06" and portal.get("neighbor") == "U-PAX"
    }
    if east_support_entries != {"U-EAST-SUPPORT/service_vestibule", "U-EAST-SUPPORT/fire_vestibule"}:
        errors.append("U-EAST-SUPPORT must preserve independent service and fire-vestibule entries from U-PAX")
    personnel_entry = external_by_id.get("PX-E-U02A-U-EMERGENCY", {})
    medbay_entry = external_by_id.get("PX-E-U02A-U-MEDBAY", {})
    if personnel_entry.get("space") != "U-EMERGENCY/distribution_hall" or personnel_entry.get("side") != "west":
        errors.append("E-U02A must leave from the west wall of the personnel distribution hall")
    if medbay_entry.get("space") != "U-MEDBAY/triage" or medbay_entry.get("side") != "east":
        errors.append("E-U02A must enter the east wall of medbay triage")
    for portal_id, expected_segment in PERSONNEL_MEDBAY_SEGMENTS.items():
        if external_by_id.get(portal_id, {}).get("segment_xz") != expected_segment:
            errors.append(f"E-U02A portal segment moved away from the approved plan: {portal_id}")
    route_a_hall_entry = external_by_id.get("PX-E-U02-U-ROUTE-A", {})
    if route_a_hall_entry.get("space") != "U-ROUTE-A/hall_access" or route_a_hall_entry.get("side") != "west":
        errors.append("Route A must enter through the hall access passage")
    for portal_id, expected_segment in ROUTE_A_EXTERNAL_SEGMENTS.items():
        if external_by_id.get(portal_id, {}).get("segment_xz") != expected_segment:
            errors.append(f"Route A external portal moved away from the approved plan: {portal_id}")
    route_a_corridor = next((item for item in geometry["connection_corridors"] if item["connection_id"] == "E-U02"), {})
    if route_a_corridor.get("centerline_xz") != [[-61.75, 3.533], [-61.75, 3.533]]:
        errors.append("E-U02 must be a shared wall doorway, not a separate connector box")
    freight_entry = external_by_id.get("PX-E-U13-U-FREIGHT", {})
    if freight_entry.get("space") != "U-FREIGHT/inspection_lane" or freight_entry.get("side") != "north":
        errors.append("E-U13 must connect the heavy spine to the north inspection gate")
    if freight_entry.get("segment_xz") != [[-3.25, 68.0], [1.25, 68.0]]:
        errors.append("E-U13 inspection gate moved away from the approved plan")
    security_north = external_by_id.get("PX-E-U08-U-SECURITY", {})
    security_south = external_by_id.get("PX-E-U09-U-SECURITY", {})
    if security_north.get("space") != "U-SECURITY/two_gate_checkpoint" or security_north.get("side") != "north":
        errors.append("U-SECURITY passenger approach must enter the north gate of the checkpoint")
    if security_south.get("space") != "U-SECURITY/two_gate_checkpoint" or security_south.get("side") != "south":
        errors.append("U-SECURITY freight-side approach must leave through the south gate of the checkpoint")
    for portal_id, expected_segment in SECURITY_EXTERNAL_SEGMENTS.items():
        if external_by_id.get(portal_id, {}).get("segment_xz") != expected_segment:
            errors.append(f"U-SECURITY checkpoint gate moved away from the approved plan: {portal_id}")

    old_core_chamber_entry = external_by_id.get("PX-E-L02-L-OLD-CORE", {})
    chamber_1_entry = external_by_id.get("PX-E-L02-L-CHAMBER-1", {})
    if old_core_chamber_entry.get("space") != "L-OLD-CORE/distribution_hall" or old_core_chamber_entry.get("side") != "west":
        errors.append("E-L02 must leave through the west wall of the old-core distribution hall")
    if chamber_1_entry.get("space") != "L-CHAMBER-1/control_post" or chamber_1_entry.get("side") != "east":
        errors.append("E-L02 must enter the combined vestibule/post on Chamber 1's east wall")
    if old_core_chamber_entry.get("segment_xz") != chamber_1_entry.get("segment_xz"):
        errors.append("E-L02 must be a shared doorway, not a bridge")

    service_freight_entry = external_by_id.get("PX-E-L15-L-SERVICE-INTERCHANGE", {})
    if service_freight_entry.get("space") != "L-SERVICE-INTERCHANGE/double_airlock" or service_freight_entry.get("side") != "south":
        errors.append("E-L15 must leave through the heavy side of the service-interchange double airlock")
    technical_freight_entry = external_by_id.get("PX-E-T08-T-FREIGHT", {})
    if technical_freight_entry.get("space") != "T-FREIGHT/heavy_spine" or technical_freight_entry.get("side") != "north":
        errors.append("E-T08 must meet the technical heavy spine directly")
    old_access_entry = external_by_id.get("PX-E-T03-T-OLD-ACCESS", {})
    if old_access_entry.get("space") != "T-OLD-ACCESS/service_vestibule" or old_access_entry.get("side") != "north":
        errors.append("E-T03 must enter the old service vestibule from the main technical corridor")

    corridor_by_id = {item["id"]: item for item in geometry["connection_corridors"]}
    expected_old_receiving_route = [[-80.0, 15.0], [-80.0, 20.0], [-91.0, 20.0], [-91.0, 43.0]]
    if corridor_by_id.get("C-E-L04", {}).get("centerline_xz") != expected_old_receiving_route:
        errors.append("E-L04 must use the orthogonal old-core access through the passenger-route junction")
    for direct_connection in ["C-E-L02", "C-E-L15", "C-E-T03", "C-E-T08"]:
        points = corridor_by_id.get(direct_connection, {}).get("centerline_xz", [])
        if len(points) != 2 or points[0] != points[1]:
            errors.append(f"Direct shared-boundary connection still produces a bridge: {direct_connection}")

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
