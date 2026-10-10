"""Move stair doors in approved_registration.json to the lateral centres of the stair flights.

Uses the resolver (non-strict) to find, per u-turn stair, where the entry and exit flights are and where the doors drawn in the
canonical SVG are. Doors that are further than the resolver tolerance from their flight are rewritten in the registration
(door_add: at_m, door_set: center_m). Run build_canonical_from_approved.py afterwards. Idempotent.
"""
import argparse
import json
from pathlib import Path

import _shift
import vertical_registry
import vertical_resolver as vr

ROOT = Path(__file__).resolve().parents[2]
REGISTRATION = ROOT / "tools/complex_v4/approved_registration.json"
MANIFEST = ROOT / "tools/complex_v4/sector_generation_manifest.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sectors = {s["sector_id"]: s for s in manifest["sectors"] if isinstance(s, dict) and "sector_id" in s}
    reg, newline = _shift.load()
    changed = 0
    for definition in vertical_registry.load_definitions().values():
        generator = definition["generator"]
        resolved = vr.resolve_stair(generator, sectors, ROOT, strict=False)
        for role, target in resolved["summary"].get("door_targets", {}).items():
            if abs(target["actual_center"] - target["expected_center"]) <= vr.DOOR_CENTER_TOLERANCE_M:
                continue
            sector_amendments = reg["sectors"][target["sector_id"]]["amendments"]
            hits = [a for a in sector_amendments if a.get("vertical", {}).get("id") == generator["vertical_id"] and a["vertical"].get("role") == role]
            if len(hits) != 1:
                raise SystemExit(f"{target['sector_id']} {generator['vertical_id']} {role}: {len(hits)} amendments")
            am = hits[0]
            line = target["line"]
            half = abs((line[2] - line[0]) + (line[3] - line[1])) / 2
            c = target["expected_center"]
            if am["op"] == "door_add":
                at = am["at_m"]
                if target["axis"] == "x":
                    am["at_m"] = [round(c - half, 3), at[1], round(c + half, 3), at[3]]
                else:
                    am["at_m"] = [at[0], round(c - half, 3), at[2], round(c + half, 3)]
            elif am["op"] == "door_set":
                fixed = line[1] if target["axis"] == "x" else line[0]
                am["center_m"] = [c, fixed] if target["axis"] == "x" else [fixed, c]
                am["near_m"] = list(am["center_m"]) if "near_m" not in am else am["near_m"]
            else:
                raise SystemExit(f"unsupported op {am['op']}")
            print(f"{target['sector_id']:24} {generator['vertical_id']:18} {role:5} {target['door_id']}: {target['actual_center']} -> {c}")
            changed += 1
    if changed and not args.dry_run:
        _shift.save(reg, newline)
    print("changed", changed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
