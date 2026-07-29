#!/usr/bin/env python3
"""Generate the portable map-package manifest for complex v3."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def main() -> None:
    overview = load("overview/metric-overview.json")
    topology = load("overview/topology.json")
    envelope_names = {item["id"]: item["name"] for item in overview["sector_envelopes"]}
    route_names = {
        "U-PAX": "Верхняя пассажирская магистраль",
        "L-PAX": "Нижняя пассажирская магистраль",
        "T-TECH": "Техническая служебная магистраль",
        "U-FRT": "Верхняя грузовая магистраль",
        "L-FRT": "Нижняя грузовая магистраль",
        "T-FRT": "Техническая грузовая магистраль",
    }
    spaces = []
    for node_id in topology["nodes"]:
        level = {"U": "LV-U", "L": "LV-L", "T": "LV-T"}[node_id[0]]
        spaces.append({
            "id": node_id,
            "name": envelope_names.get(node_id, route_names.get(node_id, node_id)),
            "layer": level,
        })
    connections = [
        {
            "id": edge["id"],
            "from": edge["from"],
            "to": edge["to"],
            "kind": edge["kind"],
            "bidirectional": True,
            "traversable": edge["traversable"],
            **({"state": edge["state"]} if "state" in edge else {}),
        }
        for edge in topology["connections"]
    ]
    all_nodes = topology["nodes"]
    artifacts = [
        {"id": "overview-metric", "type": "overview", "path": "overview/metric-overview.svg", "preview": "overview/metric-overview.png", "status": "approved", "style_id": "caretaker-style-b-v1", "depends_on": [], "covers": all_nodes},
        {"id": "topology-graph", "type": "graph", "path": "overview/topology.json", "status": "approved", "depends_on": ["overview-metric"], "covers": all_nodes},
        {"id": "sector-passports", "type": "detail", "path": "passports/sector-passports.json", "status": "verified", "style_id": "caretaker-style-b-v1", "depends_on": ["overview-metric", "topology-graph"], "covers": all_nodes},
        {"id": "vertical-section", "type": "section", "path": "vertical/vertical-section.svg", "preview": "vertical/vertical-section.png", "status": "verified", "style_id": "caretaker-style-b-v1", "depends_on": ["overview-metric", "topology-graph"], "covers": all_nodes},
        {"id": "vertical-handoff", "type": "handoff", "path": "vertical/vertical-transitions.json", "status": "verified", "depends_on": ["vertical-section", "topology-graph"], "covers": all_nodes},
        {"id": "geometry-handoff", "type": "handoff", "path": "geometry/complex-handoff.json", "status": "verified", "depends_on": ["sector-passports", "vertical-handoff"], "covers": all_nodes},
        {"id": "validation-stage-2", "type": "validation", "path": "validation/stage-2-report.md", "status": "verified", "depends_on": ["geometry-handoff"], "covers": all_nodes},
        {"id": "package-index", "type": "index", "path": "README.md", "status": "verified", "depends_on": ["validation-stage-2"], "covers": all_nodes},
    ]
    anchors = []
    for anchor in overview["anchors"]:
        position = anchor["position_xz"] if "position_xz" in anchor else [anchor["centerline_z"]]
        anchors.append({
            "id": anchor["id"],
            "tolerance": anchor["tolerance"],
            "occurrences": [
                {"artifact_id": "overview-metric", "position": position},
                {"artifact_id": "vertical-section", "position": position},
                {"artifact_id": "geometry-handoff", "position": position},
            ],
        })
    manifest = {
        "schema_version": "1.0",
        "map_id": overview["map_id"],
        "title": "Caretaker complex v3 implementation handoff",
        "units": "m",
        "coordinate_system": overview["coordinate_system"],
        "plan_style": {
            "id": "caretaker-style-b-v1",
            "name": "opaque-functional-plan",
            "source": "approved project style B",
            "rules": {
                "fills": "opaque functional zoning",
                "geometry": "solid non-overlapping rooms with separate continuous corridors",
                "labels": "minimal direct labels with one hierarchy",
                "symbols": "explicit repeatable portals and vertical anchors",
                "forbidden": "translucent overlaps and decorative door strokes",
            },
        },
        "deliverables_requested": ["overview", "details", "handoff"],
        "spaces": spaces,
        "connections": connections,
        "required_paths": topology["required_paths"],
        "forbidden_connections": topology["forbidden_direct_connections"],
        "artifacts": artifacts,
        "anchors": anchors,
        "validation": {
            "logical": "passed",
            "visual": "passed",
            "cross_artifact": "passed",
            "tested_in_engine": False,
        },
        "approval": {
            "gate_1_overview": "approved",
            "gate_2_handoff": "awaiting_user_approval",
            "gate_3_godot_blockout": "separate_task_after_gate_2",
        },
    }
    (ROOT / "map-package.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"OK: generated manifest with {len(spaces)} graph spaces, {len(connections)} connections and {len(artifacts)} artifacts")


if __name__ == "__main__":
    main()
