#!/usr/bin/env python3
"""Validate the stage-1 metric overview package for Caretaker complex v3."""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict, deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "overview" / "metric-overview.json"
SVG_PATH = ROOT / "overview" / "metric-overview.svg"
TOPOLOGY_PATH = ROOT / "overview" / "topology.json"

EXPECTED_LEVELS = {"LV-U", "LV-L", "LV-T"}
EXPECTED_ANCHORS = {
    "A-MAIN-CORE": {"LV-U", "LV-L", "LV-T"},
    "A-ROUTE-A": {"LV-U", "LV-L"},
    "A-OLD-STAIR": {"LV-L", "LV-T"},
    "A-SERVICE-STAIR": {"LV-L", "LV-T"},
    "A-EAST-STAIR": {"LV-U", "LV-L", "LV-T"},
    "A-FREIGHT-LIFT": {"LV-U", "LV-L", "LV-T"},
    "A-HEAVY-SPINE": {"LV-U", "LV-L", "LV-T"},
}
EXPECTED_SECTORS = {
    "U-EMERGENCY", "U-MEDBAY", "U-ROUTE-A", "U-DOMESTIC", "U-CONTROL",
    "U-CENTRAL-CORE", "U-EAST-SUPPORT", "U-CHAMBER-4", "U-SECURITY",
    "U-CHAMBER-6", "U-FREIGHT", "L-OLD-CORE", "L-CHAMBER-1",
    "L-ARCHIVE-A", "L-OLD-RECEIVING", "L-CHAMBER-2", "L-SLEEP-LAB",
    "L-CHAMBER-3", "L-SERVICE-INTERCHANGE", "L-FREIGHT-SERVICE",
    "L-CENTRAL-CORE", "L-EAST-STAIR", "L-CHAMBER-5", "T-ENERGY",
    "T-WORKSHOP", "T-OLD-ACCESS", "T-EAST-VERTICAL", "T-UTILITIES",
    "T-FREIGHT", "T-CIRCULATION",
}


def unique_ids(items: list[dict], label: str, errors: list[str]) -> set[str]:
    ids = [item.get("id") for item in items]
    missing = [index for index, value in enumerate(ids) if not isinstance(value, str) or not value]
    if missing:
        errors.append(f"{label}: missing id at indices {missing}")
    duplicates = sorted({value for value in ids if ids.count(value) > 1})
    if duplicates:
        errors.append(f"{label}: duplicate ids {duplicates}")
    return {value for value in ids if isinstance(value, str) and value}


