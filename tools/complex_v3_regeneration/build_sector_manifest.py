#!/usr/bin/env python3
"""Build the deterministic production sector-source inventory from sector_catalog.json."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scenes" / "complex_v3_blockout" / "sector_catalog.json"
OUTPUT = Path(__file__).with_name("sector_generation_manifest.json")
LEVEL_DIR = {"LV-U": "upper", "LV-L": "lower", "LV-T": "technical"}


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    sectors = []
    for item in sorted(catalog["sectors"], key=lambda value: value["sector_id"]):
        slug = Path(item["scene"]).stem
        level_dir = LEVEL_DIR[item["level"]]
        sectors.append({
            "sector_id": item["sector_id"],
            "level": item["level"],
            "status": "blocked",
            "blockers": [
                "canonical_svg_not_integrated",
                "exact_svg_to_world_transform_missing"
            ],
            "source_svg": f"docs/design/complex_v3/plans/sectors/{level_dir}/{slug}.svg",
            "profile": "codex-plan",
            "metric_settings": {
                "scale_m_per_svg_unit": None,
                "origin": None,
                "elevation_m": None
            },
            "shared_args": [],
            "scene_name": slug + "_generated",
            "output_resource_dir": f"res://scenes/complex_v3_regenerated/{level_dir}/{slug}",
            "local_to_world": None,
            "semantic_mappings": [],
            "material_mappings": {},
            "vertical_generators": [],
            "vertical_generator_status": "requires_explicit_handoff_mapping"
        })
    document = {
        "schema_id": "caretaker.sector_generation_manifest",
        "schema_version": "1.0.0",
        "contract_version": "1.0.0",
        "map_id": catalog["map_id"],
        "project_root": "../..",
        "sector_count": len(sectors),
        "producer_requirements": {
            "svg_to_godot3d": ">=1.19.0",
            "generate_godot_stairs": ">=2.9.0"
        },
        "sectors": sectors
    }
    OUTPUT.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
