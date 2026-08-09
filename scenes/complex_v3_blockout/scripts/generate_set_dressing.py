#!/usr/bin/env python3
"""Generate deterministic, editable set-dressing sub-scenes for complex v3."""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
OUTPUT = ROOT / "scenes/complex_v3_blockout/set_dressing"
MANIFEST = OUTPUT / "set_dressing_manifest.json"

PROP_DATA = {
    "medical_bed": ("res://objects/medical_bed.tscn", 1.1, 2.3),
    "loaded_cabinet": ("res://objects/loaded_cabinet.tscn", 1.2, 0.7),
    "wall_terminal": ("res://objects/wall_terminal.tscn", 0.9, 0.5),
    "staff_table": ("res://objects/staff_table.tscn", 1.8, 1.2),
    "loaded_locker": ("res://objects/loaded_locker.tscn", 1.2, 0.7),
    "loaded_shelf": ("res://objects/loaded_shelf.tscn", 1.5, 0.8),
    "server_rack": ("res://objects/server_rack.tscn", 1.0, 0.9),
    "security_camera": ("res://objects/security_camera.tscn", 0.7, 0.7),
    "industrial_crate": ("res://objects/industrial_crate.tscn", 1.0, 0.8),
    "emergency_barrier": ("res://objects/emergency_barrier.tscn", 1.8, 0.7),
    "workbench": ("res://objects/workbench.tscn", 2.0, 1.0),
    "generator_unit": ("res://objects/generator_unit.tscn", 1.7, 1.1),
    "debris_pile": ("res://objects/debris_pile.tscn", 1.4, 1.1),
    "operator_console": ("res://objects/complex_v3/operator_console.tscn", 1.6, 0.9),
    "pipe_cluster": ("res://objects/complex_v3/pipe_cluster.tscn", 2.6, 0.8),
    "utility_tank": ("res://objects/complex_v3/utility_tank.tscn", 1.4, 1.4),
    "containment_capsule": ("res://objects/complex_v3/containment_capsule.tscn", 3.2, 1.7),
    "wall_beacon": ("res://objects/complex_v3/wall_beacon.tscn", 0.6, 0.25),
}

CENTRAL_CORE_SECTORS = {"U-CENTRAL-CORE", "L-CENTRAL-CORE"}
CHAMBER_SECTORS = {
    "U-CHAMBER-4",
    "U-CHAMBER-6",
    "L-CHAMBER-1",
    "L-CHAMBER-2",
    "L-CHAMBER-3",
    "L-CHAMBER-5",
}
WALL_MOUNT = {
    "wall_beacon": {"depth": 0.12, "center_offset": 0.0},
    "wall_terminal": {"depth": 0.22, "center_offset": -0.01},
}

PALETTES = {
    "medical": ["medical_bed", "loaded_cabinet", "wall_terminal"],
    "command": ["operator_console", "server_rack", "loaded_locker", "security_camera"],
    "domestic": ["staff_table", "loaded_cabinet", "loaded_shelf", "loaded_locker"],
    "containment": ["containment_capsule", "wall_terminal", "generator_unit", "operator_console"],
    "freight": ["industrial_crate", "emergency_barrier", "workbench", "generator_unit"],
    "utility": ["pipe_cluster", "utility_tank", "generator_unit", "workbench"],
    "historic": ["debris_pile", "loaded_shelf", "workbench", "wall_terminal"],
}


def family_for(sector_id: str) -> str:
    if "MEDBAY" in sector_id or "EMERGENCY" in sector_id:
        return "medical"
    if "CONTROL" in sector_id or "SECURITY" in sector_id:
        return "command"
    if "DOMESTIC" in sector_id or "EAST-SUPPORT" in sector_id:
        return "domestic"
    if "CHAMBER" in sector_id or "SLEEP" in sector_id:
        return "containment"
    if "FREIGHT" in sector_id or sector_id.endswith("-FRT"):
        return "freight"
    if "OLD" in sector_id or "ARCHIVE" in sector_id or "ROUTE-A" in sector_id:
        return "historic"
    return "utility"


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", value)


def portal_centers(handoff: dict) -> dict[str, list[tuple[float, float]]]:
    result: dict[str, list[tuple[float, float]]] = {}
    for portal in handoff["internal_portals"]:
        a, b = portal["segment_xz"]
        center = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        for space_id in portal["between"]:
            result.setdefault(space_id, []).append(center)
    for portal in handoff["external_portals"]:
        a, b = portal["segment_xz"]
        center = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        result.setdefault(portal["space"], []).append(center)
    return result


