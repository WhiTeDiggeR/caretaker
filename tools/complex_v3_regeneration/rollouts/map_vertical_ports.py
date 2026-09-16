#!/usr/bin/env python3
"""Map explicit portal candidates to shafts without projection or nearest matching."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPACE_REFS = {
    "VT-MAIN-ELEVATOR": {"LV-U":"U-CENTRAL-CORE/passenger_elevator", "LV-L":"L-CENTRAL-CORE/passenger_elevator"},
    "VT-MAIN-STAIR": {"LV-U":"U-CENTRAL-CORE/main_stair", "LV-L":"L-CENTRAL-CORE/main_stair"},
    "VT-OLD-STAIR": {"LV-T":"T-OLD-ACCESS/old_stair"},
    "VT-SERVICE-STAIR": {"LV-L":"L-SERVICE-INTERCHANGE/service_stair"},
    "VT-EAST-STAIR": {"LV-U":"U-EAST-SUPPORT/emergency_stair", "LV-L":"L-EAST-STAIR/emergency_stair", "LV-T":"T-EAST-VERTICAL/east_emergency_stair"},
    "VT-FREIGHT-LIFT": {"LV-U":"U-FREIGHT/freight_lift", "LV-L":"L-FREIGHT-SERVICE/freight_lift", "LV-T":"T-FREIGHT/freight_lift"},
}


def shaft_side(segment: list, bounds: list, tolerance: float = .25) -> str | None:
    a, b = segment
    x0,z0,x1,z1 = bounds
    # Require the entire opening segment to lie on one shaft boundary.
    if abs(a[1]-b[1]) < 1e-6 and min(a[0],b[0]) >= x0-tolerance and max(a[0],b[0]) <= x1+tolerance:
        if abs(a[1]-z0) <= tolerance:
            return "north"
        if abs(a[1]-z1) <= tolerance:
            return "south"
    if abs(a[0]-b[0]) < 1e-6 and min(a[1],b[1]) >= z0-tolerance and max(a[1],b[1]) <= z1+tolerance:
        if abs(a[0]-x0) <= tolerance:
            return "west"
        if abs(a[0]-x1) <= tolerance:
            return "east"
    return None


def map_ports(handoff: dict, vertical: dict) -> dict:
    portals = handoff["internal_portals"] + handoff["external_portals"]
    datums = vertical["level_datums"]
    entries, diagnostics = [], []
    for transition in vertical["transitions"]:
        tid = transition["id"]
        if tid not in SPACE_REFS:
            entries.append({"transition_id":tid,"policy":"reuse_integrated_pilot" if tid == "VT-ROUTE-A" else "non_port_transition_requires_separate_geometry", "ports":[]})
            continue
        levels = transition.get("stops", transition.get("connects", []))
        ports = []
        for level in levels:
            space_id = SPACE_REFS[tid].get(level)
            if not space_id:
                diagnostics.append({"transition_id":tid,"level":level,"code":"explicit_space_mapping_missing","severity":"blocking"})
                continue
            candidates = [p for p in portals if space_id in p.get("between", [p.get("space")]) and p.get("state") != "closed" and p.get("traversable") is not False]
            candidates.sort(key=lambda p:p["id"])
            if not candidates:
                diagnostics.append({"transition_id":tid,"level":level,"code":"explicit_portal_missing","severity":"blocking","space_id":space_id})
            for portal in candidates:
                a,b = portal["segment_xz"]
                side = shaft_side(portal["segment_xz"], transition["shaft_bounds_xz"])
                ports.append({"portal_source_id":portal["id"],"space_source_id":space_id,"level":level,"origin":[(a[0]+b[0])/2,datums[level],(a[1]+b[1])/2],"segment_xz":portal["segment_xz"],"width_m":portal["width"],"height_m":portal["height"],"shaft_side":side,"status":"generator_boundary_port" if side else "external_threshold"})
            valid = [p for p in ports if p["level"] == level and p["shaft_side"]]
            if "stair" in transition["kind"] and not valid:
                diagnostics.append({"transition_id":tid,"level":level,"code":"generator_boundary_port_missing","severity":"blocking","portal_source_ids":[p["portal_source_id"] for p in ports if p["level"] == level],"action":"keep threshold frames active; do not infer stair generator orientation"})
        entries.append({"transition_id":tid,"policy":"explicit_candidates_only","pass_through_without_stop":transition.get("pass_through",[]),"ports":ports})
    return {"schema_id":"caretaker.vertical_port_mapping_audit","schema_version":"1.0.0","map_id":handoff["map_id"],"status":"blocked" if diagnostics else "mapped_pending_runtime", "anchor_frames_emitted":False,"boundary_tolerance_m":.25,"transitions":sorted(entries,key=lambda x:x["transition_id"]),"diagnostics":diagnostics}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report",required=True)
    args = parser.parse_args()
    h = json.loads((ROOT/"docs/design/complex_v3/handoff/geometry/complex-handoff.json").read_text(encoding="utf-8"))
    v = json.loads((ROOT/"docs/design/complex_v3/handoff/vertical/vertical-transitions.json").read_text(encoding="utf-8"))
    result = map_ports(h,v)
    output = Path(args.report)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"{result['status'].upper()}: portal_candidates={sum(len(t['ports']) for t in result['transitions'])} diagnostics={len(result['diagnostics'])}; no frames or geometry emitted")
    return 2 if result["diagnostics"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
