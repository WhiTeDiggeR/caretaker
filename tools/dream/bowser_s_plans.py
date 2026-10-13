#!/usr/bin/env python3
"""Metric SVG plans of Bowser's dream S in the svg-plan-to-godot format (#191).

The geometry is taken from the blockout ``scenes/dreams/bowser_dream.tscn`` (#182): world X is the plan x, world Z the
plan y, metres, one plan per walking level because the converter takes one ``--elevation`` per SVG. Hook nodes of the
blockout become explicit marker anchors (``data-anchor-id``) so gameplay can be bound to the generated package.

Modes:
  --write                      write ``docs/design/dream_bowser/plans/*.svg`` from the specification below
  --check                      validate the committed plans without the generator (CI); drift from the specification
                               is reported as a warning so the plans can later be edited by hand
  --generate --svg-tool-root R run the external svg-plan-to-godot (inspect + convert) for every plan into
                               ``gen/dreams/bowser_s/<plan>/Generated/Architecture``; add --dry-run to print the commands
"""
from __future__ import annotations

import argparse
import json
import math
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
# Converter settings shared by every plan (same values as the complex v4 production manifest).
SHARED_ARGS = ["--wall-thickness", "0.3", "--floor-thickness", "0.2", "--ceiling-thickness", "0.2", "--strict-wall-overlaps"]
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


