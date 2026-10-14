#!/usr/bin/env python3
"""Metric SVG plans of Bowser's dream S in the svg-plan-to-godot format (#191).

The geometry is taken from the blockout ``scenes/dreams/bowser_dream.tscn`` (#182): world X is the plan x, world Z the
plan y, metres, one plan per walking level because the converter takes one ``--elevation`` per SVG. Hook nodes of the
blockout become explicit marker anchors (``data-anchor-id``) so gameplay can be bound to the generated package.

Modes:
  --write                      write ``docs/design/dream_bowser/plans/*.svg`` from the specification below
  --check                      validate the committed plans without the generator (CI) against the rules every complex
                               v4 canonical plan satisfies plus the dream specifics; drift from the specification is a
                               warning so the plans can later be edited by hand
  --generate --svg-tool-root R the author's strict run (#214): --check, tool version, strict inspect + convert with the
                               complex v4 production settings into ``gen/dreams/bowser_s/<plan>/Generated/Architecture``,
                               collision winding fix and report checks as in regenerate_sector.py; --dry-run prints commands
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN_DIR = ROOT / "docs/design/dream_bowser/plans"
GEN_DIR = "gen/dreams/bowser_s"
MAP_ID = "caretaker-dream-bowser-s"
SPACE = "DREAM-S"
DRAWABLE = {"rect", "line", "polyline", "polygon", "path", "circle", "ellipse", "text"}
PRODUCTION_MANIFEST = ROOT / "tools/complex_v4/sector_generation_manifest.json"
# Converter settings shared by every plan: the strict set of the complex v4 production manifest without --wall-height
# (every dream wall carries its own data-wall-height). --check compares them with the manifest (#214).
SHARED_ARGS = ["--wall-thickness", "0.3", "--floor-thickness", "0.2", "--ceiling-thickness", "0.2", "--strict-wall-overlaps",
               "--strict-ceiling-alignment"]
DEFAULT_WALL_THICKNESS = 0.3
MIN_SVG_VERSION = (1, 19, 0)
# Semantic types used by the canonical complex plans; anything else is "unrecognized" for the strict inspector.
KNOWN_TYPES = {"floor", "ceiling", "floor-opening", "ceiling-opening", "wall", "door", "window", "opening", "marker", "ignore"}
ALIGN_TOLERANCE = 0.01  # converter ceiling_alignment_tolerance
MIN_SHARED_EDGE_M = 0.05
MIN_PASSAGE_M = 0.8  # player capsule 0.7 m (scenes/player.tscn) plus margin
ON_LINE_TOLERANCE = 1e-6
MARKER_DOOR_TOLERANCE = 0.6
# BowserDream.route() of scenes/dreams/bowser_dream.gd: the main route has to stay on generated floors.
ROUTE = [(4, 0, 0), (25, 0, 0), (27, 1.2, 0), (46, 1.2, 0), (56, 1.2, 0), (70, 1.2, 0), (75, 1.2, -5), (80, 1.2, -6),
         (80, 1.2, -20), (80, 1.2, -24)]


@dataclass
class Floor:
    key: str
    label: str
    x: float
    z: float
    w: float
    d: float
    source: str


@dataclass
class Door:
    key: str
    a: float  # start along the wall
    b: float  # end along the wall
    height: float
    kind: str
    source: str


@dataclass
class Wall:
    key: str
    x1: float
    z1: float
    x2: float
    z2: float
    height: float
    thickness: float
    source: str
    doors: list[Door] = field(default_factory=list)


@dataclass
class Ceiling:
    key: str
    x: float
    z: float
    w: float
    d: float
    elevation: float
    openings: list[tuple[str, float, float, float, float, str]] = field(default_factory=list)


@dataclass
class Marker:
    key: str
    x: float
    z: float
    hook: str  # node path in bowser_dream.tscn


@dataclass
class Plan:
    slug: str
    title: str
    elevation: float
    floors: list[Floor]
    walls: list[Wall]
    ceilings: list[Ceiling]
    markers: list[Marker]


def _wall(key: str, p1: tuple[float, float], p2: tuple[float, float], height: float, thickness: float, source: str,
          doors: list[Door] | None = None) -> Wall:
    return Wall(key, p1[0], p1[1], p2[0], p2[1], height, thickness, source, doors or [])


# Walls run between the centre lines of the blockout boxes, so their faces coincide with the blockout faces. Floors and
# ceilings bounded by a wall end on its centre line like in the complex v4 plans; the converter extends them to the wall
# outer face (floor_extent wall-outer), so the walkable area still matches the blockout (#214).
PLANS = [
    Plan(
        "s_low", "Сон Боузера S — нижний уровень (терраса и карниз), отметка 0,0", 0.0,
        floors=[
            Floor("terrace", "S1 ТЕРРАСА ПРИБЫТИЯ / открытое небо", 0, -6, 16, 12, "Terrace/Floor"),
            Floor("ledge", "S2 КАРНИЗ", 16, -1.5, 10, 3, "Path/Ledge"),
            Floor("step-base", "основание уступа (скрыто)", 26, -1.5, 4, 3, "Path/LedgeStep"),
        ],
        walls=[
            # The 1.2 m ledge step: four risers around the step block, the high plan puts its floor on top.
            _wall("step-riser-west", (26, -1.5), (26, 1.5), 1.2, 0.3, "Path/LedgeStep"),
            _wall("step-riser-north", (26, -1.5), (30, -1.5), 1.2, 0.3, "Path/LedgeStep"),
            _wall("step-riser-south", (26, 1.5), (30, 1.5), 1.2, 0.3, "Path/LedgeStep"),
            _wall("step-riser-east", (30, -1.5), (30, 1.5), 1.2, 0.3, "Path/LedgeStep"),
        ],
        ceilings=[],
        markers=[
            Marker("spawn", 4, 0, "Spawn"),
            Marker("silhouette-spot", 12, -4, "Terrace/SilhouetteSpot"),
        ],
    ),
    Plan(
        "s_high", "Сон Боузера S — верхний уровень (мост, двор, зал печати, бастион), отметка 1,2", 1.2,
        floors=[
            Floor("step", "ВЕРХ УСТУПА 1,2 М", 26, -1.5, 4, 3, "Path/LedgeStep"),
            Floor("chain-bridge", "ЦЕПНОЙ МОСТ 16 М / над лавой", 30, -1, 15.5, 2, "Path/Bridge"),
            Floor("yard", "S3 ДВОР ПЕРВОГО БОЯ 24×18 / открытое небо", 45.5, -9.5, 24.5, 19, "Yard/Floor"),
            Floor("seal-hall", "S4 ЗАЛ ПЕЧАТИ 20×16, высота 12", 70, -8.5, 20.5, 17, "SealHall/Floor"),
            Floor("bastion-bridge", "МОСТ К БАСТИОНУ 12 М / над лавой", 78.6, -20, 2.8, 11.5, "Bastion/Bridge"),
            Floor("bastion", "S5 БАСТИОН 10×8 / врата", 75.2, -27.8, 9.6, 7.8, "Bastion/Floor"),
        ],
        walls=[
            # The chains stop at the outer face of the yard wall instead of crossing it in the doorway.
            _wall("chain-north", (30, -1.0), (45, -1.0), 1.0, 0.1, "Path/ChainLeft"),
            _wall("chain-south", (30, 1.0), (45, 1.0), 1.0, 0.1, "Path/ChainRight"),
            _wall("yard-west", (45.5, -9.5), (45.5, 9.5), 8.0, 1.0, "Yard/WallWestNorth+WallWestSouth+LintelWest",
                  [Door("yard-entry", -2.0, 2.0, 5.0, "giant-arch", "Yard/LintelWest")]),
            _wall("yard-north", (45.5, -9.5), (70, -9.5), 8.0, 1.0, "Yard/WallNorth"),
            _wall("yard-south", (45.5, 9.5), (70, 9.5), 8.0, 1.0, "Yard/WallSouthWest+WallSouthEast+LintelSouth",
                  [Door("branch-rubble", 60.5, 63.5, 4.5, "branch-closed", "Branches/RubbleSouth")]),
            _wall("column-north-w", (57.5, -4.5), (57.5, -3.5), 8.0, 1.0, "Yard/ColumnNorth"),
            _wall("column-north-n", (57.5, -4.5), (58.5, -4.5), 8.0, 1.0, "Yard/ColumnNorth"),
            _wall("column-north-e", (58.5, -4.5), (58.5, -3.5), 8.0, 1.0, "Yard/ColumnNorth"),
            _wall("column-north-s", (57.5, -3.5), (58.5, -3.5), 8.0, 1.0, "Yard/ColumnNorth"),
            _wall("column-south-w", (57.5, 3.5), (57.5, 4.5), 8.0, 1.0, "Yard/ColumnSouth"),
            _wall("column-south-n", (57.5, 3.5), (58.5, 3.5), 8.0, 1.0, "Yard/ColumnSouth"),
            _wall("column-south-e", (58.5, 3.5), (58.5, 4.5), 8.0, 1.0, "Yard/ColumnSouth"),
            _wall("column-south-s", (57.5, 4.5), (58.5, 4.5), 8.0, 1.0, "Yard/ColumnSouth"),
            _wall("hall-west", (70, -9.5), (70, 9.5), 12.0, 1.0, "SealHall/WallWestNorth+WallWestSouth+LintelWest",
                  [Door("hall-entry", -2.0, 2.0, 7.0, "giant-arch", "SealHall/LintelWest")]),
            _wall("hall-north", (70, -8.5), (90.5, -8.5), 12.0, 1.0, "SealHall/WallNorthWest+WallNorthEast+LintelNorth",
                  [Door("side-door", 78.5, 81.5, 5.0, "side-door", "SealHall/SideDoor")]),
            _wall("hall-south", (70, 8.5), (90.5, 8.5), 12.0, 1.0, "SealHall/WallSouth"),
            _wall("hall-east", (90.5, -8.5), (90.5, 8.5), 12.0, 1.0, "SealHall/WallEastNorth+WallEastSouth+LintelEast",
                  [Door("branch-grate", -1.5, 1.5, 5.0, "branch-closed", "Branches/GrateEast")]),
            _wall("bridge-rail-west", (78.6, -20), (78.6, -9), 0.9, 0.2, "Bastion/RailWest"),
            _wall("bridge-rail-east", (81.4, -20), (81.4, -9), 0.9, 0.2, "Bastion/RailEast"),
            _wall("parapet-north", (75.2, -27.8), (84.8, -27.8), 1.0, 0.4, "Bastion/ParapetNorth"),
            _wall("parapet-west", (75.2, -27.8), (75.2, -20), 1.0, 0.4, "Bastion/ParapetWest"),
            _wall("parapet-east", (84.8, -27.8), (84.8, -20), 1.0, 0.4, "Bastion/ParapetEast"),
        ],
        ceilings=[
            Ceiling("seal-hall", 70, -8.5, 20.5, 17, 13.2,
                    [("oculus", 78, -2, 4, 4, "SealHall/CeilingWest+CeilingEast (просвет над печатью)")]),
        ],
        markers=[
            Marker("wake-line", 56, 0, "Yard/Ambush/WakeLine"),
            Marker("guard-spawn-north", 68.5, -5.75, "Yard/Ambush/GuardSpawnNorth"),
            Marker("guard-spawn-south", 68.5, 6.25, "Yard/Ambush/GuardSpawnSouth"),
            Marker("hall-threshold", 70, 0, "Yard/Ambush/HallThreshold"),
            Marker("remains", 49.6, -7.7, "Yard/Remains"),
            Marker("weapon-spot", 50.9, -7.0, "Yard/Remains/WeaponSpot"),
            Marker("seal", 80, 0, "SealHall/Seal"),
            Marker("seal-slot", 80, 0, "SealHall/SealSlot"),
            Marker("side-door", 80, -8.5, "SealHall/SideDoor"),
            Marker("gate", 80, -25, "Bastion/Gate"),
        ],
    ),
]


def fmt(value: float) -> str:
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def _is_vertical(wall: Wall) -> bool:
    return math.isclose(wall.x1, wall.x2)


def _door_segment(wall: Wall, door: Door) -> tuple[float, float, float, float]:
    if _is_vertical(wall):
        return wall.x1, door.a, wall.x1, door.b
    return door.a, wall.z1, door.b, wall.z1


def plan_bounds(plan: Plan) -> tuple[float, float, float, float]:
    xs: list[float] = []
    zs: list[float] = []
    for f in plan.floors:
        xs += [f.x, f.x + f.w]
        zs += [f.z, f.z + f.d]
    for w in plan.walls:
        xs += [w.x1, w.x2]
        zs += [w.z1, w.z2]
    return min(xs) - 2, min(zs) - 2, max(xs) + 2, max(zs) + 2


def render(plan: Plan) -> str:
    sid = f"bowser-{plan.slug.replace('_', '-')}"
    x0, z0, x1, z1 = plan_bounds(plan)
    width, height = x1 - x0, z1 - z0
    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" data-presentation-only="false" data-generator-input="true" '
        f'viewBox="{fmt(x0)} {fmt(z0)} {fmt(width)} {fmt(height)}" width="{fmt(width * 10)}" height="{fmt(height * 10)}" '
        f'data-scale="1" data-scale-unit="m-per-svg-unit" data-grid-size="1" data-map-id="{MAP_ID}" '
        f'data-plan-id="{plan.slug}" data-elevation-m="{fmt(plan.elevation)}" '
        f'data-source-plan="scenes/dreams/bowser_dream.tscn" data-derivation="blockout-182-by-tools-dream-bowser_s_plans">',
        f"  <title>{plan.title}</title>",
        "  <desc>+X восток, +Z юг, метры; отметка пола задаётся --elevation конвертера. Построено из блокаута #182 "
        "скриптом tools/dream/bowser_s_plans.py --write.</desc>",
        "  <style>.floor{fill:#d9a06b;fill-opacity:.5;stroke:none}.ceiling{fill:none;stroke:none}"
        ".wall{stroke:#3a2a22;stroke-width:.15}.door{stroke:#e8c46a;stroke-width:.3}"
        ".opening{fill:none;stroke:#e8c46a;stroke-dasharray:.3 .2;stroke-width:.08}.marker{fill:#c0392b}</style>",
        f'  <g id="{sid}-floors" data-layer="floors">',
    ]
    for i, f in enumerate(plan.floors, 1):
        out.append(f'    <rect id="{sid}-floor-{i:02d}" class="floor" data-godot-type="floor" data-space-id="{SPACE}/{f.key}" '
                   f'data-label="{f.label}" data-source-id="blockout:{f.source}" x="{fmt(f.x)}" y="{fmt(f.z)}" '
                   f'width="{fmt(f.w)}" height="{fmt(f.d)}" />')
    out.append("  </g>")
    out.append(f'  <g id="{sid}-ceilings" data-layer="ceilings">')
    n_open = 0
    for i, c in enumerate(plan.ceilings, 1):
        out.append(f'    <rect id="{sid}-ceiling-{i:02d}" class="ceiling" data-godot-type="ceiling" '
                   f'data-ceiling-elevation="{fmt(c.elevation)}" x="{fmt(c.x)}" y="{fmt(c.z)}" width="{fmt(c.w)}" height="{fmt(c.d)}" />')
        for key, ox, oz, ow, od, source in c.openings:
            n_open += 1
            out.append(f'    <rect id="{sid}-ceiling-opening-{n_open:02d}" class="opening" data-godot-type="ceiling-opening" '
                       f'data-space-id="{SPACE}/{c.key}" data-opening-key="{key}" data-source-id="blockout:{source}" '
                       f'x="{fmt(ox)}" y="{fmt(oz)}" width="{fmt(ow)}" height="{fmt(od)}" />')
    out.append("  </g>")
    out.append(f'  <g id="{sid}-walls" data-layer="walls">')
    for i, w in enumerate(plan.walls, 1):
        out.append(f'    <line id="{sid}-wall-{i:02d}" class="wall" data-godot-type="wall" data-wall-height="{fmt(w.height)}" '
                   f'data-wall-thickness="{fmt(w.thickness)}" data-surface-side-id="{SPACE}/{w.key}" data-normal-side="normal" '
                   f'data-source-id="blockout:{w.source}" x1="{fmt(w.x1)}" y1="{fmt(w.z1)}" x2="{fmt(w.x2)}" y2="{fmt(w.z2)}" />')
    out.append("  </g>")
    out.append(f'  <g id="{sid}-openings" data-layer="openings">')
    n_door = 0
    for w in plan.walls:
        for d in w.doors:
            n_door += 1
            sx, sz, ex, ez = _door_segment(w, d)
            out.append(f'    <line id="{sid}-door-{n_door:02d}" class="door" data-godot-type="door" data-door-height="{fmt(d.height)}" '
                       f'data-door-type="{d.kind}" data-door-key="{d.key}" data-inside-side="normal" data-source-id="blockout:{d.source}" '
                       f'x1="{fmt(sx)}" y1="{fmt(sz)}" x2="{fmt(ex)}" y2="{fmt(ez)}" />')
    out.append("  </g>")
    out.append(f'  <g id="{sid}-markers" data-layer="markers">')
    for m in plan.markers:
        out.append(f'    <circle id="{sid}-marker-{m.key}" class="marker" data-godot-type="marker" '
                   f'data-anchor-id="{SPACE}/{m.key}" data-anchor-role="gameplay_hook" data-hook-node="{m.hook}" '
                   f'cx="{fmt(m.x)}" cy="{fmt(m.z)}" r=".15" />')
    out.append("  </g>")
    out.append("</svg>")
    return "\n".join(out) + "\n"


def write() -> int:
    PLAN_DIR.mkdir(parents=True, exist_ok=True)
    for plan in PLANS:
        path = PLAN_DIR / f"{plan.slug}.svg"
        path.write_text(render(plan), encoding="utf-8", newline="\n")
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


# --- validation without the generator -------------------------------------------------------------------------------

def _f(element: ET.Element, name: str) -> float:
    try:
        return float(element.get(name, "nan"))
    except ValueError:
        return math.nan


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _on_segment(px: float, pz: float, line: tuple[float, float, float, float], tolerance: float) -> bool:
    x1, z1, x2, z2 = line
    dx, dz = x2 - x1, z2 - z1
    length_sq = dx * dx + dz * dz
    t = max(0.0, min(1.0, ((px - x1) * dx + (pz - z1) * dz) / length_sq)) if length_sq else 0.0
    return math.hypot(px - (x1 + t * dx), pz - (z1 + t * dz)) <= tolerance


def _in_rect(px: float, pz: float, rect: tuple[float, float, float, float], tolerance: float = 1e-6) -> bool:
    x, z, w, d = rect
    return x - tolerance <= px <= x + w + tolerance and z - tolerance <= pz <= z + d + tolerance


def _rect(element: ET.Element) -> tuple[float, float, float, float]:
    return _f(element, "x"), _f(element, "y"), _f(element, "width"), _f(element, "height")


def _line(element: ET.Element) -> tuple[float, float, float, float]:
    return _f(element, "x1"), _f(element, "y1"), _f(element, "x2"), _f(element, "y2")


def _rect_edges(rect: tuple[float, float, float, float]) -> list[tuple[bool, float, float, float]]:
    """(vertical, fixed coordinate, span start, span end) for the four edges of a plan rectangle."""
    x, z, w, d = rect
    return [(True, x, z, z + d), (True, x + w, z, z + d), (False, z, x, x + w), (False, z + d, x, x + w)]


def _parallel_walls(edge: tuple[bool, float, float, float], walls: list[dict]) -> list[tuple[dict, float]]:
    """Walls parallel to a rectangle edge sharing more than MIN_SHARED_EDGE_M of it, with their centre-line distance."""
    vertical, fixed, start, end = edge
    result = []
    for wall in walls:
        x1, z1, x2, z2 = wall["line"]
        if vertical and math.isclose(x1, x2, abs_tol=1e-9):
            offset, lo, hi = abs(x1 - fixed), min(z1, z2), max(z1, z2)
        elif not vertical and math.isclose(z1, z2, abs_tol=1e-9):
            offset, lo, hi = abs(z1 - fixed), min(x1, x2), max(x1, x2)
        else:
            continue
        if min(hi, end) - max(lo, start) > MIN_SHARED_EDGE_M:
            result.append((wall, offset))
    return result


def format_errors(root: ET.Element, label: str, elevation: float, ceiling_alignment: bool = True) -> tuple[list[str], dict]:
    """Rules every canonical complex v4 plan satisfies (tests run them on all 32 sectors), so the dream plans follow the
    same contract as the plans the generator already accepts in strict mode."""
    errors: list[str] = []
    parsed: dict[str, list] = {"floors": [], "ceilings": [], "ceiling_openings": [], "walls": [], "doors": [], "markers": []}
    ids: set[str] = set()
    for element in root.iter():
        if _local(element.tag) not in DRAWABLE:
            continue
        element_id = element.get("id", "")
        kind = element.get("data-godot-type")
        if not element_id:
            errors.append(f"{label}: drawable <{_local(element.tag)}> has no stable id")
        elif element_id in ids:
            errors.append(f"{label}: duplicate id {element_id}")
        ids.add(element_id)
        if not kind:
            errors.append(f"{label}: {element_id} has no data-godot-type")
            continue
        if kind not in KNOWN_TYPES:
            errors.append(f"{label}: {element_id} has unknown data-godot-type {kind!r} (strict inspection: unrecognized)")
            continue
        if element.get("data-anchor-role") and not element.get("data-anchor-id"):
            errors.append(f"{label}: explicit anchor {element_id} has no data-anchor-id")
        if kind in ("floor", "ceiling", "ceiling-opening") and _local(element.tag) != "rect":
            errors.append(f"{label}: {kind} {element_id} must be a rect")
            continue
        if kind == "floor":
            if not element.get("data-space-id"):
                errors.append(f"{label}: floor {element_id} has no data-space-id")
            parsed["floors"].append({"id": element_id, "rect": _rect(element)})
        elif kind == "ceiling":
            ceiling_elevation = _f(element, "data-ceiling-elevation")
            if not ceiling_elevation > elevation:
                errors.append(f"{label}: ceiling {element_id} is not above the floor elevation")
            parsed["ceilings"].append({"id": element_id, "rect": _rect(element), "elevation": ceiling_elevation})
        elif kind == "ceiling-opening":
            parsed["ceiling_openings"].append({"id": element_id, "rect": _rect(element)})
        elif kind == "wall" and _local(element.tag) == "line":
            line = _line(element)
            if not (math.isclose(line[0], line[2]) or math.isclose(line[1], line[3])):
                errors.append(f"{label}: wall {element_id} is not axis aligned")
            if not element.get("data-surface-side-id") or element.get("data-normal-side") not in ("normal", "opposite"):
                errors.append(f"{label}: wall {element_id} has no surface side")
            height = _f(element, "data-wall-height")
            thickness = _f(element, "data-wall-thickness") if element.get("data-wall-thickness") else DEFAULT_WALL_THICKNESS
            if not height > 0 or not thickness > 0:
                errors.append(f"{label}: wall {element_id} needs a positive data-wall-height / data-wall-thickness")
            parsed["walls"].append({"id": element_id, "line": line, "height": height, "thickness": thickness})
        elif kind == "door" and _local(element.tag) == "line":
            if element.get("data-inside-side") not in ("normal", "opposite"):
                errors.append(f"{label}: door {element_id} has no data-inside-side")
            height = _f(element, "data-door-height")
            if not height > 0:
                errors.append(f"{label}: door {element_id} has no data-door-height")
            parsed["doors"].append({"id": element_id, "line": _line(element), "height": height})
        elif kind == "marker":
            parsed["markers"].append({"id": element_id, "x": _f(element, "cx"), "z": _f(element, "cy"),
                                      "anchor": element.get("data-anchor-id"), "role": element.get("data-anchor-role"),
                                      "hook": element.get("data-hook-node")})
    for opening in parsed["ceiling_openings"]:
        x, z, w, d = opening["rect"]
        if not any(_in_rect(x, z, c["rect"]) and _in_rect(x + w, z + d, c["rect"]) for c in parsed["ceilings"]):
            errors.append(f"{label}: ceiling opening {opening['id']} is not inside a ceiling")
    # Floor and ceiling edges that run inside a wall footprint sit exactly on its centre line (complex v4: 773 of 773).
    for kind in ("floors", "ceilings"):
        for item in parsed[kind]:
            for edge in _rect_edges(item["rect"]):
                for wall, offset in _parallel_walls(edge, parsed["walls"]):
                    if ALIGN_TOLERANCE < offset <= wall["thickness"] / 2 + ALIGN_TOLERANCE:
                        errors.append(f"{label}: {kind[:-1]} {item['id']} edge is {offset:.3f} m off the centre line of wall "
                                      f"{wall['id']} (draw it on the wall axis, the converter extends it to the outer face)")
    # --strict-ceiling-alignment: a ceiling meets the top of every wall on its edges.
    if ceiling_alignment:
        for ceiling in parsed["ceilings"]:
            for edge in _rect_edges(ceiling["rect"]):
                for wall, offset in _parallel_walls(edge, parsed["walls"]):
                    if offset <= ALIGN_TOLERANCE and abs(elevation + wall["height"] - ceiling["elevation"]) > ALIGN_TOLERANCE:
                        errors.append(f"{label}: ceiling {ceiling['id']} at {ceiling['elevation']} does not meet the top of wall "
                                      f"{wall['id']} ({elevation} + {wall['height']})")
    floors = parsed["floors"]
    for i, first in enumerate(floors):
        ax, az, aw, ad = first["rect"]
        for second in floors[i + 1:]:
            bx, bz, bw, bd = second["rect"]
            overlap = max(0.0, min(ax + aw, bx + bw) - max(ax, bx)) * max(0.0, min(az + ad, bz + bd) - max(az, bz))
            if overlap > 1e-4:
                errors.append(f"{label}: floors {first['id']} and {second['id']} overlap by {overlap:.3f} m2")
    return errors, parsed


def check_plan(path: Path, errors: list[str], seen_ids: set[str], seen_anchors: set[str]) -> dict:
    label = path.name
    root = ET.parse(path).getroot()
    if root.get("data-generator-input") != "true" or root.get("data-presentation-only") != "false":
        errors.append(f"{label}: generator input policy metadata is missing")
    if root.get("data-scale") != "1":
        errors.append(f"{label}: data-scale must be 1 (metres)")
    elevation = _f(root, "data-elevation-m")
    if not math.isfinite(elevation):
        errors.append(f"{label}: data-elevation-m is missing")
    plan_errors, parsed = format_errors(root, label, elevation)
    errors.extend(plan_errors)
    prefix = f"bowser-{path.stem.replace('_', '-')}-"
    for element in root.iter():
        element_id = element.get("id", "")
        if _local(element.tag) in DRAWABLE and element_id:
            if element_id in seen_ids:
                errors.append(f"{label}: id {element_id} is also used by another dream plan")
            seen_ids.add(element_id)
            if not element_id.startswith(prefix):
                errors.append(f"{label}: id {element_id} does not start with {prefix}")
        # The dream has no stair generator manifest: vertical markup would be silently dropped.
        if any(name.startswith("data-vertical-") for name in element.attrib):
            errors.append(f"{label}: {element_id or _local(element.tag)} has data-vertical-* markup but the dream has no stair generator")
    walls = parsed["walls"]
    for door in parsed["doors"]:
        x1, z1, x2, z2 = door["line"]
        width = math.hypot(x2 - x1, z2 - z1)
        hosts = [w for w in walls if _on_segment(x1, z1, w["line"], ON_LINE_TOLERANCE) and _on_segment(x2, z2, w["line"], ON_LINE_TOLERANCE)]
        if len(hosts) != 1:
            errors.append(f"{label}: door {door['id']} must lie on exactly one wall, found {len(hosts)}")
        elif not 2.0 <= door["height"] < hosts[0]["height"]:
            errors.append(f"{label}: door {door['id']} height {door['height']} must be at least 2.0 and below its wall {hosts[0]['height']}")
        if width < MIN_PASSAGE_M:
            errors.append(f"{label}: door {door['id']} is {width:.2f} m wide, narrower than {MIN_PASSAGE_M} m")
        crossing = [w["id"] for w in walls if w not in hosts and (_on_segment(*w["line"][:2], door["line"], ON_LINE_TOLERANCE)
                                                                  or _on_segment(*w["line"][2:], door["line"], ON_LINE_TOLERANCE))]
        if crossing:
            errors.append(f"{label}: door {door['id']} is blocked by wall end(s) {', '.join(crossing)}")
    for marker in parsed["markers"]:
        anchor = marker["anchor"]
        if not anchor or not marker["role"] or not marker["hook"]:
            errors.append(f"{label}: marker {marker['id']} needs data-anchor-id, data-anchor-role and data-hook-node")
        elif anchor in seen_anchors:
            errors.append(f"{label}: duplicate anchor {anchor}")
        else:
            seen_anchors.add(anchor)
            # The converter publishes the frame as svg:<element id>:point, so the element id must stay derived from the anchor.
            if marker["id"] != f"{prefix}marker-{anchor.rsplit('/', 1)[-1]}":
                errors.append(f"{label}: marker {marker['id']} id does not follow its anchor {anchor}")
        on_floor = any(_in_rect(marker["x"], marker["z"], f["rect"]) for f in parsed["floors"])
        on_door = any(_on_segment(marker["x"], marker["z"], d["line"], MARKER_DOOR_TOLERANCE) for d in parsed["doors"])
        if not (on_floor or on_door):
            errors.append(f"{label}: marker {marker['id']} is neither on a floor nor at a door")
    return {"elevation": elevation, "floors": [f["rect"] for f in parsed["floors"]],
            "doors": [(d["id"], d["line"], d["height"]) for d in parsed["doors"]], "walls": walls,
            "markers": parsed["markers"], "ceilings": len(parsed["ceilings"])}


def production_shared_args(manifest_path: Path = PRODUCTION_MANIFEST) -> list[str]:
    """The strictest shared converter arguments of the complex v4 production manifest without --wall-height."""
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    variants = []
    for sector in manifest["sectors"]:
        args = list(sector["shared_args"])
        if "--wall-height" in args:
            index = args.index("--wall-height")
            del args[index:index + 2]
        variants.append(args)
    return max(variants, key=len)


def check() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    plans: dict[str, dict] = {}
    seen_ids: set[str] = set()
    seen_anchors: set[str] = set()
    production = production_shared_args()
    if SHARED_ARGS != production:
        errors.append(f"converter settings {SHARED_ARGS} differ from the complex v4 production strict settings {production}")
    for plan in PLANS:
        path = PLAN_DIR / f"{plan.slug}.svg"
        if not path.is_file():
            errors.append(f"{path.relative_to(ROOT)} is missing (run --write)")
            continue
        try:
            plans[plan.slug] = check_plan(path, errors, seen_ids, seen_anchors)
        except ET.ParseError as exc:
            errors.append(f"{path.name}: invalid XML: {exc}")
            continue
        if not math.isclose(plans[plan.slug]["elevation"], plan.elevation):
            errors.append(f"{path.name}: data-elevation-m differs from the --elevation {plan.elevation} passed to the converter")
        if path.read_text(encoding="utf-8") != render(plan):
            warnings.append(f"{path.name} differs from the specification in tools/dream/bowser_s_plans.py (hand edit?)")
    # Every waypoint of BowserDream.route() must stand on a floor (or in a doorway) of the plan of its level.
    for x, y, z in ROUTE:
        level = [p for p in plans.values() if math.isclose(p["elevation"], y)]
        if not level:
            errors.append(f"route point {(x, y, z)}: no plan at elevation {y}")
            continue
        plan = level[0]
        if not (any(_in_rect(x, z, f) for f in plan["floors"]) or any(_on_segment(x, z, line, MARKER_DOOR_TOLERANCE) for _, line, _ in plan["doors"])):
            errors.append(f"route point {(x, y, z)} is not on a generated floor")
    for warning in warnings:
        print(f"WARNING {warning}")
    for error in errors:
        print(f"ERROR {error}")
    floors = sum(len(p["floors"]) for p in plans.values())
    doors = sum(len(p["doors"]) for p in plans.values())
    print(f"DREAM_PLANS plans={len(plans)} floors={floors} doors={doors} anchors={len(seen_anchors)} route_points={len(ROUTE)} "
          f"warnings={len(warnings)} errors={len(errors)}")
    return 1 if errors else 0


# --- generation with the external tool ------------------------------------------------------------------------------

def _tool_script(root: Path, name: str) -> Path:
    for candidate in (root / "scripts" / name, root / name):
        if candidate.is_file():
            return candidate
    return root / "scripts" / name


def _version(text: object) -> tuple[int, ...] | None:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", str(text or ""))
    return tuple(int(part) for part in match.groups()) if match else None


def verify_generation(plan: Plan, preflight: dict, conversion: dict) -> list[str]:
    """What regenerate_sector.py of the complex requires from a package, plus the dream specifics (#214)."""
    errors: list[str] = []
    version = _version(conversion.get("generator_version"))
    if version is None or version < MIN_SVG_VERSION:
        errors.append(f"generator_version {conversion.get('generator_version')} is older than 1.19.0")
    if conversion.get("errors"):
        errors.append(f"conversion errors: {conversion['errors']}")
    summary = preflight.get("summary", {})
    for key in ("unrecognized", "invalid"):
        if preflight.get(key) or summary.get(key):
            errors.append(f"strict inspection left {key} elements")
    if preflight.get("spatial_handoff") != conversion.get("spatial_handoff"):
        errors.append("inspector and converter spatial_handoff differ for identical settings")
    handoff = conversion.get("spatial_handoff", {})
    if handoff.get("anchor_frame_issues"):
        errors.append(f"anchor_frame_issues: {handoff['anchor_frame_issues']}")
    counts = conversion.get("counts", {})
    expected = {"input_floor": len(plan.floors), "input_wall": len(plan.walls), "input_door": sum(len(w.doors) for w in plan.walls),
                "input_ceiling": len(plan.ceilings), "input_marker": len(plan.markers),
                "ceiling_openings_requested": sum(len(c.openings) for c in plan.ceilings)}
    for key, value in expected.items():
        if int(counts.get(key, 0)) != value:
            errors.append(f"counts.{key} is {counts.get(key, 0)}, expected {value}")
    if int(counts.get("ceiling_openings_applied", 0)) != expected["ceiling_openings_requested"]:
        errors.append("not every ceiling opening was applied")
    # Open sky: the converter must not invent ceilings over the floors that have none.
    if int(counts.get("ceiling_polygons_before_normalization", 0)) != len(plan.ceilings):
        errors.append(f"ceiling polygons {counts.get('ceiling_polygons_before_normalization')} != declared ceilings {len(plan.ceilings)}")
    for key in ("ceiling_wall_alignment_issues", "wall_volume_overlaps"):
        if int(counts.get(key, 0)):
            errors.append(f"counts.{key} is {counts[key]}")
    frames = {frame.get("anchor_id"): frame for frame in handoff.get("anchor_frames", [])}
    sid = f"bowser-{plan.slug.replace('_', '-')}"
    for marker in plan.markers:
        frame = frames.get(f"svg:{sid}-marker-{marker.key}:point")
        if frame is None:
            errors.append(f"anchor frame svg:{sid}-marker-{marker.key}:point ({SPACE}/{marker.key}) is missing")
        elif frame.get("role") != "gameplay_hook":
            errors.append(f"anchor frame of {SPACE}/{marker.key} has role {frame.get('role')}")
    return errors


def _normalize_collision_winding(scene: Path) -> None:
    """The complex backend flips converter 1.19 floor/ceiling collision faces to Godot's front; reuse it as is."""
    sys.path.insert(0, str(ROOT / "tools/complex_v4"))
    try:
        from regenerate_sector import normalize_surface_collision_winding
    finally:
        sys.path.pop(0)
    normalize_surface_collision_winding(scene)


def generate(svg_tool_root: Path, python: str, dry_run: bool) -> int:
    inspector = _tool_script(svg_tool_root, "inspect_svg_plan.py")
    converter = _tool_script(svg_tool_root, "svg_to_godot3d.py")
    if not dry_run:
        if check() != 0:
            print("--check failed; fix the plans before generation", file=sys.stderr)
            return 1
        if not (inspector.is_file() and converter.is_file()):
            print(f"svg-plan-to-godot scripts not found under {svg_tool_root}", file=sys.stderr)
            return 2
        probe = subprocess.run([python, str(inspector), "--version"], cwd=ROOT, text=True, capture_output=True)
        version = _version(probe.stdout)
        if probe.returncode != 0 or version is None or version < MIN_SVG_VERSION:
            print(f"svg-plan-to-godot >= 1.19.0 required, inspector reports {probe.stdout.strip() or probe.stderr.strip()!r}", file=sys.stderr)
            return 2
    failed = 0
    for plan in PLANS:
        source = PLAN_DIR / f"{plan.slug}.svg"
        out_dir = f"{GEN_DIR}/{plan.slug}/Generated/Architecture"
        common = ["--profile", "generic", "--scale", "1", "--origin", "none", "--elevation", fmt(plan.elevation), *SHARED_ARGS]
        report = f"{GEN_DIR}/{plan.slug}/preflight_report.json"
        scene_name = f"bowser_{plan.slug}_generated"
        commands = [
            [python, str(inspector), str(source.relative_to(ROOT)), *common, "--json", "--output-json", report, "--strict"],
            [python, str(converter), str(source.relative_to(ROOT)), out_dir, *common,
             "--resource-dir", f"res://{out_dir}", "--scene-name", scene_name, "--strict"],
        ]
        for command in commands:
            print(" ".join(command))
            if dry_run:
                continue
            (ROOT / out_dir).mkdir(parents=True, exist_ok=True)
            completed = subprocess.run(command, cwd=ROOT)
            if completed.returncode != 0:
                print(f"{plan.slug}: command failed with exit {completed.returncode}", file=sys.stderr)
                return completed.returncode
        if dry_run:
            continue
        preflight = json.loads((ROOT / report).read_text(encoding="utf-8"))
        conversion = json.loads((ROOT / out_dir / "conversion_report.json").read_text(encoding="utf-8"))
        _normalize_collision_winding(ROOT / out_dir / f"{scene_name}.tscn")
        problems = verify_generation(plan, preflight, conversion)
        for problem in problems:
            print(f"ERROR {plan.slug}: {problem}")
        failed += bool(problems)
        print(f"{plan.slug}: version {conversion.get('generator_version')} counts {json.dumps(conversion.get('counts', {}))}")
    if not dry_run:
        print(f"DREAM_GENERATION plans={len(PLANS)} failed={failed}")
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--generate", action="store_true")
    parser.add_argument("--svg-tool-root", type=Path)
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.write:
        return write()
    if args.check:
        return check()
    if args.svg_tool_root is None:
        parser.error("--generate needs --svg-tool-root")
    return generate(args.svg_tool_root, args.python, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
