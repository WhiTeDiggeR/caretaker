from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BLOCKOUT_DIR = ROOT / "scenes" / "complex_v3_blockout"
PASSPORTS_PATH = ROOT / "docs" / "design" / "complex_v3" / "handoff" / "passports" / "sector-passports.json"
GEOMETRY_PATH = ROOT / "docs" / "design" / "complex_v3" / "handoff" / "geometry" / "complex-handoff.json"
GENERATION_MANIFEST_PATH = ROOT / "tools" / "complex_v3_regeneration" / "sector_generation_manifest.json"
LEVEL_FOLDERS = {"LV-U": "upper", "LV-L": "lower", "LV-T": "technical"}
PLAN_ALIGNED_FOCUS_SECTORS = {"U-CONTROL", "U-DOMESTIC", "U-EAST-SUPPORT", "U-FREIGHT", "U-MEDBAY", "U-ROUTE-A"}
FOCUS_OVERRIDES = {
    "L-OLD-CORE": [-73.0, -4.9, 3.5],
    "T-EAST-VERTICAL": [25.0, -10.4, 4.0],
    "U-ROUTE-A": [-54.5, 1.1, 3.5],
}


def scene_slug(sector_id: str) -> str:
    return sector_id.lower().replace("-", "_")


def node_name(sector_id: str) -> str:
    return sector_id.replace("-", "_")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def existing_scene_uid(path: Path) -> str:
    if not path.exists():
        return ""
    first_line = path.read_text(encoding="utf-8").splitlines()[0]
    match = re.search(r'\buid="([^"]+)"', first_line)
    return f' uid="{match.group(1)}"' if match else ""


def main() -> None:
    passports_data = json.loads(PASSPORTS_PATH.read_text(encoding="utf-8"))
    geometry = json.loads(GEOMETRY_PATH.read_text(encoding="utf-8"))
    generation_manifest = json.loads(GENERATION_MANIFEST_PATH.read_text(encoding="utf-8"))
    generation_by_sector = {item["sector_id"]: item for item in generation_manifest["sectors"]}
    passports = sorted(passports_data["passports"], key=lambda item: item["sector_id"])
    space_counts: dict[str, int] = {}
    sector_bounds: dict[str, list[float]] = {}
    for space in geometry["spaces"]:
        sector_id = space["sector_id"]
        space_counts[sector_id] = space_counts.get(sector_id, 0) + 1
        x0, z0, x1, z1 = map(float, space["bounds_xz"])
        if sector_id not in sector_bounds:
            sector_bounds[sector_id] = [x0, z0, x1, z1]
        else:
            bounds = sector_bounds[sector_id]
            bounds[0] = min(bounds[0], x0)
            bounds[1] = min(bounds[1], z0)
            bounds[2] = max(bounds[2], x1)
            bounds[3] = max(bounds[3], z1)

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
        focus_bounds = (
            sector_bounds.get(sector_id, passport["parent_boundary_xz"])
            if sector_id in PLAN_ALIGNED_FOCUS_SECTORS
            else passport["parent_boundary_xz"]
        )
        folder = LEVEL_FOLDERS[level]
        relative_path = f"zones/{folder}/{scene_slug(sector_id)}.tscn"
        resource_path = f"res://scenes/complex_v3_blockout/{relative_path}"
        generation = generation_by_sector[sector_id]
        package_root = generation["output_resource_dir"]
        architecture_path = f'{package_root}/Generated/Architecture/{generation["scene_name"]}.tscn'
        stair_scene_path = ""
        if generation["vertical_generators"]:
            generator_id = generation["vertical_generators"][0]["generator_id"]
            stair_scene_path = f"{package_root}/Generated/Stairs/{generator_id}/{generator_id}.tscn"
        load_steps = 6 if stair_scene_path else 5
        stair_resource = (
            f'[ext_resource type="PackedScene" path="{stair_scene_path}" id="5_stairs"]'
            if stair_scene_path else ""
        )
        stair_property = 'generated_stairs_scene = ExtResource("5_stairs")' if stair_scene_path else ""
        stair_node = (
            '[node name="Stairs" parent="Generated" instance=ExtResource("5_stairs")]'
            if stair_scene_path else '[node name="Stairs" type="Node3D" parent="Generated"]'
        )
        scene_file = BLOCKOUT_DIR / relative_path
        scene_uid = existing_scene_uid(scene_file)
        wrapper = "\n".join(
            [
                f"[gd_scene load_steps={load_steps} format=3{scene_uid}]",
                "",
                '[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/complex_v3_zone.tscn" id="1_zone"]',
                f'[ext_resource type="PackedScene" path="res://scenes/complex_v3_blockout/set_dressing/sectors/{scene_slug(sector_id)}_dressing.tscn" id="2_dressing"]',
                f'[ext_resource type="PackedScene" path="{architecture_path}" id="3_architecture"]',
                '[ext_resource type="Script" path="res://scenes/complex_v3_regeneration/anchor_registry.gd" id="4_anchor_registry"]',
                stair_resource,
                "",
                f'[node name="{node_name(sector_id)}" instance=ExtResource("1_zone")]',
                f'sector_ids = PackedStringArray("{sector_id}")',
                "geometry_source = 1",
                'generated_architecture_scene = ExtResource("3_architecture")',
                stair_property,
                'authored_content_scene = ExtResource("2_dressing")',
                "editor_preview_enabled = false",
                f'metadata/complex_v3_sector_id = "{sector_id}"',
                f'metadata/sector_id = "{sector_id}"',
                "",
                '[node name="Generated" type="Node3D" parent="."]',
                'metadata/content_owner = "regenerator"',
                'metadata/contract_version = "1.0.0"',
                "",
                '[node name="Architecture" parent="Generated" instance=ExtResource("3_architecture")]',
                'metadata/content_owner = "regenerator"',
                "",
                stair_node,
                'metadata/content_owner = "regenerator"',
                "",
                '[node name="AuthoredContent" type="Node3D" parent="."]',
                f'metadata/sector_id = "{sector_id}"',
                'metadata/content_owner = "author"',
                "",
                '[node name="SetDressing" parent="AuthoredContent" instance=ExtResource("2_dressing")]',
                "",
                '[node name="AnchorRegistry" type="Node" parent="."]',
                'script = ExtResource("4_anchor_registry")',
                f'anchor_frames_path = "{package_root}/anchor_frames.json"',
                "",
            ]
        )
        if not scene_file.exists():
            created_scenes += 1
        write_text(scene_file, wrapper)
        catalog["sectors"].append(
            {
                "sector_id": sector_id,
                "level": level,
                "scene": resource_path,
                "space_count": space_counts.get(sector_id, 0),
                "neighbors": sorted(passport.get("neighbors", [])),
                "focus_xyz": FOCUS_OVERRIDES.get(sector_id, [
                    (focus_bounds[0] + focus_bounds[2]) / 2,
                    passport["local_origin_xyz"][1] + 1.1,
                    (focus_bounds[1] + focus_bounds[3]) / 2,
                ]),
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
