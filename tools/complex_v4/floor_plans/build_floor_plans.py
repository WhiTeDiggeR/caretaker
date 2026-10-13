#!/usr/bin/env python3
"""Builds an interactive HTML page with the full floor plans of complex v4 (issue #179).

Reads the canonical metric sector SVGs (docs/design/complex_v4/plans/generation/{upper,lower,technical}/*.svg),
which share one world frame in metres, and the story annotations in annotations.json (route, marks, callouts).

    python tools/complex_v4/floor_plans/build_floor_plans.py            # -> build/floor_plans.html
    python tools/complex_v4/floor_plans/build_floor_plans.py --out x.html
    python tools/complex_v4/floor_plans/build_floor_plans.py --check    # CI: build to a temp file, validate annotations
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PLANS = REPO / "docs/design/complex_v4/plans/generation"
LEVELS = ("upper", "lower", "technical")
WALL_LIKE = {"wall", "door", "window", "opening"}


def _num(element: ET.Element, key: str) -> float:
    return round(float(element.get(key)), 3)


def read_level(folder: Path) -> dict:
    level = {"sectors": [], "rooms": [], "walls": [], "doors": [], "windows": [], "openings": [], "stairs": []}
    for path in sorted(folder.glob("*.svg")):
        root = ET.parse(path).getroot()
        sector = root.get("data-sector-id")
        level["sectors"].append({"id": sector, "vb": [float(v) for v in root.get("viewBox").split()]})
        for element in root.iter():
            tag = element.tag.split("}")[-1]
            kind = element.get("data-godot-type")
            if tag == "rect" and kind == "floor":
                level["rooms"].append({
                    "s": sector, "id": element.get("data-space-id", ""), "l": element.get("data-label", ""),
                    "x": _num(element, "x"), "y": _num(element, "y"), "w": _num(element, "width"), "h": _num(element, "height"),
                })
            elif tag == "rect" and kind == "floor-opening":
                level["stairs"].append({
                    "s": sector, "x": _num(element, "x"), "y": _num(element, "y"),
                    "w": _num(element, "width"), "h": _num(element, "height"), "v": element.get("data-vertical-id", ""),
                })
            elif tag == "line" and kind in WALL_LIKE:
                segment = [_num(element, k) for k in ("x1", "y1", "x2", "y2")]
                if kind == "wall":
                    level["walls"].append(segment)
                elif kind == "door":
                    level["doors"].append({"p": segment, "t": element.get("data-door-type", "standard"), "id": element.get("id")})
                elif kind == "window":
                    level["windows"].append({"p": segment, "id": element.get("id")})
                else:
                    level["openings"].append(segment)
    return level


def validate(data: dict, annotations: dict) -> list[str]:
    rooms = {lvl: {r["id"] for r in data[lvl]["rooms"]} for lvl in LEVELS}
    windows = {lvl: {w["id"] for w in data[lvl]["windows"]} for lvl in LEVELS}
    sectors = {s["id"] for lvl in LEVELS for s in data[lvl]["sectors"]}
    errors = []
    for item in annotations.get("marks", []) + annotations.get("scenes", []):
        if item["level"] not in rooms or item["room"] not in rooms[item["level"]]:
            errors.append(f"unknown room {item['level']}:{item['room']}")
    for item in annotations.get("callouts", []):
        if item["window"] not in windows.get(item["level"], set()):
            errors.append(f"unknown window {item['level']}:{item['window']}")
    for room in annotations.get("closed_rooms", []):
        if not any(room in ids for ids in rooms.values()):
            errors.append(f"unknown closed room {room}")
    for sector in annotations.get("route_sectors", []):
        if sector not in sectors:
            errors.append(f"unknown route sector {sector}")
    return errors


def revision() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def build(out: Path) -> dict:
    data = {lvl: read_level(PLANS / lvl) for lvl in LEVELS}
    annotations = json.loads((HERE / "annotations.json").read_text(encoding="utf-8"))
    errors = validate(data, annotations)
    if errors:
        raise SystemExit("annotations.json: " + "; ".join(errors))
    page = (HERE / "template.html").read_text(encoding="utf-8")
    page = page.replace("__DATA__", json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
    page = page.replace("__ANN__", json.dumps(annotations, ensure_ascii=False).replace("</", "<\\/"))
    page = page.replace("__REV__", revision())
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=REPO / "build/floor_plans.html")
    parser.add_argument("--check", action="store_true", help="build to a temporary file and validate annotations")
    args = parser.parse_args()
    out = Path(tempfile.mkdtemp()) / "floor_plans.html" if args.check else args.out
    data = build(out)
    for lvl in LEVELS:
        level = data[lvl]
        print(f"{lvl}: {len(level['sectors'])} sectors, {len(level['rooms'])} rooms, {len(level['doors'])} doors, {len(level['windows'])} windows")
    print(f"FLOOR_PLANS ok -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
