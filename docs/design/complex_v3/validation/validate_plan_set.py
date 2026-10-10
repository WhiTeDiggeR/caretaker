#!/usr/bin/env python3
"""Validate the complete complex-v3 plan set and cross-level shaft contract."""

from __future__ import annotations

import argparse
import html
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "docs/design/complex_v3"
PASSPORT_PATH = PACKAGE / "handoff/passports/sector-passports.json"
TOPOLOGY_PATH = PACKAGE / "handoff/overview/topology.json"
VERTICAL_PATH = PACKAGE / "handoff/vertical/vertical-transitions.json"
GEOMETRY_PATH = PACKAGE / "handoff/geometry/complex-handoff.json"
REPORT_PATH = PACKAGE / "validation/plan-set-audit.md"
SVG_NS = "{http://www.w3.org/2000/svg}"
SHAPES = {"rect", "line", "path", "polygon", "polyline", "circle", "ellipse", "text"}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def values(value: str) -> list[float]:
    return [float(item) for item in value.split(",") if item]


def same(a: list[float], b: list[float], tolerance: float = 1e-6) -> bool:
    return len(a) == len(b) and all(math.isclose(x, y, abs_tol=tolerance) for x, y in zip(a, b))


def contains(bounds: list[float], position: list[float], tolerance: float = 0.25) -> bool:
    x0, z0, x1, z1 = bounds
    x, z = position
    return x0 - tolerance <= x <= x1 + tolerance and z0 - tolerance <= z <= z1 + tolerance


def shared_boundary_overlap(a: list[float], b: list[float], tolerance: float = 1e-6) -> bool:
    x_overlap = min(a[2], b[2]) - max(a[0], b[0])
    z_overlap = min(a[3], b[3]) - max(a[1], b[1])
    vertical = z_overlap > tolerance and (
        math.isclose(a[2], b[0], abs_tol=tolerance) or math.isclose(b[2], a[0], abs_tol=tolerance)
    )
    horizontal = x_overlap > tolerance and (
        math.isclose(a[3], b[1], abs_tol=tolerance) or math.isclose(b[3], a[1], abs_tol=tolerance)
    )
    return vertical or horizontal


def wall_edges(area: dict) -> list[tuple[str, float, float, float, float, str]]:
    x0, z0, x1, z1 = area["bounds_xz"]
    thickness = float(area["wall_thickness"])
    owner = str(area["id"])
    return [
        ("horizontal", z0, x0, x1, thickness, owner),
        ("horizontal", z1, x0, x1, thickness, owner),
        ("vertical", x0, z0, z1, thickness, owner),
        ("vertical", x1, z0, z1, thickness, owner),
    ]


def mixed_thickness_wall_overlap(a: tuple, b: tuple, tolerance: float = 1e-6) -> bool:
    axis_a, fixed_a, start_a, end_a, thickness_a, _ = a
    axis_b, fixed_b, start_b, end_b, thickness_b, _ = b
    if math.isclose(thickness_a, thickness_b, abs_tol=tolerance):
        return False
    if axis_a == axis_b:
        longitudinal = min(end_a, end_b) - max(start_a, start_b)
        transverse = (thickness_a + thickness_b) * 0.5 - abs(fixed_a - fixed_b)
        return longitudinal > tolerance and transverse > tolerance
    horizontal, vertical = (a, b) if axis_a == "horizontal" else (b, a)
    _, horizontal_z, horizontal_x0, horizontal_x1, horizontal_thickness, _ = horizontal
    _, vertical_x, vertical_z0, vertical_z1, vertical_thickness, _ = vertical
    x_overlap = min(horizontal_x1, vertical_x + vertical_thickness * 0.5) - max(horizontal_x0, vertical_x - vertical_thickness * 0.5)
    z_overlap = min(horizontal_z + horizontal_thickness * 0.5, vertical_z1) - max(horizontal_z - horizontal_thickness * 0.5, vertical_z0)
    return x_overlap > tolerance and z_overlap > tolerance


