"""Stair-to-shaft fit check.

For every stair generator of the production packages compares, in world plan coordinates:
  * the stair footprint (flights and landings, taken from the generator report) with the shaft rectangle;
  * the lower entry / upper exit anchor of the stair with the stair doors (data-vertical-role entry|exit) drawn in the canonical SVG.
Gaps between the walking surface and the door / shaft wall larger than the tolerances are reported.
Exit code 1 if any gap exceeds --max-gap (default 0.6 m); --warn-only always exits 0.
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SVG_ROOT = ROOT / "docs/design/complex_v4/plans/generation"
LEVEL_DIR = {"U": "upper", "L": "lower", "T": "technical"}


def world(local_to_world: dict, point: list[float]) -> tuple[float, float, float]:
    o, bx, by, bz = (local_to_world[k] for k in ("origin", "basis_x", "basis_y", "basis_z"))
    return tuple(o[i] + bx[i] * point[0] + by[i] * point[1] + bz[i] * point[2] for i in range(3))


def stair_doors(sector_id: str, vertical_id: str) -> list[dict]:
    folder = LEVEL_DIR[sector_id[0]]
    path = SVG_ROOT / folder / (sector_id.lower().replace("-", "_") + ".svg")
    doors = []
    for tag in re.findall(r"<line\b[^>]*>", path.read_text(encoding="utf-8")):
        if f'data-vertical-id="{vertical_id}"' not in tag or 'data-godot-type="door"' not in tag:
            continue
        attr = lambda name: re.search(name + r'="([^"]*)"', tag).group(1)  # noqa: E731
        role = re.search(r'data-vertical-role="([^"]*)"', tag)
        x1, y1, x2, y2 = (float(attr(n)) for n in ("x1", "y1", "x2", "y2"))
        doors.append({"id": attr("id"), "role": role.group(1) if role else "", "center": ((x1 + x2) / 2, (y1 + y2) / 2), "ends": ((x1, y1), (x2, y2))})
    return doors


def check(max_gap: float) -> tuple[list[dict], int]:
    rows, bad = [], 0
    for manifest_path in sorted((ROOT / "gen").glob("*/*/generation_manifest.json")):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for generator in manifest.get("vertical_generators", []):
            if generator.get("kind") != "stair":
                continue
            report_path = manifest_path.parent / "Generated/Stairs" / generator["generator_id"] / "generation_report.json"
            report = json.loads(report_path.read_text(encoding="utf-8"))
            resolved, l2w = generator["resolved"], generator["local_to_world"]
            anchors = {a["role"]: world(l2w, a["origin"]) for a in report.get("anchor_frames", []) if a["role"] in ("lower_entry", "upper_exit")}
            row = {"vertical": generator["vertical_id"], "sector": manifest["sector_id"], "layout": resolved["layout"], "gaps": []}
            for role, level_key in (("lower_entry", "lower"), ("upper_exit", "upper")):
                sector_id = generator["levels"][level_key]["sector_id"]
                role_name = "entry" if role == "lower_entry" else "exit"
                doors = [d for d in stair_doors(sector_id, generator["vertical_id"]) if d["role"] in (role_name, "")]
                anchor = anchors.get(role)
                if not doors or anchor is None:
                    row["gaps"].append({"role": role, "sector": sector_id, "error": "no door or anchor"})
                    bad += 1
                    continue
                dist = min(math.hypot(anchor[0] - d["center"][0], anchor[2] - d["center"][1]) for d in doors)
                row["gaps"].append({"role": role, "sector": sector_id, "anchor_xz": [round(anchor[0], 2), round(anchor[2], 2)], "door_distance_m": round(dist, 2), "doors": [d["id"] for d in doors]})
                if dist > max_gap:
                    bad += 1
            rows.append(row)
    return rows, bad


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-gap", type=float, default=0.6)
    parser.add_argument("--warn-only", action="store_true")
    args = parser.parse_args()
    rows, bad = check(args.max_gap)
    for row in rows:
        for gap in row["gaps"]:
            flag = "!!" if gap.get("error") or gap["door_distance_m"] > args.max_gap else "ok"
            print(flag, row["vertical"], gap["role"], gap.get("sector"), gap.get("anchor_xz"), gap.get("door_distance_m", gap.get("error")), gap.get("doors"))
    print(f"stairs={len(rows)} gaps_over_{args.max_gap}={bad}")
    return 0 if args.warn_only or not bad else 1


if __name__ == "__main__":
    sys.exit(main())
