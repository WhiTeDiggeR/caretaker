#!/usr/bin/env python3
"""Validate the fixture-only Generated/AuthoredContent scene contract."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BLOCKOUT = ROOT / "scenes" / "complex_v3_blockout"
FIXTURES = BLOCKOUT / "fixtures"


def main() -> int:
    errors: list[str] = []
    wrapper_script = (BLOCKOUT / "complex_v3_sector_wrapper.gd").read_text(encoding="utf-8")
    builder_script = (BLOCKOUT / "complex_v3_blockout.gd").read_text(encoding="utf-8")
    base_scene = (BLOCKOUT / "complex_v3_zone.tscn").read_text(encoding="utf-8")
    fixture = (FIXTURES / "sector_wrapper_fixture.tscn").read_text(encoding="utf-8")
    authored = (FIXTURES / "authored_content_fixture.tscn").read_text(encoding="utf-8")
    architecture = (FIXTURES / "generated_architecture_fixture.tscn").read_text(encoding="utf-8")
    stairs = (FIXTURES / "generated_stairs_fixture.tscn").read_text(encoding="utf-8")

    if not wrapper_script.startswith("@tool\nextends Node3D\nclass_name ComplexV3SectorWrapper\n"):
        errors.append("sector wrapper must be a Godot editor-aware Node3D class")
    if not builder_script.startswith('@tool\nextends "res://scenes/complex_v3_blockout/complex_v3_sector_wrapper.gd"\n'):
        errors.append("legacy blockout builder must inherit the regeneration wrapper")
    for token in (
        'metadata/regeneration_contract_version = "1.0.0"',
        'metadata/generated_owner = "regenerator"',
        'metadata/authored_content_owner = "author"',
    ):
        if token not in base_scene:
            errors.append(f"base zone scene is missing contract metadata: {token}")
    expected_resources = (
        "generated_architecture_fixture.tscn",
        "generated_stairs_fixture.tscn",
        "authored_content_fixture.tscn",
    )
    for resource in expected_resources:
        if fixture.count(resource) != 1:
            errors.append(f"wrapper fixture must reference {resource} exactly once")
    if '[node name="AuthoredContent" type="Node3D"]' not in authored:
        errors.append("manual layer must be rooted in its own AuthoredContent scene")
    if "Generated" in authored or "EditorPreview" in authored:
        errors.append("authored scene must not serialize Generated or EditorPreview")
    if "AuthoredContent" in architecture or "AuthoredContent" in stairs:
        errors.append("generated resources must not contain authored content")
    if "StaticBody3D" not in architecture or "StaticBody3D" not in stairs:
        errors.append("fixture generated resources must exercise runtime collision stripping")
    if "staging.name = GENERATED_NAME" not in wrapper_script or "previous.free()" not in wrapper_script:
        errors.append("wrapper must replace only the Generated root after staging is built")
    if "_strip_preview_physics(preview)" not in wrapper_script:
        errors.append("wrapper must strip collision from transient editor preview")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print("OK: fixture separates generated architecture, generated stairs, authored content and transient preview")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
