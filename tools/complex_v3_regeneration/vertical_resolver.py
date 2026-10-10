"""Derive vertical (stair) generator geometry from SVG markup.

The SVG plans are the source of truth for the shaft footprint, the entry and exit doors and the
level heights. A manifest vertical generator with ``"source": "svg"`` keeps only non-geometric
choices; this module computes the generator arguments and the ``local_to_world`` transform.
Markup contract: docs/design/complex_v3/regeneration/vertical-markup.md
"""

from __future__ import annotations

import copy
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

BOUNDARY_TOLERANCE_M = 0.25
FOOTPRINT_TOLERANCE_M = 0.001
WIDTH_TOLERANCE_M = 0.01
DEFAULT_CLEARANCE_M = 0.01
OPENING_TYPES = {"floor-opening", "ceiling-opening"}
SIDES = {"north", "east", "south", "west"}
# The project maps generator-local axes to world axes by a 180 degree turn about Y:
# local north (+z) is world north (-z), local east (+x) is world west (-x).
LOCAL_SIDE = {"north": "north", "south": "south", "east": "west", "west": "east"}
# Unit step from a boundary side into the shaft, as (dx, dz) in world axes (+z is south).
INWARD = {"north": (0.0, 1.0), "south": (0.0, -1.0), "west": (1.0, 0.0), "east": (-1.0, 0.0)}
ROTATION = {"basis_x": [-1, 0, 0], "basis_y": [0, 1, 0], "basis_z": [0, 0, -1]}
GEOMETRIC_ARGS = {
    "--shaft-width", "--shaft-length", "--floor-height", "--layout", "--stair-width",
    "--lower-entry-side", "--upper-exit-side", "--shaft-wall-bottom", "--shaft-wall-top",
    "--turn-direction", "--invert-z", "--origin", "--no-shaft",
}


class VerticalError(ValueError):
    pass


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _number(element: ET.Element, name: str, label: str) -> float:
    try:
        value = float(element.attrib[name])
    except (KeyError, ValueError) as exc:
        raise VerticalError(f"{label}: attribute {name} is missing or not a number") from exc
    if not math.isfinite(value):
        raise VerticalError(f"{label}: attribute {name} is not finite")
    return value


def _format(value: float) -> str:
    return f"{round(value, 6):g}"


def read_markup(svg_path: Path, vertical_id: str) -> dict[str, list[dict[str, Any]]]:
    """Return the shaft rectangles and entry/exit doors marked for one vertical in an SVG."""
    root = ET.parse(svg_path).getroot()
    shafts: list[dict[str, Any]] = []
    doors: list[dict[str, Any]] = []
    for element in root.iter():
        if element.attrib.get("data-vertical-id") != vertical_id:
            continue
        element_id = element.attrib.get("id", "?")
        label = f"{svg_path.name}#{element_id}"
        role = element.attrib.get("data-vertical-role")
        kind = element.attrib.get("data-godot-type")
        tag = _local_name(element.tag)
        if role == "shaft":
            if tag != "rect" or kind not in OPENING_TYPES:
                raise VerticalError(f"{label}: a shaft must be a rect typed floor-opening or ceiling-opening")
            x, z = _number(element, "x", label), _number(element, "y", label)
            width, depth = _number(element, "width", label), _number(element, "height", label)
            if width <= 0 or depth <= 0:
                raise VerticalError(f"{label}: shaft size must be positive")
            shafts.append({"id": element_id, "kind": kind, "rect": (x, z, x + width, z + depth)})
        elif role in {"entry", "exit"}:
            if tag != "line" or kind != "door":
                raise VerticalError(f"{label}: an {role} must be a line typed door")
            doors.append({
                "id": element_id, "role": role,
                "line": (_number(element, "x1", label), _number(element, "y1", label), _number(element, "x2", label), _number(element, "y2", label)),
            })
        else:
            raise VerticalError(f"{label}: data-vertical-role must be shaft, entry or exit")
    return {"shafts": shafts, "doors": doors}


def _single(items: list[dict[str, Any]], what: str, svg_name: str) -> dict[str, Any]:
    if len(items) != 1:
        raise VerticalError(f"{svg_name}: expected exactly one {what}, found {len(items)}")
    return items[0]


def door_side(door: dict[str, Any], rect: tuple[float, float, float, float]) -> tuple[str, float]:
    """Return the shaft side a door line lies on and the door width."""
    x0, z0, x1, z1 = rect
    ax, ay, bx, by = door["line"]
    if abs(ay - by) < 1e-6 and min(ax, bx) >= x0 - BOUNDARY_TOLERANCE_M and max(ax, bx) <= x1 + BOUNDARY_TOLERANCE_M:
        if abs(ay - z0) <= BOUNDARY_TOLERANCE_M:
            return "north", abs(bx - ax)
        if abs(ay - z1) <= BOUNDARY_TOLERANCE_M:
            return "south", abs(bx - ax)
    if abs(ax - bx) < 1e-6 and min(ay, by) >= z0 - BOUNDARY_TOLERANCE_M and max(ay, by) <= z1 + BOUNDARY_TOLERANCE_M:
        if abs(ax - x0) <= BOUNDARY_TOLERANCE_M:
            return "west", abs(by - ay)
        if abs(ax - x1) <= BOUNDARY_TOLERANCE_M:
            return "east", abs(by - ay)
    raise VerticalError(f"door {door['id']} does not lie on a side of the shaft {tuple(round(v, 3) for v in rect)}")


def _sector(sectors: dict[str, dict[str, Any]], sector_id: str, vertical_id: str) -> dict[str, Any]:
    if sector_id not in sectors:
        raise VerticalError(f"{vertical_id}: unknown sector {sector_id}")
    return sectors[sector_id]