def main() -> int:
    errors: list[str] = []
    required_files = [
        ROOT / "production-brief.md",
        ROOT / "production-ledger.md",
        ROOT / "plan-style-contract.md",
        ROOT / "coordinate-system.md",
        DATA_PATH,
        TOPOLOGY_PATH,
        ROOT / "overview" / "topology.md",
        SVG_PATH,
        ROOT / "overview" / "metric-overview.png",
    ]
    for path in required_files:
        if not path.is_file():
            errors.append(f"missing file: {path.relative_to(ROOT)}")

    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors))
        return 1

    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    topology = json.loads(TOPOLOGY_PATH.read_text(encoding="utf-8"))
    svg_text = SVG_PATH.read_text(encoding="utf-8")
    ET.fromstring(svg_text)

    if data.get("units") != "m":
        errors.append("units must be m")
    if data.get("plan_style_id") != "caretaker-style-b-v1":
        errors.append("unexpected plan_style_id")
    if "style=caretaker-style-b-v1" not in svg_text:
        errors.append("SVG metadata does not declare the task-wide style")

    level_ids = unique_ids(data.get("levels", []), "levels", errors)
    if level_ids != EXPECTED_LEVELS:
        errors.append(f"level set mismatch: {sorted(level_ids)}")

    anchor_items = data.get("anchors", [])
    anchor_ids = unique_ids(anchor_items, "anchors", errors)
    if anchor_ids != set(EXPECTED_ANCHORS):
        errors.append(f"anchor set mismatch: {sorted(anchor_ids)}")
    for anchor in anchor_items:
        anchor_id = anchor.get("id")
        if set(anchor.get("levels", [])) != EXPECTED_ANCHORS.get(anchor_id, set()):
            errors.append(f"anchor level coverage mismatch: {anchor_id}")
        tolerance = anchor.get("tolerance")
        if not isinstance(tolerance, (int, float)) or tolerance <= 0:
            errors.append(f"invalid anchor tolerance: {anchor_id}")
        if anchor_id != "A-HEAVY-SPINE":
            position = anchor.get("position_xz")
            if not isinstance(position, list) or len(position) != 2 or not all(isinstance(v, (int, float)) for v in position):
                errors.append(f"invalid XZ position: {anchor_id}")

    sectors = data.get("sector_envelopes", [])
    sector_ids = unique_ids(sectors, "sectors", errors)
    if sector_ids != EXPECTED_SECTORS:
        missing = sorted(EXPECTED_SECTORS - sector_ids)
        extra = sorted(sector_ids - EXPECTED_SECTORS)
        errors.append(f"sector set mismatch: missing={missing}, extra={extra}")
    for sector in sectors:
        if sector.get("level") not in EXPECTED_LEVELS:
            errors.append(f"unknown sector level: {sector.get('id')}")
        bounds = sector.get("bounds_xz")
        if not isinstance(bounds, list) or len(bounds) != 4 or not all(isinstance(v, (int, float)) for v in bounds):
            errors.append(f"invalid sector envelope: {sector.get('id')}")
        elif bounds[0] >= bounds[2] or bounds[1] >= bounds[3]:
            errors.append(f"inverted sector envelope: {sector.get('id')}")

    route_ids = unique_ids(data.get("routes", []), "routes", errors)
    if route_ids != {"R-PAX", "R-TECH", "R-FRT", "R-A", "R-OLD-FRT"}:
        errors.append(f"route set mismatch: {sorted(route_ids)}")

    nodes = topology.get("nodes", [])
    if len(nodes) != len(set(nodes)):
        errors.append("topology has duplicate nodes")
    node_set = set(nodes)
    graph: dict[str, set[str]] = defaultdict(set)
    direct_edges: set[frozenset[str]] = set()
    connection_ids = unique_ids(topology.get("connections", []), "topology connections", errors)
    for connection in topology.get("connections", []):
        source, target = connection.get("from"), connection.get("to")
        if source not in node_set or target not in node_set:
            errors.append(f"topology connection references unknown node: {connection.get('id')}")
            continue
        direct_edges.add(frozenset((source, target)))
        if connection.get("traversable"):
            graph[source].add(target)
            graph[target].add(source)

    def reachable(source: str, target: str) -> bool:
        queue = deque([source])
        visited = {source}
        while queue:
            current = queue.popleft()
            if current == target:
                return True
            for neighbor in graph[current]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        return False

    for path in topology.get("required_paths", []):
        source, target = path.get("from"), path.get("to")
        if source not in node_set or target not in node_set:
            errors.append(f"required path references unknown node: {source} -> {target}")
        elif not reachable(source, target):
            errors.append(f"required path is unreachable: {source} -> {target}")
    for edge in topology.get("forbidden_direct_connections", []):
        source, target = edge.get("from"), edge.get("to")
        if frozenset((source, target)) in direct_edges:
            errors.append(f"forbidden direct connection exists: {source} <-> {target}")

    expected_graph_sectors = EXPECTED_SECTORS - {"T-CIRCULATION"}
    missing_graph_sectors = sorted(expected_graph_sectors - node_set)
    if missing_graph_sectors:
        errors.append(f"topology misses sectors: {missing_graph_sectors}")

    # Cross-artifact identity checks. Short labels in the overview are allowed,
    # but every level and every anchor role must be visibly represented.
    for token in ("LV-U", "LV-L", "LV-T", "MAIN", "OLD", "SERVICE", "EAST", "FREIGHT", "ROUTE A"):
        if token not in svg_text:
            errors.append(f"SVG misses visible token: {token}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} issue(s)")
        return 1

    print(
        "OK: stage-1 package is internally consistent: "
        f"{len(level_ids)} levels, {len(anchor_ids)} anchors, "
        f"{len(sector_ids)} sectors, {len(route_ids)} routes, "
        f"{len(connection_ids)} topology connections"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
