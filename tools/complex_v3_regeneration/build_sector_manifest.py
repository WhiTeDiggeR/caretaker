#!/usr/bin/env python3
"""Build the single deterministic production manifest for all complex_v3 sectors."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scenes" / "complex_v3_blockout" / "sector_catalog.json"
OUTPUT = Path(__file__).with_name("sector_generation_manifest.json")
SOURCE_MANIFESTS = (
    Path(__file__).with_name("rollouts") / "lower_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "upper_generation_manifest.json",
    Path(__file__).with_name("rollouts") / "technical_generation_manifest.json",
    Path(__file__).with_name("pilots") / "u_medbay" / "pilot_generation_manifest.json",
    Path(__file__).with_name("pilots") / "route_a_vertical" / "pilot_generation_manifest.json",
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


def circulation_entry(parameterization: dict[str, Any]) -> dict[str, Any]:
    return {
        "sector_id": "T-CIRCULATION", "level": "LV-T", "status": "ready", "blockers": [],
        "source_svg": "docs/design/complex_v3/plans/generation/technical/t_circulation.svg",
        "profile": "generic",
        "metric_settings": {"scale_m_per_svg_unit": 1.0, "origin": "none", "elevation_m": -11.5},
        "shared_args": ["--wall-height", "2.8", "--wall-thickness", "0.3", "--floor-thickness", "0.2", "--ceiling-thickness", "0.2", "--strict-wall-overlaps"],
        "semantic_mappings": [], "material_mappings": {},
        "scene_name": "t_circulation_generated", "output_resource_dir": "res://gen/t/t_circulation",
        "local_to_world": {"origin": [0, 0, 0], "basis_x": [1, 0, 0], "basis_y": [0, 1, 0], "basis_z": [0, 0, 1]},
        "anchor_parameterization": copy.deepcopy(parameterization), "vertical_generators": [],
        "safe_regeneration": {
            "composition_input": "scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/t_circulation/composition.json",
            "bindings_input": "scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/t_circulation/object_bindings.json",
        },
    }


def main() -> int:
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
    source_by_id["T-CIRCULATION"] = circulation_entry(parameterization)
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
            "authored_scene": f"res://scenes/complex_v3_blockout/set_dressing/sectors/{slug}_dressing.tscn",
        })
        sectors.append(sector)

    document = {
        "schema_id": "caretaker.sector_generation_manifest", "schema_version": "1.1.0",
        "contract_version": "1.0.0", "map_id": catalog["map_id"], "project_root": "../..",
        "sector_count": len(sectors),
        "producer_requirements": {"svg_to_godot3d": ">=1.19.0", "generate_godot_stairs": ">=2.9.0"},
        "sectors": sectors,
    }
    write_json(OUTPUT, document)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
