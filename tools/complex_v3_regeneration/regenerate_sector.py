#!/usr/bin/env python3
"""Generate one complex_v3 sector into an isolated staging directory."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


VERSION = "1.1.0"
CONTRACT_VERSION = "1.0.0"
EPS = 1.0e-6
ANCHOR_TYPES = {"point", "wall", "door", "floor", "ceiling", "shaft", "stair_entry", "stair_exit"}
MIN_SVG_VERSION = (1, 19, 0)
MIN_STAIR_VERSION = (2, 9, 0)


class RegenerationError(Exception):
    pass


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Generate one complex_v3 sector into staging.")
    result.add_argument("--sector", required=True)
    result.add_argument("--staging", required=True)
    result.add_argument("--manifest", default=str(Path(__file__).with_name("sector_generation_manifest.json")))
    result.add_argument("--svg-tool-root", required=True, help="Canonical svg-plan-to-godot package/source root")
    result.add_argument("--stair-tool-root", help="Canonical generate-godot-stairs root when vertical generators are configured")
    result.add_argument("--python", default=sys.executable)
    return result


def canonical_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RegenerationError(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RegenerationError(f"JSON root must be an object: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _portable_value(value: Any, replacements: Sequence[tuple[str, str]]) -> Any:
    if isinstance(value, str):
        result = value
        for original, replacement in replacements:
            result = result.replace(original, replacement)
        return result.replace("\\", "/") if "$" in result else result
    if isinstance(value, list):
        return [_portable_value(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: _portable_value(item, replacements) for key, item in value.items()}
    return value


def sanitize_generated_metadata(staging: Path, replacements: Sequence[tuple[str, str]]) -> None:
    """Remove machine/worktree paths from committed JSON and scene metadata."""
    expanded: list[tuple[str, str]] = []
    for original, replacement in replacements:
        if not original:
            continue
        expanded.extend(((original, replacement), (original.replace("\\", "/"), replacement)))
    expanded.sort(key=lambda item: len(item[0]), reverse=True)
    for path in sorted(staging.rglob("*.json")):
        write_json(path, _portable_value(load_json(path), expanded))
    for path in sorted(staging.rglob("*.tscn")):
        text = path.read_text(encoding="utf-8")
        for original, replacement in expanded:
            text = text.replace(original.replace("\\", "\\\\"), replacement).replace(original, replacement)
        path.write_text(text, encoding="utf-8")


def require_empty_staging(path: Path) -> None:
    if path.exists() and any(path.iterdir()):
        raise RegenerationError(f"Staging directory must be absent or empty: {path}")
    path.mkdir(parents=True, exist_ok=True)


def find_script(root: Path, name: str) -> Path:
    candidates = (root / "scripts" / name, root / name)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise RegenerationError(f"Required canonical tool script is missing: {name} under {root}")


def validate_transform(value: Any, label: str) -> dict[str, list[float]]:
    if not isinstance(value, dict):
        raise RegenerationError(f"{label} exact local_to_world transform is missing")
    keys = ("origin", "basis_x", "basis_y", "basis_z")
    vectors: dict[str, list[float]] = {}
    for key in keys:
        vector = value.get(key)
        if not isinstance(vector, list) or len(vector) != 3 or not all(isinstance(item, (int, float)) and math.isfinite(item) for item in vector):
            raise RegenerationError(f"{label} local_to_world.{key} must be three finite numbers")
        vectors[key] = [float(item) for item in vector]
    basis = [vectors[key] for key in keys[1:]]
    for index, vector in enumerate(basis):
        if abs(sum(item * item for item in vector) - 1.0) > EPS:
            raise RegenerationError(f"{label} basis vector {keys[index + 1]} is not normalized")
        for other in basis[index + 1:]:
            if abs(sum(a * b for a, b in zip(vector, other))) > EPS:
                raise RegenerationError(f"{label} local_to_world basis is not orthogonal")
    if any(abs(a - b) > EPS for a, b in zip(vectors["basis_y"], [0.0, 1.0, 0.0])):
        raise RegenerationError(f"{label} basis_y must preserve complex_v3 world +Y")
    if abs(vectors["basis_x"][1]) > EPS or abs(vectors["basis_z"][1]) > EPS:
        raise RegenerationError(f"{label} local_to_world must keep the horizontal XZ plane horizontal")
    return vectors


def require_version(value: Any, minimum: tuple[int, int, int], label: str) -> str:
    if not isinstance(value, str):
        raise RegenerationError(f"{label} did not report its version")
    try:
        parsed = tuple(int(part) for part in value.split(".")[:3])
    except ValueError as exc:
        raise RegenerationError(f"{label} reported an invalid version: {value}") from exc
    if len(parsed) != 3 or parsed < minimum:
        expected = ".".join(str(part) for part in minimum)
        raise RegenerationError(f"{label} {value} is older than required {expected}")
    return value


def transform_vector(vector: Sequence[float], transform: dict[str, list[float]]) -> list[float]:
    return [
        round(transform["basis_x"][axis] * vector[0] + transform["basis_y"][axis] * vector[1] + transform["basis_z"][axis] * vector[2], 6)
        for axis in range(3)
    ]


def transform_point(point: Sequence[float], transform: dict[str, list[float]]) -> list[float]:
    vector = transform_vector(point, transform)
    return [round(vector[index] + transform["origin"][index], 6) for index in range(3)]


def transform_frame(frame: dict[str, Any], transform: dict[str, list[float]]) -> dict[str, Any]:
    anchor_id = frame.get("anchor_id")
    if not isinstance(anchor_id, str) or not anchor_id:
        raise RegenerationError("Anchor frame has no stable anchor_id")
    anchor_type = frame.get("type")
    if anchor_type not in ANCHOR_TYPES:
        legacy_kind = frame.get("kind")
        detail = f"; legacy kind={legacy_kind!r} is not accepted" if legacy_kind is not None else ""
        raise RegenerationError(f"Anchor {anchor_id} has invalid contract type{detail}")
    if frame.get("status") != "active":
        raise RegenerationError(f"Anchor {anchor_id} is not active")
    source_ref = frame.get("source_ref")
    if not isinstance(source_ref, dict) or not source_ref.get("artifact_id") or not source_ref.get("source_id"):
        raise RegenerationError(f"Anchor {anchor_id} has invalid source_ref")
    if not isinstance(frame.get("bounds"), dict) or not isinstance(frame.get("placement_limits"), dict):
        raise RegenerationError(f"Anchor {anchor_id} must declare bounds and placement_limits")
    required_vectors = ("origin", "forward", "normal", "up")
    for key in required_vectors:
        vector = frame.get(key)
        if not isinstance(vector, list) or len(vector) != 3:
            raise RegenerationError(f"Anchor {frame.get('anchor_id', '<unknown>')} has invalid {key}")
    result = copy.deepcopy(frame)
    result["origin"] = transform_point(frame["origin"], transform)
    for key in ("forward", "normal", "up"):
        result[key] = transform_vector(frame[key], transform)
    bounds = result.get("bounds", {})
    polygon = bounds.pop("polygon_xz_m", bounds.pop("polygon_xz", None))
    if polygon is not None:
        elevation = float(bounds.get("elevation_m", frame["origin"][1]))
        world_polygon = [transform_point([point[0], elevation, point[1]], transform) for point in polygon]
        bounds["polygon_xz"] = [[point[0], point[2]] for point in world_polygon]
        bounds["elevation_m"] = world_polygon[0][1] if world_polygon else result["origin"][1]
    clear_bounds = bounds.get("clear_bounds_xz")
    if isinstance(clear_bounds, list) and len(clear_bounds) == 4:
        min_x, min_z, max_x, max_z = (float(value) for value in clear_bounds)
        elevation = float(bounds.get("bottom_y", frame["origin"][1]))
        corners = [
            transform_point([min_x, elevation, min_z], transform),
            transform_point([min_x, elevation, max_z], transform),
            transform_point([max_x, elevation, min_z], transform),
            transform_point([max_x, elevation, max_z], transform),
        ]
        bounds["clear_bounds_xz"] = [
            min(point[0] for point in corners), min(point[2] for point in corners),
            max(point[0] for point in corners), max(point[2] for point in corners),
        ]
    if "elevation_m" in bounds and polygon is None:
        bounds["elevation_m"] = round(float(bounds["elevation_m"]) + transform["origin"][1], 6)
    for key in ("bottom_y", "top_y"):
        if key in bounds:
            bounds[key] = round(float(bounds[key]) + transform["origin"][1], 6)
    result["geometry_hash"] = sha256_bytes(canonical_json({key: value for key, value in result.items() if key != "geometry_hash"}))
    return result


def _finite_range(value: Any, label: str) -> list[float]:
    if (
        not isinstance(value, list) or len(value) != 2
        or not all(isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(float(item)) for item in value)
        or float(value[0]) > float(value[1])
    ):
        raise RegenerationError(f"{label} must be a finite [min, max] range")
    return [float(value[0]), float(value[1])]


def _dot_xz(point: Sequence[float], origin: Sequence[float], axis: Sequence[float]) -> float:
    return (float(point[0]) - float(origin[0])) * float(axis[0]) + (float(point[1]) - float(origin[2])) * float(axis[2])


def _segments_intersect_xz(a: Sequence[float], b: Sequence[float], c: Sequence[float], d: Sequence[float]) -> bool:
    def orientation(first: Sequence[float], second: Sequence[float], third: Sequence[float]) -> float:
        return (float(second[0]) - float(first[0])) * (float(third[1]) - float(first[1])) - (float(second[1]) - float(first[1])) * (float(third[0]) - float(first[0]))

    values = orientation(a, b, c), orientation(a, b, d), orientation(c, d, a), orientation(c, d, b)
    if values[0] * values[1] < -EPS and values[2] * values[3] < -EPS:
        return True
    return any(abs(value) <= EPS and _point_on_segment_xz(point, first, second) for value, point, first, second in (
        (values[0], c, a, b), (values[1], d, a, b), (values[2], a, c, d), (values[3], b, c, d),
    ))


def _point_on_segment_xz(point: Sequence[float], first: Sequence[float], second: Sequence[float]) -> bool:
    x, z = float(point[0]), float(point[1])
    return min(float(first[0]), float(second[0])) - EPS <= x <= max(float(first[0]), float(second[0])) + EPS and min(float(first[1]), float(second[1])) - EPS <= z <= max(float(first[1]), float(second[1])) + EPS


def _polygons_overlap_xz(first: Sequence[Sequence[float]], second: Sequence[Sequence[float]]) -> bool:
    if any(_point_in_polygon_xz(point, first) for point in second) or any(_point_in_polygon_xz(point, second) for point in first):
        return True
    return any(
        _segments_intersect_xz(first[index], first[(index + 1) % len(first)], second[other], second[(other + 1) % len(second)])
        for index in range(len(first)) for other in range(len(second))
    )


def parameterize_frames(
    frames: list[dict[str, Any]], sector: dict[str, Any], handoff: dict[str, Any],
) -> list[dict[str, Any]]:
    """Apply explicit sector policy and exact geometric surface parameterization.

    Converter 1.19 deliberately cannot choose project-specific placement ranges.
    The adapter derives only UV extents from exact polygons; all behavioral
    limits and wall-face selection must be declared by the manifest.
    """
    policy = sector.get("anchor_parameterization")
    if policy is None:
        return frames
    if not isinstance(policy, dict):
        raise RegenerationError("anchor_parameterization must be an object")
    defaults = policy.get("defaults_by_type")
    if not isinstance(defaults, dict):
        raise RegenerationError("anchor_parameterization.defaults_by_type must be an object")
    unexpected = sorted(set(defaults) - ANCHOR_TYPES)
    if unexpected:
        raise RegenerationError("Unknown parameterization anchor types: " + ", ".join(unexpected))
    opening_records = handoff.get("surface_openings", [])
    if not isinstance(opening_records, list):
        raise RegenerationError("spatial_handoff.surface_openings must be an array")
    result: list[dict[str, Any]] = []
    for raw in frames:
        frame = copy.deepcopy(raw)
        anchor_type = str(frame["type"])
        declared = defaults.get(anchor_type)
        if not isinstance(declared, dict):
            raise RegenerationError(f"No explicit anchor_parameterization policy for {anchor_type}")
        limits = declared.get("placement_limits")
        if not isinstance(limits, dict):
            raise RegenerationError(f"{anchor_type} placement_limits are missing")
        for name in ("normal_offset_m", "height_m"):
            _finite_range(limits.get(name), f"{anchor_type}.placement_limits.{name}")
        rotations = limits.get("rotation_deg")
        if not isinstance(rotations, dict):
            raise RegenerationError(f"{anchor_type}.placement_limits.rotation_deg is missing")
        for name in ("yaw", "pitch", "roll"):
            _finite_range(rotations.get(name), f"{anchor_type}.placement_limits.rotation_deg.{name}")
        frame["placement_limits"] = copy.deepcopy(limits)
        bounds = frame["bounds"]
        if anchor_type in {"floor", "ceiling"}:
            polygon = bounds.get("polygon_xz")
            if not isinstance(polygon, list) or len(polygon) < 3:
                raise RegenerationError(f"{frame['anchor_id']} has no exact polygon_xz")
            origin, axis_u = frame["origin"], frame["forward"]
            axis_v = [-float(axis_u[2]), 0.0, float(axis_u[0])]
            u_values = [_dot_xz(point, origin, axis_u) for point in polygon]
            v_values = [_dot_xz(point, origin, axis_v) for point in polygon]
            bounds["u_range_m"] = [round(min(u_values), 6), round(max(u_values), 6)]
            bounds["v_range_m"] = [round(min(v_values), 6), round(max(v_values), 6)]
            holes: list[list[list[float]]] = []
            for opening in opening_records:
                if not isinstance(opening, dict) or opening.get("surface") != anchor_type or not opening.get("applied"):
                    continue
                opening_polygon = opening.get("polygon_xz_m")
                if not isinstance(opening_polygon, list) or not opening_polygon:
                    raise RegenerationError("Applied surface opening has no exact polygon")
                # An opening belongs to this frame only when every point is in
                # its exact polygon. Boundary-clipped ambiguity is blocked.
                contained = all(_point_in_polygon_xz(point, polygon) for point in opening_polygon)
                if contained:
                    holes.append([[float(point[0]), float(point[1])] for point in opening_polygon])
                elif _polygons_overlap_xz(polygon, opening_polygon):
                    raise RegenerationError(f"Surface opening overlaps multiple frames or crosses the boundary of {frame['anchor_id']}")
            bounds["holes_xz"] = holes
        elif anchor_type == "wall":
            if declared.get("origin") != "finished_face":
                raise RegenerationError("Wall parameterization must explicitly select origin=finished_face")
            thickness = bounds.get("thickness_m")
            if not isinstance(thickness, (int, float)) or not math.isfinite(float(thickness)) or float(thickness) <= 0:
                raise RegenerationError(f"{frame['anchor_id']} has no valid wall thickness")
            centerline_origin = list(frame["origin"])
            frame["origin"] = [
                round(float(centerline_origin[index]) + float(frame["normal"][index]) * float(thickness) * 0.5, 6)
                for index in range(3)
            ]
            bounds["centerline_origin"] = centerline_origin
            bounds["along_range_m"] = [0.0, float(bounds["length_m"])]
        elif anchor_type in {"door", "stair_entry", "stair_exit"}:
            length = bounds.get("width_m", bounds.get("clear_width_m"))
            if not isinstance(length, (int, float)) or not math.isfinite(float(length)) or float(length) < 0:
                raise RegenerationError(f"{frame['anchor_id']} has no valid linear width")
            role = str(frame.get("role", ""))
            bounds["along_range_m"] = [-float(length) * 0.5, float(length) * 0.5] if anchor_type == "door" else [0.0, float(length)]
            bounds["origin_semantics"] = "line_center" if anchor_type == "door" else role
        frame["geometry_hash"] = sha256_bytes(canonical_json({key: value for key, value in frame.items() if key != "geometry_hash"}))
        result.append(frame)
    return result


def _point_in_polygon_xz(point: Sequence[float], polygon: Sequence[Sequence[float]]) -> bool:
    x, z = float(point[0]), float(point[1])
    inside = False
    for index, first in enumerate(polygon):
        second = polygon[(index + 1) % len(polygon)]
        ax, az, bx, bz = float(first[0]), float(first[1]), float(second[0]), float(second[1])
        cross = (x - ax) * (bz - az) - (z - az) * (bx - ax)
        if abs(cross) <= EPS and min(ax, bx) - EPS <= x <= max(ax, bx) + EPS and min(az, bz) - EPS <= z <= max(az, bz) + EPS:
            return True
        if (az > z) != (bz > z):
            crossing_x = ax + (z - az) * (bx - ax) / (bz - az)
            if x < crossing_x:
                inside = not inside
    return inside


def run_command(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)


def ensure_success(process: subprocess.CompletedProcess[str], stage: str) -> None:
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip() or "no diagnostic output"
        raise RegenerationError(f"{stage} failed with exit code {process.returncode}: {detail}")


def validate_generated_files(root: Path, names: Sequence[str], stage: str) -> None:
    missing = [name for name in names if not (root / name).is_file() or (root / name).stat().st_size == 0]
    if missing:
        raise RegenerationError(f"{stage} reported missing or empty files: {', '.join(missing)}")


def normalized_anchor_document(
    map_id: str,
    sector_id: str,
    generation_id: str,
    producer_versions: dict[str, str],
    frames: list[dict[str, Any]],
) -> dict[str, Any]:
    ids = [frame.get("anchor_id") for frame in frames]
    if any(not isinstance(anchor_id, str) or not anchor_id for anchor_id in ids):
        raise RegenerationError("Generated anchor frame has no stable anchor_id")
    if len(ids) != len(set(ids)):
        raise RegenerationError("Generated anchor frames contain duplicate IDs")
    return {
        "schema_id": "caretaker.anchor_frames",
        "schema_version": "1.0.0",
        "contract_version": CONTRACT_VERSION,
        "map_id": map_id,
        "sector_id": sector_id,
        "generation_id": generation_id,
        "producer": {"name": "complex_v3_regenerate_sector", "version": VERSION, "components": producer_versions},
        "coordinate_space": {"units": "m", "horizontal_plane": "XZ", "up_axis": "+Y", "space": "world"},
        "anchors": sorted(frames, key=lambda frame: frame["anchor_id"]),
    }


def generate_svg(
    python: str,
    svg_root: Path,
    project_root: Path,
    staging: Path,
    sector: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    inspector = find_script(svg_root, "inspect_svg_plan.py")
    converter = find_script(svg_root, "svg_to_godot3d.py")
    source = (project_root / sector["source_svg"]).resolve()
    if not source.is_file():
        raise RegenerationError(f"Sector source SVG is missing: {source}")
    shared_args = sector.get("shared_args")
    if not isinstance(shared_args, list) or not all(isinstance(value, str) for value in shared_args):
        raise RegenerationError("Sector shared_args must be a string array")
    mappings = sector.get("semantic_mappings", [])
    if not isinstance(mappings, list) or not all(isinstance(value, str) and "=" in value for value in mappings):
        raise RegenerationError("Sector semantic_mappings must be CLASS=TYPE strings")
    metric = sector.get("metric_settings")
    if not isinstance(metric, dict):
        raise RegenerationError("Sector metric_settings must explicitly declare scale, origin, and elevation")
    scale = metric.get("scale_m_per_svg_unit")
    origin = metric.get("origin")
    elevation = metric.get("elevation_m")
    if not isinstance(scale, (int, float)) or scale <= 0 or origin not in ("center", "top-left", "none") or not isinstance(elevation, (int, float)):
        raise RegenerationError("Sector metric_settings are incomplete or invalid")
    material_mappings = sector.get("material_mappings")
    if not isinstance(material_mappings, dict):
        raise RegenerationError("Sector material_mappings must be an object")
    if material_mappings:
        raise RegenerationError("Explicit material overrides are not supported by svg-plan-to-godot 1.19 and must not be guessed")
    common_args = [
        "--profile", sector["profile"], "--scale", str(scale), "--origin", origin,
        "--elevation", str(elevation), *shared_args,
    ]
    for mapping in mappings:
        common_args.extend(["--map-class", mapping])
    architecture = staging / "Generated" / "Architecture"
    architecture.mkdir(parents=True)
    preflight_path = staging / "preflight_report.json"
    inspection_command = [python, str(inspector), str(source), *common_args, "--json", "--output-json", str(preflight_path), "--strict"]
    inspection = run_command(inspection_command, project_root)
    ensure_success(inspection, "SVG inspection")
    preflight = load_json(preflight_path)
    if preflight.get("unrecognized") or preflight.get("invalid"):
        raise RegenerationError("Strict SVG inspection left unresolved or invalid elements")
    resource_dir = sector["output_resource_dir"].rstrip("/") + "/Generated/Architecture"
    conversion_command = [
        python, str(converter), str(source), str(architecture), *common_args,
        "--resource-dir", resource_dir, "--scene-name", sector["scene_name"], "--strict",
    ]
    conversion = run_command(conversion_command, project_root)
    ensure_success(conversion, "SVG conversion")
    conversion_report = load_json(architecture / "conversion_report.json")
    require_version(conversion_report.get("generator_version"), MIN_SVG_VERSION, "svg-plan-to-godot")
    if conversion_report.get("errors"):
        raise RegenerationError("SVG conversion report contains errors")
    if preflight.get("spatial_handoff") != conversion_report.get("spatial_handoff"):
        raise RegenerationError("Inspector and converter spatial_handoff differ for identical settings")
    handoff = conversion_report.get("spatial_handoff", {})
    issues = handoff.get("anchor_frame_issues", [])
    if issues:
        raise RegenerationError("SVG handoff contains blocking anchor_frame_issues")
    validate_generated_files(architecture, conversion_report.get("files", []), "SVG conversion")
    transform = validate_transform(sector.get("local_to_world"), "SVG")
    frames = [transform_frame(frame, transform) for frame in handoff.get("anchor_frames", [])]
    commands = [
        {"stage": "inspect", "argv": inspection_command, "exit_code": inspection.returncode},
        {"stage": "convert", "argv": conversion_command, "exit_code": conversion.returncode},
    ]
    return conversion_report, frames, commands


def generate_stairs(
    python: str,
    stair_root: Path | None,
    project_root: Path,
    staging: Path,
    sector: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    configs = sector.get("vertical_generators", [])
    if not configs:
        return [], [], []
    if stair_root is None:
        raise RegenerationError("Sector requires vertical generators but --stair-tool-root was not supplied")
    generator = find_script(stair_root, "generate_godot_stairs.py")
    frames: list[dict[str, Any]] = []
    reports: list[dict[str, Any]] = []
    commands: list[dict[str, Any]] = []
    for config in configs:
        generator_id = config.get("generator_id")
        args = config.get("args")
        if not isinstance(generator_id, str) or not isinstance(args, list) or not all(isinstance(value, str) for value in args):
            raise RegenerationError("Vertical generator requires generator_id and string-array args")
        output = staging / "Generated" / "Stairs" / generator_id
        output.mkdir(parents=True)
        resource_dir = sector["output_resource_dir"].rstrip("/") + "/Generated/Stairs/" + generator_id
        command = [python, str(generator), str(output), *args, "--resource-dir", resource_dir]
        process = run_command(command, project_root)
        ensure_success(process, f"Stair generator {generator_id}")
        report = load_json(output / "generation_report.json")
        require_version(report.get("generator_version"), MIN_STAIR_VERSION, "generate-godot-stairs")
        validation = report.get("geometry_validation", {})
        if report.get("status") != "ok" or report.get("errors") or not validation.get("ok") or not validation.get("compiled", {}).get("ok") or not validation.get("shaft", {}).get("ok"):
            raise RegenerationError(f"Stair generator {generator_id} did not pass all geometry validations")
        validate_generated_files(output, report.get("files", []), f"Stair generator {generator_id}")
        transform = validate_transform(config.get("local_to_world"), f"Stair generator {generator_id}")
        anchor_frames = report.get("anchor_frames")
        if report.get("schema_id") != "caretaker.godot_stairs.generation_report" or report.get("schema_version") != "1.1.0" or not isinstance(anchor_frames, list) or not anchor_frames:
            raise RegenerationError(f"Stair generator {generator_id} did not emit the T03 anchor frame contract")
        frames.extend(transform_frame(frame, transform) for frame in anchor_frames)
        reports.append(report)
        commands.append({"stage": "stairs", "generator_id": generator_id, "argv": command, "exit_code": process.returncode})
    return reports, frames, commands


def execute(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest).resolve()
    manifest = load_json(manifest_path)
    project_root = (manifest_path.parent / manifest.get("project_root", ".")).resolve()
    sectors = manifest.get("sectors")
    if not isinstance(sectors, list):
        raise RegenerationError("Manifest sectors must be an array")
    matches = [value for value in sectors if isinstance(value, dict) and value.get("sector_id") == args.sector]
    if len(matches) != 1:
        raise RegenerationError(f"Unknown or duplicate sector ID: {args.sector}")
    sector = matches[0]
    blockers = sector.get("blockers", [])
    if sector.get("status") != "ready" or blockers:
        detail = ", ".join(str(value) for value in blockers) or "sector status is not ready"
        raise RegenerationError(f"Sector {args.sector} configuration is blocked: {detail}")
    required = (
        "source_svg", "profile", "metric_settings", "shared_args", "semantic_mappings", "material_mappings",
        "scene_name", "output_resource_dir", "local_to_world",
    )
    missing = [key for key in required if key not in sector]
    if missing:
        raise RegenerationError("Sector configuration is incomplete: " + ", ".join(missing))
    output_resource_dir = sector["output_resource_dir"]
    if not isinstance(output_resource_dir, str) or not output_resource_dir.startswith("res://") or "AuthoredContent" in output_resource_dir or ".." in output_resource_dir:
        raise RegenerationError("output_resource_dir must be a safe res:// Generated package path")
    staging = Path(args.staging).resolve()
    require_empty_staging(staging)
    source = (project_root / sector["source_svg"]).resolve()
    source_hash = sha256_file(source) if source.is_file() else "missing"
    input_fingerprint = {"manifest_sector": sector, "source_sha256": source_hash}
    generation_id = sha256_bytes(canonical_json(input_fingerprint))
    conversion_report, svg_frames, commands = generate_svg(args.python, Path(args.svg_tool_root).resolve(), project_root, staging, sector)
    stair_reports, stair_frames, stair_commands = generate_stairs(
        args.python, Path(args.stair_tool_root).resolve() if args.stair_tool_root else None,
        project_root, staging, sector,
    )
    commands.extend(stair_commands)
    frames = parameterize_frames(svg_frames + stair_frames, sector, conversion_report.get("spatial_handoff", {}))
    anchor_document = normalized_anchor_document(
        manifest["map_id"], args.sector, generation_id,
        {"sector_backend": VERSION, "svg_converter": conversion_report.get("generator_version", "unknown"), "stair_generator": stair_reports[0].get("generator_version", "none") if stair_reports else "none"},
        frames,
    )
    write_json(staging / "anchor_frames.json", anchor_document)
    resolved_manifest = {
        "schema_id": "caretaker.sector_generation_result",
        "schema_version": "1.0.0",
        "contract_version": CONTRACT_VERSION,
        "map_id": manifest["map_id"],
        "sector_id": args.sector,
        "generation_id": generation_id,
        "source": {"path": sector["source_svg"], "sha256": source_hash},
        "output_resource_dir": sector["output_resource_dir"],
        "local_to_world": sector["local_to_world"],
        "geometry_settings": {
            "profile": sector["profile"], "metric_settings": sector["metric_settings"],
            "shared_args": sector["shared_args"], "semantic_mappings": sector["semantic_mappings"],
            "material_mappings": sector["material_mappings"],
        },
        "vertical_generators": sector.get("vertical_generators", []),
        "generated_paths": {"package_root": ".", "architecture": "Generated/Architecture", "stairs": "Generated/Stairs", "anchors": "anchor_frames.json"},
    }
    write_json(staging / "generation_manifest.json", resolved_manifest)
    report = {
        "schema_id": "caretaker.sector_regeneration_report",
        "schema_version": "1.0.0",
        "contract_version": CONTRACT_VERSION,
        "status": "ok",
        "sector_id": args.sector,
        "generation_id": generation_id,
        "commands": commands,
        "anchor_count": len(anchor_document["anchors"]),
        "errors": [],
        "warnings": [],
        "files": [
            "anchor_frames.json", "generation_manifest.json", "preflight_report.json",
            "Generated/Architecture/conversion_report.json",
            *[f"Generated/Stairs/{config['generator_id']}/generation_report.json" for config in sector.get("vertical_generators", [])],
        ],
    }
    write_json(staging / "regeneration_report.json", report)
    replacements = [
        (str(staging), "$STAGING"), (str(project_root), "$PROJECT_ROOT"),
        (str(Path(args.svg_tool_root).resolve()), "$SVG_TOOL_ROOT"),
        (str(Path(args.stair_tool_root).resolve()), "$STAIR_TOOL_ROOT") if args.stair_tool_root else ("", ""),
        (str(Path(args.python).resolve()), "$PYTHON"),
    ]
    sanitize_generated_metadata(staging, replacements)
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        return execute(args)
    except RegenerationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