def parse_plan(path: Path, errors: list[str]) -> tuple[ET.Element | None, dict]:
    try:
        root = ET.parse(path).getroot()
    except Exception as exc:
        fail(errors, f"{path.relative_to(ROOT)}: invalid SVG: {exc}")
        return None, {}
    if root.tag != f"{SVG_NS}svg":
        fail(errors, f"{path.relative_to(ROOT)}: root is not SVG")
    for attribute in ("viewBox", "data-scale", "data-grid-size", "data-plan-style-id"):
        if not root.get(attribute):
            fail(errors, f"{path.relative_to(ROOT)}: missing {attribute}")
    if root.get("data-plan-style-id") != "caretaker-style-b-v1":
        fail(errors, f"{path.relative_to(ROOT)}: inconsistent plan style")
    if root.get("data-semantic-layer-contract") != "per-object-v1":
        fail(errors, f"{path.relative_to(ROOT)}: semantic object layers are not declared")
    ids: set[str] = set()
    layers = 0
    parents = {child: parent for parent in root.iter() for child in parent}
    for element in root.iter():
        element_id = element.get("id")
        if element_id:
            if element_id in ids:
                fail(errors, f"{path.relative_to(ROOT)}: duplicate id {element_id}")
            ids.add(element_id)
        tag = element.tag.removeprefix(SVG_NS)
        if tag == "g" and element.get("data-layer"):
            layers += 1
        if tag in SHAPES:
            if not element_id:
                fail(errors, f"{path.relative_to(ROOT)}: editable {tag} has no id")
            if not (element.get("class") or element.get("data-kind")):
                fail(errors, f"{path.relative_to(ROOT)}: {element_id or tag} has no semantics")
            parent = parents.get(element)
            if parent is None or parent.tag != f"{SVG_NS}g" or parent.get("data-layer") not in {
                "rooms", "walls", "openings", "equipment", "labels", "annotations"
            }:
                fail(errors, f"{path.relative_to(ROOT)}: {element_id or tag} is not in a semantic object layer")
    if not layers:
        fail(errors, f"{path.relative_to(ROOT)}: no semantic layer")
    if not any(element.tag == f"{SVG_NS}style" and element.get("id") == "plan-render-fallback" for element in root.iter()):
        fail(errors, f"{path.relative_to(ROOT)}: concrete Style B fallback is missing")
    metadata: dict = {}
    for element in root.findall(f".//{SVG_NS}metadata"):
        if (element.get("id") or "").endswith("-metadata"):
            try:
                metadata = json.loads(html.unescape(element.text or ""))
            except Exception as exc:
                fail(errors, f"{path.relative_to(ROOT)}: invalid plan metadata: {exc}")
            break
    return root, metadata