def pick_position(space: dict, footprint: tuple[float, float], portals: list[tuple[float, float]]) -> tuple[float, float, float]:
    x0, z0, x1, z1 = map(float, space["bounds_xz"])
    half_x = footprint[0] * 0.5 + 0.45
    half_z = footprint[1] * 0.5 + 0.45
    center_x = (x0 + x1) * 0.5
    center_z = (z0 + z1) * 0.5
    if space["id"] == "T-FREIGHT/freight_lift":
        return center_x, float(space["floor_y"]), center_z
    candidates = [
        (x0 + half_x, center_z),
        (x1 - half_x, center_z),
        (center_x, z0 + half_z),
        (center_x, z1 - half_z),
    ]
    if x1 - x0 < half_x * 2.0 or z1 - z0 < half_z * 2.0:
        return ((x0 + x1) * 0.5, float(space["floor_y"]), (z0 + z1) * 0.5)
    def score(point: tuple[float, float]) -> float:
        if not portals:
            return math.hypot(point[0] - (x0 + x1) * 0.5, point[1] - (z0 + z1) * 0.5)
        return min(math.hypot(point[0] - px, point[1] - pz) for px, pz in portals)
    x, z = max(candidates, key=score)
    return x, float(space["floor_y"]), z


def snap_to_nearest_wall(space: dict, x: float, z: float, center_offset: float) -> tuple[float, float, float, str]:
    x0, z0, x1, z1 = map(float, space["bounds_xz"])
    half_wall = float(space.get("wall_thickness", 0.3)) * 0.5
    side = min(
        (
            (abs(x - x0), "west"),
            (abs(x - x1), "east"),
            (abs(z - z0), "north"),
            (abs(z - z1), "south"),
        ),
        key=lambda candidate: candidate[0],
    )[1]
    if side == "west":
        return x0 + half_wall + center_offset, z, math.pi * 0.5, side
    if side == "east":
        return x1 - half_wall - center_offset, z, -math.pi * 0.5, side
    if side == "north":
        return x, z0 + half_wall + center_offset, 0.0, side
    return x, z1 - half_wall - center_offset, math.pi, side


def choose_prop(space: dict, family: str, index: int) -> str:
    space_name = str(space.get("name", ""))
    if space_name == "electrical_room" and str(space.get("sector_id", "")) in {"U-CENTRAL-CORE", "L-CENTRAL-CORE"}:
        return "generator_unit"
    if space_name in {"passenger_elevator", "main_stair"}:
        return "wall_beacon"
    transit_words = ("airlock", "circulation", "corridor", "distribution", "gallery", "junction", "lobby", "threshold", "vestibule", "receiving_hall", "service_reception", "unloading_bay", "freight_platform")
    if any(word in str(space.get("name", "")).lower() for word in transit_words):
        return "wall_beacon"
    width = float(space["bounds_xz"][2]) - float(space["bounds_xz"][0])
    depth = float(space["bounds_xz"][3]) - float(space["bounds_xz"][1])
    palette = PALETTES[family]
    for offset in range(len(palette)):
        key = palette[(index + offset) % len(palette)]
        _, size_x, size_z = PROP_DATA[key]
        if width >= size_x + 1.2 and depth >= size_z + 1.2:
            return key
    return "wall_terminal"


def collect_frames(handoff: dict, spaces: dict[str, dict]) -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {}
    for portal in handoff["internal_portals"]:
        owner = spaces[portal["between"][0]]["sector_id"]
        result.setdefault(owner, []).append(portal)
    for portal in handoff["external_portals"]:
        if portal["id"] == "PX-E-U02-U-EMERGENCY":
            # E-U02 is a shared-wall doorway. Its Route A side owns the single
            # frame so the full assembly matches ordinary internal doors.
            continue
        owner = spaces[portal["space"]]["sector_id"]
        result.setdefault(owner, []).append(portal)
    return result


