"""Verify the isolated U-MEDBAY pilot against the metric handoff and T01 artifacts."""

from __future__ import annotations

import argparse
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


VERSION = "1.0.0"
EPS = 1.0e-6


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} root must be an object")
    return value


def close(first: list[float], second: list[float]) -> bool:
    return len(first) == len(second) and all(math.isclose(float(a), float(b), abs_tol=EPS) for a, b in zip(first, second))


def line_segment(element: ET.Element) -> list[list[float]]:
    return [[float(element.attrib["x1"]), float(element.attrib["y1"])], [float(element.attrib["x2"]), float(element.attrib["y2"])]]


def main() -> int:
    args = parse_args()
    project = args.project_root.resolve()
    pilot = project / "scenes/complex_v3_regeneration/pilots/u_medbay"
    handoff = load_json(project / "docs/design/complex_v3/handoff/geometry/complex-handoff.json")
    anchors = load_json(pilot / "live/anchor_frames.json")
    bindings = load_json(pilot / "AuthoredContent/object_bindings.json")
    composition = load_json(pilot / "AuthoredContent/composition.json")
    root = ET.parse(pilot / "source/u_medbay_pilot.svg").getroot()
    elements = {element.attrib["id"]: element for element in root.iter() if "id" in element.attrib}
    errors: list[str] = []
    checks: list[str] = []

    sector = next((item for item in handoff["sectors"] if item.get("id") == "U-MEDBAY"), None)
    if sector is None or not close(sector["bounds_xz"], [-94, 7, -80, 15]):
        errors.append("handoff sector bounds are missing or changed")
    else:
        checks.append("sector_bounds")

    spaces = {item["id"]: item for item in handoff["spaces"] if item.get("sector_id") == "U-MEDBAY"}
    floors = [element for element in elements.values() if element.attrib.get("data-godot-type") == "floor"]
    if len(floors) != 7 or set(spaces) != {element.attrib.get("data-space-id") for element in floors}:
        errors.append("SVG floor set differs from the seven handoff spaces")
    else:
        for floor in floors:
            bounds = spaces[floor.attrib["data-space-id"]]["bounds_xz"]
            actual = [float(floor.attrib["x"]), float(floor.attrib["y"]), float(floor.attrib["x"]) + float(floor.attrib["width"]), float(floor.attrib["y"]) + float(floor.attrib["height"])]
            if not close(actual, bounds):
                errors.append(f"{floor.attrib['id']} differs from handoff bounds")
        checks.append("seven_space_rectangles")

    portals = {item["id"]: item for item in handoff["internal_portals"] if str(item.get("id", "")).startswith("P-U-MEDBAY-")}
    portals["PX-E-U02A-U-MEDBAY"] = next(item for item in handoff["external_portals"] if item.get("id") == "PX-E-U02A-U-MEDBAY")
    doors = [element for element in elements.values() if element.attrib.get("data-godot-type") == "door"]
    if len(doors) != 7 or set(portals) != {element.attrib.get("data-handoff-id") for element in doors}:
        errors.append("SVG door set differs from the six internal and one external handoff portals")
    else:
        for door in doors:
            portal = portals[door.attrib["data-handoff-id"]]
            if line_segment(door) != portal["segment_xz"]:
                errors.append(f"{door.attrib['id']} segment differs from {portal['id']}")
            if door.attrib.get("data-inside-side") not in {"normal", "opposite"}:
                errors.append(f"{door.attrib['id']} has no explicit inside side")
            if "data-hinge-side" in door.attrib:
                errors.append(f"{door.attrib['id']} invents a hinge side")
        checks.append("seven_portal_segments_and_explicit_sides")

    svg_ids = [element.attrib["id"] for element in root.iter() if "id" in element.attrib]
    if len(svg_ids) != len(set(svg_ids)):
        errors.append("SVG IDs are not unique")
    anchor_items = anchors.get("anchors", [])
    anchor_ids = [item.get("anchor_id") for item in anchor_items]
    if len(anchor_ids) != 45 or len(anchor_ids) != len(set(anchor_ids)):
        errors.append("anchor_frames must contain 45 unique stable IDs")
    if any(":hinge" in str(anchor_id) for anchor_id in anchor_ids):
        errors.append("hinge anchor exists without an explicit hinge side")
    if any((item.get("source_ref") or {}).get("source_id") not in elements for item in anchor_items):
        errors.append("anchor source_ref points outside stable SVG IDs")
    checks.append("stable_svg_and_anchor_ids")

    bound_ids = {item["object_ref"]["object_id"] for item in bindings.get("bindings", [])}
    object_ids = {item["object_id"] for item in composition.get("objects", [])}
    if len(bound_ids) != 3 or len(object_ids) != 4 or not bound_ids < object_ids:
        errors.append("pilot must contain three bound objects and one free object")
    else:
        checks.append("three_bound_one_free")
    if not (project / "docs/design/complex_v3/plans/sectors/upper/u_medbay.svg").is_file():
        errors.append("control U-MEDBAY source is missing")
    else:
        checks.append("control_source_preserved")

    report = {
        "schema_id": "caretaker.u_medbay_pilot_verification",
        "schema_version": "1.0.0",
        "verifier_version": VERSION,
        "status": "passed" if not errors else "blocked",
        "checks": checks,
        "counts": {"spaces": len(floors), "doors": len(doors), "anchors": len(anchor_ids), "bindings": len(bound_ids), "objects": len(object_ids)},
        "errors": errors,
    }
    output = args.output or pilot / "reports/handoff-verification.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{report['status'].upper()}: checks={len(checks)} errors={len(errors)}")
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