def validate_viewer(svg: Path, errors: list[str]) -> None:
    viewer = svg.with_suffix(".html")
    if not viewer.exists():
        fail(errors, f"{svg.relative_to(ROOT)}: sibling viewer missing")
        return
    text = viewer.read_text(encoding="utf-8")
    if f'name="map-viewer-source" content="{svg.name}"' not in text:
        fail(errors, f"{viewer.relative_to(ROOT)}: source marker mismatch")
    if re.search(r"<svg\b", text, re.I):
        fail(errors, f"{viewer.relative_to(ROOT)}: viewer duplicates SVG markup")
    if "Content-Security-Policy" not in text or "sandbox" not in text:
        fail(errors, f"{viewer.relative_to(ROOT)}: viewer lacks CSP or sandbox")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()
    errors: list[str] = []
    passports = json.loads(PASSPORT_PATH.read_text(encoding="utf-8"))["passports"]
    topology = json.loads(TOPOLOGY_PATH.read_text(encoding="utf-8"))
    vertical = json.loads(VERTICAL_PATH.read_text(encoding="utf-8"))
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    transition_by_id = {item["id"]: item for item in vertical["transitions"]}
    metadata_by_sector: dict[str, dict] = {}

    overview_svgs = sorted((PACKAGE / "plans/overview").glob("*/current/*.svg"))
    if len(overview_svgs) != 3:
        fail(errors, f"expected 3 overview SVG plans, found {len(overview_svgs)}")
    for source in overview_svgs:
        parse_plan(source, errors)
        validate_viewer(source, errors)

    for passport in passports:
        source = (PASSPORT_PATH.parent / passport["source_detail"]).resolve()
        if source.suffix.lower() != ".svg" or not source.exists():
            fail(errors, f"{passport['sector_id']}: canonical SVG source missing: {passport['source_detail']}")
            continue
        root, metadata = parse_plan(source, errors)
        validate_viewer(source, errors)
        if root is None:
            continue
        sector_id = passport["sector_id"]
        metadata_by_sector[sector_id] = metadata
        if root.get("data-sector-id") != sector_id or metadata.get("sector_id") != sector_id:
            fail(errors, f"{sector_id}: sector identity mismatch")
        if root.get("data-level") != passport["level"] or metadata.get("level") != passport["level"]:
            fail(errors, f"{sector_id}: level mismatch")
        if not same(values(root.get("data-parent-bounds-xz", "")), passport["parent_boundary_xz"]):
            fail(errors, f"{sector_id}: parent boundary differs from overview passport")
        if metadata.get("parent_boundary_xz") != passport["parent_boundary_xz"]:
            fail(errors, f"{sector_id}: embedded parent boundary differs from passport")
        if sorted(metadata.get("neighbors", [])) != sorted(passport.get("neighbors", [])):
            fail(errors, f"{sector_id}: neighbor list differs from passport")

    # Every graph adjacency must be reciprocal in the two detailed passports.
    passports_by_id = {item["sector_id"]: item for item in passports}
    for edge in topology["connections"]:
        a, b = edge["from"], edge["to"]
        if a in passports_by_id and b in passports_by_id:
            if b not in passports_by_id[a]["neighbors"] or a not in passports_by_id[b]["neighbors"]:
                fail(errors, f"{edge['id']}: detail adjacency is not reciprocal")

    # A shaft/opening is one immutable XZ footprint shared by all endpoint plans.
    for transition in vertical["transitions"]:
        if transition["kind"] == "historic_inclined_freight_tunnel":
            continue
        shaft = transition.get("shaft_bounds_xz")
        opening = transition.get("clear_opening_bounds_xz")
        if not shaft or not opening or len(shaft) != 4 or len(opening) != 4:
            fail(errors, f"{transition['id']}: missing fixed shaft/opening bounds")
            continue
        if not (shaft[0] < opening[0] < opening[2] < shaft[2] and shaft[1] < opening[1] < opening[3] < shaft[3]):
            fail(errors, f"{transition['id']}: clear opening is not inside shaft footprint")
        position = transition.get("center_xz")
        if position and not contains(opening, position, 0.0):
            fail(errors, f"{transition['id']}: center lies outside clear opening")

    for sector_id, metadata in metadata_by_sector.items():
        for record in metadata.get("vertical_transitions", []):
            authoritative = transition_by_id.get(record["id"])
            if not authoritative:
                fail(errors, f"{sector_id}: unknown transition {record['id']}")
                continue
            for field in ("shaft_bounds_xz", "clear_opening_bounds_xz"):
                if record.get(field) != authoritative.get(field):
                    fail(errors, f"{sector_id}: {record['id']} {field} differs between levels")

    physical_routes = [item for item in geometry["route_spaces"] if item["kind"] != "cable_gallery"]
    physical_areas = geometry["spaces"] + physical_routes
    shared_area_boundaries = 0
    for index, a in enumerate(physical_areas):
        for b in physical_areas[index + 1:]:
            if a["floor_y"] != b["floor_y"] or not shared_boundary_overlap(a["bounds_xz"], b["bounds_xz"]):
                continue
            shared_area_boundaries += 1
            if not math.isclose(float(a["wall_thickness"]), float(b["wall_thickness"]), abs_tol=1e-6):
                fail(errors, f"shared wall thickness mismatch: {a['id']} <> {b['id']}")
    wall_defaults = geometry.get("wall_defaults", {})
    if wall_defaults.get("shared_boundary_policy") != "canonical-centerline-single-thickness":
        fail(errors, "metric handoff does not declare canonical shared wall centerlines")
    if wall_defaults.get("junction_policy") != "butt-no-positive-overlap":
        fail(errors, "metric handoff does not require non-overlapping butt wall joints")

    mixed_thickness_overlaps: set[tuple[str, str]] = set()
    edges_by_floor: dict[float, list[tuple]] = {}
    for area in physical_areas:
        edges_by_floor.setdefault(float(area["floor_y"]), []).extend(wall_edges(area))
    for edges in edges_by_floor.values():
        for index, edge_a in enumerate(edges):
            for edge_b in edges[index + 1:]:
                owner_a, owner_b = edge_a[5], edge_b[5]
                if owner_a == owner_b or not mixed_thickness_wall_overlap(edge_a, edge_b):
                    continue
                mixed_thickness_overlaps.add(tuple(sorted((owner_a, owner_b))))
    for owner_a, owner_b in sorted(mixed_thickness_overlaps):
        fail(errors, f"mixed-thickness wall solids overlap: {owner_a} <> {owner_b}")

    # Route A has explicit slab openings because these two plans are already
    # being prepared for direct SVG-to-Godot conversion.
    opening_checks = {
        "U-ROUTE-A": ("route-a-stair-floor-opening", "floor-opening"),
        "L-ARCHIVE-A": ("route-a-stair-ceiling-opening", "ceiling-opening"),
        "L-OLD-CORE": ("old-stair-lower-floor-opening", "floor-opening"),
        "T-OLD-ACCESS": ("old-stair-technical-ceiling-opening", "ceiling-opening"),
    }
    for sector_id, (element_id, godot_type) in opening_checks.items():
        source = (PASSPORT_PATH.parent / passports_by_id[sector_id]["source_detail"]).resolve()
        root = ET.parse(source).getroot()
        found = next((e for e in root.iter() if e.get("id") == element_id), None)
        if found is None or found.get("data-godot-type") != godot_type:
            fail(errors, f"{sector_id}: explicit vertical slab opening is missing")

    status = "PASS" if not errors else "FAIL"
    if args.write_report:
        transition_rows = "\n".join(
            f"| {item['id']} | {item.get('anchor', '—')} | {item.get('shaft_bounds_xz', '—')} | {item.get('clear_opening_bounds_xz', '—')} |"
            for item in vertical["transitions"]
            if item["kind"] != "historic_inclined_freight_tunnel"
        )
        report = f"""# Complex v3 plan-set audit

Status: **{status}**

- Canonical plan pairs: {len(overview_svgs) + len(passports)} (3 overview + {len(passports)} detailed).
- Plan style: `caretaker-style-b-v1` throughout.
- Topology connections checked: {len(topology['connections'])}.
- Sector passports checked: {len(passports)}.
- Geometry policy: approved drawing geometry preserved; metric handoff controls shared anchors and shafts.
- Physical area boundaries checked: {len(physical_areas)} areas, {shared_area_boundaries} exact shared centerlines, one thickness per common wall.
- Wall solids checked: {len(mixed_thickness_overlaps)} mixed-thickness overlaps; junction policy is trimmed butt contact.

## Fixed vertical footprints

| Transition | Anchor | Outer shaft XZ, m | Clear opening XZ, m |
|---|---|---|---|
{transition_rows}

## Result

{('No contradictions detected.' if not errors else chr(10).join('- ' + error for error in errors))}
"""
        REPORT_PATH.write_text(report, encoding="utf-8")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)
    print(f"OK: {len(overview_svgs) + len(passports)} plan pairs, {len(topology['connections'])} adjacencies, and {len(transition_by_id) - 1} vertical shafts are consistent")


if __name__ == "__main__":
    main()