def planned_prop(spaces: dict[str, dict], sector_id: str, space_name: str, prop: str, x: float, z: float, rotation_y: float, suffix: str, wall_side: str | None = None) -> dict:
    space_id = f"{sector_id}/{space_name}"
    space = spaces[space_id]
    path, size_x, size_z = PROP_DATA[prop]
    y = float(space["floor_y"])
    if prop == "wall_terminal":
        y += 1.2
    elif prop == "security_camera":
        y += 2.65
    elif prop == "wall_beacon":
        y += 2.35
    placement = {
        "kind": "prop",
        "id": f"{space_id}::{prop}::{suffix}",
        "space_id": space_id,
        "scene": path,
        "position": [x, y, z],
        "rotation_y": rotation_y,
        "footprint_xz": [size_x, size_z],
        "plan_aligned": True,
    }
    if wall_side is not None:
        placement["wall_mount_depth"] = WALL_MOUNT[prop]["depth"]
        placement["wall_mount_center_offset"] = WALL_MOUNT[prop]["center_offset"]
        placement["wall_mount_side"] = wall_side
    return placement


def control_center_props(spaces: dict[str, dict]) -> list[dict]:
    return [
        planned_prop(spaces, "U-CONTROL", "command_office", "operator_console", -29.083, -10.500, 0.0, "desk"),
        planned_prop(spaces, "U-CONTROL", "coordination_room", "operator_console", -23.250, -10.500, 0.0, "briefing"),
        planned_prop(spaces, "U-CONTROL", "communications_room", "wall_terminal", -19.725, -8.557, math.pi, "west", "south"),
        planned_prop(spaces, "U-CONTROL", "communications_room", "wall_terminal", -15.542, -8.557, math.pi, "center", "south"),
        planned_prop(spaces, "U-CONTROL", "communications_room", "wall_terminal", -12.333, -8.557, math.pi, "east", "south"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "wall_terminal", -31.860, -2.167, math.pi * 0.5, "status_screen", "west"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "operator_console", -26.958, -3.375, 0.0, "island_nw"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "operator_console", -22.083, -3.375, 0.0, "island_ne"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "operator_console", -26.958, -0.458, 0.0, "island_sw"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "operator_console", -22.083, -0.458, 0.0, "island_se"),
        planned_prop(spaces, "U-CONTROL", "operator_hall", "operator_console", -24.500, 2.333, math.pi, "central"),
        planned_prop(spaces, "U-CONTROL", "access_vestibule", "wall_beacon", -13.875, -1.275, math.pi, "south", "south"),
        planned_prop(spaces, "U-CONTROL", "duty_support", "loaded_cabinet", -13.875, 3.483, math.pi, "supplies"),
        planned_prop(spaces, "U-CONTROL", "fire_vestibule", "wall_beacon", -19.767, 4.708, math.pi * 0.5, "west", "west"),
        planned_prop(spaces, "U-CONTROL", "power_buffer", "generator_unit", -29.188, 7.833, 0.0, "ups"),
        planned_prop(spaces, "U-CONTROL", "network_node", "server_rack", -24.188, 7.833, 0.0, "network"),
        planned_prop(spaces, "U-CONTROL", "server_room", "server_rack", -20.208, 8.625, 0.0, "rack_1"),
        planned_prop(spaces, "U-CONTROL", "server_room", "server_rack", -17.958, 8.625, 0.0, "rack_2"),
        planned_prop(spaces, "U-CONTROL", "server_room", "server_rack", -15.708, 8.625, 0.0, "rack_3"),
        planned_prop(spaces, "U-CONTROL", "server_room", "server_rack", -13.458, 8.625, 0.0, "rack_4"),
        planned_prop(spaces, "U-CONTROL", "east_access", "wall_beacon", -8.150, 4.500, -math.pi * 0.5, "east", "east"),
    ]


