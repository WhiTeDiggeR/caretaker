#!/usr/bin/env python3
"""Validate the generated sector-scene composition for complex v3."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCENE_DIR = ROOT / "scenes" / "complex_v3_blockout"
CATALOG_PATH = SCENE_DIR / "sector_catalog.json"
PASSPORTS_PATH = ROOT / "docs/design/complex_v3/handoff/passports/sector-passports.json"
GEOMETRY_PATH = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
ASSEMBLY_PATH = SCENE_DIR / "complex_v3_blockout.tscn"


def main() -> int:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    passports = json.loads(PASSPORTS_PATH.read_text(encoding="utf-8"))["passports"]
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    errors: list[str] = []
    passport_by_sector = {item["sector_id"]: item for item in passports}
    geometry_sectors = {item["sector_id"] for item in geometry["spaces"]}
    catalog_sectors = {item["sector_id"] for item in catalog["sectors"]}
    if len(catalog["sectors"]) != 30 or len(catalog_sectors) != 30:
        errors.append("catalog must contain 30 unique sector scenes")
    if catalog_sectors != set(passport_by_sector):
        errors.append("catalog sector IDs do not match sector passports")
    missing_geometry_sectors = catalog_sectors - geometry_sectors
    extra_geometry_sectors = geometry_sectors - catalog_sectors
    if missing_geometry_sectors != {"T-CIRCULATION"} or extra_geometry_sectors:
        errors.append(
            "catalog sector IDs do not match geometry sectors: "
            f"missing={sorted(missing_geometry_sectors)}, "
            f"extra={sorted(extra_geometry_sectors)}"
        )
    if sum(item["space_count"] for item in catalog["sectors"]) != 139:
        errors.append("catalog space counts do not total 139")

    assembly = ASSEMBLY_PATH.read_text(encoding="utf-8")
    for item in catalog["sectors"]:
        scene_path = item["scene"].replace("res://", "")
        scene_file = ROOT / scene_path
        if not scene_file.is_file():
            errors.append(f"missing sector scene: {scene_path}")
            continue
        content = scene_file.read_text(encoding="utf-8")
        if item["sector_id"] not in content:
            errors.append(f"scene does not declare sector ID: {scene_path}")
        if "complex_v3_zone.tscn" not in content:
            errors.append(f"scene does not instance the common zone base: {scene_path}")
        if '[node name="AuthoredContent" type="Node3D" parent="."]' not in content:
            errors.append(f"scene has no preserved AuthoredContent root: {scene_path}")
        if "editor_preview_enabled = true" not in content:
            errors.append(f"scene does not enable editor preview: {scene_path}")
        if item["sector_id"] == "T-CIRCULATION" and "preview_shared_infrastructure_when_standalone = true" not in content:
            errors.append("T-CIRCULATION must expose the standalone infrastructure preview")
        resource_path = item["scene"]
        if assembly.count(resource_path) != 1:
            errors.append(f"assembly must instance exactly one {resource_path}")
        expected_neighbors = sorted(passport_by_sector[item["sector_id"]].get("neighbors", []))
        if item["neighbors"] != expected_neighbors:
            errors.append(f"neighbor mismatch for {item['sector_id']}")
    if assembly.count("complex_v3_infrastructure.tscn") != 1:
        errors.append("assembly must instance shared infrastructure exactly once")
    builder = (SCENE_DIR / "complex_v3_blockout.gd").read_text(encoding="utf-8")
    assembly_script = (SCENE_DIR / "complex_v3_assembly.gd").read_text(encoding="utf-8")
    if not builder.startswith("@tool\n"):
        errors.append("sector builder must run as an editor tool")
    if "return build_collisions and not Engine.is_editor_hint()" not in builder:
        errors.append("editor preview must not build physics collisions")
    if "editor_preview_show_ceilings := false" not in builder or "not Engine.is_editor_hint() or editor_preview_show_ceilings" not in builder:
        errors.append("editor preview ceilings must be independently hidden by default")
    if not assembly_script.startswith("@tool\n") or "part.editor_preview_enabled = false" not in assembly_script:
        errors.append("full assembly must disable child editor previews")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print("OK: 30 sector scenes match passports, 139 spaces and one shared infrastructure scene")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
