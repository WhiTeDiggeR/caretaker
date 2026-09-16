#!/usr/bin/env python3
"""Validate the 30 canonical metric SVG inputs and run strict tool preflight."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/complex_v3_regeneration/sector_generation_manifest.json"
CANONICAL_PREFIX = "docs/design/complex_v3/plans/generation/"
DRAWABLE = {"rect", "line", "polyline", "polygon", "path", "circle", "ellipse", "text"}
LEVEL_ELEVATION = {"LV-U": 0.0, "LV-L": -6.0, "LV-T": -11.5}
SETTINGS_MANIFESTS = [
    ROOT / "tools/complex_v3_regeneration/rollouts/upper_generation_manifest.json",
    ROOT / "tools/complex_v3_regeneration/rollouts/lower_generation_manifest.json",
    ROOT / "tools/complex_v3_regeneration/rollouts/technical_generation_manifest.json",
    ROOT / "tools/complex_v3_regeneration/pilots/u_medbay/pilot_generation_manifest.json",
    ROOT / "tools/complex_v3_regeneration/pilots/route_a_vertical/pilot_generation_manifest.json",
]


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def validate_structure(project_root: Path, manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    sectors = manifest.get("sectors", [])
    if manifest.get("sector_count") != 30 or len(sectors) != 30:
        errors.append("production manifest must contain exactly 30 sectors")
    sector_ids = [str(item.get("sector_id", "")) for item in sectors]
    if len(sector_ids) != len(set(sector_ids)):
        errors.append("production manifest contains duplicate sector IDs")
    sources = [str(item.get("source_svg", "")) for item in sectors]
    if len(sources) != len(set(sources)):
        errors.append("each sector must own one unique canonical SVG")
    for sector, relative in zip(sectors, sources):
        label = str(sector.get("sector_id", relative))
        if not relative.startswith(CANONICAL_PREFIX):
            errors.append(f"{label}: source is outside canonical generation tree: {relative}")
            continue
        source = project_root / relative
        if not source.is_file():
            errors.append(f"{label}: canonical SVG is missing: {relative}")
            continue
        try:
            root = ET.parse(source).getroot()
        except ET.ParseError as exc:
            errors.append(f"{label}: invalid XML: {exc}")
            continue
        if root.get("data-generator-input") != "true" or root.get("data-presentation-only") != "false":
            errors.append(f"{label}: canonical source policy metadata is missing")
        scale = root.get("data-scale")
        if scale is None or scale == "relative":
            errors.append(f"{label}: data-scale must be an explicit metric number")
        else:
            try:
                if not math.isfinite(float(scale)) or float(scale) <= 0:
                    raise ValueError
            except ValueError:
                errors.append(f"{label}: invalid data-scale {scale!r}")
        ids: list[str] = []
        for element in root.iter():
            if local_name(element.tag) not in DRAWABLE:
                continue
            element_id = element.get("id")
            semantic = element.get("data-godot-type")
            if not element_id:
                errors.append(f"{label}: drawable <{local_name(element.tag)}> has no stable id")
            else:
                ids.append(element_id)
            if not semantic:
                errors.append(f"{label}: {element_id or local_name(element.tag)} has no explicit data-godot-type")
            if semantic == "floor" and not element.get("data-space-id"):
                errors.append(f"{label}: floor {element_id} has no data-space-id")
            if element.get("data-anchor-role") and not element.get("data-anchor-id"):
                errors.append(f"{label}: explicit anchor {element_id} has no data-anchor-id")
        if len(ids) != len(set(ids)):
            errors.append(f"{label}: duplicate SVG ids")
    return errors


def production_settings() -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for path in SETTINGS_MANIFESTS:
        for sector in json.loads(path.read_text(encoding="utf-8"))["sectors"]:
            result[sector["sector_id"]] = sector
    result["T-CIRCULATION"] = {
        "profile": "generic",
        "metric_settings": {"scale_m_per_svg_unit": 1.0, "origin": "none", "elevation_m": -11.5},
        "shared_args": ["--wall-thickness", "0.3", "--floor-thickness", "0.2", "--ceiling-thickness", "0.2", "--strict-wall-overlaps"],
    }
    return result


def strict_preflight(project_root: Path, manifest: dict[str, Any], tool_root: Path) -> tuple[list[dict[str, Any]], list[str], str]:
    inspector = tool_root / "inspect_svg_plan.py"
    if not inspector.is_file():
        return [], [f"inspector not found: {inspector}"], "unavailable"
    version_run = subprocess.run([sys.executable, str(inspector), "--version"], text=True, encoding="utf-8", errors="replace", capture_output=True)
    version = version_run.stdout.strip() if version_run.returncode == 0 else "unavailable"
    results: list[dict[str, Any]] = []
    errors: list[str] = []
    settings_by_sector = production_settings()
    with tempfile.TemporaryDirectory(prefix="complex-v3-canonical-preflight-") as temporary:
        temporary_root = Path(temporary)
        for sector in sorted(manifest["sectors"], key=lambda item: item["sector_id"]):
            source = project_root / sector["source_svg"]
            report_path = temporary_root / f"{sector['sector_id']}.json"
            settings = settings_by_sector.get(sector["sector_id"])
            if settings is None:
                errors.append(f"{sector['sector_id']}: production conversion settings are missing")
                continue
            metric = settings["metric_settings"]
            command = [
                sys.executable, str(inspector), str(source),
                "--profile", str(settings.get("profile", "generic")),
                "--scale", str(metric["scale_m_per_svg_unit"]),
                "--origin", str(metric["origin"]),
                "--elevation", str(metric["elevation_m"]),
                *[str(value) for value in settings.get("shared_args", [])],
                "--strict", "--output-json", str(report_path),
            ]
            completed = subprocess.run(command, text=True, encoding="utf-8", errors="replace", capture_output=True)
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else {}
            summary = report.get("summary", {})
            item = {
                "sector_id": sector["sector_id"],
                "source_svg": sector["source_svg"],
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "exit_code": completed.returncode,
                "recognized": int(summary.get("recognized", 0)),
                "explicitly_ignored": int(summary.get("explicitly_ignored", 0)),
                "unrecognized": int(summary.get("unrecognized", 0)),
                "invalid": int(summary.get("invalid", 0)),
                "warnings": report.get("warnings", []),
            }
            results.append(item)
            if completed.returncode != 0 or item["unrecognized"] or item["invalid"]:
                errors.append(f"{sector['sector_id']}: strict preflight failed with exit {completed.returncode}")
    return results, errors, version


def conversion_regression(project_root: Path, tool_root: Path) -> tuple[dict[str, Any], list[str]]:
    converter = tool_root / "svg_to_godot3d.py"
    inspector = tool_root / "inspect_svg_plan.py"
    errors: list[str] = []
    result: dict[str, Any] = {"sector_id": "U-CONTROL", "noop_byte_equivalent": False, "stable_anchor_id": False, "geometry_changed": False}
    with tempfile.TemporaryDirectory(prefix=".t19-conversion-", dir=project_root) as temporary:
        temporary_root = Path(temporary)
        source = temporary_root / "u_control.svg"
        output = temporary_root / "generated"
        shutil.copy2(project_root / "docs/design/complex_v3/plans/generation/upper/u_control.svg", source)
        common = [
            "--profile", "generic", "--scale", "1", "--origin", "none", "--elevation", "0",
            "--wall-thickness", ".3", "--floor-thickness", ".2", "--ceiling-thickness", ".2",
            "--strict", "--strict-wall-overlaps", "--strict-ceiling-alignment",
        ]
        command = [sys.executable, str(converter), str(source), str(output), "--project-root", str(project_root), "--scene-name", "t19_control", *common]
        first = subprocess.run(command, text=True, encoding="utf-8", errors="replace", capture_output=True)
        if first.returncode != 0:
            return result, ["U-CONTROL: first conversion failed"]
        excluded = {"conversion_report.json"}
        before = {path.relative_to(output).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in output.rglob("*") if path.is_file() and path.name not in excluded}
        second = subprocess.run(command, text=True, encoding="utf-8", errors="replace", capture_output=True)
        after = {path.relative_to(output).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in output.rglob("*") if path.is_file() and path.name not in excluded}
        result["noop_file_count"] = len(before)
        result["noop_byte_equivalent"] = before == after
        if before != after:
            errors.append("U-CONTROL: repeated conversion changed generated bytes")

        original_report = temporary_root / "original-inspection.json"
        moved_report = temporary_root / "moved-inspection.json"
        inspect_common = [*common[:-2]]  # semantic strict; geometry may intentionally stop meeting a neighbour.
        original = subprocess.run([sys.executable, str(inspector), str(source), *inspect_common, "--output-json", str(original_report)], text=True, encoding="utf-8", errors="replace", capture_output=True)
        tree = ET.parse(source)
        wall = next(element for element in tree.getroot().iter() if element.get("data-godot-type") == "wall" and element.get("x2") is not None)
        wall_id = str(wall.get("id"))
        old_x2 = str(wall.get("x2"))
        new_x2 = f"{float(old_x2) - 0.125:g}"
        source_text = source.read_text(encoding="utf-8")
        pattern = rf'(<line\s+id="{re.escape(wall_id)}"[^>]*\bx2="){re.escape(old_x2)}(")'
        moved_text, replacements = re.subn(pattern, rf"\g<1>{new_x2}\g<2>", source_text, count=1)
        if replacements != 1:
            return result, ["U-CONTROL: could not apply deterministic wall move"]
        with source.open("w", encoding="utf-8", newline="\n") as stream:
            stream.write(moved_text)
        moved = subprocess.run([sys.executable, str(inspector), str(source), *inspect_common, "--output-json", str(moved_report)], text=True, encoding="utf-8", errors="replace", capture_output=True)
        if original.returncode != 0 or moved.returncode != 0:
            errors.append("U-CONTROL: move regression inspection failed")
        else:
            original_frames = {item["anchor_id"]: item for item in json.loads(original_report.read_text(encoding="utf-8"))["spatial_handoff"]["anchor_frames"]}
            moved_frames = {item["anchor_id"]: item for item in json.loads(moved_report.read_text(encoding="utf-8"))["spatial_handoff"]["anchor_frames"]}
            anchor_id = f"svg:{wall_id}:wall"
            result["anchor_id"] = anchor_id
            result["stable_anchor_id"] = anchor_id in original_frames and anchor_id in moved_frames
            result["geometry_changed"] = result["stable_anchor_id"] and original_frames[anchor_id]["geometry_hash"] != moved_frames[anchor_id]["geometry_hash"]
            if not result["stable_anchor_id"]:
                errors.append("U-CONTROL: moving a wall lost its stable anchor ID")
            if not result["geometry_changed"]:
                errors.append("U-CONTROL: moving a wall did not change anchor geometry")
    return result, errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--svg-tool-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    errors = validate_structure(ROOT, manifest)
    results: list[dict[str, Any]] = []
    regression: dict[str, Any] = {}
    version = "not-run"
    if not errors:
        results, preflight_errors, version = strict_preflight(ROOT, manifest, args.svg_tool_root.resolve())
        errors.extend(preflight_errors)
    if not errors:
        regression, regression_errors = conversion_regression(ROOT, args.svg_tool_root.resolve())
        errors.extend(regression_errors)
    report = {
        "schema_id": "caretaker.canonical_svg_preflight",
        "schema_version": "1.0.0",
        "map_id": manifest.get("map_id"),
        "status": "ready" if not errors else "blocked",
        "inspector_version": version,
        "sector_count": len(results),
        "canonical_root": CANONICAL_PREFIX.rstrip("/"),
        "results": results,
        "conversion_regression": regression,
        "errors": errors,
    }
    write_json(args.report.resolve(), report)
    print(f"CANONICAL_SVG_PREFLIGHT status={report['status']} sectors={len(results)} errors={len(errors)}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