def domestic_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "U-DOMESTIC"
    return [
        planned_prop(spaces, sector_id, "canteen", "staff_table", -54.16, -9.24, 0.0, "table_nw"),
        planned_prop(spaces, sector_id, "canteen", "staff_table", -50.00, -9.24, 0.0, "table_ne"),
        planned_prop(spaces, sector_id, "canteen", "staff_table", -54.16, -7.32, 0.0, "table_sw"),
        planned_prop(spaces, sector_id, "canteen", "staff_table", -50.00, -7.32, 0.0, "table_se"),
        planned_prop(spaces, sector_id, "canteen", "loaded_cabinet", -46.50, -8.00, math.pi * 0.5, "serving_counter"),
        planned_prop(spaces, sector_id, "kitchen", "workbench", -39.40, -9.36, 0.0, "prep"),
        planned_prop(spaces, sector_id, "kitchen", "workbench", -35.56, -9.36, 0.0, "hot_line"),
        planned_prop(spaces, sector_id, "kitchen", "workbench", -39.80, -6.80, 0.0, "island_w"),
        planned_prop(spaces, sector_id, "kitchen", "workbench", -37.48, -6.80, 0.0, "island_c"),
        planned_prop(spaces, sector_id, "kitchen", "workbench", -35.16, -6.80, 0.0, "island_e"),
        planned_prop(spaces, sector_id, "kitchen", "loaded_cabinet", -35.56, -4.32, 0.0, "wash_return"),
        planned_prop(spaces, sector_id, "dry_store", "loaded_shelf", -40.20, 1.60, 0.0, "shelf_n"),
        planned_prop(spaces, sector_id, "dry_store", "loaded_shelf", -40.20, 3.40, 0.0, "shelf_s"),
        planned_prop(spaces, sector_id, "cold_store", "loaded_shelf", -35.20, 1.60, 0.0, "cold_rack_n"),
        planned_prop(spaces, sector_id, "cold_store", "loaded_shelf", -35.20, 3.40, 0.0, "cold_rack_s"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -41.20, 8.20, 0.0, "west_n"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -41.20, 9.80, 0.0, "west_c"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -41.20, 11.40, 0.0, "west_s"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -39.80, 8.20, 0.0, "east_n"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -39.80, 9.80, 0.0, "east_c"),
        planned_prop(spaces, sector_id, "locker_room", "loaded_locker", -39.80, 11.40, 0.0, "east_s"),
        planned_prop(spaces, sector_id, "rest_room", "staff_table", -34.60, 9.20, 0.0, "table_n"),
        planned_prop(spaces, sector_id, "rest_room", "staff_table", -34.60, 11.50, 0.0, "table_s"),
    ]


def east_support_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "U-EAST-SUPPORT"
    return [
        planned_prop(spaces, sector_id, "supply_store", "loaded_shelf", 12.50, -8.00, 0.0, "linen"),
        planned_prop(spaces, sector_id, "supply_store", "loaded_cabinet", 15.50, -8.00, 0.0, "chemicals"),
        planned_prop(spaces, sector_id, "cleaning_room", "utility_tank", 12.50, -2.50, 0.0, "wash_sink"),
        planned_prop(spaces, sector_id, "cleaning_room", "workbench", 15.20, -2.50, 0.0, "equipment"),
        planned_prop(spaces, sector_id, "duty_room", "workbench", 14.00, 3.80, 0.0, "desk"),
        planned_prop(spaces, sector_id, "duty_room", "loaded_cabinet", 12.50, 5.60, 0.0, "cabinet"),
    ]


def medbay_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "U-MEDBAY"
    procedure = spaces[f"{sector_id}/procedure_room"]
    offset_x = float(procedure["bounds_xz"][0]) - (-102.0)
    x = lambda value: value + offset_x
    return [
        planned_prop(spaces, sector_id, "procedure_room", "medical_bed", x(-99.20), 9.10, 0.0, "procedure_table"),
        planned_prop(spaces, sector_id, "procedure_room", "workbench", x(-96.20), 8.10, 0.0, "instrument_bench"),
        planned_prop(spaces, sector_id, "procedure_room", "loaded_cabinet", x(-96.20), 10.35, 0.0, "sterile_cabinet"),
        planned_prop(spaces, sector_id, "observation_ward", "medical_bed", x(-100.20), 13.10, 0.0, "bed_west"),
        planned_prop(spaces, sector_id, "observation_ward", "medical_bed", x(-98.60), 13.10, 0.0, "bed_center"),
        planned_prop(spaces, sector_id, "observation_ward", "medical_bed", x(-97.00), 13.10, 0.0, "bed_east"),
        planned_prop(spaces, sector_id, "clean_store", "loaded_cabinet", x(-91.19), 9.25, 0.0, "sterile_stock"),
        planned_prop(spaces, sector_id, "sanitary_airlock", "utility_tank", x(-89.04), 7.75, 0.0, "decon_unit"),
        planned_prop(spaces, sector_id, "triage", "wall_terminal", x(-90.15), 12.604, math.pi, "intake_terminal", "south"),
        planned_prop(spaces, sector_id, "medical_post", "operator_console", x(-90.15), 13.70, 0.0, "duty_console"),
        planned_prop(spaces, sector_id, "medical_post", "loaded_cabinet", x(-90.15), 14.45, 0.0, "medicine_cabinet"),
        planned_prop(spaces, sector_id, "clean_corridor", "wall_beacon", x(-94.482), 11.80, math.pi * 0.5, "clean_route", "west"),
    ]


