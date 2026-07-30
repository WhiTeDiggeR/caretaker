#!/usr/bin/env python3
"""Static source checks for the complex v3 Godot blockout."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
VERTICAL = ROOT / "docs/design/complex_v3/handoff/vertical/vertical-transitions.json"
SCENE_DIR = ROOT / "scenes/complex_v3_blockout"


def main() -> int:
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    vertical = json.loads(VERTICAL.read_text(encoding="utf-8"))
    errors: list[str] = []
    expected_files = {
        "complex_v3_blockout.gd",
        "complex_v3_assembly.gd",
        "complex_v3_blockout.tscn",
        "complex_v3_zone.tscn",
        "complex_v3_infrastructure.tscn",
        "sector_catalog.json",
        "complex_v3_blockout_test.gd",
        "complex_v3_blockout_test.tscn",
        "complex_v3_blockout_check.gd",
        "complex_v3_portal_check.gd",
        "complex_v3_sector_check.gd",
        "complex_v3_visual_check.gd",
        "complex_v3_editor_preview_check.gd",
        "complex_v3_editor_preview_check.tscn",
    }
    missing = sorted(name for name in expected_files if not (SCENE_DIR / name).is_file())
    if missing:
        errors.append(f"missing blockout files: {missing}")
    if handoff.get("status") != "verified" or handoff.get("units") != "m":
        errors.append("geometry handoff must be verified and metric")
    expected_spaces = sum(len(sector["space_ids"]) for sector in handoff.get("sectors", []))
    if len(handoff.get("spaces", [])) != expected_spaces:
        errors.append(f"handoff must contain {expected_spaces} passport-declared room spaces")
    if len(handoff.get("route_spaces", [])) != 7:
        errors.append("handoff must contain 7 route spaces")
    if len(vertical.get("anchors", [])) != 7:
        errors.append("vertical handoff must contain 7 anchors")
    if len(vertical.get("transitions", [])) != 8:
        errors.append("vertical handoff must contain 8 transition records")
    script = (SCENE_DIR / "complex_v3_blockout.gd").read_text(encoding="utf-8")
    for required in ("internal_portals", "external_portals", "connection_corridors", "controlled_technical_transitions"):
        if required not in script:
            errors.append(f"builder does not consume {required}")
    startup = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/underground_research_complex.tscn"' not in startup:
        errors.append("startup scene changed unexpectedly")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print("OK: blockout source is linked to the verified metric handoff; startup scene is unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
