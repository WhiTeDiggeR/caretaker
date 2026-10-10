#!/usr/bin/env python3
"""Stable identities, authored corrections, and transform audits for set dressing."""

from __future__ import annotations

import hashlib
import json
import math
import re
import os
import tempfile
from pathlib import Path
from typing import Any


IDENTITY_CORRECTION = {
    "translation_m": [0.0, 0.0, 0.0],
    "rotation_y_rad": 0.0,
    "scale_multiplier": [1.0, 1.0, 1.0],
}
VECTOR_RE = re.compile(r"Vector3\(([^)]+)\)")


def stable_id(prefix: str, placement_id: str) -> str:
    digest = hashlib.sha256(placement_id.encode("utf-8")).hexdigest()[:20].upper()
    return f"{prefix}-{digest}"


def object_id_for(placement_id: str) -> str:
    return stable_id("OBJ-SET", placement_id)


def binding_id_for(placement_id: str) -> str:
    return stable_id("BIND-SET", placement_id)


def seed_transform(placement: dict[str, Any]) -> dict[str, Any]:
    return {
        "position": [float(value) for value in placement["position"]],
        "rotation_y": float(placement.get("rotation_y", 0.0)),
        "scale": [float(value) for value in placement.get("scale", [1.0, 1.0, 1.0])],
    }


def normalize_correction(value: dict[str, Any] | None) -> dict[str, Any]:
    value = value or {}
    return {
        "translation_m": [float(item) for item in value.get("translation_m", [0.0, 0.0, 0.0])],
        "rotation_y_rad": float(value.get("rotation_y_rad", 0.0)),
        "scale_multiplier": [float(item) for item in value.get("scale_multiplier", [1.0, 1.0, 1.0])],
    }


def apply_correction(seed: dict[str, Any], correction: dict[str, Any]) -> dict[str, Any]:
    correction = normalize_correction(correction)
    return {
        "position": [seed["position"][index] + correction["translation_m"][index] for index in range(3)],
        "rotation_y": seed["rotation_y"] + correction["rotation_y_rad"],
        "scale": [seed["scale"][index] * correction["scale_multiplier"][index] for index in range(3)],
    }


def correction_between(seed: dict[str, Any], actual: dict[str, Any]) -> dict[str, Any]:
    multipliers = []
    for old, new in zip(seed["scale"], actual["scale"]):
        multiplier = new / old if not math.isclose(old, 0.0, abs_tol=1e-12) else 1.0
        multipliers.append(1.0 if math.isclose(multiplier, 1.0, abs_tol=5e-5) else multiplier)
    translations = [actual["position"][index] - seed["position"][index] for index in range(3)]
    translations = [0.0 if math.isclose(value, 0.0, abs_tol=5e-5) else value for value in translations]
    rotation = actual["rotation_y"] - seed["rotation_y"]
    return {
        "translation_m": translations,
        "rotation_y_rad": 0.0 if math.isclose(rotation, 0.0, abs_tol=5e-8) else rotation,
        "scale_multiplier": multipliers,
    }


def _vector(line: str) -> list[float]:
    match = VECTOR_RE.search(line)
    if match is None:
        raise ValueError(f"invalid Vector3 line: {line}")
    values = [float(value.strip()) for value in match.group(1).split(",")]
    if len(values) != 3 or not all(math.isfinite(value) for value in values):
        raise ValueError(f"invalid finite Vector3: {line}")
    return values


def parse_scene_transforms(path: Path) -> dict[str, dict[str, Any]]:
    """Read placement transforms from legacy instances or authored wrappers."""
    result: dict[str, dict[str, Any]] = {}
    block: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines() + ["[node flush]"]:
        if line.startswith("[node ") and block:
            header = next((item for item in block if item.startswith("[node ")), "")
            placement_line = next((item for item in block if item.startswith('metadata/placement_id = "')), None)
            transform_lines = [item for item in block if re.match(r"^(transform|quaternion|rotation_degrees|top_level)\s*=", item)]
            if transform_lines:
                raise ValueError(f"{path}: unsupported transform serialization; use Godot audit, not a lossy text conversion")
            if placement_line is not None:
                placement_id = json.loads(placement_line.split(" = ", 1)[1])
                if not placement_id or placement_id in result:
                    raise ValueError(f"{path}: empty or duplicate placement ID: {placement_id}")
                if 'parent="."' not in header:
                    raise ValueError(f"{path}: non-root placement parent requires explicit migration")
                position_line = next((item for item in block if item.startswith("position = Vector3")), None)
                rotation_line = next((item for item in block if item.startswith("rotation = Vector3")), None)
                scale_line = next((item for item in block if item.startswith("scale = Vector3")), None)
                rotation = _vector(rotation_line) if rotation_line else [0.0, 0.0, 0.0]
                if rotation[0] != 0.0 or rotation[2] != 0.0:
                    raise ValueError(f"{path}: pitch/roll requires full Godot transform migration")
                result[placement_id] = {
                    "position": _vector(position_line) if position_line else [0.0, 0.0, 0.0],
                    "rotation_y": rotation[1],
                    "scale": _vector(scale_line) if scale_line else [1.0, 1.0, 1.0],
                }
            elif header:
                if any(re.match(r"^(position|rotation|scale)\s*=", item) for item in block):
                    raise ValueError(f"{path}: transformed parent/Content requires full Godot audit")
                if 'parent="."' in header or ('parent=' in header and 'name="Content"' not in header):
                    raise ValueError(f"{path}: extra authored node requires explicit migration")
            block = []
        block.append(line)
    return result