def route_a_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "U-ROUTE-A"
    return [
        planned_prop(spaces, sector_id, "hall_access", "wall_beacon", -60.50, 5.383, math.pi, "route_marker", "south"),
        planned_prop(spaces, sector_id, "service_store", "loaded_shelf", -57.70, -4.50, 0.0, "shelf_west"),
        planned_prop(spaces, sector_id, "service_store", "loaded_shelf", -55.30, -4.50, 0.0, "shelf_east"),
        planned_prop(spaces, sector_id, "ventilation_room", "pipe_cluster", -51.50, -4.50, 0.0, "duct_bank_west"),
        planned_prop(spaces, sector_id, "ventilation_room", "pipe_cluster", -49.00, -1.50, math.pi * 0.5, "duct_bank_east"),
    ]


def lower_route_a_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "L-ARCHIVE-A"
    return [
        planned_prop(spaces, sector_id, "archive_main", "loaded_shelf", -57.0, -8.0, 0.0, "archive_row_1"),
        planned_prop(spaces, sector_id, "archive_main", "loaded_shelf", -53.0, -8.0, 0.0, "archive_row_2"),
        planned_prop(spaces, sector_id, "archive_main", "loaded_shelf", -49.0, -8.0, 0.0, "archive_row_3"),
        planned_prop(spaces, sector_id, "archive_main", "loaded_shelf", -45.0, -8.0, 0.0, "archive_row_4"),
        planned_prop(spaces, sector_id, "route_a_service_passage", "wall_beacon", -60.85, 8.667, math.pi * 0.5, "old_core_exit", "west"),
        planned_prop(spaces, sector_id, "route_a_partition", "loaded_shelf", -46.5, 5.0, math.pi * 0.5, "displaced_archive_1"),
        planned_prop(spaces, sector_id, "route_a_partition", "loaded_shelf", -43.5, 5.0, math.pi * 0.5, "displaced_archive_2"),
    ]


def old_core_props(spaces: dict[str, dict]) -> list[dict]:
    sector_id = "L-OLD-CORE"
    return [
        planned_prop(spaces, sector_id, "distribution_hall", "operator_console", -73.0, 12.0, 0.0, "navigation_island"),
        planned_prop(spaces, sector_id, "distribution_hall", "wall_terminal", -62.14, 14.0, -math.pi * 0.5, "route_status", "east"),
        planned_prop(spaces, sector_id, "reserve_control", "workbench", -75.0, -8.0, 0.0, "analog_console"),
        planned_prop(spaces, sector_id, "relay_room", "server_rack", -65.0, -10.0, 0.0, "relay_bank"),
        planned_prop(spaces, sector_id, "senior_room", "loaded_cabinet", -65.0, -4.0, 0.0, "records"),
        planned_prop(spaces, sector_id, "control_access", "wall_beacon", -71.778, 2.183, math.pi, "control_door", "south"),
    ]


