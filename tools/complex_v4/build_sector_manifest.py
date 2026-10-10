#!/usr/bin/env python3
"""Build the single deterministic production manifest for all complex_v4 sectors."""

from __future__ import annotations

import argparse
import copy
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scenes" / "complex_v4" / "sector_catalog.json"
OUTPUT = Path(__file__).with_name("sector_generation_manifest.json")
VERTICAL_DEFINITIONS = Path(__file__).with_name("vertical_definitions.json")
SOURCE_MANIFESTS = (
    Path(__file__).with_name("rollouts") / "lower_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "upper_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "technical_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "u_medbay_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "route_a_generation_manifest.json",
)
LEVEL_CODE = {"LV-U": "u", "LV-L": "l", "LV-T": "t"}


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


CIRCULATION = {  # corridor / trunk owners: sector id -> (level, folder, level code, elevation)
    "T-CIRCULATION": ("LV-T", "technical", "t", -11.5),
    "U-CIRCULATION": ("LV-U", "upper", "u", 0.0),
    "L-CIRCULATION": ("LV-L", "lower", "l", -6.0),
}


def circulation_entry(sector_id: str, parameterization: dict[str, Any]) -> dict[str, Any]:
    level, folder, code, elevation = CIRCULATION[sector_id]
    slug = sector_id.lower().replace("-", "_")
    return {
        "sector_id": sector_id, "level": level, "status": "ready", "blockers": [],
        "source_svg": f"docs/design/complex_v4/plans/generation/{folder}/{slug}.svg",
        "profile": "generic",
        "metric_settings": {"scale_m_per_svg_unit": 1.0, "origin": "none", "elevation_m": elevation},
        "shared_args": ["--wall-height", "2.8", "--wall-thickness", "0.3", "--floor-thickness", "0.2", "--ceiling-thickness", "0.2", "--strict-wall-overlaps"],
        "semantic_mappings": [], "material_mappings": {},
        "scene_name": f"{slug}_generated", "output_resource_dir": f"res://gen/{code}/{slug}",
        "local_to_world": {"origin": [0, 0, 0], "basis_x": [1, 0, 0], "basis_y": [0, 1, 0], "basis_z": [0, 0, 1]},
        "anchor_parameterization": copy.deepcopy(parameterization), "vertical_generators": [],
        "safe_regeneration": {
            "composition_input": f"scenes/complex_v4/regeneration/rollout/{folder}/AuthoredContent/{slug}/composition.json",
            "bindings_input": f"scenes/complex_v4/regeneration/rollout/{folder}/AuthoredContent/{slug}/object_bindings.json",
        },
    }



def canonical_wall_height(source_svg: str) -> float:
    """Wall height drawn in the canonical SVG (data-wall-height); every wall of a sector must carry the same value."""
    text = (ROOT / source_svg).read_text(encoding="utf-8")
    heights = {float(value) for value in re.findall(r'data-wall-height="([0-9.]+)"', text)}
    if len(heights) != 1:
        raise ValueError(f"{source_svg}: expected one wall height, found {sorted(heights)}")
    return heights.pop()


def set_shared_wall_height(sector: dict[str, Any], height: float) -> None:
    arguments = sector["shared_args"]
    value = f"{height:g}"
    if "--wall-height" in arguments:
        arguments[arguments.index("--wall-height") + 1] = value
    else:
        arguments[:0] = ["--wall-height", value]


def apply_vertical_definitions(source_by_id: dict[str, dict[str, Any]]) -> None:
    """Replace the static stair configuration with the SVG-derived definitions."""
    hosts: dict[str, bool] = {}
    for stair in load_json(VERTICAL_DEFINITIONS)["stairs"]:
        host = stair["host_sector_id"]
        if host not in source_by_id:
            raise ValueError(f"Vertical definition host sector is unknown: {host}")
        if hosts.get(host):
            raise ValueError(f"Sector {host} hosts more than one stair generator; a sector scene has a single Stairs layer, host each flight in its own (upper) sector")
        hosts[host] = True
        source_by_id[host]["vertical_generators"] = [copy.deepcopy(stair["generator"])]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    options = parser.parse_args(argv)
    catalog = load_json(CATALOG)
    catalog_by_id = {item["sector_id"]: item for item in catalog["sectors"]}
    source_by_id: dict[str, dict[str, Any]] = {}
    parameterization: dict[str, Any] | None = None
    for source_path in SOURCE_MANIFESTS:
        for source in load_json(source_path)["sectors"]:
            source_by_id[source["sector_id"]] = copy.deepcopy(source)
            if source["sector_id"] == "U-ROUTE-A":
                parameterization = copy.deepcopy(source["anchor_parameterization"])
    if parameterization is None:
        raise ValueError("U-ROUTE-A parameterization template is missing")
    for circulation_id in CIRCULATION:
        source_by_id[circulation_id] = circulation_entry(circulation_id, parameterization)
    # Production authored content is empty (objects are re-placed from scratch); the pilot AuthoredContent stays a test input.
    for sector_id, level_dir in (("U-MEDBAY", "upper"), ("U-ROUTE-A", "upper"), ("L-ARCHIVE-A", "lower")):
        slug = sector_id.lower().replace("-", "_")
        base = f"scenes/complex_v4/regeneration/rollout/{level_dir}/AuthoredContent/{slug}"
        source_by_id[sector_id]["safe_regeneration"] = {"composition_input": f"{base}/composition.json", "bindings_input": f"{base}/object_bindings.json"}
    apply_vertical_definitions(source_by_id)
    if set(source_by_id) != set(catalog_by_id):
        missing = sorted(set(catalog_by_id) - set(source_by_id))
        extra = sorted(set(source_by_id) - set(catalog_by_id))
        raise ValueError(f"Manifest sources do not match catalog; missing={missing}, extra={extra}")

    sectors: list[dict[str, Any]] = []
    for sector_id in sorted(catalog_by_id):
        catalog_entry = catalog_by_id[sector_id]
        sector = source_by_id[sector_id]
        slug = Path(catalog_entry["scene"]).stem
        level = catalog_entry["level"]
        sector.update({
            "level": level, "status": "ready", "blockers": [],
            "scene_name": f"{slug}_generated", "output_resource_dir": f"res://gen/{LEVEL_CODE[level]}/{slug}",
            "sector_scene": catalog_entry["scene"],
            "authored_scene": f"res://scenes/complex_v4/set_dressing/sectors/{slug}_dressing.tscn",
        })
        # The stair shaft walls start above the lower ceiling: use the wall height the plan really draws, not a legacy setting.
        set_shared_wall_height(sector, canonical_wall_height(sector["source_svg"]))
        sectors.append(sector)

    document = {
        "schema_id": "caretaker.sector_generation_manifest", "schema_version": "1.1.0",
        "contract_version": "1.0.0", "map_id": catalog["map_id"], "project_root": "../..",
        "sector_count": len(sectors),
        "producer_requirements": {"svg_to_godot3d": ">=1.19.0", "generate_godot_stairs": ">=2.9.0"},
        "sectors": sectors,
    }
    write_json(options.output, document)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
