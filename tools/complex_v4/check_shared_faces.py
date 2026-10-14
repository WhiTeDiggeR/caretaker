#!/usr/bin/env python3
"""Find surfaces that would flicker (z-fighting) in the generated complex, from the canonical SVGs (#205).

The converter (svg-plan-to-godot 1.19, ``--wall-thickness 0.3``, butt joints) turns every wall line into a
box ``thickness`` wide that reaches ``thickness / 2`` past each end, and every floor/ceiling rect into a
slab of exactly that rect. It resolves joints only inside one sector. So, per level:

- ``floor_overlap``   floors of two sectors overlap: both floor and ceiling slabs are drawn twice;
- ``wall_overlap``    wall boxes of two sectors overlap: shared walls and wall ends sticking into a
                      neighbour's wall have coincident faces;
- ``parallel_walls``  two parallel, not collinear walls of one sector are closer than the thickness and
                      their boxes overlap (the converter merges only walls within 0.02 m);
- ``opening_corner``  an opening ends inside the box of a perpendicular wall of its sector (but not on its
                      centre line, which opens the whole bay): its jamb lies in the plane of that wall's face;
- ``opening_off_wall`` an opening crosses no wall of its own sector (stair entries are markers and skipped).

Usage: python tools/complex_v4/check_shared_faces.py [--json]. Exit 1 when anything is found.
"""
from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / "docs/design/complex_v4/plans/generation"
WALL_THICKNESS_M = 0.3
MERGE_TOLERANCE_M = 0.02      # converter --wall-merge-tolerance: closer parallel walls are merged
MIN_AREA_M2 = 0.0004          # same threshold as surface_conflict_check.gd
EPS = 1e-6


def _float(el: ET.Element, name: str) -> float:
    return float(el.get(name, 0))


def load_sectors(plans: Path = PLANS) -> dict[str, dict]:
    sectors: dict[str, dict] = {}
    for path in sorted(plans.glob("*/*.svg")):
        root = ET.parse(path).getroot()
        sector = {"id": root.get("data-sector-id", path.stem), "level": root.get("data-level", ""), "floors": [], "walls": [], "openings": []}
        for el in root.iter():
            kind = el.get("data-godot-type")
            if kind == "floor":
                x, z, w, h = (_float(el, k) for k in ("x", "y", "width", "height"))
                sector["floors"].append((el.get("id"), x, z, x + w, z + h))
            elif kind == "wall":
                sector["walls"].append((el.get("id"), _float(el, "x1"), _float(el, "y1"), _float(el, "x2"), _float(el, "y2")))
            elif kind in {"door", "opening", "window"} and not el.get("data-vertical-id"):   # stair entries are markers, not wall cuts
                sector["openings"].append((el.get("id"), _float(el, "x1"), _float(el, "y1"), _float(el, "x2"), _float(el, "y2")))
        sectors[sector["id"]] = sector
    return sectors


def wall_axis(x1: float, z1: float, x2: float, z2: float) -> tuple[str, float, float, float] | None:
    """("h"|"v", fixed, lo, hi) of an axis-aligned segment, None for a slanted one."""
    if abs(z1 - z2) < EPS:
        return "h", z1, min(x1, x2), max(x1, x2)
    if abs(x1 - x2) < EPS:
        return "v", x1, min(z1, z2), max(z1, z2)
    return None


def wall_box(wall: tuple, thickness: float = WALL_THICKNESS_M) -> tuple[float, float, float, float] | None:
    axis = wall_axis(*wall[1:])
    if axis is None:
        return None
    orient, fixed, lo, hi = axis
    half = thickness / 2
    if orient == "h":
        return lo - half, fixed - half, hi + half, fixed + half
    return fixed - half, lo - half, fixed + half, hi + half


def overlap_area(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> float:
    dx = min(a[2], b[2]) - max(a[0], b[0])
    dz = min(a[3], b[3]) - max(a[1], b[1])
    return dx * dz if dx > EPS and dz > EPS else 0.0


def find(sectors: dict[str, dict]) -> list[dict]:
    findings: list[dict] = []
    ids = sorted(sectors)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            sa, sb = sectors[a], sectors[b]
            if sa["level"] != sb["level"]:
                continue
            for fa in sa["floors"]:
                for fb in sb["floors"]:
                    area = overlap_area(fa[1:], fb[1:])
                    if area > MIN_AREA_M2:
                        findings.append({"kind": "floor_overlap", "a": fa[0], "b": fb[0], "area_m2": round(area, 4)})
            boxes_b = [(w[0], wall_box(w)) for w in sb["walls"]]
            for wa in sa["walls"]:
                box_a = wall_box(wa)
                if box_a is None:
                    continue
                for wb_id, box_b in boxes_b:
                    area = overlap_area(box_a, box_b) if box_b else 0.0
                    if area > MIN_AREA_M2:
                        findings.append({"kind": "wall_overlap", "a": wa[0], "b": wb_id, "area_m2": round(area, 4)})
    for sid in ids:
        findings.extend(_inside_sector(sectors[sid]))
    return findings


def _inside_sector(sector: dict) -> list[dict]:
    findings: list[dict] = []
    walls = [(w[0], wall_axis(*w[1:])) for w in sector["walls"]]
    walls = [(wid, axis) for wid, axis in walls if axis]
    half = WALL_THICKNESS_M / 2
    for i, (ida, (oa, fa, la, ha)) in enumerate(walls):
        for idb, (ob, fb, lb, hb) in walls[i + 1:]:
            if oa != ob or abs(fa - fb) <= MERGE_TOLERANCE_M or abs(fa - fb) >= WALL_THICKNESS_M - EPS:
                continue
            reach = min(ha, hb) - max(la, lb) + WALL_THICKNESS_M
            if reach > EPS:
                area = reach * (WALL_THICKNESS_M - abs(fa - fb))
                if area > MIN_AREA_M2:
                    findings.append({"kind": "parallel_walls", "a": ida, "b": idb, "area_m2": round(area, 4)})
    for oid, *coords in sector["openings"]:
        axis = wall_axis(*coords)
        if axis is None:
            continue
        orient, fixed, lo, hi = axis
        if not any(o == orient and abs(f - fixed) <= 0.1 and min(hi, h) - max(lo, l) > 0.05 for _, (o, f, l, h) in walls):
            findings.append({"kind": "opening_off_wall", "a": oid, "b": ""})
            continue
        for wid, (o, f, l, h) in walls:
            if o == orient or not (l - half - EPS <= fixed <= h + half + EPS):
                continue
            for end in (lo, hi):
                if 0.001 < abs(end - f) < half - 0.001:   # an opening ending on the centre line removes the corner
                    findings.append({"kind": "opening_corner", "a": oid, "b": wid, "distance_m": round(abs(end - f), 3)})
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true", help="print the findings as JSON")
    args = parser.parse_args()
    findings = find(load_sectors())
    if args.json:
        print(json.dumps(findings, ensure_ascii=False, indent=1))
    else:
        for item in findings:
            print(f"{item['kind']:16s} {item['a']} / {item['b']} {item.get('area_m2', item.get('distance_m', ''))}")
    counts: dict[str, int] = {}
    for item in findings:
        counts[item["kind"]] = counts.get(item["kind"], 0) + 1
    print("SHARED_FACES " + " ".join(f"{k}={v}" for k, v in sorted(counts.items())) + f" total={len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