def make_manifest() -> dict:
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    spaces = {space["id"]: space for space in handoff["spaces"]}
    centers = portal_centers(handoff)
    frames = collect_frames(handoff, spaces)
    sectors = []
    for sector in catalog["sectors"]:
        sector_id = sector["sector_id"]
        family = family_for(sector_id)
        placements = []
        sector_spaces = sorted((s for s in spaces.values() if s["sector_id"] == sector_id), key=lambda s: s["id"])
        if sector_id == "U-CONTROL":
            placements.extend(control_center_props(spaces))
        elif sector_id == "U-DOMESTIC":
            placements.extend(domestic_props(spaces))
        elif sector_id == "U-EAST-SUPPORT":
            placements.extend(east_support_props(spaces))
        elif sector_id == "U-MEDBAY":
            placements.extend(medbay_props(spaces))
        elif sector_id == "U-ROUTE-A":
            placements.extend(route_a_props(spaces))
        elif sector_id == "L-ARCHIVE-A":
            placements.extend(lower_route_a_props(spaces))
        elif sector_id == "L-OLD-CORE":
            placements.extend(old_core_props(spaces))
        for index, space in enumerate(sector_spaces if sector_id not in {"U-CONTROL", "U-DOMESTIC", "U-EAST-SUPPORT", "U-MEDBAY", "U-ROUTE-A", "L-ARCHIVE-A", "L-OLD-CORE"} else []):
            prop = choose_prop(space, family, index)
            path, size_x, size_z = PROP_DATA[prop]
            x, y, z = pick_position(space, (size_x, size_z), centers.get(space["id"], []))
            if prop == "wall_terminal":
                y += 1.2
            elif prop == "security_camera":
                y += 2.65
            elif prop == "wall_beacon":
                y += 2.35
            cx = (float(space["bounds_xz"][0]) + float(space["bounds_xz"][2])) * 0.5
            cz = (float(space["bounds_xz"][1]) + float(space["bounds_xz"][3])) * 0.5
            rotation_y = math.atan2(cx - x, cz - z)
            wall_mount_depth = None
            wall_mount_side = None
            wall_mount_center_offset = None
            should_wall_mount = (
                sector_id in CENTRAL_CORE_SECTORS and prop in WALL_MOUNT
            ) or (
                sector_id in CHAMBER_SECTORS and prop == "wall_beacon"
            )
            if should_wall_mount:
                wall_mount_depth = WALL_MOUNT[prop]["depth"]
                wall_mount_center_offset = WALL_MOUNT[prop]["center_offset"]
                x, z, rotation_y, wall_mount_side = snap_to_nearest_wall(space, x, z, wall_mount_center_offset)
            placement = {"kind": "prop", "id": f"{space['id']}::{prop}", "space_id": space["id"], "scene": path, "position": [x, y, z], "rotation_y": rotation_y, "footprint_xz": [size_x, size_z]}
            if wall_mount_depth is not None:
                placement["wall_mount_depth"] = wall_mount_depth
                placement["wall_mount_center_offset"] = wall_mount_center_offset
                placement["wall_mount_side"] = wall_mount_side
            placements.append(placement)
        if not sector_spaces:
            x, y, z = map(float, sector["focus_xyz"])
            path, size_x, size_z = PROP_DATA["pipe_cluster"]
            placements.append({"kind": "prop", "id": f"{sector_id}::pipe_cluster", "space_id": "", "scene": path, "position": [x + 4.0, y, z + 4.0], "rotation_y": 0.0, "footprint_xz": [size_x, size_z]})
        for portal in frames.get(sector_id, []):
            a, b = portal["segment_xz"]
            width = float(portal["width"])
            related_spaces = " ".join(portal.get("between", [portal.get("space", "")]))
            central_wide_passenger = sector_id in {"U-CENTRAL-CORE", "L-CENTRAL-CORE"} and str(portal.get("type", "")) == "internal-door"
            cargo = (width >= 3.0 and not central_wide_passenger) or "freight" in str(portal.get("type", "")) or "cargo" in str(portal.get("type", "")) or "cargo_" in related_spaces
            frame_path = "res://objects/complex_v3/open_cargo_gate_frame.tscn" if cargo else "res://objects/complex_v3/open_door_frame.tscn"
            default_width = 4.16 if cargo else 2.38
            space_id = portal.get("space", portal.get("between", [""])[0])
            floor_y = float(spaces[space_id]["floor_y"])
            rotation_y = 0.0 if abs(float(b[0]) - float(a[0])) >= abs(float(b[1]) - float(a[1])) else math.pi * 0.5
            placements.append({"kind": "open_portal_frame", "id": portal["id"], "space_id": space_id, "scene": frame_path, "position": [(float(a[0]) + float(b[0])) * 0.5, floor_y, (float(a[1]) + float(b[1])) * 0.5], "rotation_y": rotation_y, "scale": [width / default_width, float(portal["height"]) / (3.0 if cargo else 2.4), 1.0], "traversable": bool(portal.get("traversable", True))})
        sectors.append({"sector_id": sector_id, "family": family, "zone_scene": sector["scene"], "dressing_scene": f"res://scenes/complex_v3_blockout/set_dressing/sectors/{sector_id.lower().replace('-', '_')}_dressing.tscn", "placements": placements})
    return {"schema_version": "1.0", "source": "HANDOFF-GEOMETRY-01", "sector_count": len(sectors), "sectors": sectors}


