#!/usr/bin/env python3
"""Validate persistent set-dressing identities, bindings, and authored corrections."""

from __future__ import annotations

import json
from pathlib import Path

from set_dressing_migration import parse_scene_transforms


ROOT = Path(__file__).resolve().parents[3]
SET_DRESSING = ROOT / "scenes/complex_v3_blockout/set_dressing"
BINDINGS = ROOT / "scenes/complex_v3_blockout/bindings"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    manifest = load(SET_DRESSING / "set_dressing_manifest.json")
    corrections = load(SET_DRESSING / "authored_corrections.json")
    report = load(SET_DRESSING / "migration/migration_report.json")
    errors = []
    if manifest.get("schema_id") != "caretaker.set_dressing_manifest" or manifest.get("schema_version") != "2.0.0":
        errors.append("manifest must use caretaker.set_dressing_manifest 2.0.0")
    placements = [placement for sector in manifest["sectors"] for placement in sector["placements"]]
    object_ids = [str(placement.get("object_id", "")) for placement in placements]
    placement_ids = [str(placement.get("id", "")) for placement in placements]
    if "" in object_ids or len(object_ids) != len(set(object_ids)):
        errors.append("persistent object_id values must be non-empty and globally unique")
    if "" in placement_ids or len(placement_ids) != len(set(placement_ids)):
        errors.append("legacy placement IDs must be non-empty and preserved uniquely")
    correction_ids = {str(item["object_id"]) for item in corrections.get("objects", [])}
    if correction_ids != set(object_ids):
        errors.append("authored corrections must cover exactly the manifest object IDs")
    modes = {mode: 0 for mode in ("anchor", "unresolved", "free")}
    binding_ids = set()
    bound_objects = set()
    for sector in manifest["sectors"]:
        scene_path = ROOT / sector["dressing_scene"].removeprefix("res://")
        scene_transforms = parse_scene_transforms(scene_path)
        if set(scene_transforms) != {placement["id"] for placement in sector["placements"]}:
            errors.append(f"scene placement set differs from manifest: {sector['sector_id']}")
        document = load(BINDINGS / f"{sector['sector_id'].lower().replace('-', '_')}.bindings.json")
        if document.get("schema_id") != "caretaker.object_bindings" or document.get("sector_id") != sector["sector_id"]:
            errors.append(f"invalid binding document header: {sector['sector_id']}")
        for binding in document.get("bindings", []):
            binding_id = str(binding["binding_id"])
            object_id = str(binding["object_ref"]["object_id"])
            if binding_id in binding_ids:
                errors.append(f"duplicate binding_id: {binding_id}")
            binding_ids.add(binding_id)
            bound_objects.add(object_id)
            if binding["anchor_ref"]["expected_type"] != "door" or not str(binding["anchor_ref"]["anchor_id"]).endswith(":door:center"):
                errors.append(f"portal binding is not an explicit door center: {binding_id}")
        for placement in sector["placements"]:
            mode = str(placement.get("binding", {}).get("mode", ""))
            if mode not in modes:
                errors.append(f"unknown binding mode: {placement['id']}")
                continue
            modes[mode] += 1
            if mode == "anchor" and placement["object_id"] not in bound_objects:
                errors.append(f"missing normative binding: {placement['id']}")
            if mode == "unresolved" and not ("wall_mount_side" in placement or placement["kind"] == "open_portal_frame"):
                errors.append(f"unresolved object lacks source evidence: {placement['id']}")
    if modes != {"anchor": 0, "unresolved": 211, "free": 145}:
        errors.append(f"unexpected migration classification counts: {modes}")
    unresolved_report_ids = {item["object_id"] for item in report.get("unresolved_bindings", [])}
    manifest_unresolved_ids = {placement["object_id"] for placement in placements if placement["binding"]["mode"] == "unresolved"}
    if unresolved_report_ids != manifest_unresolved_ids:
        errors.append("migration report must list every and only unresolved binding")
    if errors:
        raise SystemExit("Set-dressing migration validation failed:\n- " + "\n- ".join(errors))
    print(f"SET_DRESSING_MIGRATION_OK objects={len(object_ids)} bindings={len(binding_ids)} unresolved={modes['unresolved']} free={modes['free']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
