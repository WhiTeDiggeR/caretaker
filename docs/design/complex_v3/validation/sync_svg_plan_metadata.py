#!/usr/bin/env python3
"""Synchronize canonical plan metadata with passports and vertical handoff."""

from __future__ import annotations

import html
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "docs/design/complex_v3"
PASSPORT_PATH = PACKAGE / "handoff/passports/sector-passports.json"
TOPOLOGY_PATH = PACKAGE / "handoff/overview/topology.json"
VERTICAL_PATH = PACKAGE / "handoff/vertical/vertical-transitions.json"


def encode(values: list[float] | list[str]) -> str:
    return ",".join(map(str, values))


def replace_root_attribute(svg: str, name: str, value: str) -> str:
    root_end = svg.find(">")
    root = svg[:root_end]
    escaped = html.escape(value, quote=True)
    pattern = re.compile(rf'(\b{re.escape(name)}\s*=\s*)["\'][^"\']*["\']')
    if pattern.search(root):
        root = pattern.sub(rf'\1"{escaped}"', root, count=1)
    else:
        root += f' {name}="{escaped}"'
    return root + svg[root_end:]


def transition_map(passports: list[dict], topology: dict, vertical: dict) -> dict[str, list[dict]]:
    by_edge: dict[str, list[str]] = {}
    for transition in vertical["transitions"]:
        for edge_id in transition.get("represents_connections", []):
            by_edge.setdefault(edge_id, []).append(transition["id"])
    transitions = {item["id"]: item for item in vertical["transitions"]}
    result: dict[str, list[dict]] = {item["sector_id"]: [] for item in passports}
    for edge in topology["connections"]:
        for transition_id in by_edge.get(edge["id"], []):
            transition = transitions[transition_id]
            for sector_id in (edge["from"], edge["to"]):
                if sector_id in result and transition not in result[sector_id]:
                    result[sector_id].append(transition)
    # The main stair shares the main-core footprint but is not a separate graph edge.
    main_stair = transitions["VT-MAIN-STAIR"]
    for sector_id in ("U-CENTRAL-CORE", "L-CENTRAL-CORE"):
        result[sector_id].append(main_stair)
    return result


def update_embedded_metadata(svg: str, passport: dict, transitions: list[dict]) -> str:
    pattern = re.compile(r'(<metadata\b[^>]*-metadata[^>]*>)([\s\S]*?)(</metadata>)', re.I)
    match = pattern.search(svg)
    if not match:
        raise ValueError(f"plan metadata block missing for {passport['sector_id']}")
    payload = json.loads(html.unescape(match.group(2)))
    payload.update(
        {
            "sector_id": passport["sector_id"],
            "level": passport["level"],
            "parent_boundary_xz": passport["parent_boundary_xz"],
            "local_origin_xyz": passport["local_origin_xyz"],
            "anchors": passport.get("anchors", []),
            "neighbors": passport.get("neighbors", []),
            "source_detail": passport["source_detail"],
            "vertical_transitions": [
                {
                    key: transition[key]
                    for key in (
                        "id",
                        "anchor",
                        "kind",
                        "shaft_bounds_xz",
                        "clear_opening_bounds_xz",
                        "connects",
                        "stops",
                        "pass_through",
                    )
                    if key in transition
                }
                for transition in transitions
            ],
        }
    )
    encoded = html.escape(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return svg[: match.start()] + match.group(1) + encoded + match.group(3) + svg[match.end() :]


def main() -> None:
    passports = json.loads(PASSPORT_PATH.read_text(encoding="utf-8"))["passports"]
    topology = json.loads(TOPOLOGY_PATH.read_text(encoding="utf-8"))
    vertical = json.loads(VERTICAL_PATH.read_text(encoding="utf-8"))
    by_sector = transition_map(passports, topology, vertical)
    for passport in passports:
        source = (PASSPORT_PATH.parent / passport["source_detail"]).resolve()
        svg = source.read_text(encoding="utf-8")
        transitions = by_sector[passport["sector_id"]]
        svg = replace_root_attribute(svg, "data-sector-id", passport["sector_id"])
        svg = replace_root_attribute(svg, "data-level", passport["level"])
        svg = replace_root_attribute(svg, "data-parent-bounds-xz", encode(passport["parent_boundary_xz"]))
        svg = replace_root_attribute(svg, "data-local-origin-xyz", encode(passport["local_origin_xyz"]))
        svg = replace_root_attribute(svg, "data-anchor-ids", encode([a["id"] for a in passport.get("anchors", [])]))
        svg = replace_root_attribute(svg, "data-transition-ids", encode([t["id"] for t in transitions]))
        svg = update_embedded_metadata(svg, passport, transitions)
        source.write_text(svg, encoding="utf-8")
        print(source.relative_to(ROOT))


if __name__ == "__main__":
    main()