def render_scene(sector: dict) -> str:
    paths = sorted({placement["scene"] for placement in sector["placements"]})
    ids = {path: str(index + 1) for index, path in enumerate(paths)}
    lines = [f"[gd_scene load_steps={len(paths) + 1} format=3]", ""]
    for path in paths:
        lines.append(f'[ext_resource type="PackedScene" path="{path}" id="{ids[path]}"]')
    lines += ["", f'[node name="{safe_name(sector["sector_id"])}_SetDressing" type="Node3D"]', f'metadata/sector_id = "{sector["sector_id"]}"', f'metadata/material_family = "{sector["family"]}"']
    for index, placement in enumerate(sector["placements"]):
        name = safe_name(f"{index + 1:03d}_{placement['id']}")
        x, y, z = placement["position"]
        lines += ["", f'[node name="{name}" parent="." instance=ExtResource("{ids[placement["scene"]]}")]', f"position = Vector3({x:.4f}, {y:.4f}, {z:.4f})"]
        if abs(float(placement["rotation_y"])) > 0.0001:
            lines.append(f"rotation = Vector3(0, {float(placement['rotation_y']):.7f}, 0)")
        if "scale" in placement:
            sx, sy, sz = placement["scale"]
            lines.append(f"scale = Vector3({sx:.5f}, {sy:.5f}, {sz:.5f})")
        lines.append(f'metadata/placement_id = "{placement["id"]}"')
        if placement["kind"] == "open_portal_frame":
            lines.append("metadata/open_passage = true")
    return "\n".join(lines) + "\n"


def attach_to_zone(zone_path: Path, dressing_res: str) -> None:
    text = zone_path.read_text(encoding="utf-8")
    if dressing_res in text and 'name="SetDressing"' in text:
        return
    text = re.sub(r'\n\[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/set_dressing/[^\n]+\n', "\n", text)
    text = re.sub(r'\n\[node name="SetDressing" parent="AuthoredContent" instance=ExtResource\("2_dressing"\)\]\n?', "\n", text)
    text = re.sub(r"\[gd_scene load_steps=\d+ format=3\]", "[gd_scene load_steps=3 format=3]", text, count=1)
    marker = '[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/complex_v3_zone.tscn" id="1_zone"]'
    addition = marker + f'\n[ext_resource type="PackedScene" path="{dressing_res}" id="2_dressing"]'
    text = text.replace(marker, addition)
    text = text.rstrip() + '\n\n[node name="SetDressing" parent="AuthoredContent" instance=ExtResource("2_dressing")]\n'
    zone_path.write_text(text, encoding="utf-8", newline="\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate complex-v3 set dressing.")
    parser.add_argument(
        "--sector-id",
        action="append",
        dest="sector_ids",
        help="Regenerate only this sector; may be repeated. The existing manifest entries for all other sectors are preserved.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generated_manifest = make_manifest()
    selected = set(args.sector_ids or [])
    if selected:
        known = {sector["sector_id"] for sector in generated_manifest["sectors"]}
        unknown = sorted(selected - known)
        if unknown:
            raise SystemExit(f"Unknown sector ids: {', '.join(unknown)}")
        existing = json.loads(MANIFEST.read_text(encoding="utf-8"))
        replacements = {
            sector["sector_id"]: sector
            for sector in generated_manifest["sectors"]
            if sector["sector_id"] in selected
        }
        manifest = existing
        manifest["sectors"] = [replacements.get(sector["sector_id"], sector) for sector in existing["sectors"]]
        sectors_to_write = [sector for sector in manifest["sectors"] if sector["sector_id"] in selected]
    else:
        manifest = generated_manifest
        sectors_to_write = manifest["sectors"]
    sector_dir = OUTPUT / "sectors"
    sector_dir.mkdir(parents=True, exist_ok=True)
    for sector in sectors_to_write:
        scene_path = ROOT / sector["dressing_scene"].removeprefix("res://")
        scene_path.write_text(render_scene(sector), encoding="utf-8", newline="\n")
        attach_to_zone(ROOT / sector["zone_scene"].removeprefix("res://"), sector["dressing_scene"])
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    prop_count = sum(sum(p["kind"] == "prop" for p in s["placements"]) for s in manifest["sectors"])
    frame_count = sum(sum(p["kind"] == "open_portal_frame" for p in s["placements"]) for s in manifest["sectors"])
    print(f"Generated {len(sectors_to_write)} sector dressing scenes; manifest totals: {prop_count} props, {frame_count} open portal frames")


if __name__ == "__main__":
    main()