# Walls run between the centre lines of the blockout boxes, so their faces coincide with the blockout faces.
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
            Floor("chain-bridge", "ЦЕПНОЙ МОСТ 16 М / над лавой", 30, -1, 16, 2, "Path/Bridge"),
            Floor("yard", "S3 ДВОР ПЕРВОГО БОЯ 24×18 / открытое небо", 46, -9, 23.5, 18, "Yard/Floor"),
            Floor("seal-hall", "S4 ЗАЛ ПЕЧАТИ 20×16, высота 12", 70.5, -8, 19.5, 16, "SealHall/Floor"),
            Floor("bastion-bridge", "МОСТ К БАСТИОНУ 12 М / над лавой", 78.5, -20, 3, 11, "Bastion/Bridge"),
            Floor("bastion", "S5 БАСТИОН 10×8 / врата", 75, -28, 10, 8, "Bastion/Floor"),
        ],
        walls=[
            _wall("chain-north", (30, -1.0), (46, -1.0), 1.0, 0.1, "Path/ChainLeft"),
            _wall("chain-south", (30, 1.0), (46, 1.0), 1.0, 0.1, "Path/ChainRight"),
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
            Ceiling("seal-hall", 70.5, -8, 19.5, 16, 13.2,
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
    return float(element.get(name, "nan"))


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


def check_plan(path: Path, errors: list[str], seen_ids: set[str], seen_anchors: set[str]) -> dict:
    label = path.name
    root = ET.parse(path).getroot()
    if root.get("data-generator-input") != "true" or root.get("data-presentation-only") != "false":
        errors.append(f"{label}: generator input policy metadata is missing")
    if root.get("data-scale") != "1":
        errors.append(f"{label}: data-scale must be 1 (metres)")
    elevation = float(root.get("data-elevation-m", "nan"))
    if not math.isfinite(elevation):
        errors.append(f"{label}: data-elevation-m is missing")
    floors: list[tuple[float, float, float, float]] = []
    walls: list[tuple[str, tuple[float, float, float, float], float]] = []
    doors: list[tuple[str, tuple[float, float, float, float], float]] = []
    ceilings: list[tuple[float, float, float, float]] = []
    markers: list[tuple[str, float, float]] = []
    for element in root.iter():
        if _local(element.tag) not in DRAWABLE:
            continue
        element_id = element.get("id", "")
        kind = element.get("data-godot-type")
        if not element_id:
            errors.append(f"{label}: drawable without id")
        elif element_id in seen_ids:
            errors.append(f"{label}: duplicate id {element_id}")
        seen_ids.add(element_id)
        if not kind:
            errors.append(f"{label}: {element_id} has no data-godot-type")
            continue
        if kind == "floor":
            if not element.get("data-space-id"):
                errors.append(f"{label}: floor {element_id} has no data-space-id")
            floors.append((_f(element, "x"), _f(element, "y"), _f(element, "width"), _f(element, "height")))
        elif kind == "ceiling":
            ceilings.append((_f(element, "x"), _f(element, "y"), _f(element, "width"), _f(element, "height")))
            if _f(element, "data-ceiling-elevation") <= elevation:
                errors.append(f"{label}: ceiling {element_id} is not above the floor elevation")
        elif kind == "ceiling-opening":
            rect = (_f(element, "x"), _f(element, "y"), _f(element, "width"), _f(element, "height"))
            if not any(_in_rect(rect[0], rect[1], c) and _in_rect(rect[0] + rect[2], rect[1] + rect[3], c) for c in ceilings):
                errors.append(f"{label}: ceiling opening {element_id} is not inside a ceiling")
        elif kind == "wall":
            line = (_f(element, "x1"), _f(element, "y1"), _f(element, "x2"), _f(element, "y2"))
            if not (math.isclose(line[0], line[2]) or math.isclose(line[1], line[3])):
                errors.append(f"{label}: wall {element_id} is not axis aligned")
            if not element.get("data-surface-side-id") or not element.get("data-normal-side"):
                errors.append(f"{label}: wall {element_id} has no surface side")
            walls.append((element_id, line, _f(element, "data-wall-height")))
        elif kind == "door":
            line = (_f(element, "x1"), _f(element, "y1"), _f(element, "x2"), _f(element, "y2"))
            doors.append((element_id, line, _f(element, "data-door-height")))
        elif kind == "marker":
            anchor = element.get("data-anchor-id")
            if not anchor or not element.get("data-anchor-role"):
                errors.append(f"{label}: marker {element_id} has no data-anchor-id / data-anchor-role")
            elif anchor in seen_anchors:
                errors.append(f"{label}: duplicate anchor {anchor}")
            else:
                seen_anchors.add(anchor)
            markers.append((element_id, _f(element, "cx"), _f(element, "cy")))
    for door_id, line, height in doors:
        width = math.hypot(line[2] - line[0], line[3] - line[1])
        hosts = [(wall_id, wall_height) for wall_id, wall_line, wall_height in walls
                 if _on_segment(line[0], line[1], wall_line, ON_LINE_TOLERANCE) and _on_segment(line[2], line[3], wall_line, ON_LINE_TOLERANCE)]
        if len(hosts) != 1:
            errors.append(f"{label}: door {door_id} must lie on exactly one wall, found {len(hosts)}")
        elif not 2.0 <= height < hosts[0][1]:
            errors.append(f"{label}: door {door_id} height {height} must be at least 2.0 and below its wall {hosts[0][1]}")
        if width < MIN_PASSAGE_M:
            errors.append(f"{label}: door {door_id} is {width:.2f} m wide, narrower than {MIN_PASSAGE_M} m")
    for marker_id, x, z in markers:
        on_floor = any(_in_rect(x, z, f) for f in floors)
        on_door = any(_on_segment(x, z, line, MARKER_DOOR_TOLERANCE) for _, line, _ in doors)
        if not (on_floor or on_door):
            errors.append(f"{label}: marker {marker_id} is neither on a floor nor at a door")
    return {"elevation": elevation, "floors": floors, "doors": doors, "walls": walls}


def check() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    plans: dict[str, dict] = {}
    seen_ids: set[str] = set()
    seen_anchors: set[str] = set()
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


def generate(svg_tool_root: Path, python: str, dry_run: bool) -> int:
    inspector = _tool_script(svg_tool_root, "inspect_svg_plan.py")
    converter = _tool_script(svg_tool_root, "svg_to_godot3d.py")
    if not dry_run and not (inspector.is_file() and converter.is_file()):
        print(f"svg-plan-to-godot scripts not found under {svg_tool_root}", file=sys.stderr)
        return 2
    for plan in PLANS:
        source = PLAN_DIR / f"{plan.slug}.svg"
        out_dir = f"{GEN_DIR}/{plan.slug}/Generated/Architecture"
        common = ["--profile", "generic", "--scale", "1", "--origin", "none", "--elevation", fmt(plan.elevation), *SHARED_ARGS]
        report = f"{GEN_DIR}/{plan.slug}/preflight_report.json"
        commands = [
            [python, str(inspector), str(source.relative_to(ROOT)), *common, "--json", "--output-json", report, "--strict"],
            [python, str(converter), str(source.relative_to(ROOT)), out_dir, *common,
             "--resource-dir", f"res://{out_dir}", "--scene-name", f"bowser_{plan.slug}_generated", "--strict"],
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
        if not dry_run:
            conversion = json.loads((ROOT / out_dir / "conversion_report.json").read_text(encoding="utf-8"))
            if conversion.get("errors"):
                print(f"{plan.slug}: conversion report has errors", file=sys.stderr)
                return 1
            print(f"{plan.slug}: version {conversion.get('generator_version')} counts {json.dumps(conversion.get('counts', {}))}")
    return 0


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
