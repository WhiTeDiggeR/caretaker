#!/usr/bin/env python3
"""Read-only shared ownership audit; candidates are not collision proof."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def audit(handoff: dict, vertical: dict) -> dict:
    owners, diagnostics, connectors = [], [], []
    seen = set()
    for item in handoff["route_spaces"] + handoff["connection_corridors"] + handoff["controlled_technical_transitions"]:
        identity = item["id"]
        if identity in seen:
            diagnostics.append({"code":"duplicate_shared_source_id", "source_id":identity, "severity":"blocking"})
        seen.add(identity)
        owners.append({"source_id":identity, "owner":"complex_v3_infrastructure", "ownership":"generated", "authored_sector_copy_allowed":False})
    for corridor in handoff["connection_corridors"]:
        points = corridor["centerline_xz"]
        portals = [p["id"] for p in handoff["external_portals"] if p["connection_id"] == corridor["connection_id"]]
        zero = all(p == points[0] for p in points)
        connectors.append({"source_id":corridor["id"], "connection_id":corridor["connection_id"], "zero_length":zero, "portal_source_refs":sorted(portals), "frame_policy":"alias_explicit_portal_frames" if zero else "derive_endpoint_frames_from_directed_centerline", "geometry_policy":"no_corridor_prism" if zero else "shared_only", "state":corridor["state"], "traversable":corridor["traversable"]})
        if zero and not portals:
            diagnostics.append({"code":"zero_length_connector_without_explicit_portal", "source_id":corridor["id"], "severity":"blocking"})
    verticals = []
    for transition in vertical["transitions"]:
        identity = transition["id"]
        policy = "reuse_integrated_pilot" if identity == "VT-ROUTE-A" else "pending_geometry_and_combined_validation"
        missing = []
        if "stair" in transition["kind"] and identity != "VT-ROUTE-A":
            for key in ("lower_entry_side", "upper_exit_side"):
                if key not in transition:
                    missing.append(key)
            if missing:
                diagnostics.append({"code":"explicit_stair_port_orientation_missing", "source_id":identity, "severity":"blocking", "missing_fields":missing, "action":"resolve_from_explicit_portal_geometry_or_reviewed_config; never_guess"})
        if "elevator" in transition["kind"]:
            diagnostics.append({"code":"lift_threshold_mapping_pending", "source_id":identity, "severity":"blocking", "action":"map_each_stop_to_exact_portal; do_not_create_stop_on_pass_through_level"})
        verticals.append({"source_id":identity, "owner":"route_a_vertical_pilot" if identity == "VT-ROUTE-A" else "complex_v3_infrastructure", "policy":policy, "shaft_bounds_xz":transition.get("shaft_bounds_xz"), "clear_opening_bounds_xz":transition.get("clear_opening_bounds_xz"), "missing_explicit_port_fields":missing})
    candidates = []
    sector_levels = {s["id"]:s["level"] for s in handoff["sectors"]}
    for route in handoff["route_spaces"]:
        for space in handoff["spaces"]:
            if sector_levels[space["sector_id"]] != route["level"]:
                continue
            a, b = route["bounds_xz"], space["bounds_xz"]
            dx, dz = min(a[2],b[2])-max(a[0],b[0]), min(a[3],b[3])-max(a[1],b[1])
            if dx > 1e-6 and dz > 1e-6:
                candidates.append({"shared_source_id":route["id"], "sector_space_id":space["id"], "overlap_area_m2":round(dx*dz,6), "classification":"bounds_candidate_not_collision_proof", "action":"clip_or_single_owner_union_before_combined_assembly"})
    return {"schema_id":"caretaker.shared_regeneration_input_audit", "schema_version":"1.0.0", "map_id":handoff["map_id"], "status":"not_ready_for_combined_assembly", "geometry_generated":False, "startup_modified":False, "owners":sorted(owners,key=lambda x:x["source_id"]), "connectors":sorted(connectors,key=lambda x:x["source_id"]), "verticals":sorted(verticals,key=lambda x:x["source_id"]), "sector_shared_bounds_candidates":candidates, "diagnostics":diagnostics, "combined_collision_verification":"not_run"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    handoff = json.loads((ROOT/"docs/design/complex_v3/handoff/geometry/complex-handoff.json").read_text(encoding="utf-8"))
    vertical = json.loads((ROOT/"docs/design/complex_v3/handoff/vertical/vertical-transitions.json").read_text(encoding="utf-8"))
    report = audit(handoff, vertical)
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
    print(f"AUDIT_ONLY owners={len(report['owners'])} connectors={len(report['connectors'])} verticals={len(report['verticals'])} bounds_candidates={len(report['sector_shared_bounds_candidates'])} pending_diagnostics={len(report['diagnostics'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
