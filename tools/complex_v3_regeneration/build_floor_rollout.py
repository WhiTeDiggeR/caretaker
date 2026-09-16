#!/usr/bin/env python3
"""Materialize authored binding inputs around immutable canonical metric SVGs."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
DRESSING = ROOT / "scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"
LEVELS = {"upper": ("LV-U", 0.0), "lower": ("LV-L", -6.0), "technical": ("LV-T", -11.5)}
PILOTS = {"upper": {"U-MEDBAY", "U-ROUTE-A"}, "lower": {"L-ARCHIVE-A"}, "technical": set()}
EPS = 1.0e-6


class BuildError(ValueError):
    pass


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def stable_id(prefix: str, semantic: str) -> str:
    return f"{prefix}-{hashlib.sha256(semantic.encode('utf-8')).hexdigest()[:10]}"


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def edges(spaces: list[dict[str, Any]]) -> list[dict[str, Any]]:
    raw = []
    for space in spaces:
        x0, z0, x1, z1 = map(float, space["bounds_xz"])
        for orientation, fixed, start, end, side in (
            ("h", z0, x0, x1, "north"), ("h", z1, x0, x1, "south"),
            ("v", x0, z0, z1, "west"), ("v", x1, z0, z1, "east"),
        ):
            raw.append({"orientation": orientation, "fixed": fixed, "start": start, "end": end, "contributors": [(space["id"], side)]})
    result = []
    groups: dict[tuple[str, float], list[dict[str, Any]]] = defaultdict(list)
    for item in raw:
        groups[item["orientation"], item["fixed"]].append(item)
    for (orientation, fixed), items in groups.items():
        cuts = sorted({value for item in items for value in (item["start"], item["end"])})
        atoms = []
        for start, end in zip(cuts, cuts[1:]):
            if end - start <= EPS:
                continue
            midpoint = (start + end) * 0.5
            contributors = sorted(c for item in items if item["start"] - EPS <= midpoint <= item["end"] + EPS for c in item["contributors"])
            if contributors:
                atoms.append({"orientation": orientation, "fixed": fixed, "start": start, "end": end, "contributors": contributors})
        for atom in atoms:
            if result and all(result[-1][key] == atom[key] for key in ("orientation", "fixed", "contributors")) and math.isclose(result[-1]["end"], atom["start"], abs_tol=EPS):
                result[-1]["end"] = atom["end"]
            else:
                result.append(atom)
    merged: list[dict[str, Any]] = []
    for item in result:
        if (
            merged and merged[-1]["orientation"] == item["orientation"]
            and merged[-1]["fixed"] == item["fixed"]
            and math.isclose(merged[-1]["end"], item["start"], abs_tol=EPS)
            and len(merged[-1]["contributors"]) == len(item["contributors"]) == 1
            and normal_side(merged[-1]["contributors"][0][1]) == normal_side(item["contributors"][0][1])
        ):
            merged[-1]["end"] = item["end"]
            merged[-1]["contributors"] = sorted(set(merged[-1]["contributors"] + item["contributors"]))
        else:
            merged.append(item)
    seen: dict[str, int] = defaultdict(int)
    for item in merged:
        semantic = "--".join(f"{slug(space)}-{side}" for space, side in item["contributors"])
        seen[semantic] += 1
        stable = hashlib.sha256(semantic.encode("utf-8")).hexdigest()[:10]
        item["id"] = f"w-{stable}" + (f"-{seen[semantic]}" if seen[semantic] > 1 else "")
    return merged


def wall_contains(wall: dict[str, Any], segment: list[list[float]]) -> bool:
    (x0, z0), (x1, z1) = segment
    if wall["orientation"] == "h":
        return abs(z0 - wall["fixed"]) <= EPS and abs(z1 - wall["fixed"]) <= EPS and wall["start"] - EPS <= min(x0, x1) and max(x0, x1) <= wall["end"] + EPS
    return abs(x0 - wall["fixed"]) <= EPS and abs(x1 - wall["fixed"]) <= EPS and wall["start"] - EPS <= min(z0, z1) and max(z0, z1) <= wall["end"] + EPS


def choose_wall_face(wall: dict[str, Any], mounted: set[tuple[str, str]]) -> tuple[str, str]:
    requested = [item for item in wall["contributors"] if item in mounted]
    if len(requested) > 1:
        raise BuildError(f"wall {wall['id']} has authored mounts on both finished faces")
    return requested[0] if requested else wall["contributors"][0]


def normal_side(side: str) -> str:
    return "normal" if side in {"north", "east"} else "opposite"


def portal_side(portal: dict[str, Any], spaces_by_id: dict[str, dict[str, Any]]) -> str:
    target = portal["between"][0] if "between" in portal else portal["space"]
    if target not in spaces_by_id:
        raise BuildError(f"{portal['id']} has no local target space")
    bounds = spaces_by_id[target]["bounds_xz"]
    center = ((bounds[0] + bounds[2]) * 0.5, (bounds[1] + bounds[3]) * 0.5)
    a, b = portal["segment_xz"]
    midpoint = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    normal = (-dz / length, dx / length)
    dot = normal[0] * (center[0] - midpoint[0]) + normal[1] * (center[1] - midpoint[1])
    if abs(dot) <= EPS:
        raise BuildError(f"{portal['id']} inside side is ambiguous")
    return "normal" if dot > 0 else "opposite"


def portal_is_traversable(portal: dict[str, Any]) -> bool:
    if portal.get("state") not in {"openable", "closed"}:
        raise BuildError(f"{portal.get('id')}: unsupported portal state")
    if "traversable" in portal and not isinstance(portal["traversable"], bool):
        raise BuildError(f"{portal.get('id')}: traversable must be boolean")
    if portal.get("state") == "closed" and portal.get("traversable") is True:
        raise BuildError(f"{portal.get('id')}: closed portal cannot be traversable")
    return portal.get("traversable") is not False and portal.get("state") != "closed"


def node_names(scene_path: Path) -> dict[str, str]:
    result, current = {}, None
    for line in scene_path.read_text(encoding="utf-8").splitlines():
        match = re.match(r'\[node name="([^"]+)" type="Node3D" parent="\."\]', line)
        if match:
            current = match.group(1)
        placement = re.match(r'metadata/placement_id = "([^"]+)"', line)
        if current and placement:
            result[placement.group(1)] = current
    return result


def build_sector(sector: dict[str, Any], handoff: dict[str, Any], dressing: dict[str, Any], level_name: str, elevation: float, root: Path) -> dict[str, Any]:
    sector_id, sector_slug = sector["id"], sector["id"].lower().replace("-", "_")
    spaces = [item for item in handoff["spaces"] if item["sector_id"] == sector_id]
    spaces_by_id = {item["id"]: item for item in spaces}
    sector_height = max(float(item["clear_height"]) for item in spaces)
    dress = next(item for item in dressing["sectors"] if item["sector_id"] == sector_id)
    mounted = {(item["space_id"], item["wall_mount_side"]) for item in dress["placements"] if "wall_mount_side" in item}
    walls = edges(spaces)
    for wall in walls:
        wall["face"] = choose_wall_face(wall, mounted)
    portals = [item for item in handoff["internal_portals"] if any(value in spaces_by_id for value in item["between"])]
    portals += [item for item in handoff["external_portals"] if item.get("space") in spaces_by_id]
    traversable_portals = portals if level_name == "upper" else [item for item in portals if portal_is_traversable(item)]
    sealed_portals = [] if level_name == "upper" else [item for item in portals if not portal_is_traversable(item)]
    portal_walls: dict[str, dict[str, Any]] = {}
    for portal in portals:
        matches = [wall for wall in walls if wall_contains(wall, portal["segment_xz"])]
        if len(matches) != 1:
            raise BuildError(f"{portal['id']} matches {len(matches)} walls")
        portal_walls[portal["id"]] = matches[0]
    min_x = min(item["bounds_xz"][0] for item in spaces) - 1
    min_z = min(item["bounds_xz"][1] for item in spaces) - 1
    max_x = max(item["bounds_xz"][2] for item in spaces) + 1
    max_z = max(item["bounds_xz"][3] for item in spaces) + 1
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{min_x:g} {min_z:g} {max_x-min_x:g} {max_z-min_z:g}" data-scale="1" data-scale-unit="m-per-svg-unit" data-artifact-id="ROLLOUT-{sector_id}" data-plan-style-id="caretaker-style-b-v1">', f'  <title>{sector_id} metric regeneration source</title>', '  <g id="floors" data-layer="floors">']
    for space in spaces:
        x0, z0, x1, z1 = space["bounds_xz"]
        lines.append(f'    <rect id="{stable_id("f", space["id"])}" data-godot-type="floor" data-space-id="{space["id"]}" x="{x0:g}" y="{z0:g}" width="{x1-x0:g}" height="{z1-z0:g}"/>')
    lines += ['  </g>', '  <g id="ceilings" data-layer="ceilings">']
    for space in spaces:
        x0, z0, x1, z1 = space["bounds_xz"]
        lines.append(f'    <rect id="{stable_id("c", space["id"])}" data-godot-type="ceiling" data-ceiling-elevation="{elevation+space["clear_height"]:g}" x="{x0:g}" y="{z0:g}" width="{x1-x0:g}" height="{z1-z0:g}"/>')
    lines += ['  </g>', '  <g id="walls" data-layer="walls">']
    wall_by_face: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for wall in walls:
        space_id, side = wall["face"]
        wall_height = max(float(spaces_by_id[value[0]]["clear_height"]) for value in wall["contributors"])
        wall_by_face[space_id, side].append(wall)
        if wall["orientation"] == "h": x1, z1, x2, z2 = wall["start"], wall["fixed"], wall["end"], wall["fixed"]
        else: x1, z1, x2, z2 = wall["fixed"], wall["start"], wall["fixed"], wall["end"]
        lines.append(f'    <line id="{wall["id"]}" data-godot-type="wall" data-wall-height="{wall_height:g}" data-wall-thickness=".3" data-surface-side-id="{space_id}/{side}" data-normal-side="{normal_side(side)}" x1="{x1:g}" y1="{z1:g}" x2="{x2:g}" y2="{z2:g}"/>')
    lines += ['  </g>', '  <g id="doors" data-layer="doors">']
    for portal in traversable_portals:
        a, b = portal["segment_xz"]
        lines.append(f'    <line id="{stable_id("d", portal["id"])}" data-godot-type="door" data-handoff-id="{portal["id"]}" data-inside-side="{portal_side(portal, spaces_by_id)}" data-door-height="{portal["height"]:g}" data-wall-thickness=".3" x1="{a[0]:g}" y1="{a[1]:g}" x2="{b[0]:g}" y2="{b[1]:g}"/>')
    lines += ['  </g>']
    if sealed_portals:
        lines.append('  <g id="sealed-portals" data-layer="markers">')
    for portal in sealed_portals:
        a, b = portal["segment_xz"]
        x, z = (a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5
        lines.append(f'    <circle id="{stable_id("p", portal["id"])}" data-godot-type="marker" data-anchor-id="{portal["id"]}" data-anchor-role="sealed_portal" data-handoff-id="{portal["id"]}" data-portal-state="{portal["state"]}" data-traversable="false" cx="{x:g}" cy="{z:g}" r=".01"/>')
    if sealed_portals:
        lines.append('  </g>')
    lines.append('</svg>')
    source = ROOT / f"docs/design/complex_v3/plans/generation/{level_name}/{sector_slug}.svg"
    if not source.is_file():
        raise BuildError(f"canonical SVG is missing: {source.relative_to(ROOT)}")

    infrastructure = []
    for space in spaces:
        infrastructure += [
            {"infrastructure_id": f"INFRA-{sector_id}-FLOOR-{slug(space['name']).upper()}", "owner": "generated", "kind": "floor", "source_anchor_id": f"svg:{stable_id('f', space['id'])}:floor", "derivation": "floor_prism", "bounds": {"min": [0,0,0], "max": [0,0,0]}},
            {"infrastructure_id": f"INFRA-{sector_id}-CEILING-{slug(space['name']).upper()}", "owner": "generated", "kind": "ceiling", "source_anchor_id": f"svg:{stable_id('c', space['id'])}:ceiling", "derivation": "ceiling_prism", "bounds": {"min": [0,0,0], "max": [0,0,0]}},
        ]
    for wall in walls:
        openings = [f"svg:{stable_id('d', portal['id'])}:door:center" for portal in traversable_portals if portal_walls[portal["id"]] is wall]
        infrastructure.append({"infrastructure_id": f"INFRA-{sector_id}-{wall['id'].upper()}", "owner": "generated", "kind": "wall", "source_anchor_id": f"svg:{wall['id']}:wall", "derivation": "wall_prism_segments", "opening_anchor_ids": openings, "bounds": {"min": [0,0,0], "max": [0,0,0]}})
    nodes = node_names(ROOT / dress["dressing_scene"].removeprefix("res://"))
    objects, bindings = [], []
    for placement in dress["placements"]:
        position = list(map(float, placement["position"]))
        if placement.get("kind") == "open_portal_frame":
            portal = next((item for item in portals if item["id"] == placement["id"]), None)
            if portal is None:
                raise BuildError(f"{placement['id']} door frame has no local handoff portal")
            width = math.hypot(portal["segment_xz"][1][0] - portal["segment_xz"][0][0], portal["segment_xz"][1][1] - portal["segment_xz"][0][1])
            depth = 0.1
            height = float(portal["height"])
            if level_name == "upper" or portal_is_traversable(portal):
                anchor_id, expected = f"svg:{stable_id('d', portal['id'])}:door:center", "door"
                placement_doc = {"mode":"linear", "linear":{"along":{"policy":"centered","offset_m":0}}, "normal_offset_m":0, "height_m":0, "rotation":{"representation":"euler_deg","order":"YXZ","yaw_pitch_roll":[0,0,0]}}
                footprint, center, mode = [width, height, depth], [0, height/2, 0], "door"
                wall_integration = {"mode":"door_frame", "max_depth_m":0.3}
            else:
                wall = portal_walls[portal["id"]]
                _space_id, wall_side = wall["face"]
                a, b = portal["segment_xz"]
                coordinate = ((a[0] + b[0]) * 0.5) if wall["orientation"] == "h" else ((a[1] + b[1]) * 0.5)
                distance = coordinate - wall["start"] if wall_side in {"north", "east"} else wall["end"] - coordinate
                anchor_id, expected = f"svg:{wall['id']}:wall", "wall"
                placement_doc = {"mode":"linear", "linear":{"along":{"policy":"from_start_m","distance_m":round(distance,6)}}, "normal_offset_m":0, "height_m":0, "rotation":{"representation":"euler_deg","order":"YXZ","yaw_pitch_roll":[0,0,0]}}
                footprint, center, mode = [width, height, depth], [0, height/2, 0], "wall"
                wall_integration = {"mode":"mounted", "max_depth_m":0.3}
        else:
            if "footprint_xz" not in placement:
                raise BuildError(f"{placement['id']} has no explicit footprint_xz")
            width, depth = map(float, placement["footprint_xz"])
        wall_side = placement.get("wall_mount_side")
        if placement.get("kind") == "open_portal_frame":
            pass
        elif wall_side:
            candidates = [wall for wall in walls if (placement["space_id"], wall_side) in wall["contributors"] and (wall["start"]-EPS <= (position[0] if wall["orientation"]=="h" else position[2]) <= wall["end"]+EPS)]
            if len(candidates) != 1 or candidates[0]["face"] != (placement["space_id"], wall_side):
                raise BuildError(f"{placement['id']} has no unique authored wall face")
            wall = candidates[0]
            coordinate = position[0] if wall["orientation"] == "h" else position[2]
            distance = coordinate-wall["start"] if wall_side in {"north", "east"} else wall["end"]-coordinate
            anchor_id, expected = f"svg:{wall['id']}:wall", "wall"
            placement_doc = {"mode":"linear", "linear":{"along":{"policy":"from_start_m","distance_m":round(distance,6)}}, "normal_offset_m":max(0.0, float(placement.get("wall_mount_center_offset", 0.0))), "height_m":position[1]-elevation, "rotation":{"representation":"euler_deg","order":"YXZ","yaw_pitch_roll":[0,0,0]}}
            footprint = [width if wall["orientation"] == "h" else depth, 0.4, max(0.05, float(placement.get("wall_mount_depth", depth if wall["orientation"] == "h" else width)))]
            center = [0, 0, 0]
            mode = "wall"
            wall_integration = {"mode":"mounted", "max_depth_m":float(placement.get("wall_mount_depth", footprint[2]))}
        else:
            space = spaces_by_id[placement["space_id"]]
            x0, z0, x1, z1 = map(float, space["bounds_xz"])
            anchor_id, expected = f"svg:{stable_id('f', space['id'])}:floor", "floor"
            placement_doc = {"mode":"surface", "surface":{"u":{"policy":"from_start_m","distance_m":round(position[0]-x0,6)},"v":{"policy":"from_start_m","distance_m":round(position[2]-z0,6)}}, "normal_offset_m":0, "height_m":0, "rotation":{"representation":"euler_deg","order":"YXZ","yaw_pitch_roll":[math.degrees(float(placement.get("rotation_y",0))),0,0]}}
            footprint, center, mode = [width, 0.01, depth], [0, 0.005, 0], "floor"
            wall_integration = None
        object_id = placement["object_id"]
        object_doc = {"object_id":object_id,"owner":"authored","sector_id":sector_id,"space_id":None if mode == "door" else placement["space_id"],"placement_mode":mode,"support_tolerance_m":0.02,"bounds":{"min":[position[0]-width/2,elevation,position[2]-depth/2],"max":[position[0]+width/2,elevation+0.01,position[2]+depth/2]}}
        if wall_integration is not None:
            object_doc["wall_integration"] = wall_integration
        if level_name != "upper" and placement.get("kind") == "open_portal_frame" and not portal_is_traversable(portal):
            object_doc["portal_semantics"] = {"portal_id": portal["id"], "state": portal["state"], "traversable": portal_is_traversable(portal)}
        objects.append(object_doc)
        bindings.append({"binding_id":f"BIND-{object_id}","object_ref":{"object_id":object_id,"scene":dress["dressing_scene"],"node_path_hint":f"AuthoredContent/SetDressing/{nodes[placement['id']]}"},"anchor_ref":{"anchor_id":anchor_id,"expected_type":expected},"placement":placement_doc,"footprint_m":footprint,"footprint_center_m":center,"constraints":{"inside_anchor_bounds":True,"collision_free":True},"on_missing_anchor":"block"})
    authored = root / f"AuthoredContent/{sector_slug}"
    write_json(authored / "composition.json", {"schema_id":"caretaker.composition_validation_input","schema_version":"1.0.0","map_id":handoff["map_id"],"sector_id":sector_id,"generation_id":"bootstrap-before-first-regeneration","sector_bounds":{"min":[sector["bounds_xz"][0]-.15,elevation-.2,sector["bounds_xz"][1]-.15],"max":[sector["bounds_xz"][2]+.15,elevation+sector_height+.2,sector["bounds_xz"][3]+.15]},"spaces":[{"space_id":s["id"],"sector_id":sector_id,"bounds":{"min":[s["bounds_xz"][0],elevation,s["bounds_xz"][1]],"max":[s["bounds_xz"][2],elevation+s["clear_height"],s["bounds_xz"][3]]}} for s in spaces],"anchors":[],"infrastructure":infrastructure,"objects":objects,"declared_warnings":[]})
    write_json(authored / "object_bindings.json", {"schema_id":"caretaker.object_bindings","schema_version":"1.0.0","map_id":handoff["map_id"],"sector_id":sector_id,"bindings":bindings})
    level_code = {"upper":"u", "lower":"l", "technical":"t"}[level_name]
    shared_args = ["--wall-height",f"{sector_height:g}","--wall-thickness","0.3","--floor-thickness","0.2","--ceiling-thickness","0.2","--strict-wall-overlaps"]
    if len({float(item["clear_height"]) for item in spaces}) == 1:
        shared_args.append("--strict-ceiling-alignment")
    result = {"sector_id":sector_id,"level":sector["level"],"status":"ready","blockers":[],"source_svg":str(source.relative_to(ROOT)).replace("\\","/"),"profile":"generic","metric_settings":{"scale_m_per_svg_unit":1.0,"origin":"none","elevation_m":elevation},"shared_args":shared_args,"semantic_mappings":[],"material_mappings":{},"scene_name":sector_slug+"_generated","output_resource_dir":f"res://gen/{level_code}/{sector_slug}","local_to_world":{"origin":[0,0,0],"basis_x":[1,0,0],"basis_y":[0,1,0],"basis_z":[0,0,1]},"anchor_parameterization":{"defaults_by_type":{"door":{"placement_limits":{"normal_offset_m":[0,1],"height_m":[0,sector_height],"rotation_deg":{"yaw":[0,0],"pitch":[0,0],"roll":[0,0]}}},"wall":{"origin":"finished_face","placement_limits":{"normal_offset_m":[0,1],"height_m":[0,sector_height],"rotation_deg":{"yaw":[0,0],"pitch":[0,0],"roll":[0,0]}}},"floor":{"placement_limits":{"normal_offset_m":[0,0],"height_m":[0,0],"rotation_deg":{"yaw":[-180,180],"pitch":[0,0],"roll":[0,0]}}},"ceiling":{"placement_limits":{"normal_offset_m":[0,0],"height_m":[0,0],"rotation_deg":{"yaw":[-180,180],"pitch":[0,0],"roll":[0,0]}}},"point":{"placement_limits":{"normal_offset_m":[0,0],"height_m":[0,0],"rotation_deg":{"yaw":[0,0],"pitch":[0,0],"roll":[0,0]}}}}},"vertical_generators":[],"safe_regeneration":{"composition_input":str((authored/"composition.json").relative_to(ROOT)).replace("\\","/"),"bindings_input":str((authored/"object_bindings.json").relative_to(ROOT)).replace("\\","/")}}
    if not sealed_portals:
        result["anchor_parameterization"]["defaults_by_type"].pop("point")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--level", choices=LEVELS, required=True)
    args = parser.parse_args()
    level_id, elevation = LEVELS[args.level]
    handoff, dressing = (json.loads(path.read_text(encoding="utf-8")) for path in (HANDOFF, DRESSING))
    output = ROOT / f"scenes/complex_v3_regeneration/rollout/{args.level}"
    sectors = [sector for sector in handoff["sectors"] if sector["level"] == level_id and sector["id"] not in PILOTS[args.level]]
    entries = [build_sector(sector, handoff, dressing, args.level, elevation, output) for sector in sorted(sectors, key=lambda item:item["id"])]
    manifest = {"schema_id":"caretaker.sector_generation_manifest","schema_version":"1.0.0","contract_version":"1.0.0","map_id":handoff["map_id"],"project_root":"../../..","sector_count":len(entries),"producer_requirements":{"svg_to_godot3d":">=1.19.0","generate_godot_stairs":">=2.9.0"},"sectors":entries}
    write_json(ROOT / f"tools/complex_v3_regeneration/rollouts/{args.level}_generation_manifest.json", manifest)
    print(f"BUILT {args.level}: sectors={len(entries)} objects={sum(len(json.loads((output/'AuthoredContent'/e['sector_id'].lower().replace('-','_')/'composition.json').read_text())['objects']) for e in entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
