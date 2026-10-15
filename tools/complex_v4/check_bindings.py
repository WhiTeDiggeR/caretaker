#!/usr/bin/env python3
"""Authored object bindings of complex_v4 survive regeneration (#224).

Every placed object of a sector is an ``AnchoredObject3D`` in the sector's authored scene, bound by its ``object_id`` to a
stable anchor ID of the generated package (``svg:<element id>:<type>``, element IDs by room and side, #206). This check
looks up every binding by ID and reports the lost ones; nothing is ever matched by position or by a nearby anchor.

Per binding:
- ``ok`` — the anchor is in the live package (``gen/**/anchor_frames.json``) and the placement fits it;
- ``pending`` — the package is older than the canonical SVG (regeneration not run yet) and the anchor exists only in
  the SVG; the placement is checked against the anchor frames predicted from the SVG;
- ``lost`` — the anchor is in neither (renamed or removed element), ``invalid`` — the anchor exists but the object no
  longer fits it (type, bounds, placement limits).

The sector must also be consistent: every bound object exists once in the authored scene and in the sector's
composition (``safe_regeneration.composition_input``), the composition is up to date with the SVG and the bindings
(``--write-composition`` rebuilds it), the composition validator of ``safe_regenerate.py`` reports it clean, and the
authored transform of every object equals the transform its binding resolves to (no jump after regeneration).

Anchor frames predicted from the SVG reproduce the converter's anchors of walls, doors, floors and ceilings
(``predict_anchor_frames``); ``test_check_bindings.py`` keeps them equal to the real packages of every sector whose
package is built from its current SVG.

Usage:
    python tools/complex_v4/check_bindings.py [--sector U-EMERGENCY ...] [--strict] [--verbose]
    python tools/complex_v4/check_bindings.py --sector U-EMERGENCY --write-bindings

``--write-bindings`` rebuilds the sector's bindings from the AnchoredObject3D nodes of its authored scene (their
``anchor_id``, ``expected_anchor_type`` and ``metadata/footprint_m``), then its composition; ``--write-composition``
rebuilds only the composition.

Exit 1 on a lost or invalid binding or an inconsistent sector; ``--strict`` (after regeneration) also fails while a
sector still waits for regeneration.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
MANIFEST = TOOLS / "sector_generation_manifest.json"
ANCHORED_SCRIPT = "res://scenes/complex_v4/regeneration/anchored_object_3d.gd"
## Converter conventions for the predicted frames (svg_to_godot3d 1.19, sector backend 1.1.1).
WALL_THICKNESS_M = 0.3
SLAB_THICKNESS_M = 0.2
## An authored transform may differ from its resolved binding by this much (metres, basis components).
POSITION_TOLERANCE_M = 0.02
BASIS_TOLERANCE = 1.0e-3
## A floor-standing object counts as supported within this gap (composition validator default).
SUPPORT_TOLERANCE_M = 0.02
PLACEMENT_MODE = {"floor": "floor", "ceiling": "ceiling", "wall": "wall", "door": "door_frame"}


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


RESOLVE = _load("complex_v4_resolve_bindings_224", TOOLS / "resolve_bindings.py")
VALIDATE = _load("complex_v4_validate_composition_224", TOOLS / "composition_validator/validate_composition.py")


def res_path(resource: str) -> Path:
    return ROOT / resource.removeprefix("res://")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


# ------------------------------------------------------------------ predicted anchor frames


def _num(element: ET.Element, key: str) -> float:
    return float(element.get(key, "0"))


def _round(values: Any) -> Any:
    if isinstance(values, (list, tuple)):
        return [_round(value) for value in values]
    return round(float(values), 6) + 0.0


def _cross(a: list[float], b: list[float]) -> list[float]:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _line_frame(element: ET.Element, elevation: float) -> tuple[list[float], list[float], list[float], float]:
    """Start, forward and normal of a wall or door line, and its length (canonical endpoint order)."""
    start = [_num(element, "x1"), elevation, _num(element, "y1")]
    end = [_num(element, "x2"), elevation, _num(element, "y2")]
    side = element.get("data-normal-side" if element.get("data-godot-type") == "wall" else "data-inside-side", "normal")
    if side == "opposite":
        start, end = end, start
    length = math.dist((start[0], start[2]), (end[0], end[2]))
    forward = [(end[axis] - start[axis]) / length for axis in range(3)]
    return start, forward, _cross(forward, [0.0, 1.0, 0.0]), length


def predict_anchor_frames(svg_text: str, sector: dict[str, Any]) -> dict[str, Any]:
    """Anchor frames of walls, doors, floors and ceilings the converter writes for this canonical SVG."""
    elevation = float(sector["metric_settings"]["elevation_m"])
    limits = sector["anchor_parameterization"]["defaults_by_type"]
    anchors: list[dict[str, Any]] = []

    def frame(anchor_id: str, kind: str, role: str, source_id: str, origin: list[float], forward: list[float],
              normal: list[float], bounds: dict[str, Any], **extra: Any) -> dict[str, Any]:
        item = {
            "anchor_id": anchor_id, "type": kind, "role": role, "status": "active",
            "source_ref": {"artifact_id": "geometry-handoff", "source_kind": "svg", "source_id": source_id},
            "origin": _round(origin), "forward": _round(forward), "normal": _round(normal), "up": [0.0, 1.0, 0.0],
            "bounds": bounds, "placement_limits": limits[kind]["placement_limits"],
        }
        item.update(extra)
        return item

    for element in ET.fromstring(svg_text).iter():
        kind, ident = element.get("data-godot-type"), element.get("id", "")
        if kind in ("floor", "ceiling"):
            x, z, width, depth = (_num(element, key) for key in ("x", "y", "width", "height"))
            # The ceiling elevation of the plan is absolute (world metres); floors lie on the level elevation.
            level = float(element.get("data-ceiling-elevation", "0")) if kind == "ceiling" else elevation
            polygon = [[x, z], [x + width, z], [x + width, z + depth], [x, z + depth]]
            anchors.append(frame(
                f"svg:{ident}:{kind}", kind, "surface", ident, [x, level, z], [1.0, 0.0, 0.0],
                [0.0, 1.0 if kind == "floor" else -1.0, 0.0],
                {"kind": "planar_surface", "elevation_m": _round(level), "thickness_m": SLAB_THICKNESS_M,
                 "orientation_policy": "world_positive_x", "polygon_xz": _round(polygon),
                 "u_range_m": _round([0.0, width]), "v_range_m": _round([0.0, depth]), "holes_xz": []},
            ))
        elif kind == "wall":
            start, forward, normal, length = _line_frame(element, elevation)
            origin = [start[axis] + normal[axis] * WALL_THICKNESS_M * 0.5 for axis in range(3)]
            anchors.append(frame(
                f"svg:{ident}:wall", "wall", "surface", ident, origin, forward, normal,
                {"kind": "linear_surface", "length_m": _round(length), "height_m": _round(float(element.get("data-wall-height", "0"))),
                 "thickness_m": WALL_THICKNESS_M, "orientation_policy": "canonical_endpoint_order",
                 "surface_side_id": element.get("data-surface-side-id", ""), "normal_side": element.get("data-normal-side", "normal"),
                 "source_segment_index": 1, "centerline_origin": _round(start), "along_range_m": _round([0.0, length])},
            ))
        elif kind == "door":
            start, forward, normal, length = _line_frame(element, elevation)
            center = [start[axis] + forward[axis] * length * 0.5 for axis in range(3)]
            bounds = {"kind": "portal", "width_m": _round(length), "height_m": _round(float(element.get("data-door-height", "0"))),
                      "bottom_m": 0.0, "wall_thickness_m": WALL_THICKNESS_M, "orientation_policy": "canonical_endpoint_order",
                      "inside_side": element.get("data-inside-side", "normal"), "along_range_m": _round([-length * 0.5, length * 0.5]),
                      "origin_semantics": "line_center"}
            for role, side in (("center", 0.0), ("threshold_inside", 0.5), ("threshold_outside", -0.5)):
                origin = [center[axis] + normal[axis] * WALL_THICKNESS_M * side for axis in range(3)]
                anchors.append(frame(f"svg:{ident}:door:{role}", "door", role, ident, origin, forward, normal, dict(bounds),
                                     metadata={"side_status": "explicit"}))
    return {"map_id": "caretaker-complex-v4", "sector_id": sector["sector_id"], "generation_id": "predicted-from-svg", "anchors": anchors}


# ------------------------------------------------------------------ authored scene


_NODE_RE = re.compile(r'^\[node name="(?P<name>[^"]+)"(?P<rest>[^\]]*)\]')


def _transform_from_text(text: str) -> tuple[list[list[float]], list[float]]:
    values = [float(item) for item in text.split(",")]
    basis = [[values[0], values[1], values[2]], [values[3], values[4], values[5]], [values[6], values[7], values[8]]]
    return basis, values[9:12]


def _compose(parent: tuple[list[list[float]], list[float]], child: tuple[list[list[float]], list[float]]) -> tuple[list[list[float]], list[float]]:
    (pb, po), (cb, co) = parent, child
    basis = [[sum(pb[row][k] * cb[k][col] for k in range(3)) for col in range(3)] for row in range(3)]
    origin = [sum(pb[row][k] * co[k] for k in range(3)) + po[row] for row in range(3)]
    return basis, origin


IDENTITY = ([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]], [0.0, 0.0, 0.0])


def anchored_objects(scene_path: Path) -> dict[str, list[dict[str, Any]]]:
    """``object_id`` -> AnchoredObject3D nodes of a text scene, with scene-root transforms (rows of the basis)."""
    text = scene_path.read_text(encoding="utf-8")
    scripts = {match.group(2): match.group(1) for match in re.finditer(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', text)}
    nodes: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    current: dict[str, Any] | None = None
    for line in text.splitlines():
        header = _NODE_RE.match(line)
        if header:
            parent_match = re.search(r'parent="([^"]*)"', header.group("rest"))
            parent = parent_match.group(1) if parent_match else None
            path = "." if parent is None else (header.group("name") if parent == "." else f"{parent}/{header.group('name')}")
            current = {"path": path, "parent": parent, "transform": IDENTITY, "script": None, "object_id": None,
                       "anchor_id": "", "expected_anchor_type": "wall", "name": header.group("name"),
                       "footprint_m": None, "footprint_center_m": [0.0, 0.0, 0.0]}
            nodes[path] = current
            order.append(path)
            continue
        if line.startswith("["):
            current = None
            continue
        if current is None:
            continue
        if line.startswith("transform = Transform3D("):
            current["transform"] = _transform_from_text(line[len("transform = Transform3D("):-1])
        elif line.startswith("script = ExtResource("):
            current["script"] = scripts.get(line.split('"')[1])
        elif line.startswith("object_id = "):
            current["object_id"] = json.loads(line.split("=", 1)[1].strip())
        elif line.startswith(("anchor_id = ", "expected_anchor_type = ")):
            key, value = line.split(" = ", 1)
            current[key] = json.loads(value)
        elif line.startswith(("metadata/footprint_m = Vector3(", "metadata/footprint_center_m = Vector3(")):
            key, value = line.split(" = ", 1)
            current[key.removeprefix("metadata/")] = [float(item) for item in value[len("Vector3("):-1].split(",")]
    world: dict[str, tuple[list[list[float]], list[float]]] = {}
    found: dict[str, list[dict[str, Any]]] = {}
    for path in order:
        node = nodes[path]
        parent = node["parent"]
        base = IDENTITY if parent is None else world.get("." if parent == "." else parent, IDENTITY)
        world[path] = node["transform"] if parent is None else _compose(base, node["transform"])
        if node["script"] == ANCHORED_SCRIPT:
            found.setdefault(str(node["object_id"] or ""), []).append({
                "path": path, "name": node["name"], "transform": world[path], "type": node["expected_anchor_type"],
                "anchor_id": node["anchor_id"], "footprint_m": node["footprint_m"], "footprint_center_m": node["footprint_center_m"]})
    return found


# ------------------------------------------------------------------ composition


def _svg_rooms(svg_text: str) -> tuple[dict[str, ET.Element], list[ET.Element], list[ET.Element]]:
    floors, walls, doors = {}, [], []
    for element in ET.fromstring(svg_text).iter():
        kind = element.get("data-godot-type")
        if kind == "floor":
            floors[element.get("data-space-id", "")] = element
        elif kind == "wall":
            walls.append(element)
        elif kind == "door":
            doors.append(element)
    return floors, walls, doors


def _on_wall(door: ET.Element, wall: ET.Element) -> bool:
    dx1, dz1, dx2, dz2 = (_num(door, key) for key in ("x1", "y1", "x2", "y2"))
    wx1, wz1, wx2, wz2 = (_num(wall, key) for key in ("x1", "y1", "x2", "y2"))
    if abs(wx1 - wx2) < 1e-6:
        return abs(dx1 - wx1) < 1e-3 and abs(dx2 - wx1) < 1e-3 and min(wz1, wz2) - 1e-3 <= min(dz1, dz2) and max(dz1, dz2) <= max(wz1, wz2) + 1e-3
    return abs(dz1 - wz1) < 1e-3 and abs(dz2 - wz1) < 1e-3 and min(wx1, wx2) - 1e-3 <= min(dx1, dx2) and max(dx1, dx2) <= max(wx1, wx2) + 1e-3


def build_composition(sector: dict[str, Any], svg_text: str, bindings: dict[str, Any], frames: dict[str, Any]) -> dict[str, Any]:
    """Composition input of ``safe_regenerate.py``: spaces and generated infrastructure by stable anchor ID, and one
    object per binding. Bounds are those of the predicted frames; the resolver recomputes them from the real ones."""
    elevation = float(sector["metric_settings"]["elevation_m"])
    floors, walls, doors = _svg_rooms(svg_text)
    by_id = {frame["anchor_id"]: frame for frame in frames["anchors"]}
    spaces, infrastructure = [], []
    for space_id, floor in sorted(floors.items()):
        x, z, width, depth = (_num(floor, key) for key in ("x", "y", "width", "height"))
        height = max((float(w.get("data-wall-height", "0")) for w in walls if space_id in w.get("data-wall-rooms", "").split("|")), default=0.0)
        spaces.append({"space_id": space_id, "sector_id": sector["sector_id"],
                       "bounds": {"min": _round([x, elevation, z]), "max": _round([x + width, elevation + height, z + depth])}})
    for element in ET.fromstring(svg_text).iter():
        kind, ident = element.get("data-godot-type"), element.get("id", "")
        if kind in ("floor", "ceiling"):
            anchor_id = f"svg:{ident}:{kind}"
            infrastructure.append({"infrastructure_id": f"INFRA-{ident.upper()}", "owner": "generated", "kind": kind,
                                   "source_anchor_id": anchor_id, "derivation": f"{kind}_prism",
                                   "bounds": RESOLVE.derive_infrastructure_bounds({"derivation": f"{kind}_prism"}, by_id[anchor_id])})
    # The resolver cuts every wall around its doors from the real anchors; the whole wall here is the fallback.
    for element in walls:
        ident = element.get("id", "")
        openings = [f"svg:{door.get('id')}:door:center" for door in doors if _on_wall(door, element)]
        infrastructure.append({"infrastructure_id": f"INFRA-{ident.upper()}", "owner": "generated", "kind": "wall",
                               "source_anchor_id": f"svg:{ident}:wall", "derivation": "wall_prism_segments",
                               "opening_anchor_ids": openings,
                               "bounds": RESOLVE.derive_infrastructure_bounds({"derivation": "wall_prism"}, by_id[f"svg:{ident}:wall"])})
    objects = []
    for binding in bindings["bindings"]:
        anchor_id = binding["anchor_ref"]["anchor_id"]
        kind = binding["anchor_ref"]["expected_type"]
        frame = by_id.get(anchor_id)
        item: dict[str, Any] = {"object_id": binding["object_ref"]["object_id"], "owner": "authored", "sector_id": sector["sector_id"],
                                "placement_mode": PLACEMENT_MODE[kind]}
        if kind in ("floor", "ceiling"):
            space = next((space_id for space_id, floor in floors.items() if anchor_id.startswith(f"svg:{floor.get('id')}:")
                          or anchor_id == f"svg:{floor.get('id', '').replace('--floor', '--ceiling')}:ceiling"), None)
            if space:
                item["space_id"] = space
        if kind == "floor":
            item["support_tolerance_m"] = SUPPORT_TOLERANCE_M
        item["bounds"] = {"min": [0.0, 0.0, 0.0], "max": [0.0, 0.0, 0.0]}  # lost or invalid: reported by the check
        if frame:
            try:
                item["bounds"] = RESOLVE.resolve_binding(binding, frame)["bounds"]
            except RESOLVE.BindingResolutionError:
                pass
        objects.append(item)
    xs = [value for space in spaces for value in (space["bounds"]["min"][0], space["bounds"]["max"][0])]
    zs = [value for space in spaces for value in (space["bounds"]["min"][2], space["bounds"]["max"][2])]
    top = max(space["bounds"]["max"][1] for space in spaces)
    return {
        "schema_id": "caretaker.composition_validation_input", "schema_version": "1.0.0", "map_id": frames["map_id"],
        "sector_id": sector["sector_id"], "generation_id": "bootstrap-before-first-regeneration",
        "sector_bounds": {"min": _round([min(xs) - 0.15, elevation - SLAB_THICKNESS_M, min(zs) - 0.15]),
                          "max": _round([max(xs) + 0.15, top + SLAB_THICKNESS_M, max(zs) + 0.15])},
        "spaces": spaces, "anchors": [], "infrastructure": infrastructure, "objects": objects, "declared_warnings": [],
    }


# ------------------------------------------------------------------ bindings from the authored scene


def _dot(a: list[float], b: list[float]) -> float:
    return sum(a[axis] * b[axis] for axis in range(3))


def _axis_policy(value: float, bounds: list[float]) -> dict[str, Any]:
    """Distance from the nearer end of the anchor, so an object keeps its distance to the nearer wall when the room changes."""
    start, end = float(bounds[0]), float(bounds[1])
    if value - start <= end - value:
        return {"policy": "from_start_m", "distance_m": round(max(0.0, value - start), 4)}
    return {"policy": "from_end_m", "distance_m": round(max(0.0, end - value), 4)}


def derive_binding(sector: dict[str, Any], node: dict[str, Any], object_id: str, frame: dict[str, Any]) -> dict[str, Any]:
    """Binding that puts the object where it stands in the authored scene, relative to its anchor frame."""
    kind = frame["type"]
    if node["footprint_m"] is None:
        raise RESOLVE.BindingResolutionError(f"{object_id}: set metadata/footprint_m on the node")
    basis_rows, origin = node["transform"]
    columns = [[basis_rows[row][col] for row in range(3)] for col in range(3)]
    forward, up, normal = frame["forward"], frame["up"], frame["normal"]
    offset = [origin[axis] - frame["origin"][axis] for axis in range(3)]
    if kind in RESOLVE.LINEAR_TYPES:
        along_range = frame["bounds"].get("along_range_m", [0.0, frame["bounds"].get("length_m")])
        placement = {"mode": "linear", "linear": {"along": _axis_policy(_dot(offset, forward), along_range)},
                     "normal_offset_m": round(_dot(offset, normal), 4), "height_m": round(_dot(offset, up), 4)}
        anchor_columns, yaw = [forward, up, normal], 0.0
    else:
        axis_v = _cross(forward, up)
        placement = {"mode": "surface", "surface": {"u": _axis_policy(_dot(offset, forward), frame["bounds"]["u_range_m"]),
                                                    "v": _axis_policy(_dot(offset, axis_v), frame["bounds"]["v_range_m"])},
                     "normal_offset_m": 0.0, "height_m": round(_dot(offset, up), 4)}
        yaw = round(math.degrees(math.atan2(-_dot(columns[0], axis_v), _dot(columns[0], forward))), 4) + 0.0
        anchor_columns = [forward, up, axis_v]
    placement["rotation"] = {"representation": "euler_deg", "order": "YXZ", "yaw_pitch_roll": [yaw, 0.0, 0.0]}
    # What the anchor and yaw do not explain (a door turned to the other side) is the author correction.
    resolved = RESOLVE.matrix_multiply(RESOLVE.basis_matrix(anchor_columns), RESOLVE.euler_yxz((yaw, 0.0, 0.0)))
    correction = RESOLVE.matrix_multiply(tuple(zip(*resolved)), basis_rows)
    binding: dict[str, Any] = {
        "binding_id": f"BIND-{sector['sector_id']}-{object_id}",
        "object_ref": {"object_id": object_id, "scene": sector["authored_scene"], "node_path_hint": node["path"]},
        "anchor_ref": {"anchor_id": frame["anchor_id"], "expected_type": kind},
        "placement": placement,
        "footprint_m": [round(value, 4) for value in node["footprint_m"]],
        "footprint_center_m": [round(value, 4) for value in node["footprint_center_m"]],
    }
    if any(abs(correction[row][col] - (1.0 if row == col else 0.0)) > BASIS_TOLERANCE for row in range(3) for col in range(3)):
        binding["author_correction"] = {"origin": [0.0, 0.0, 0.0]} | {
            f"basis_{axis}": [round(correction[row][index] + 0.0, 6) for row in range(3)] for index, axis in enumerate("xyz")}
    binding["constraints"] = {"inside_anchor_bounds": True, "collision_free": False}
    binding["on_missing_anchor"] = "block"
    return binding


def write_bindings(sector: dict[str, Any]) -> list[str]:
    """Rebuilds the sector's bindings document from the AnchoredObject3D nodes of its authored scene (``anchor_id``,
    ``expected_anchor_type``, ``metadata/footprint_m``) against the live package, or the SVG while it waits for
    regeneration. Objects without an ``anchor_id`` stay free."""
    svg_path = ROOT / sector["source_svg"]
    package = res_path(sector["output_resource_dir"])
    fresh = read_json(package / "generation_manifest.json").get("source", {}).get("sha256") == sha256_file(svg_path)
    frames = read_json(package / "anchor_frames.json") if fresh else predict_anchor_frames(svg_path.read_text(encoding="utf-8"), sector)
    by_id = {frame["anchor_id"]: frame for frame in frames["anchors"]}
    errors, bindings = [], []
    for object_id, nodes in sorted(anchored_objects(res_path(sector["authored_scene"])).items()):
        for node in nodes:
            if not node["anchor_id"]:
                continue
            frame = by_id.get(node["anchor_id"])
            if frame is None or frame["type"] != node["type"]:
                errors.append(f"{object_id}: no {node['type']} anchor {node['anchor_id']}")
                continue
            try:
                bindings.append(derive_binding(sector, node, object_id, frame))
            except RESOLVE.BindingResolutionError as error:
                errors.append(str(error))
    if not errors:
        write_json(ROOT / sector["safe_regeneration"]["bindings_input"], {
            "schema_id": "caretaker.object_bindings", "schema_version": "1.0.0", "map_id": frames["map_id"],
            "sector_id": sector["sector_id"], "bindings": bindings})
    return errors


# ------------------------------------------------------------------ check


def _matches(authored: tuple[list[list[float]], list[float]], resolved: dict[str, Any], binding: dict[str, Any]) -> bool:
    """Whether the authored transform is the one the binding resolves to (anchor, placement and author correction)."""
    basis_rows, origin = authored
    rows = RESOLVE.basis_matrix([resolved["basis_x"], resolved["basis_y"], resolved["basis_z"]])
    correction = binding.get("author_correction")
    if correction:
        rows = RESOLVE.matrix_multiply(rows, RESOLVE.basis_matrix([correction[f"basis_{axis}"] for axis in "xyz"]))
        shift = RESOLVE.transform_vector(rows, correction["origin"])
        resolved = resolved | {"origin": [resolved["origin"][axis] + shift[axis] for axis in range(3)]}
    if any(abs(origin[axis] - resolved["origin"][axis]) > POSITION_TOLERANCE_M for axis in range(3)):
        return False
    return all(abs(basis_rows[row][col] - rows[row][col]) <= BASIS_TOLERANCE for row in range(3) for col in range(3))


def check_sector(sector: dict[str, Any], write_composition: bool = False) -> dict[str, Any]:
    sector_id = sector["sector_id"]
    svg_path = ROOT / sector["source_svg"]
    svg_text = svg_path.read_text(encoding="utf-8")
    package = res_path(sector["output_resource_dir"])
    generation = read_json(package / "generation_manifest.json")
    fresh = generation.get("source", {}).get("sha256") == sha256_file(svg_path)
    live = read_json(package / "anchor_frames.json")
    predicted = predict_anchor_frames(svg_text, sector)
    live_frames = {frame["anchor_id"]: frame for frame in live["anchors"]}
    predicted_frames = {frame["anchor_id"]: frame for frame in predicted["anchors"]}
    config = sector["safe_regeneration"]
    bindings_path = ROOT / config["bindings_input"]
    bindings = read_json(bindings_path)
    scene = res_path(sector["authored_scene"])
    objects = anchored_objects(scene)
    result: dict[str, Any] = {"sector_id": sector_id, "package": "fresh" if fresh else "stale", "bindings": [], "errors": []}
    errors: list[str] = result["errors"]
    if bindings.get("sector_id") != sector_id or bindings.get("map_id") != live.get("map_id"):
        errors.append(f"{bindings_path.relative_to(ROOT)}: map_id/sector_id do not match the package")
    resolved_by_object: dict[str, dict[str, Any]] = {}
    for binding in bindings.get("bindings", []):
        object_id = binding["object_ref"]["object_id"]
        anchor_id = binding["anchor_ref"]["anchor_id"]
        entry = {"object_id": object_id, "anchor_id": anchor_id}
        frame = live_frames.get(anchor_id)
        if frame is not None:
            entry["status"] = "ok"
        elif not fresh and anchor_id in predicted_frames:
            entry["status"], frame = "pending", predicted_frames[anchor_id]
        else:
            entry["status"] = "lost"
            entry["reason"] = "anchor is in neither the package nor the SVG" if not fresh else "anchor is not in the package"
        if frame is not None:
            try:
                resolved = RESOLVE.resolve_binding(binding, frame)
                resolved_by_object[object_id] = resolved
            except RESOLVE.BindingResolutionError as error:
                entry["status"], entry["reason"] = "invalid", str(error)
        if binding["object_ref"].get("scene") != sector["authored_scene"]:
            errors.append(f"{object_id}: object_ref.scene is not {sector['authored_scene']}")
        nodes = objects.get(object_id, [])
        if len(nodes) != 1:
            errors.append(f"{object_id}: {len(nodes)} AnchoredObject3D nodes in {scene.relative_to(ROOT)}")
        elif nodes[0]["type"] != binding["anchor_ref"]["expected_type"]:
            errors.append(f"{object_id}: node expects a {nodes[0]['type']} anchor, binding a {binding['anchor_ref']['expected_type']}")
        elif object_id in resolved_by_object and not _matches(nodes[0]["transform"], resolved_by_object[object_id], binding):
            errors.append(f"{object_id}: authored transform differs from its binding (moves on regeneration)")
        result["bindings"].append(entry)
    for object_id, nodes in objects.items():
        if not object_id or len(nodes) > 1:
            errors.append(f"AnchoredObject3D without a unique object_id: {', '.join(node['path'] for node in nodes)}")
    composition_path = ROOT / config["composition_input"]
    if bindings.get("bindings"):
        expected = build_composition(sector, svg_text, bindings, predicted)
        if write_composition:
            write_json(composition_path, expected)
        if read_json(composition_path) != json.loads(json.dumps(expected)):
            errors.append(f"{composition_path.relative_to(ROOT)} is out of date: run check_bindings.py --sector {sector_id} --write-composition")
        frames = live if fresh else predicted
        try:
            document = RESOLVE.resolve_document(read_json(composition_path), bindings, frames)
            issues, _context = VALIDATE.validate_document(document)
        except (RESOLVE.BindingResolutionError, VALIDATE.ValidationInputError) as error:
            issues = [{"severity": "blocking", "code": "input", "object_id": "-", "evidence": {"message": str(error)}}]
        for issue in issues:
            if issue["severity"] == "blocking" and not (issue["code"] == "missing_anchor" and not fresh):
                errors.append(f"composition {issue['code']}: {issue['object_id']} — {issue['evidence']['message']}")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--sector", action="append", default=[], help="sector ID (repeatable); default: all sectors")
    parser.add_argument("--strict", action="store_true", help="also fail while a sector waits for regeneration")
    parser.add_argument("--write-bindings", action="store_true", help="rebuild the bindings from the authored scene, then the composition")
    parser.add_argument("--write-composition", action="store_true", help="rebuild the composition input from the SVG and bindings")
    parser.add_argument("--verbose", action="store_true", help="print every binding")
    args = parser.parse_args(argv)
    sectors = read_json(MANIFEST)["sectors"]
    wanted = set(args.sector)
    unknown = wanted - {sector["sector_id"] for sector in sectors}
    if unknown:
        parser.error(f"unknown sector: {', '.join(sorted(unknown))}")
    if (args.write_bindings or args.write_composition) and not wanted:
        parser.error("--write-bindings and --write-composition need --sector")
    totals = {"ok": 0, "pending": 0, "lost": 0, "invalid": 0}
    failed = False
    for sector in sectors:
        if wanted and sector["sector_id"] not in wanted:
            continue
        if args.write_bindings:
            write_errors = write_bindings(sector)
            for error in write_errors:
                print(f"  ERROR    {error}")
            if write_errors:
                failed = True
                continue
        result = check_sector(sector, args.write_composition or args.write_bindings)
        counts = {key: sum(entry["status"] == key for entry in result["bindings"]) for key in totals}
        for key, value in counts.items():
            totals[key] += value
        if result["bindings"] or result["errors"] or wanted:
            state = "собран из текущего SVG" if result["package"] == "fresh" else "ждёт перегенерации"
            print(f"BINDINGS {result['sector_id']} пакет: {state}; привязок {len(result['bindings'])}: "
                  + ", ".join(f"{key}={value}" for key, value in counts.items()))
        for entry in result["bindings"]:
            if entry["status"] in ("lost", "invalid") or args.verbose:
                print(f"  {entry['status'].upper():8} {entry['object_id']} -> {entry['anchor_id']}" + (f": {entry['reason']}" if entry.get("reason") else ""))
        for error in result["errors"]:
            print(f"  ERROR    {error}")
        failed |= bool(result["errors"]) or counts["lost"] > 0 or counts["invalid"] > 0
        failed |= args.strict and counts["pending"] > 0
    print("BINDINGS_CHECK " + " ".join(f"{key}={value}" for key, value in totals.items()) + (" FAILED" if failed else " OK"))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
