from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BLOCKOUT_DIR = ROOT / "scenes" / "complex_v3_blockout"
PASSPORTS_PATH = ROOT / "docs" / "design" / "complex_v3" / "handoff" / "passports" / "sector-passports.json"
GEOMETRY_PATH = ROOT / "docs" / "design" / "complex_v3" / "handoff" / "geometry" / "complex-handoff.json"
LEVEL_FOLDERS = {"LV-U": "upper", "LV-L": "lower", "LV-T": "technical"}


def scene_slug(sector_id: str) -> str:
    return sector_id.lower().replace("-", "_")


def node_name(sector_id: str) -> str:
    return sector_id.replace("-", "_")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def main() -> None:
    passports_data = json.loads(PASSPORTS_PATH.read_text(encoding="utf-8"))
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    passports = sorted(passports_data["passports"], key=lambda item: item["sector_id"])
    space_counts: dict[str, int] = {}
    for space in geometry["spaces"]:
        sector_id = space["sector_id"]
        space_counts[sector_id] = space_counts.get(sector_id, 0) + 1

    catalog = {
        "schema_version": "1.0",
        "map_id": geometry["map_id"],
        "source_artifact_id": geometry["artifact_id"],
        "sector_count": len(passports),
        "space_count": sum(space_counts.values()),
        "sectors": [],
    }
    created_scenes = 0
    assembly_resources = [
        '[ext_resource type="Script" path="res://scenes/complex_v3_blockout/complex_v3_assembly.gd" id="1_assembly"]',
        '[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/complex_v3_infrastructure.tscn" id="2_infrastructure"]',
    ]
    assembly_nodes: list[str] = []
    for index, passport in enumerate(passports, start=3):
        sector_id = passport["sector_id"]
        level = passport["level"]
        folder = LEVEL_FOLDERS[level]
        relative_path = f"zones/{folder}/{scene_slug(sector_id)}.tscn"
        resource_path = f"res://scenes/complex_v3_blockout/{relative_path}"
        wrapper = "\n".join(
            [
                "[gd_scene load_steps=2 format=3]",
                "",
                '[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/complex_v3_zone.tscn" id="1_zone"]',
                "",
                f'[node name="{node_name(sector_id)}" instance=ExtResource("1_zone")]',
                f'sector_ids = PackedStringArray("{sector_id}")',
                "editor_preview_enabled = true",
                'preview_shared_infrastructure_when_standalone = true' if sector_id == "T-CIRCULATION" else "",
                "",
                '[node name="AuthoredContent" type="Node3D" parent="."]',
                f'metadata/sector_id = "{sector_id}"',
                "",
            ]
        )
        scene_file = BLOCKOUT_DIR / relative_path
        if not scene_file.exists():
            write_text(scene_file, wrapper)
            created_scenes += 1
        else:
            existing = scene_file.read_text(encoding="utf-8")
            if "editor_preview_enabled = true" not in existing:
                marker = f'sector_ids = PackedStringArray("{sector_id}")\n'
                existing = existing.replace(marker, marker + "editor_preview_enabled = true\n", 1)
                write_text(scene_file, existing)
        catalog["sectors"].append(
            {
                "sector_id": sector_id,
                "level": level,
                "scene": resource_path,
                "space_count": space_counts.get(sector_id, 0),
                "neighbors": sorted(passport.get("neighbors", [])),
                "focus_xyz": [
                    (passport["parent_boundary_xz"][0] + passport["parent_boundary_xz"][2]) / 2,
                    passport["local_origin_xyz"][1] + 1.1,
                    (passport["parent_boundary_xz"][1] + passport["parent_boundary_xz"][3]) / 2,
                ],
                "standalone_infrastructure_preview": sector_id == "T-CIRCULATION",
            }
        )
        resource_id = f"{index:02d}_{scene_slug(sector_id)}"
        assembly_resources.append(
            f'[ext_resource type="PackedScene" path="{resource_path}" id="{resource_id}"]'
        )
        assembly_nodes.append(
            f'[node name="{node_name(sector_id)}" parent="Zones" instance=ExtResource("{resource_id}")]'
        )

    assembly = "\n".join(
        [
            f"[gd_scene load_steps={len(assembly_resources) + 1} format=3]",
            "",
            *assembly_resources,
            "",
            '[node name="ComplexV3Blockout" type="Node3D"]',
            'script = ExtResource("1_assembly")',
            "",
            '[node name="Zones" type="Node3D" parent="."]',
            "",
            *assembly_nodes,
            "",
            '[node name="Infrastructure" parent="." instance=ExtResource("2_infrastructure")]',
            "",
        ]
    )
    write_text(BLOCKOUT_DIR / "complex_v3_blockout.tscn", assembly)
    write_text(
        BLOCKOUT_DIR / "sector_catalog.json",
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
    )
    print(
        f"OK: indexed {len(passports)} sector scenes with "
        f"{sum(space_counts.values())} spaces; created {created_scenes} missing scenes"
    )


if __name__ == "__main__":
    main()
