#!/usr/bin/env python3
"""Atomically build shared infrastructure plus deterministic anchor frames."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
VERTICAL = ROOT / "docs/design/complex_v3/handoff/vertical/vertical-transitions.json"
PORT_REPORT = ROOT / "scenes/complex_v3_regeneration/rollout/shared/reports/vertical-port-mapping.json"
AUDIT_REPORT = ROOT / "scenes/complex_v3_regeneration/rollout/shared/reports/shared-input-audit.json"
LIVE = ROOT / "gen/shared"
LEVEL_Y = {"LV-U":0.0,"LV-L":-6.0,"LV-T":-11.5}


def dump(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")


def point_basis(a: list, b: list) -> tuple[list,list]:
    dx,dz = b[0]-a[0],b[1]-a[1]
    length = math.hypot(dx,dz)
    if length <= 1e-9:
        return [1.0,0.0,0.0],[0.0,0.0,1.0]
    forward=[dx/length,0.0,dz/length]
    return forward,[-forward[2],0.0,forward[0]]


def frame(anchor_id: str, kind: str, role: str, source_id: str, origin: list, forward: list, normal: list, bounds: dict, metadata: dict | None=None) -> dict:
    result={"anchor_id":anchor_id,"type":kind,"role":role,"status":"active","source_ref":{"artifact_id":"HANDOFF-GEOMETRY-01","source_kind":"shared_handoff","source_id":source_id},"origin":origin,"forward":forward,"normal":normal,"up":[0.0,1.0,0.0],"bounds":bounds}
    if metadata:
        result["metadata"]=metadata
    return result


def build_frames(h: dict, v: dict, port_report: dict) -> dict:
    anchors=[]
    for route in h["route_spaces"]:
        x0,z0,x1,z1=route["bounds_xz"]
        anchors.append(frame(f"shared:{route['id']}:floor","floor","shared_route_surface",route["id"],[(x0+x1)/2,route["floor_y"],(z0+z1)/2],[1,0,0],[0,1,0],{"kind":"planar_surface","elevation_m":route["floor_y"],"polygon_xz":[[x0,z0],[x1,z0],[x1,z1],[x0,z1]],"thickness_m":.2},{"geometry_owner":"sector_rollouts","route_kind":route["kind"]}))
    for corridor in h["connection_corridors"] + h["controlled_technical_transitions"]:
        points=corridor["centerline_xz"]
        y=LEVEL_Y.get(corridor.get("level"), next((LEVEL_Y[k] for k in LEVEL_Y if corridor.get("connection_id","").startswith("E-"+k[-1])), 0.0))
        forward,normal=point_basis(points[0],points[-1])
        if points[0] == points[-1]:
            continue
        for label,p in (("start",points[0]),("end",points[-1])):
            anchors.append(frame(f"shared:{corridor['id']}:point:{label}","point","corridor_entry",corridor["id"],[p[0],y,p[1]],forward,normal,{"kind":"point","radius_m":0.0},{"connection_id":corridor.get("connection_id"),"endpoint":label}))
    transitions={item["id"]:item for item in v["transitions"]}
    for transition in v["transitions"]:
        if "shaft_bounds_xz" not in transition:
            continue
        x0,z0,x1,z1=transition["shaft_bounds_xz"]
        levels=transition.get("stops",transition.get("connects",[]))
        bottom=min(LEVEL_Y[level] for level in levels)
        top=max(LEVEL_Y[level] for level in levels)
        anchors.append(frame(f"shared:{transition['id']}:shaft","shaft","vertical_envelope",transition["id"],[(x0+x1)/2,bottom,(z0+z1)/2],[1,0,0],[0,0,1],{"kind":"shaft_volume","footprint_xz":[[x0,z0],[x1,z0],[x1,z1],[x0,z1]],"bottom_m":bottom,"top_m":top},{"geometry_owner":"route_a_vertical_pilot" if transition["id"]=="VT-ROUTE-A" else "blocked_pending_opening_contract"}))
    for mapped in port_report["transitions"]:
        transition=transitions[mapped["transition_id"]]
        levels=transition.get("stops",transition.get("connects",[]))
        for port in mapped["ports"]:
            a,b=port["segment_xz"]
            forward,normal=point_basis(a,b)
            if "stair" in transition["kind"]:
                kind="stair_entry" if LEVEL_Y[port["level"]] == min(LEVEL_Y[x] for x in levels) else "stair_exit"
            else:
                kind="door"
            aid=f"shared:{transition['id']}:{port['level']}:{port['portal_source_id']}:{kind}"
            anchors.append(frame(aid,kind,"vertical_threshold",port["portal_source_id"],port["origin"],forward,normal,{"kind":"linear","length_m":port["width_m"],"height_m":port["height_m"]},{"transition_id":transition["id"],"level":port["level"],"port_relation":port["status"]}))
    ids=[a["anchor_id"] for a in anchors]
    if len(ids)!=len(set(ids)):
        raise ValueError("duplicate shared anchor IDs")
    digest=hashlib.sha256((HANDOFF.read_text(encoding="utf-8")+VERTICAL.read_text(encoding="utf-8")+PORT_REPORT.read_text(encoding="utf-8")).encode()).hexdigest()
    return {"schema_id":"caretaker.anchor_frames","schema_version":"1.0.0","contract_version":"1.0.0","map_id":h["map_id"],"sector_id":"SHARED-INFRASTRUCTURE","generation_id":"sha256:"+digest,"producer":{"name":"build_shared_contract","version":"1.0.0"},"coordinate_space":{"units":"m","horizontal_plane":"XZ","up_axis":"+Y","space":"world"},"anchors":sorted(anchors,key=lambda x:x["anchor_id"])}


def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",default=os.environ.get("GODOT_BIN"))
    args=parser.parse_args()
    if not args.godot:
        raise SystemExit("GODOT_BIN or --godot required")
    h=json.loads(HANDOFF.read_text(encoding="utf-8")); v=json.loads(VERTICAL.read_text(encoding="utf-8")); ports=json.loads(PORT_REPORT.read_text(encoding="utf-8")); audit=json.loads(AUDIT_REPORT.read_text(encoding="utf-8"))
    staging=ROOT/f"gen/.shared-staging-{uuid.uuid4().hex}"
    resource=f"res://{staging.relative_to(ROOT).as_posix()}/Generated/Infrastructure/shared_infrastructure_generated.tscn"
    try:
        completed=subprocess.run([args.godot,"--headless","--disable-crash-handler","--path",str(ROOT),"--script","res://tools/complex_v3_regeneration/rollouts/build_shared_package.gd","--",f"--output={resource}"],text=True,encoding="utf-8",errors="replace",capture_output=True)
        if completed.returncode:
            raise RuntimeError(completed.stdout+completed.stderr)
        scene=staging/"Generated/Infrastructure/shared_infrastructure_generated.tscn"
        if not scene.exists() or scene.stat().st_size == 0:
            raise RuntimeError("Godot did not create staged scene")
        scene.write_text(re.sub(r" unique_id=\d+", "", scene.read_text(encoding="utf-8")), encoding="utf-8", newline="\n")
        dump(staging/"anchor_frames.json",build_frames(h,v,ports))
        dump(staging/"generation_report.json",{
            "schema_id":"caretaker.shared_generation_report",
            "schema_version":"1.0.0",
            "status":"ready_with_blocking_vertical_diagnostics",
            "map_id":h["map_id"],
            "generated_scene":"Generated/Infrastructure/shared_infrastructure_generated.tscn",
            "geometry_policy":"external_single_owner",
            "geometry_owners":{"horizontal_routes":"sector_rollouts","connectors":"sector_rollouts","VT-ROUTE-A":"route_a_vertical_pilot"},
            "generated_vertical_geometry":[],
            "unresolved_vertical_geometry":["VT-MAIN-ELEVATOR","VT-MAIN-STAIR","VT-OLD-INCLINE","VT-OLD-STAIR","VT-SERVICE-STAIR","VT-EAST-STAIR","VT-FREIGHT-LIFT"],
            "blocking_reason":"No vertical may be emitted until its sector-owned floors and walls expose a non-overlapping shaft/opening boundary.",
            "connector_aliases":[item for item in audit.get("connectors", []) if item.get("zero_length")],
            "vertical_mapping_report":"res://scenes/complex_v3_regeneration/rollout/shared/reports/vertical-port-mapping.json",
            "startup_modified":False,
        })
        backup=ROOT/f"gen/.shared-backup-{uuid.uuid4().hex}"
        if LIVE.exists():
            LIVE.replace(backup)
        try:
            staging.replace(LIVE)
        except Exception:
            if backup.exists(): backup.replace(LIVE)
            raise
        if backup.exists(): shutil.rmtree(backup)
    finally:
        if staging.exists(): shutil.rmtree(staging)
    print(f"SHARED_SAFE_REGENERATE_OK anchors={len(json.loads((LIVE/'anchor_frames.json').read_text())['anchors'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