def snapshot(root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    objects = []
    for sector in manifest["sectors"]:
        scene_path = root / sector["dressing_scene"].removeprefix("res://")
        transforms = parse_scene_transforms(scene_path)
        if set(transforms) != {item["id"] for item in sector["placements"]}:
            raise ValueError(f"{scene_path}: scene/manifest placement sets differ")
        for placement in sector["placements"]:
            placement_id = placement["id"]
            if placement_id not in transforms:
                raise ValueError(f"{scene_path}: missing placement node {placement_id}")
            objects.append({
                "object_id": placement.get("object_id", object_id_for(placement_id)),
                "placement_id": placement_id,
                "sector_id": sector["sector_id"],
                "transform": transforms[placement_id],
            })
    objects.sort(key=lambda item: item["object_id"])
    if len({item["object_id"] for item in objects}) != len(objects):
        raise ValueError("duplicate persistent object ID in snapshot")
    return {
        "schema_id": "caretaker.set_dressing_transform_snapshot",
        "schema_version": "1.0.0",
        "map_id": "caretaker-complex-v3",
        "object_count": len(objects),
        "objects": objects,
    }


def validate_legacy_scene(path: Path, sector: dict[str, Any]) -> None:
    """Block bootstrap if it cannot preserve a legacy edit rather than guess."""
    text = path.read_text(encoding="utf-8")
    resources = dict((resource_id, resource_path) for resource_path, resource_id in re.findall(
        r'\[ext_resource type="PackedScene" path="([^"]+)" id="([^"]+)"\]', text
    ))
    placements = {item["id"]: item for item in sector["placements"]}
    for block in re.split(r"(?=^\[node )", text, flags=re.MULTILINE)[1:]:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        header = lines[0]
        fields = {}
        for line in lines[1:]:
            if " = " not in line:
                raise ValueError(f"{path}: unsupported scene section")
            key, value = line.split(" = ", 1)
            if key in fields:
                raise ValueError(f"{path}: duplicate property {key}")
            fields[key] = value
        allowed = {"position", "rotation", "scale", "metadata/placement_id", "metadata/open_passage", "metadata/sector_id", "metadata/material_family"}
        if set(fields) - allowed:
            raise ValueError(f"{path}: authored properties require explicit migration: {sorted(set(fields) - allowed)}")
        if "metadata/placement_id" in fields:
            placement_id = json.loads(fields["metadata/placement_id"])
            instance = re.search(r'instance=ExtResource\("([^"]+)"\)', header)
            if instance is None or placement_id not in placements or resources.get(instance.group(1)) != placements[placement_id]["scene"]:
                raise ValueError(f"{path}: authored asset differs from manifest")


def compare_snapshots(before: dict[str, Any], after: dict[str, Any], tolerance: float = 1e-5) -> dict[str, Any]:
    before_by_id = {item["object_id"]: item for item in before["objects"]}
    after_by_id = {item["object_id"]: item for item in after["objects"]}
    if len(before_by_id) != len(before["objects"]) or len(after_by_id) != len(after["objects"]):
        raise ValueError("duplicate object IDs cannot be audited")
    issues = []
    max_delta = 0.0
    for object_id in sorted(set(before_by_id) | set(after_by_id)):
        if object_id not in before_by_id or object_id not in after_by_id:
            issues.append({"object_id": object_id, "reason": "object_set_changed"})
            continue
        left = before_by_id[object_id]["transform"]
        right = after_by_id[object_id]["transform"]
        deltas = [abs(a - b) for key in ("position", "scale") for a, b in zip(left[key], right[key])]
        deltas.append(abs(left["rotation_y"] - right["rotation_y"]))
        object_delta = max(deltas)
        max_delta = max(max_delta, object_delta)
        if object_delta > tolerance:
            issues.append({"object_id": object_id, "reason": "transform_changed", "max_delta": object_delta})
    return {
        "tolerance": tolerance,
        "max_delta": max_delta,
        "status": "passed" if not issues else "failed",
        "issues": issues,
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