def _shared_value(sector: dict[str, Any], flag: str) -> float:
    arguments = sector.get("shared_args", [])
    if flag not in arguments or arguments.index(flag) + 1 >= len(arguments):
        raise VerticalError(f"sector {sector['sector_id']} has no {flag} in shared_args")
    return float(arguments[arguments.index(flag) + 1])


def resolve_stair(entry: dict[str, Any], sectors: dict[str, dict[str, Any]], project_root: Path) -> dict[str, Any]:
    vertical_id = str(entry.get("vertical_id", ""))
    if not vertical_id:
        raise VerticalError("a vertical generator with source=svg requires vertical_id")
    levels = entry.get("levels", {})
    upper = _sector(sectors, str(levels.get("upper", {}).get("sector_id", "")), vertical_id)
    lower = _sector(sectors, str(levels.get("lower", {}).get("sector_id", "")), vertical_id)
    fixed = sorted(GEOMETRIC_ARGS.intersection(entry.get("args", [])))
    if fixed:
        raise VerticalError(f"{vertical_id}: {', '.join(fixed)} are derived from the plan and must not be set in args")
    upper_name, lower_name = Path(upper["source_svg"]).name, Path(lower["source_svg"]).name
    upper_markup = read_markup(project_root / upper["source_svg"], vertical_id)
    lower_markup = read_markup(project_root / lower["source_svg"], vertical_id)
    upper_rect = _single(upper_markup["shafts"], "shaft opening", upper_name)["rect"]
    lower_rect = _single(lower_markup["shafts"], "shaft opening", lower_name)["rect"]
    if any(abs(a - b) > FOOTPRINT_TOLERANCE_M for a, b in zip(upper_rect, lower_rect)):
        raise VerticalError(
            f"{vertical_id}: shaft footprints differ between levels: {upper_name} {tuple(round(v, 3) for v in upper_rect)} "
            f"vs {lower_name} {tuple(round(v, 3) for v in lower_rect)}"
        )
    exit_door = _single([d for d in upper_markup["doors"] if d["role"] == "exit"], "exit door", upper_name)
    entry_door = _single([d for d in lower_markup["doors"] if d["role"] == "entry"], "entry door", lower_name)
    exit_side, exit_width = door_side(exit_door, upper_rect)
    entry_side, entry_width = door_side(entry_door, upper_rect)
    if abs(exit_width - entry_width) > WIDTH_TOLERANCE_M:
        raise VerticalError(f"{vertical_id}: entry door is {entry_width:.3f} m wide but exit door is {exit_width:.3f} m; they must match")
    if exit_side == entry_side:
        layout = "u-turn"
    elif exit_side == {"north": "south", "south": "north", "east": "west", "west": "east"}[entry_side]:
        layout = "straight"
    else:
        layout = "l-turn"
    lower_y = float(lower["metric_settings"]["elevation_m"])
    upper_y = float(upper["metric_settings"]["elevation_m"])
    floor_height = upper_y - lower_y
    if floor_height <= 0:
        raise VerticalError(f"{vertical_id}: the upper level must be above the lower level")
    bottom = _shared_value(lower, "--wall-height") + _shared_value(lower, "--ceiling-thickness")
    if bottom >= floor_height:
        raise VerticalError(f"{vertical_id}: lower walls plus ceiling ({bottom}) reach the upper floor ({floor_height})")
    clearance = float(entry.get("clearance_m", DEFAULT_CLEARANCE_M))
    x0, z0, x1, z1 = upper_rect
    width, length = x1 - x0, z1 - z0
    if entry_side in {"north", "south"}:
        width -= 2 * clearance
    else:
        length -= 2 * clearance
    dx, dz = INWARD[entry_side]
    centre = ((x0 + x1) / 2 + dx * clearance, (z0 + z1) / 2 + dz * clearance)
    arguments = [
        "--shaft-width", _format(width), "--shaft-length", _format(length), "--floor-height", _format(floor_height),
        "--layout", layout, "--stair-width", _format(entry_width),
        "--lower-entry-side", LOCAL_SIDE[entry_side], "--upper-exit-side", LOCAL_SIDE[exit_side],
        "--shaft-wall-bottom", _format(bottom), "--shaft-wall-top", _format(floor_height),
        *entry.get("args", []),
    ]
    transform = {"origin": [round(centre[0], 6), lower_y, round(centre[1], 6)], **copy.deepcopy(ROTATION)}
    summary = {
        "vertical_id": vertical_id, "layout": layout, "entry_side": entry_side, "exit_side": exit_side,
        "shaft_m": [round(x1 - x0, 6), round(z1 - z0, 6)], "stair_width_m": round(entry_width, 6),
        "floor_height_m": round(floor_height, 6), "clearance_m": clearance,
    }
    return {"args": arguments, "local_to_world": transform, "summary": summary}


def resolve_sector_verticals(sector: dict[str, Any], manifest: dict[str, Any], project_root: Path) -> dict[str, Any]:
    """Return the sector with every ``source: svg`` vertical generator resolved from the plans."""
    generators = sector.get("vertical_generators", [])
    if not any(isinstance(item, dict) and item.get("source") == "svg" for item in generators):
        return sector
    sectors = {item["sector_id"]: item for item in manifest.get("sectors", []) if isinstance(item, dict) and "sector_id" in item}
    resolved = copy.deepcopy(sector)
    for generator in resolved["vertical_generators"]:
        if generator.get("source") != "svg":
            continue
        result = resolve_stair(generator, sectors, project_root)
        generator["args"] = result["args"]
        generator["local_to_world"] = result["local_to_world"]
        generator["resolved"] = result["summary"]
    return resolved
