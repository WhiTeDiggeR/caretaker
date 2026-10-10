#!/usr/bin/env python3
"""Snapshot or compare set-dressing transforms without loading Godot."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from set_dressing_migration import compare_snapshots, snapshot, write_json


ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--compare", nargs=2, metavar=("BEFORE", "AFTER"), type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--tolerance", type=float, default=1e-5)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if bool(args.snapshot) == bool(args.compare):
        raise SystemExit("choose exactly one of --snapshot or --compare")
    if args.snapshot:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        value = snapshot(ROOT, manifest)
        write_json(args.snapshot, value)
        print(f"SET_DRESSING_SNAPSHOT_OK objects={value['object_count']} path={args.snapshot}")
        return 0
    before = json.loads(args.compare[0].read_text(encoding="utf-8"))
    after = json.loads(args.compare[1].read_text(encoding="utf-8"))
    result = compare_snapshots(before, after, args.tolerance)
    if args.report:
        write_json(args.report, result)
    if result["status"] != "passed":
        raise SystemExit(f"SET_DRESSING_TRANSFORM_AUDIT_FAILED issues={len(result['issues'])}")
    print(f"SET_DRESSING_TRANSFORM_AUDIT_OK objects={before['object_count']} max_delta={result['max_delta']:.9f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
