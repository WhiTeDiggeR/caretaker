#!/usr/bin/env python3
"""Write a portable summary for a completed floor rollout."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--level", choices=("upper", "lower", "technical"), required=True)
    parser.add_argument("--godot-smoke-passed", action="store_true")
    parser.add_argument("--visual-comparisons-passed", action="store_true")
    args = parser.parse_args()
    code = {"upper": "u", "lower": "l", "technical": "t"}[args.level]
    manifest = read(ROOT / f"tools/complex_v3_regeneration/rollouts/{args.level}_generation_manifest.json")
    rollout = ROOT / f"scenes/complex_v3_regeneration/rollout/{args.level}"
    summaries, errors, all_anchors, all_objects = [], [], [], []
    for sector in manifest["sectors"]:
        sector_id = sector["sector_id"]
        slug = sector_id.lower().replace("-", "_")
        live = ROOT / f"gen/{code}/{slug}"
        frames = read(live / "anchor_frames.json")
        bindings = read(rollout / f"AuthoredContent/{slug}/object_bindings.json")
        safe = read(rollout / f"reports/{sector_id}-safe.json")
        anchor_ids = [item["anchor_id"] for item in frames["anchors"]]
        object_ids = [item["object_ref"]["object_id"] for item in bindings["bindings"]]
        if safe.get("status") != "noop" or safe.get("ready") is not True:
            errors.append(f"{sector_id}: final safe regeneration was not ready noop")
        if len(anchor_ids) != len(set(anchor_ids)):
            errors.append(f"{sector_id}: duplicate anchor IDs")
        if len(object_ids) != len(set(object_ids)):
            errors.append(f"{sector_id}: duplicate object IDs")
        all_anchors.extend(anchor_ids)
        all_objects.extend(object_ids)
        summaries.append({
            "sector_id": sector_id,
            "generation_id": frames["generation_id"],
            "anchor_count": len(anchor_ids),
            "binding_count": len(object_ids),
            "safe_regeneration": "noop",
            "ready": True,
        })
    if len(all_anchors) != len(set(all_anchors)):
        errors.append("anchor IDs are not globally unique")
    if len(all_objects) != len(set(all_objects)):
        errors.append("object IDs are not globally unique")
    if args.level == "upper" and len(all_objects) != 149:
        errors.append(f"upper object count is {len(all_objects)}, expected 149")
    report = {
        "schema_id": "caretaker.floor_regeneration_rollout_report",
        "schema_version": "1.0.0",
        "map_id": manifest["map_id"],
        "level": args.level,
        "status": "passed" if not errors else "failed",
        "sector_count": len(summaries),
        "anchor_count": len(all_anchors),
        "binding_count": len(all_objects),
        "checks": {
            "final_safe_regeneration": "noop_ready",
            "anchor_ids": "globally_unique",
            "object_ids": "globally_unique",
            "missing_anchor_policy": "covered_by_unit_test",
            "godot_smoke": "passed" if args.godot_smoke_passed else "run_separately",
            "visual_comparisons": "passed" if args.visual_comparisons_passed else "run_separately",
        },
        "sectors": summaries,
        "errors": errors,
    }
    output = rollout / f"reports/{args.level}_rollout_report.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{report['status'].upper()}: sectors={len(summaries)} anchors={len(all_anchors)} bindings={len(all_objects)}")
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
