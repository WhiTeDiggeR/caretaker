#!/usr/bin/env python3
"""Build the canonical metric SVG inputs of complex_v4 from the approved plans.

The approved presentation plans under ``docs/design/complex_v4/sources/plans/sectors`` are the
only geometry source. Metric scale and world position are taken from the approved
overview plan of the same level (see ``approved_registration.json``). Nothing in the
approved geometry is corrected here: every inconsistency is written to the per-sector
extraction report so it can be reviewed and decided by a person.

Usage:
    python tools/complex_v4/build_canonical_from_approved.py \
        [--sector U-EMERGENCY ...] [--report-dir docs/design/complex_v4/review/data]
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / "docs/design/complex_v4/sources/plans"          # approved source plans: the only geometry source
V4 = ROOT / "docs/design/complex_v4"                    # generated canonical inputs: complex version 4
REGISTRATION = Path(__file__).with_name("approved_registration.json")
FINISHES = Path(__file__).with_name("room_finishes.json")
NS = "{http://www.w3.org/2000/svg}"
SNAP_PX = 2.5
# Shared walls and slabs between sectors (#205): the converter builds a 0.3 m wall box that reaches 0.15 m past
# each line end and resolves joints only inside one sector, so a wall or floor drawn by two sectors flickers.
WALL_THICKNESS_M = 0.3      # --wall-thickness of every sector in sector_generation_manifest.json
COLLINEAR_M = 0.002         # walls of two sectors this close are one wall
OPENING_JAMB_CLEAR_M = 0.2  # an opening end keeps this distance from the centre line of a perpendicular wall
SHARED_FACES_RULE = "D-49"  # data-shared-faces on the SVG root: built with the ownership rule (coplanar_check.gd reads it)

ROOM_CLASSES = {
    "personnel", "support", "corridor", "room", "passenger", "security", "command", "containment",
    "airlock", "lab", "old", "energy", "utility", "domestic", "medical", "heavy", "stair", "lift",
    "walkway", "vertical", "store", "controlled", "cargo", "checkpoint", "service", "shaft", "gallery",
    "work", "mixed", "research", "late", "equipment-room", "outer",
}
ENVELOPE_CLASSES = {"shell", "canvas", "wall", "void"}
FEATURE_CLASSES = {"equipment", "damaged", "screen", "counter", "reinforce", "store-shelf"}
GAP_DOOR = {"door-gap", "support-gap", "work-gap", "energy-gap", "utility-gap", "stair-gap", "cargo-gap", "equip-gap"}
GAP_OPENING = {"opening", "room-gap"}
WALL_LINE = {"wall", "barrier", "partition"}
TRUNK_WORDS = (
    "ГЛАВНЫЙ ПАССАЖИРСКИЙ КОРИДОР", "ПАССАЖИРСКАЯ МАГИСТРАЛЬ", "ПАССАЖИРСКИЙ / КОРИДОР",
    "ТЯЖЁЛАЯ ТРАНСПОРТНАЯ МАГИСТРАЛЬ", "ТЯЖЁЛАЯ ГРУЗОВАЯ МАГИСТРАЛЬ", "ТЯЖЁЛАЯ МАГИСТРАЛЬ",
    "ГЛАВНЫЙ СЛУЖЕБНЫЙ КОРИДОР", "КАБЕЛЬНО-ТРУБОПРОВОДНАЯ ГАЛЕРЕЯ",
)
TRANSLIT = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y",
    "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f",
    "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
}


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def slug(text: str) -> str:
    out = "".join(TRANSLIT.get(ch, ch) for ch in text.lower())
    out = re.sub(r"[^a-z0-9]+", "-", out).strip("-")
    return out[:28].strip("-") or "room"


# --- stable element IDs (#206)
# Anchor IDs are "svg:<element id>:<type>", so element IDs must not depend on drawing order. Every generated element gets a
# readable stable ID built from its room and side (data-surface-side-id / data-stable-id) and an element id derived from it.

def room_local(space: str) -> str:
    """Room part of a space ID: "U-SECURITY/kpp" -> "kpp"."""
    return space.split("/", 1)[-1]


def element_id(stable: str) -> str:
    """Element id for a stable ID: "U-SECURITY/kpp:north" -> "u-security--kpp--north" (slugs never contain "--")."""
    parts = re.split(r"[/:]", stable.lower())
    return "--".join(re.sub(r"[^a-z0-9]+", "-", part).strip("-") for part in parts)


def unique_ids(bases: list[str], qualifiers: list[str]) -> list[str]:
    """Stable IDs for items with the given base IDs: a base used once stays as is, a repeated base gets ":<qualifier>",
    and a repeated base + qualifier gets "-2", "-3" in the given order."""
    counts: dict[str, int] = {}
    for base in bases:
        counts[base] = counts.get(base, 0) + 1
    named = [base if counts[base] == 1 else f"{base}:{qualifier}" for base, qualifier in zip(bases, qualifiers)]
    seen: dict[str, int] = {}
    result = []
    for name in named:
        seen[name] = seen.get(name, 0) + 1
        result.append(name if seen[name] == 1 else f"{name}-{seen[name]}")
    return result


def finish_attr(finishes: dict[str, Any], space: str) -> str:
    """data-finish-class of a room from tools/complex_v4/room_finishes.json (room rule, else sector default)."""
    sector, room = space.split("/", 1)
    entry = finishes.get("sectors", {}).get(sector, {})
    value = entry.get("rooms", {}).get(room, entry.get("default", ""))
    if value and value not in finishes.get("classes", {}):
        raise ValueError(f"{space}: unknown finish class {value!r}")
    return f' data-finish-class="{value}"' if value else ""


@dataclass
class Rect:
    x: float
    y: float
    w: float
    h: float
    cls: str
    kind: str
    ident: str
    label: str = ""
    role: str = ""          # room | carve | envelope | feature | context | trunk | subfeature | window
    reason: str = ""
    space: str = ""
    group: str = ""         # pieces of one carved room share a group id

    @property
    def box(self) -> tuple[float, float, float, float]:
        return (self.x, self.y, self.w, self.h)

    @property
    def x2(self) -> float:
        return self.x + self.w

    @property
    def y2(self) -> float:
        return self.y + self.h


@dataclass
class Line:
    x1: float
    y1: float
    x2: float
    y2: float
    cls: str
    kind: str
    ident: str


@dataclass
class Text:
    x: float
    y: float
    s: str


@dataclass
class Plan:
    rects: list[Rect] = field(default_factory=list)
    lines: list[Line] = field(default_factory=list)
    texts: list[Text] = field(default_factory=list)
    others: list[tuple[str, str, str]] = field(default_factory=list)
    door_paths: list[tuple[str, str]] = field(default_factory=list)


def parse_plan(path: Path, dropped_ids: set[str]) -> Plan:
    root = ET.parse(path).getroot()
    plan = Plan()
    for el in root.iter():
        tag = local(el.tag)
        ident = el.get("id", "")
        if ident in dropped_ids:
            continue
        cls = el.get("class") or ""
        kind = el.get("data-kind") or ""
        if tag == "rect" and el.get("width") and kind:
            plan.rects.append(Rect(float(el.get("x", 0)), float(el.get("y", 0)), float(el.get("width")), float(el.get("height")), cls, kind, ident))
        elif tag == "line" and kind:
            plan.lines.append(Line(float(el.get("x1")), float(el.get("y1")), float(el.get("x2")), float(el.get("y2")), cls, kind, ident))
        elif tag == "text" and el.get("x") is not None and kind == "label":
            plan.texts.append(Text(float(el.get("x")), float(el.get("y", 0)), "".join(el.itertext()).strip()))
        elif tag == "text" and kind == "label":
            tr = el.get("transform", "")
            m = re.search(r"translate\(([-\d.]+)[ ,]+([-\d.]+)\)", tr)
            if m:
                plan.texts.append(Text(float(m.group(1)), float(m.group(2)), "".join(el.itertext()).strip()))
        elif tag == "path" and kind == "opening" and cls == "door":
            plan.door_paths.append((el.get("d", ""), ident))
        elif tag in {"path", "polyline", "polygon", "circle", "ellipse"} and kind:
            plan.others.append((tag, cls, ident))
    return plan


def inside(rect: Rect, px: float, py: float, pad: float = 0.0) -> bool:
    return rect.x - pad <= px <= rect.x2 + pad and rect.y - pad <= py <= rect.y2 + pad


def same_box(a: tuple[float, float, float, float], b: tuple[float, float, float, float], tol: float = 1.5) -> bool:
    return all(abs(p - q) <= tol for p, q in zip(a, b))


def contains(outer: Rect, inner: Rect, tol: float = 1.5) -> bool:
    return (outer.x - tol <= inner.x and outer.y - tol <= inner.y and inner.x2 <= outer.x2 + tol and inner.y2 <= outer.y2 + tol
            and outer.w * outer.h > inner.w * inner.h + 1)


def assign_labels(plan: Plan) -> None:
    for rect in plan.rects:
        lines = [t for t in plan.texts if inside(rect, t.x, t.y)]
        lines.sort(key=lambda t: (t.y, t.x))
        rect.label = " / ".join(t.s for t in lines)


def classify(plan: Plan, entry: dict[str, Any], owns_trunks: bool) -> None:
    only = [tuple(b) for b in entry.get("only", [])]
    exclude = [tuple(b) for b in entry.get("exclude", [])]
    for r in plan.rects:
        cls = r.cls
        if only:
            if any(same_box(r.box, b) for b in only):
                if cls in ENVELOPE_CLASSES:
                    r.role, r.reason = "envelope", "outline of a room group"
                else:
                    r.role = "room"
            else:
                r.role = "context"
                r.reason = "outside this sector's rooms (shared drawing)"
            continue
        if any(same_box(r.box, b) for b in exclude) or r.ident in entry.get("exclude_ids", []):
            r.role, r.reason = "context", "neighbour / foreign element drawn in the plan"
        elif cls in ENVELOPE_CLASSES:
            r.role, r.reason = "envelope", "outline of a room group"
        elif cls == "context-zone":
            r.role, r.reason = "context", "neighbouring sector drawn for orientation"
        elif cls == "window":
            r.role = "window"
        elif cls in FEATURE_CLASSES and cls != "work":
            r.role, r.reason = "feature", "equipment or furniture"
        elif cls in ROOM_CLASSES or (cls == "work"):
            trunk = any(w in r.label.upper() for w in TRUNK_WORDS)
            if trunk and not owns_trunks:
                r.role, r.reason = "trunk", "shared route space owned by no sector"
            else:
                r.role = "room"
        else:
            r.role, r.reason = "feature", f"unclassified class {cls!r}"
    rooms = [r for r in plan.rects if r.role == "room"]
    for r in rooms:
        inner = [o for o in rooms if o is not r and contains(r, o)]
        if len(inner) >= 2:
            coverage = sum(o.w * o.h for o in inner) / (r.w * r.h)
            if coverage >= 0.85:
                r.role, r.reason = "envelope", f"outline of a room group (inner rooms cover {coverage:.0%})"
            else:
                r.role, r.reason = "carve", f"room with sub-rooms cut out of it (inner rooms cover {coverage:.0%})"
                own = [t for t in plan.texts if inside(r, t.x, t.y) and not any(inside(o, t.x, t.y) for o in inner)]
                own.sort(key=lambda t: (t.y, t.x))
                r.label = " / ".join(t.s for t in own)
    rooms = [r for r in plan.rects if r.role == "room"]
    for r in rooms:
        for other in rooms:
            if other is not r and other.role == "room" and r.role == "room" and contains(other, r):
                if r.w * r.h < 0.04 * other.w * other.h or (r.cls == other.cls and r.w * r.h < 0.12 * other.w * other.h):
                    r.role, r.reason = "subfeature", f"small element inside {other.ident}"
                else:
                    other.role, other.reason = "carve", "room with a sub-room cut out of it"
                    inner = [o for o in rooms if o is not other and contains(other, o)]
                    own = [t for t in plan.texts if inside(other, t.x, t.y) and not any(inside(o, t.x, t.y) for o in inner)]
                    own.sort(key=lambda t: (t.y, t.x))
                    other.label = " / ".join(t.s for t in own)
                break



def carve(outer: Rect, plan_rects: list[Rect], min_w: float = 0.5, min_h: float = 0.5) -> list[Rect]:
    """Cut the inner rooms out of ``outer`` and return the remaining rectangles."""
    inner = [o for o in plan_rects if o.role == "room" and o is not outer and contains(outer, o)]
    xs = sorted({outer.x, outer.x2, *[v for o in inner for v in (o.x, o.x2)]})
    ys = sorted({outer.y, outer.y2, *[v for o in inner for v in (o.y, o.y2)]})

    def covered(cx: float, cy: float) -> bool:
        return any(o.x <= cx <= o.x2 and o.y <= cy <= o.y2 for o in inner)

    rows: list[list[tuple[float, float]]] = []
    for j in range(len(ys) - 1):
        cy = (ys[j] + ys[j + 1]) / 2
        spans: list[tuple[float, float]] = []
        for i in range(len(xs) - 1):
            cx = (xs[i] + xs[i + 1]) / 2
            if not covered(cx, cy) and ys[j + 1] - ys[j] > 0.5 and xs[i + 1] - xs[i] > 0.5:
                if spans and abs(spans[-1][1] - xs[i]) < 1e-6:
                    spans[-1] = (spans[-1][0], xs[i + 1])
                else:
                    spans.append((xs[i], xs[i + 1]))
        rows.append(spans)
    pieces: list[Rect] = []
    open_pieces: dict[tuple[float, float], Rect] = {}
    for j, spans in enumerate(rows):
        current: dict[tuple[float, float], Rect] = {}
        for span in spans:
            if span in open_pieces:
                piece = open_pieces[span]
                piece.h = ys[j + 1] - piece.y
                current[span] = piece
            else:
                piece = Rect(span[0], ys[j], span[1] - span[0], ys[j + 1] - ys[j], outer.cls, outer.kind, outer.ident, outer.label, "room", "", "", outer.ident)
                pieces.append(piece)
                current[span] = piece
        open_pieces = current
    return [p for p in pieces if p.w >= min_w and p.h >= min_h]


def cluster(values: list[float], tol: float) -> dict[float, float]:
    ordered = sorted(set(values))
    mapping: dict[float, float] = {}
    group: list[float] = []
    for v in ordered:
        if group and v - group[-1] > tol:
            avg = sum(group) / len(group)
            for g in group:
                mapping[g] = group[0] if False else avg
            group = []
        group.append(v)
    if group:
        avg = sum(group) / len(group)
        for g in group:
            mapping[g] = avg
    return mapping


@dataclass
class Transform:
    kx: float
    ky: float
    ox: float
    oy: float
    sx: float
    sy: float

    def px(self, x: float) -> float:
        return round((x - self.ox) * self.kx + self.sx, 3)

    def py(self, y: float) -> float:
        return round((y - self.oy) * self.ky + self.sy, 3)


def build_transform(entry: dict[str, Any], level: dict[str, Any]) -> tuple[Transform, dict[str, Any]]:
    scale = level["scale_px_per_m"]
    x0, z0 = level["origin_ov_px"]
    pp, oo = entry["pair"]["plan"], entry["pair"]["ov"]
    kx = (oo[2] / pp[2]) / scale
    ky = (oo[3] / pp[3]) / scale
    sx = (oo[0] - x0) / scale + float(entry.get("offset_m", [0, 0])[0])
    sy = (oo[1] - z0) / scale + float(entry.get("offset_m", [0, 0])[1])
    tf = Transform(kx, ky, pp[0], pp[1], sx, sy)
    info = {
        "plan_px_per_m_x": round(1 / kx, 3), "plan_px_per_m_y": round(1 / ky, 3),
        "anisotropy_percent": round(abs(kx - ky) / ((kx + ky) / 2) * 100, 1),
        "world_envelope_m": [round(sx, 2), round(sy, 2), round(oo[2] / scale, 2), round(oo[3] / scale, 2)],
    }
    checks = []
    for pair in entry.get("check_pairs", []):
        p, o = pair["plan"], pair["ov"]
        checks.append({
            "plan_px": p, "overview_px": o,
            "plan_size_m": [round(p[2] * kx, 2), round(p[3] * ky, 2)],
            "overview_size_m": [round(o[2] / scale, 2), round(o[3] / scale, 2)],
        })
    info["check_pairs"] = checks
    return tf, info


def edge_segments(r: Rect) -> list[tuple[str, float, float, float]]:
    return [("h", r.y, r.x, r.x2), ("h", r.y2, r.x, r.x2), ("v", r.x, r.y, r.y2), ("v", r.x2, r.y, r.y2)]


def gap_host(line: Line, rooms: list[Rect]) -> list[Rect]:
    hosts = []
    horiz = abs(line.y1 - line.y2) < 1e-6
    for r in rooms:
        for orient, fixed, a, b in edge_segments(r):
            if horiz and orient == "h" and abs(line.y1 - fixed) <= SNAP_PX * 2:
                lo, hi = sorted((line.x1, line.x2))
                if hi > a - SNAP_PX and lo < b + SNAP_PX:
                    hosts.append(r)
                    break
            if not horiz and orient == "v" and abs(line.x1 - fixed) <= SNAP_PX * 2:
                lo, hi = sorted((line.y1, line.y2))
                if hi > a - SNAP_PX and lo < b + SNAP_PX:
                    hosts.append(r)
                    break
    return hosts



def collect_openings(plan: Plan, rooms: list[Rect]) -> list[dict[str, Any]]:
    """Return every drawn passage as a wall-aligned segment (plan px).

    Three encodings are used by the approved plans: explicit gap lines, thick gate lines
    and door-swing glyphs (an arc plus a diagonal). Windows are lines/rects on a wall.
    """
    items: list[dict[str, Any]] = []

    def add(orient: str, fixed: float, lo: float, hi: float, gtype: str, source: str, src: str, prio: int) -> None:
        items.append({"orient": orient, "fixed": fixed, "lo": min(lo, hi), "hi": max(lo, hi), "gtype": gtype, "source": source, "src": src,
                      "prio": prio, "px": [fixed, min(lo, hi), max(lo, hi)]})

    for l in plan.lines:
        horiz = abs(l.y1 - l.y2) < 1e-6
        vert = abs(l.x1 - l.x2) < 1e-6
        if not (horiz or vert):
            continue
        orient, fixed = ("h", l.y1) if horiz else ("v", l.x1)
        lo, hi = (l.x1, l.x2) if horiz else (l.y1, l.y2)
        if l.cls in GAP_DOOR:
            add(orient, fixed, lo, hi, "door", l.cls, l.ident, 3)
        elif l.cls in GAP_OPENING:
            add(orient, fixed, lo, hi, "opening", l.cls, l.ident, 3)
        elif l.cls == "gate":
            add(orient, fixed, lo, hi, "door", "gate", l.ident, 2)
        elif l.cls == "window":
            add(orient, fixed, lo, hi, "window", "window", l.ident, 4)
    for r in plan.rects:
        if r.role == "window":
            if r.h >= r.w:
                add("v", r.x + r.w / 2, r.y, r.y2, "window", "window-rect", r.ident, 4)
            else:
                add("h", r.y + r.h / 2, r.x, r.x2, "window", "window-rect", r.ident, 4)
    # door-swing glyphs: "M x1 y1 A r r 0 0 s x2 y2" quarter arc around a hinge on the wall
    for d, ident in plan.door_paths:
        items.extend(arc_openings(d, ident, rooms))
    # merge duplicates: the same passage may be drawn as gap + glyph + gate
    items.sort(key=lambda c: -c["prio"])
    kept: list[dict[str, Any]] = []
    for c in items:
        dup = False
        for k in kept:
            if k["orient"] == c["orient"] and abs(k["fixed"] - c["fixed"]) <= SNAP_PX * 2 and (k["gtype"] == "window") == (c["gtype"] == "window"):
                overlap = min(k["hi"], c["hi"]) - max(k["lo"], c["lo"])
                if overlap > 0.3 * min(k["hi"] - k["lo"], c["hi"] - c["lo"]):
                    dup = True
                    break
        if not dup:
            kept.append(c)
    return kept


def arc_openings(path_d: str, ident: str, rooms: list[Rect]) -> list[dict[str, Any]]:
    m = re.match(r"M\s*([-\d.]+)[ ,]+([-\d.]+)\s*A\s*([-\d.]+)[ ,]+([-\d.]+)\s+0\s+0\s+[01]\s+([-\d.]+)[ ,]+([-\d.]+)", path_d.strip())
    if not m:
        return []
    x1, y1, _, _, x2, y2 = (float(v) for v in m.groups())
    options = []
    for cx, cy in ((x1, y2), (x2, y1)):
        for (ex, ey) in ((x1, y1), (x2, y2)):
            if abs(ex - cx) < 1e-6 and abs(ey - cy) < 1e-6:
                continue
            if abs(ey - cy) < 1e-6:          # segment along a horizontal wall
                options.append(("h", cy, cx, ex))
            elif abs(ex - cx) < 1e-6:        # along a vertical wall
                options.append(("v", cx, cy, ey))
    best = None
    for orient, fixed, a, b in options:
        probe = {"orient": orient, "fixed": fixed, "lo": min(a, b), "hi": max(a, b)}
        hosts = host_rooms(probe, rooms, strict=True)
        score = len(hosts)
        if score and (best is None or score > best[0]):
            best = (score, probe)
    if best is None:
        return []
    probe = best[1]
    probe.update({"gtype": "door", "source": "door-glyph", "src": ident, "prio": 1, "px": [probe["fixed"], probe["lo"], probe["hi"]]})
    return [probe]


def host_rooms(c: dict[str, Any], rooms: list[Rect], strict: bool = False) -> list[Rect]:
    hosts = []
    tol = SNAP_PX if strict else SNAP_PX * 2
    for r in rooms:
        for orient, fixed, a, b in edge_segments(r):
            if orient != c["orient"] or abs(c["fixed"] - fixed) > tol:
                continue
            if strict:
                ok = c["lo"] >= a - tol and c["hi"] <= b + tol
            else:
                ok = c["hi"] > a - SNAP_PX and c["lo"] < b + SNAP_PX
            if ok:
                hosts.append(r)
                break
    return hosts


def fmt(value: float) -> str:
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text if text not in {"-0", ""} else "0"


# --- shared walls and slabs (#205) -----------------------------------------------------------------------------
# Ownership rule: of two sectors of one level, the one with the lower rank owns every wall, opening and slab
# edge they share; ties go to the smaller sector ID. Circulation sectors (the public corridors) rank 0, the rest 1;
# an entry may set "shared_face_rank" explicitly. Sectors are built in rank order and each one adapts to the
# sectors built before it on its level: its room edges closer than a wall thickness to an owner's opposite edge
# move onto it, its walls on an owner's wall are dropped, its wall ends stop at the owner's wall face, and its
# openings on a dropped wall are left to the owner's matching opening.

def shared_face_rank(sector_id: str, entry: dict[str, Any]) -> tuple[int, str]:
    return int(entry.get("shared_face_rank", 0 if sector_id.endswith("-CIRCULATION") else 1)), sector_id


def _to_px(tf: Transform, orient: str, value_m: float) -> float:
    """Inverse of Transform.px / Transform.py for a vertical ("v", x) or horizontal ("h", z) edge value."""
    return (value_m - tf.sx) / tf.kx + tf.ox if orient == "v" else (value_m - tf.sy) / tf.ky + tf.oy


def room_edges_m(rooms: list[Rect], tf: Transform) -> list[tuple[str, float, float, float, str, float]]:
    """(orient, fixed_m, lo_m, hi_m, side, fixed_px) of every room edge; side "lo" = the room lies after the edge."""
    out = []
    for r in rooms:
        x1, x2, z1, z2 = tf.px(r.x), tf.px(r.x2), tf.py(r.y), tf.py(r.y2)
        out += [("h", z1, x1, x2, "lo", r.y), ("h", z2, x1, x2, "hi", r.y2), ("v", x1, z1, z2, "lo", r.x), ("v", x2, z1, z2, "hi", r.x2)]
    return out


def _move_edge(rooms: list[Rect], mapping: dict[float, float], orient: str, old: float, new: float) -> None:
    for r in rooms:
        if orient == "v":
            x1 = new if abs(r.x - old) < 1e-9 else r.x
            x2 = new if abs(r.x2 - old) < 1e-9 else r.x2
            r.x, r.w = x1, x2 - x1
        else:
            y1 = new if abs(r.y - old) < 1e-9 else r.y
            y2 = new if abs(r.y2 - old) < 1e-9 else r.y2
            r.y, r.h = y1, y2 - y1
    for key, value in mapping.items():
        if abs(value - old) < 1e-9:
            mapping[key] = new


def clip_cut_to_rooms(rect_m: list[float], rooms: list[dict[str, Any]], faces: dict[str, Any]) -> tuple[float, float, float, float]:
    """A shaft cut must stay inside the rooms it opens. When the ownership rule (D-49) pulls a room edge back onto an owner's edge,
    a cut drawn to the old edge would stick out by less than a wall thickness; clip it to the rooms it lies in. Both levels of a
    shaft border the same owner edge, so they are clipped alike and the shaft stays one footprint."""
    x0, z0, w, h = rect_m
    x1, z1 = x0 + w, z0 + h
    covering = [rm["world_m"] for rm in rooms
                if min(x1, rm["world_m"][0] + rm["world_m"][2]) - max(x0, rm["world_m"][0]) > 1e-6
                and min(z1, rm["world_m"][1] + rm["world_m"][3]) - max(z0, rm["world_m"][1]) > 1e-6]
    if not covering:
        return x0, z0, w, h
    lx0 = min(r[0] for r in covering); lx1 = max(r[0] + r[2] for r in covering)
    lz0 = min(r[1] for r in covering); lz1 = max(r[1] + r[3] for r in covering)
    clipped = (max(x0, lx0) if 0 < lx0 - x0 < WALL_THICKNESS_M else x0, max(z0, lz0) if 0 < lz0 - z0 < WALL_THICKNESS_M else z0,
               min(x1, lx1) if 0 < x1 - lx1 < WALL_THICKNESS_M else x1, min(z1, lz1) if 0 < z1 - lz1 < WALL_THICKNESS_M else z1)
    if clipped != (x0, z0, x1, z1):
        faces.setdefault("clipped_cuts", []).append({"from_m": [round(v, 3) for v in (x0, z0, x1, z1)], "to_m": [round(v, 3) for v in clipped]})
    return clipped[0], clipped[1], round(clipped[2] - clipped[0], 6), round(clipped[3] - clipped[1], 6)


def snap_close_edges(rooms: list[Rect], xs: dict[float, float], ys: dict[float, float], tf: Transform, notes: list[dict]) -> None:
    """Inside one sector: parallel edges closer than a wall thickness whose walls would overlap become one line.

    The longer edge stays; the converter would otherwise build two overlapping wall boxes (it merges only 0.02 m)."""
    for orient, mapping in (("v", xs), ("h", ys)):
        for _ in range(len(rooms) * 4):
            edges = [e for e in room_edges_m(rooms, tf) if e[0] == orient]
            length: dict[float, float] = {}
            for e in edges:
                length[e[5]] = length.get(e[5], 0.0) + e[3] - e[2]
            pair = next(((a, b) for a in edges for b in edges
                         if 1e-6 < abs(a[1] - b[1]) < WALL_THICKNESS_M and min(a[3], b[3]) - max(a[2], b[2]) > -WALL_THICKNESS_M), None)
            if pair is None:
                break
            keep, move = sorted(pair, key=lambda e: (-length[e[5]], e[1]))
            notes.append({"orient": orient, "from_m": move[1], "to_m": keep[1], "reason": "parallel walls of this sector closer than the wall thickness"})
            _move_edge(rooms, mapping, orient, move[5], keep[5])


def snap_to_owner_edges(rooms: list[Rect], xs: dict[float, float], ys: dict[float, float], tf: Transform,
                        owners: list[dict[str, Any]], notes: list[dict]) -> None:
    """Room edges facing an owner's room edge closer than a wall thickness move onto it: one wall line, no slab overlap."""
    owner_edges = [(o["sector_id"], e) for o in owners for e in o["edges"]]
    for _ in range(len(rooms) * 4):
        best = None
        for e in room_edges_m(rooms, tf):
            for owner, oe in owner_edges:
                if oe[0] != e[0] or oe[4] == e[4]:
                    continue
                gap = abs(oe[1] - e[1])
                if 1e-6 < gap < WALL_THICKNESS_M and min(oe[3], e[3]) - max(oe[2], e[2]) > 0.05 and (best is None or gap < best[0]):
                    best = (gap, e, oe, owner)
        if best is None:
            return
        _gap, e, oe, owner = best
        notes.append({"orient": e[0], "from_m": e[1], "to_m": oe[1], "owner": owner, "reason": "edge facing the owner's room"})
        _move_edge(rooms, xs if e[0] == "v" else ys, e[0], e[5], _to_px(tf, e[0], oe[1]))


def wall_axis(q: tuple[float, float, float, float]) -> tuple[str, float, float, float] | None:
    x1, z1, x2, z2 = q
    if abs(z1 - z2) < 1e-6:
        return "h", z1, min(x1, x2), max(x1, x2)
    if abs(x1 - x2) < 1e-6:
        return "v", x1, min(z1, z2), max(z1, z2)
    return None


def _axis_q(orient: str, fixed: float, lo: float, hi: float) -> tuple[float, float, float, float]:
    return (lo, fixed, hi, fixed) if orient == "h" else (fixed, lo, fixed, hi)


def _owner_end_reach(owner_walls: list[tuple[str, dict[str, Any]]], ow: dict[str, Any], end: float) -> float:
    """How far the owner's wall box reaches past its line end ``end``: t/2 when an owner wall crosses that point at a right
    angle (the converter joins the corner and the perpendicular box covers it anyway), 0 at a free end."""
    t = WALL_THICKNESS_M
    for _owner, pw in owner_walls:
        if (pw["orient"] != ow["orient"] and abs(pw["fixed"] - end) <= COLLINEAR_M
                and pw["lo"] - t / 2 - 1e-6 <= ow["fixed"] <= pw["hi"] + t / 2 + 1e-6):
            return t / 2
    return 0.0


def resolve_owned_walls(walls: list[dict[str, Any]], owners: list[dict[str, Any]], shared: dict[str, Any]) -> list[dict[str, Any]]:
    """Drop the parts of this sector's walls that an owner already draws and stop wall ends at the owner's face."""
    t = WALL_THICKNESS_M
    owner_walls = [(o["sector_id"], w) for o in owners for w in o["walls"]]
    out: list[dict[str, Any]] = []
    for wall in walls:
        axis = wall_axis(wall["q"])
        if axis is None or not owner_walls:
            out.append(wall)
            continue
        orient, fixed, lo, hi = axis
        pieces = [[lo, hi]]
        owners_hit: set[str] = set()
        for owner, ow in owner_walls:
            if ow["orient"] != orient or abs(ow["fixed"] - fixed) > COLLINEAR_M:
                continue
            # The rest of this wall starts where the owner's wall box ends. The converter runs an owner's wall end on into a
            # perpendicular wall at that point (a corner) by t/2 and leaves a free end where it is; this wall's own free end is
            # not extended either. Cutting a full t past the owner's end left a see-through slit of t/2 at every corner.
            cut_lo = ow["lo"] - _owner_end_reach(owner_walls, ow, ow["lo"])
            cut_hi = ow["hi"] + _owner_end_reach(owner_walls, ow, ow["hi"])
            nxt = []
            for a, b in pieces:
                if min(b, ow["hi"]) - max(a, ow["lo"]) <= 1e-6:
                    nxt.append([a, b])          # touches the owner's wall end only: a butt joint, kept
                    continue
                owners_hit.add(owner)
                if cut_lo - a > 1e-6:
                    nxt.append([a, cut_lo])
                if b - cut_hi > 1e-6:
                    nxt.append([cut_hi, b])
            pieces = nxt
        for owner, ow in owner_walls:
            if ow["orient"] == orient or not (ow["lo"] - t / 2 - 1e-6 <= fixed <= ow["hi"] + t / 2 + 1e-6):
                continue
            face = ow["fixed"]
            for piece in pieces:
                # The converter does not extend a free wall end, so the end of this line is where its box ends: stop it at the
                # owner's wall face (half a wall thickness off the owner's centre line). Stopping a full thickness off left a
                # see-through slit of t/2 at every such joint.
                if abs(piece[1] - face) < t - 1e-6 and piece[0] < face:
                    piece[1] = face - t / 2
                    owners_hit.add(owner)
                elif abs(piece[0] - face) < t - 1e-6 and piece[1] > face:
                    piece[0] = face + t / 2
                    owners_hit.add(owner)
        pieces = [p for p in pieces if p[1] - p[0] > 0.01]
        if not owners_hit:
            out.append(wall)
            continue
        if not pieces:
            shared["dropped_walls"].append({"id": wall["id"], "owner": sorted(owners_hit), "world_m": list(wall["q"])})
            continue
        for k, (a, b) in enumerate(pieces):
            surface = wall["surface"] if k == 0 else f'{wall["surface"]}:part-{k + 1}'
            piece = dict(wall, id=wall["id"] if k == 0 else element_id(surface), surface=surface, q=_axis_q(orient, fixed, a, b))
            out.append(piece)
        shared["trimmed_walls"].append({"id": wall["id"], "owner": sorted(owners_hit), "world_m": list(wall["q"]),
                                        "pieces_m": [[round(a, 3), round(b, 3)] for a, b in pieces]})
    return out


def clear_opening_corners(orient: str, fixed: float, lo: float, hi: float, walls: list[dict[str, Any]]) -> tuple[float, float]:
    """Move an opening along its wall so that no end lies inside the box of a perpendicular wall (jamb z-fighting)."""
    t = WALL_THICKNESS_M
    for _ in range(4):
        moved = False
        for w in walls:
            axis = wall_axis(w["q"])
            if axis is None or axis[0] == orient or not (axis[2] - t / 2 - 1e-6 <= fixed <= axis[3] + t / 2 + 1e-6):
                continue
            face = axis[1]
            if 0.001 < lo - face < OPENING_JAMB_CLEAR_M:
                shift = face + OPENING_JAMB_CLEAR_M - lo
                lo, hi, moved = lo + shift, hi + shift, True
            elif 0.001 < face - hi < OPENING_JAMB_CLEAR_M:
                shift = hi - (face - OPENING_JAMB_CLEAR_M)
                lo, hi, moved = lo - shift, hi - shift, True
        if not moved:
            break
    return lo, hi


def build_sector(sector_id: str, entry: dict[str, Any], reg: dict[str, Any],
                 finishes: dict[str, Any] | None = None, shared_level: list[dict[str, Any]] | None = None) -> tuple[str, dict[str, Any], Path]:
    """Build one sector. ``shared_level`` holds the already built sectors of its level, which own shared faces (D-49);
    without it the sector is built alone, as before the ownership rule."""
    global SNAP_PX
    if finishes is None:
        finishes = json.loads(FINISHES.read_text(encoding="utf-8")) if FINISHES.is_file() else {}
    SNAP_PX = float(entry.get("snap_px", 2.5))
    level = reg["levels"][entry["level"]]
    plan = Plan() if not entry.get("plan") else parse_plan(PLANS / entry["plan"], set(reg["post_approval_ids"]))
    # u_route_a.svg carries pilot edits; the shared drawing is read from the untouched u_emergency plan.
    for rect in plan.rects:
        override = reg.get("rect_overrides", {}).get(rect.ident)
        if override:
            rect.h = float(override.get("height", rect.h))
            rect.w = float(override.get("width", rect.w))
    assign_labels(plan)
    for _old, _new in entry.get("label_replace", {}).items():
        for rect in plan.rects:
            rect.label = rect.label.replace(_old, _new)
    tf, tf_info = build_transform(entry, level)
    for am in entry.get("amendments", []):
        if am["op"] == "plan_stretch":
            split, dpx = float(am["split_px"]), am["dx_m"] / tf.kx
            for r in plan.rects:
                if r.x >= split - 0.5:
                    r.x += dpx
                elif abs(r.x2 - split) < 1.0:
                    r.w += dpx
            for l in plan.lines:
                if min(l.x1, l.x2) >= split - 0.5:
                    l.x1 += dpx
                    l.x2 += dpx
                elif min(l.x1, l.x2) < split < max(l.x1, l.x2):
                    if l.x1 > l.x2:
                        l.x1 += dpx
                    else:
                        l.x2 += dpx
            if am.get("drop_door_glyphs"):
                plan.door_paths.clear()
            continue
        if am["op"] == "room_add" and "rect_px" in am:
            px_, py_, pw_, ph_ = am["rect_px"]
            plan.rects.append(Rect(px_, py_, pw_, ph_, am.get("class", "support"), "space", f"amendment-{am['id']}", am["label"], "room", group=am.get("group", "")))
            continue
        if am["op"] == "room_add":
            x, z, w, h = am["rect_m"]
            plan.rects.append(Rect((x - tf.sx) / tf.kx + tf.ox, (z - tf.sy) / tf.ky + tf.oy, w / tf.kx, h / tf.ky, am.get("class", "support"), "space",
                                   f"amendment-{am['id']}", am["label"], "room", group=am.get("group", "")))
            continue
        if am["op"] not in {"rect_set", "rect_grow"}:
            continue
        if am.get("ids"):
            targets = [r for r in plan.rects if r.ident in am["ids"]]
        else:
            first = next((r for r in plan.rects if r.label.upper().startswith(am["label"].upper())), None)
            targets = [first] if first else []
        for target in targets:
            if am["op"] == "rect_set":
                x, z, w, h = am["rect_m"]
                target.x, target.y = (x - tf.sx) / tf.kx + tf.ox, (z - tf.sy) / tf.ky + tf.oy
                target.w, target.h = w / tf.kx, h / tf.ky
            else:
                by_x, by_y = am.get("by_m", 0) / tf.kx, am.get("by_m", 0) / tf.ky
                side = am["side"]
                if side == "s": target.h += by_y
                elif side == "n": target.y -= by_y; target.h += by_y
                elif side == "e": target.w += by_x
                elif side == "w": target.x -= by_x; target.w += by_x
    classify(plan, entry, bool(entry.get("owns_trunks")))
    wall_h = float(entry["wall_height"])

    pieces_total = 0
    for r in [r for r in plan.rects if r.role == "carve"]:
        pieces = carve(r, plan.rects, 1.0 / tf.kx, 1.0 / tf.ky)
        pieces_total += len(pieces)
        plan.rects.extend(pieces)
    rooms = [r for r in plan.rects if r.role == "room"]
    # --- snap room edges so neighbouring rooms share exact wall centre lines
    snap = float(entry.get("snap_px", SNAP_PX))
    xs = cluster([v for r in rooms for v in (r.x, r.x2)], snap)
    ys = cluster([v for r in rooms for v in (r.y, r.y2)], snap)
    for r in rooms:
        nx1, nx2, ny1, ny2 = xs[r.x], xs[r.x2], ys[r.y], ys[r.y2]
        r.x, r.y, r.w, r.h = nx1, ny1, nx2 - nx1, ny2 - ny1
    owners = list(shared_level or [])
    faces: dict[str, Any] = {"rank": list(shared_face_rank(sector_id, entry)), "owners": [o["sector_id"] for o in owners],
                              "snapped_edges": [], "dropped_walls": [], "trimmed_walls": [], "dropped_openings": [], "moved_openings": []}
    if shared_level is not None:        # the ownership rule applies when the complex is built (build_all)
        snap_close_edges(rooms, xs, ys, tf, faces["snapped_edges"])
        snap_to_owner_edges(rooms, xs, ys, tf, owners, faces["snapped_edges"])
    seen: dict[str, int] = {}
    group_space: dict[str, str] = {}
    for r in rooms:
        if r.group and r.group in group_space and r.ident.startswith("amendment-"):
            r.space = group_space[r.group]          # pieces of one amended room share the space id
            continue
        base = slug(r.label.split(" / ")[0] if r.label else f"{r.cls}")
        seen[base] = seen.get(base, 0) + 1
        r.space = f"{sector_id}/{base}" + (f"-{seen[base]}" if seen[base] > 1 else "")
        if r.group and r.ident.startswith("amendment-"):
            group_space[r.group] = r.space

    report: dict[str, Any] = {
        "sector_id": sector_id, "level": level["level_id"], "source_plan": (f"docs/design/complex_v4/sources/plans/{entry['plan']}" if entry.get("plan") else "synthetic: overview of the level"),
        "registration": tf_info, "wall_height_m": wall_h, "rooms": [], "openings": [], "ignored": [], "anomalies": [],
    }
    sid = sector_id.lower()
    out: list[str] = []
    bbox = [math.inf, math.inf, -math.inf, -math.inf]

    def grow(x: float, y: float) -> None:
        bbox[0], bbox[1], bbox[2], bbox[3] = min(bbox[0], x), min(bbox[1], y), max(bbox[2], x), max(bbox[3], y)

    floors: list[str] = []
    ceilings: list[str] = []
    piece_ids = unique_ids([r.space for r in rooms], [r.ident for r in rooms])   # pieces of one room share its space id
    for r, piece in zip(rooms, piece_ids):
        x, y = tf.px(r.x), tf.py(r.y)
        w, h = round(tf.px(r.x2) - x, 3), round(tf.py(r.y2) - y, 3)
        grow(x, y); grow(x + w, y + h)
        label = ET.Element("x", a=r.label).get("a").replace('"', "&quot;")
        finish = finish_attr(finishes, r.space)
        floor_id, ceiling_id = f"{piece}:floor", f"{piece}:ceiling"
        floors.append(
            f'    <rect id="{element_id(floor_id)}" class="floor" data-godot-type="floor" data-space-id="{r.space}" data-stable-id="{floor_id}"{finish} '
            f'data-label="{label}" data-source-id="{r.ident}" x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" />'
        )
        ceilings.append(
            f'    <rect id="{element_id(ceiling_id)}" class="ceiling" data-godot-type="ceiling" data-ceiling-elevation="{fmt(level["elevation_m"] + wall_h)}" '
            f'data-space-id="{r.space}" data-stable-id="{ceiling_id}"{finish} x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" />'
        )
        report["rooms"].append({
            "id": element_id(floor_id), "stable_id": floor_id, "space_id": r.space, "label": r.label, "class": r.cls, "source_id": r.ident,
            "plan_px": [round(r.x, 1), round(r.y, 1), round(r.w, 1), round(r.h, 1)],
            "world_m": [round(x, 3), round(y, 3), round(w, 3), round(h, 3)], "size_m": [round(w, 2), round(h, 2)],
            "area_m2": round(w * h, 1),
        })
    out.append(f'  <g id="{sid}-floors" data-layer="floors">')
    out.extend(floors)
    out.append("  </g>")
    out.append(f'  <g id="{sid}-ceilings" data-layer="ceilings">')
    out.extend(ceilings)
    out.append("  </g>")

    # --- walls: every room edge, split where the pair of rooms on its two sides changes, so each wall segment separates
    # exactly one room (or one room and the outside) from another and can be named after that room and side (#206).
    # Edges between pieces of one carved / amended room (same group) are not walls.
    edges: dict[tuple[str, float], list[tuple[float, float, Rect, bool]]] = {}
    for r in rooms:
        for orient, fixed, lo, hi in edge_segments(r):
            # low side = the room lies north of a horizontal / west of a vertical line
            low = (orient == "h" and abs(fixed - r.y2) < 1e-6) or (orient == "v" and abs(fixed - r.x2) < 1e-6)
            edges.setdefault((orient, round(fixed, 4)), []).append((lo, hi, r, low))
    wall_items: list[tuple[str, float, float, float, Rect | None, Rect | None]] = []
    for (orient, fixed), items in sorted(edges.items(), key=lambda kv: kv[0]):
        cuts = sorted({v for lo, hi, _r, _low in items for v in (lo, hi)})
        current: list[Any] | None = None
        for a_, b_ in zip(cuts, cuts[1:]):
            if b_ - a_ <= 1e-9:
                continue
            mid = (a_ + b_) / 2
            low_room = next((r for lo, hi, r, low in items if low and lo <= mid <= hi), None)
            high_room = next((r for lo, hi, r, low in items if not low and lo <= mid <= hi), None)
            if (low_room is None and high_room is None) or (low_room and high_room and low_room.group and low_room.group == high_room.group):
                pair = None
            else:
                pair = (low_room, high_room)
            if current and pair and current[4] is pair[0] and current[5] is pair[1] and abs(current[3] - a_) <= 1e-6:
                current[3] = b_
                continue
            if current:
                wall_items.append(tuple(current))  # type: ignore[arg-type]
            current = [orient, fixed, a_, b_, pair[0], pair[1]] if pair else None
        if current:
            wall_items.append(tuple(current))  # type: ignore[arg-type]
    wall_items.sort(key=lambda t: (t[0], t[2] if t[0] == "h" else t[1], t[1] if t[0] == "h" else t[2]))
    walls: list[dict[str, Any]] = []
    # finished-face side: "normal" = room lies south of a horizontal / west of a vertical wall. The wall is named after the room
    # on its finished side: the north wall of the room south of it, the east wall of the room west of it.
    wall_meta = []
    for orient, fixed, lo, hi, low_room, high_room in wall_items:
        if orient == "h":
            root, other, side = (high_room, low_room, "north") if high_room else (low_room, None, "south")
        else:
            root, other, side = (low_room, high_room, "east") if low_room else (high_room, None, "west")
        normal = "normal" if (orient == "h" and high_room) or (orient == "v" and low_room) else "opposite"
        wall_meta.append((root, other, side, normal))
    wall_ids = unique_ids([f"{root.space}:{side}" for root, _o, side, _n in wall_meta],
                          [room_local(other.space) if other else "outer" for _r, other, _s, _n in wall_meta])
    n_wall = 0
    for (orient, fixed, lo, hi, _low, _high), (root, other, side, normal), stable in zip(wall_items, wall_meta, wall_ids):
        n_wall += 1
        if orient == "h":
            q = (tf.px(lo), tf.py(fixed), tf.px(hi), tf.py(fixed))
        else:
            q = (tf.px(fixed), tf.py(lo), tf.px(fixed), tf.py(hi))
        wall_rooms = root.space + (f"|{other.space}" if other else "")
        walls.append({"id": element_id(stable), "surface": stable, "normal": normal, "attrs": f'data-wall-rooms="{wall_rooms}" ', "q": q})
    wall_lines = [l for l in plan.lines if l.cls in WALL_LINE]
    for am in entry.get("amendments", []):
        if am["op"] == "wall_shift":
            for l in wall_lines:
                if l.cls == am.get("class", "partition"):
                    l.y1 += am["dz_m"] / tf.ky
                    l.y2 += am["dz_m"] / tf.ky
    for am in entry.get("amendments", []):
        if am["op"] == "wall_add":
            for k, seg in enumerate(am["segments_m"], 1):
                wall_lines.append(Line((seg[0] - tf.sx) / tf.kx + tf.ox, (seg[1] - tf.sy) / tf.ky + tf.oy,
                                       (seg[2] - tf.sx) / tf.kx + tf.ox, (seg[3] - tf.sy) / tf.ky + tf.oy, "wall", "wall", f"amendment-{am['id']}-{k}"))
        if am["op"] == "wall_replace":
            wall_lines = [l for l in wall_lines if l.cls != am.get("class", "partition")]
            for k, seg in enumerate(am["segments_m"], 1):
                wall_lines.append(Line((seg[0] - tf.sx) / tf.kx + tf.ox, (seg[1] - tf.sy) / tf.ky + tf.oy,
                                       (seg[2] - tf.sx) / tf.kx + tf.ox, (seg[3] - tf.sy) / tf.ky + tf.oy, "wall", "wall", f"amendment-{am['id']}-{k}"))
    # free wall lines of the plan (partitions, amendment walls) are named after their source element
    line_ids = unique_ids([f"{sector_id}/line:{l.ident}" for l in wall_lines], [str(k) for k in range(1, len(wall_lines) + 1)])
    for l, stable in zip(wall_lines, line_ids):
        n_wall += 1
        q = (tf.px(l.x1), tf.py(l.y1), tf.px(l.x2), tf.py(l.y2))
        grow(q[0], q[1]); grow(q[2], q[3])
        mx, my = (l.x1 + l.x2) / 2, (l.y1 + l.y2) / 2
        host = next((r for r in rooms if r.x <= mx <= r.x2 and r.y <= my <= r.y2), None)
        hosted = f'data-wall-rooms="{host.space}" ' if host else ""
        walls.append({"id": element_id(stable), "surface": stable, "normal": "normal", "attrs": f'{hosted}data-source-id="{l.ident}" ', "q": q})
    walls = resolve_owned_walls(walls, owners, faces)
    out.append(f'  <g id="{sid}-walls" data-layer="walls">')
    for w in walls:
        q = w["q"]
        out.append(f'    <line id="{w["id"]}" class="wall" data-godot-type="wall" data-wall-height="{fmt(wall_h)}" '
                   f'data-surface-side-id="{w["surface"]}" data-normal-side="{w["normal"]}" '
                   f'{w["attrs"]}x1="{fmt(q[0])}" y1="{fmt(q[1])}" x2="{fmt(q[2])}" y2="{fmt(q[3])}" />')
    out.append("  </g>")
    report["wall_segments"] = n_wall

    # --- windows
    window_lines: list[Line] = [Line(l.x1, l.y1, l.x2, l.y2, l.cls, l.kind, l.ident) for l in plan.lines if l.cls == "window"]
    for r in plan.rects:
        if r.role == "window":
            if r.h >= r.w:
                window_lines.append(Line(r.x + r.w / 2, r.y, r.x + r.w / 2, r.y2, "window", "geometry", r.ident))
            else:
                window_lines.append(Line(r.x, r.y + r.h / 2, r.x2, r.y + r.h / 2, "window", "geometry", r.ident))

    # --- door / opening lines
    cands = collect_openings(plan, rooms)
    if entry.get("drop_plan_openings"):
        cands = []
    for am in entry.get("amendments", []):
        if "near_px" in am:
            am["near_m"] = [tf.px(am["near_px"][0]), tf.py(am["near_px"][1])]
        if "at_px" in am:
            ax1, ay1, ax2, ay2 = am["at_px"]
            am["at_m"] = [tf.px(ax1), tf.py(ay1), tf.px(ax2), tf.py(ay2)]
        if "center_px" in am:
            am["center_m"] = [tf.px(am["center_px"][0]), tf.py(am["center_px"][1])]
        if am["op"] == "door_add" and "center_px" in am and "orient" in am:
            cxm, czm = tf.px(am["center_px"][0]), tf.py(am["center_px"][1])
            half = am["width_m"] / 2
            am["at_m"] = [cxm, czm - half, cxm, czm + half] if am["orient"] == "v" else [cxm - half, czm, cxm + half, czm]
        if am["op"] == "door_add":
            x1, z1, x2, z2 = am["at_m"]
            if abs(x1 - x2) < 1e-6:
                orient, fixed_px = "v", (x1 - tf.sx) / tf.kx + tf.ox
                lo, hi = sorted(((z1 - tf.sy) / tf.ky + tf.oy, (z2 - tf.sy) / tf.ky + tf.oy))
            else:
                orient, fixed_px = "h", (z1 - tf.sy) / tf.ky + tf.oy
                lo, hi = sorted(((x1 - tf.sx) / tf.kx + tf.ox, (x2 - tf.sx) / tf.kx + tf.ox))
            cands.append({"orient": orient, "fixed": fixed_px, "lo": lo, "hi": hi, "gtype": am.get("kind", "door"), "source": f"amendment {am['id']}",
                          "src": f"amendment-{am['id']}", "prio": 9, "px": [fixed_px, lo, hi], "dtype": am.get("type"), "height": am.get("height_m"), "vertical": am.get("vertical"), "force": am.get("force")})
        elif am["op"] == "opening_remove":
            for c in list(cands):
                mid = (c["lo"] + c["hi"]) / 2
                cx, cz = (tf.px(mid), tf.py(c["fixed"])) if c["orient"] == "h" else (tf.px(c["fixed"]), tf.py(mid))
                if abs(cx - am["near_m"][0]) + abs(cz - am["near_m"][1]) < 1.0 and (not am.get("gtype") or c["gtype"] == am["gtype"]):
                    cands.remove(c)
                    break
        elif am["op"] == "door_set":
            best, best_d = None, 1e9
            for c in cands:
                if c["gtype"] == "window":
                    continue
                mid = (c["lo"] + c["hi"]) / 2
                cx, cz = (tf.px(mid), tf.py(c["fixed"])) if c["orient"] == "h" else (tf.px(c["fixed"]), tf.py(mid))
                dist = abs(cx - am["near_m"][0]) + abs(cz - am["near_m"][1])
                if dist < best_d:
                    best, best_d = c, dist
            if best is None or best_d > 2.0:
                report["anomalies"].append({"type": "amendment_not_applied", "id": am["id"], "note": "no opening near the given point"})
                continue
            mid = (best["lo"] + best["hi"]) / 2
            if am.get("center_m"):
                cm = am["center_m"]
                mid = ((cm[0] - tf.sx) / tf.kx + tf.ox) if best["orient"] == "h" else ((cm[1] - tf.sy) / tf.ky + tf.oy)
            k = tf.kx if best["orient"] == "h" else tf.ky
            half = float(am["width_m"]) / 2 / k
            best["lo"], best["hi"] = mid - half, mid + half
            best["dtype"], best["height"] = am.get("type"), am.get("height_m")
            if am.get("vertical"):
                best["vertical"] = am["vertical"]
            if am.get("kind"):
                best["gtype"] = am["kind"]
    report["amendments"] = [am["id"] for am in entry.get("amendments", [])]
    out.append(f'  <g id="{sid}-openings" data-layer="openings">')
    n_open = 0
    placed: list[tuple[dict[str, Any], list[Rect], str, tuple[float, float, float, float], float, str, Rect, Rect | None]] = []
    for c in cands:
        hosts = host_rooms(c, rooms)
        if not hosts and c.get("force"):
            hosts = [r for r in rooms if r.space]
        if not hosts:
            if c["orient"] == "h":
                wm = [tf.px(c["lo"]), tf.py(c["fixed"]), tf.px(c["hi"]), tf.py(c["fixed"])]
            else:
                wm = [tf.px(c["fixed"]), tf.py(c["lo"]), tf.px(c["fixed"]), tf.py(c["hi"])]
            report["anomalies"].append({"type": "opening_not_on_sector_wall", "source_id": c["src"], "source": c["source"], "plan_px": c["px"], "world_m": wm, "gtype": c["gtype"],
                                        "note": "drawn opening does not lie on a wall of any room of this sector (trunk corridor or neighbour wall)"})
            continue
        if c.get("force"):
            fixed = c["fixed"]
        else:
            fixed = min((xs if c["orient"] == "v" else ys), key=lambda v: abs(v - c["fixed"]))
            fixed = (xs if c["orient"] == "v" else ys)[fixed]
        lo, hi = c["lo"], c["hi"]
        if c["orient"] == "h":
            p = (tf.px(lo), tf.py(fixed), tf.px(hi), tf.py(fixed))
            width = (hi - lo) * tf.kx
        else:
            p = (tf.px(fixed), tf.py(lo), tf.px(fixed), tf.py(hi))
            width = (hi - lo) * tf.ky
        n_open += 1
        gtype = c["gtype"]
        mid = (lo + hi) / 2
        if c["orient"] == "h":
            low = next((r for r in rooms if abs(r.y2 - fixed) < 1e-6 and r.x <= mid <= r.x2), None)    # north
            high = next((r for r in rooms if abs(r.y - fixed) < 1e-6 and r.x <= mid <= r.x2), None)    # south
        else:
            low = next((r for r in rooms if abs(r.x2 - fixed) < 1e-6 and r.y <= mid <= r.y2), None)    # west
            high = next((r for r in rooms if abs(r.x - fixed) < 1e-6 and r.y <= mid <= r.y2), None)    # east
        # an opening is named after the alphabetically first of its two rooms and the other one: "<room>:door:<neighbour>"
        # an opening on a partition inside a room (not on a room edge) belongs to the room that contains it
        cx, cy = ((mid, fixed) if c["orient"] == "h" else (fixed, mid))
        containing = [r for r in rooms if r.x <= cx <= r.x2 and r.y <= cy <= r.y2]
        sides = (sorted([r for r in (low, high) if r is not None], key=lambda r: r.space)
                 or sorted(containing, key=lambda r: r.space)[:1] or sorted(hosts, key=lambda r: r.space)[:1])
        root_room, other_room = sides[0], (sides[1] if len(sides) > 1 else None)
        o_axis = wall_axis(p)
        if o_axis and not c.get("vertical"):
            orient_m, fixed_m, lo_m, hi_m = o_axis
            on_own = any(wa and wa[0] == orient_m and abs(wa[1] - fixed_m) <= COLLINEAR_M and min(wa[3], hi_m) - max(wa[2], lo_m) > 0.05
                         for wa in (wall_axis(w["q"]) for w in walls))
            owner_hit = next(((o["sector_id"], ow) for o in owners for ow in o["walls"] if ow["orient"] == orient_m
                              and abs(ow["fixed"] - fixed_m) <= COLLINEAR_M and min(ow["hi"], hi_m) - max(ow["lo"], lo_m) > 0.05), None)
            if not on_own and owner_hit:
                owner_id = owner_hit[0]
                dropped_id = f"{root_room.space}:{gtype}:{room_local(other_room.space) if other_room else 'outer'}"
                match = next((oo["id"] for o in owners if o["sector_id"] == owner_id for oo in o["openings"]
                              if oo["orient"] == orient_m and abs(oo["fixed"] - fixed_m) <= COLLINEAR_M and min(oo["hi"], hi_m) - max(oo["lo"], lo_m) > 0.05), None)
                faces["dropped_openings"].append({"id": dropped_id, "type": gtype, "owner": owner_id, "owner_opening": match,
                                                  "rooms": sorted({h.space for h in hosts}), "world_m": [round(v, 3) for v in p]})
                if match is None:
                    report["anomalies"].append({"type": "shared_opening_missing_in_owner", "id": dropped_id, "owner": owner_id, "world_m": [round(v, 3) for v in p],
                                                "note": "the wall belongs to the owner sector, which has no opening here"})
                continue
            new_lo, new_hi = clear_opening_corners(orient_m, fixed_m, lo_m, hi_m, walls) if shared_level is not None else (lo_m, hi_m)
            if abs(new_lo - lo_m) > 1e-6:
                faces["moved_openings"].append({"id": c["src"], "shift_m": round(new_lo - lo_m, 3), "reason": "jamb inside a perpendicular wall"})
                p = _axis_q(orient_m, fixed_m, round(new_lo, 3), round(new_hi, 3))
        attr = ""
        if gtype == "door":
            # "inside" is the room that owns the door: the smaller of the two rooms, or the only one
            if low and high:
                inside_high = (high.w * high.h) <= (low.w * low.h)
            else:
                inside_high = bool(high)
            inside = "normal" if (inside_high and c["orient"] == "h") or ((not inside_high) and c["orient"] == "v") else "opposite"
            height = c.get("height") or (4.5 if width >= 4.0 and wall_h >= 5.0 else 2.4)
            dtype = f' data-door-type="{c["dtype"]}"' if c.get("dtype") else ""
            vert = f' data-vertical-id="{c["vertical"]["id"]}" data-vertical-role="{c["vertical"]["role"]}"' if c.get("vertical") else ""
            attr = f' data-door-height="{fmt(height)}"{dtype}{vert} data-inside-side="{inside}"'
        elif gtype == "opening" and c.get("dtype"):
            attr = f' data-door-type="{c["dtype"]}"'
        elif gtype == "window":
            attr = ""
        grow(p[0], p[1]); grow(p[2], p[3])
        placed.append((c, hosts, attr, p, width, gtype, root_room, other_room))
    opening_ids = unique_ids([f"{root.space}:{gtype}:{room_local(other.space) if other else 'outer'}" for _c, _h, _a, _p, _w, gtype, root, other in placed],
                             [c["src"] for c, *_rest in placed])
    for (c, hosts, attr, p, width, gtype, root_room, other_room), stable in zip(placed, opening_ids):
        oid = element_id(stable)
        rooms_attr = root_room.space + (f"|{other_room.space}" if other_room else "")
        out.append(f'    <line id="{oid}" data-godot-type="{gtype}"{attr} data-stable-id="{stable}" data-wall-rooms="{rooms_attr}" '
                   f'data-source-id="{c["src"]}" x1="{fmt(p[0])}" y1="{fmt(p[1])}" x2="{fmt(p[2])}" y2="{fmt(p[3])}" />')
        report["openings"].append({
            "id": oid, "stable_id": stable, "type": gtype, "source": c["source"], "source_id": c["src"], "width_m": round(width, 2),
            "rooms": sorted({h.space for h in hosts}), "world_m": [round(v, 3) for v in p],
        })
    out.append("  </g>")

    cuts = [am for am in entry.get("amendments", []) if am["op"] == "vertical_cut"]
    if cuts:
        out.append(f'  <g id="{sid}-vertical" data-layer="vertical">')
        for am in cuts:
            x, z, w, h = clip_cut_to_rooms(am["rect_m"], report["rooms"], faces)
            host = next((rm for rm in report["rooms"] if rm["world_m"][0] - 1e-6 <= x + w / 2 <= rm["world_m"][0] + rm["world_m"][2] + 1e-6
                         and rm["world_m"][1] - 1e-6 <= z + h / 2 <= rm["world_m"][1] + rm["world_m"][3] + 1e-6), None)
            space = f' data-space-id="{host["space_id"]}"' if host else ""
            grow(x, z); grow(x + w, z + h)
            cut_id = f'{sector_id}/{am["vertical_id"]}:{am["kind"]}'
            out.append(f'    <rect id="{element_id(cut_id)}" class="opening" data-godot-type="{am["kind"]}"{space} data-vertical-id="{am["vertical_id"]}" data-stable-id="{cut_id}" '
                       f'data-vertical-role="shaft" x="{fmt(x)}" y="{fmt(z)}" width="{fmt(w)}" height="{fmt(h)}" />')
        out.append("  </g>")

    # --- context / ignored drawing (kept visible for orientation, never generated)
    out.append(f'  <g id="{sid}-context" data-layer="context" opacity="0.35">')
    ci = 0
    for r in plan.rects:
        if r.role in {"context", "trunk", "envelope", "subfeature"}:
            ci += 1
            x, y = tf.px(r.x), tf.py(r.y)
            w, h = round(tf.px(r.x2) - x, 3), round(tf.py(r.y2) - y, 3)
            out.append(f'    <rect id="{sid}-context-{ci:02d}" class="context-{r.role}" data-godot-type="ignore" data-source-id="{r.ident}" fill="none" stroke="#888" stroke-width="0.08" x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" />')
            report["ignored"].append({"source_id": r.ident, "role": r.role, "class": r.cls, "label": r.label, "reason": r.reason,
                                      "world_m": [round(x, 2), round(y, 2), round(w, 2), round(h, 2)]})
    out.append("  </g>")
    n_feat = sum(1 for r in plan.rects if r.role == "feature")
    report["feature_rects_ignored"] = n_feat
    report["shared_faces"] = faces
    report["unmapped_other_elements"] = len(plan.others)

    # --- anomalies on rooms
    for i, a in enumerate(rooms):
        for b in rooms[i + 1:]:
            ox = min(a.x2, b.x2) - max(a.x, b.x)
            oy = min(a.y2, b.y2) - max(a.y, b.y)
            if ox > SNAP_PX and oy > SNAP_PX:
                report["anomalies"].append({"type": "rooms_overlap", "a": a.space, "b": b.space,
                                            "overlap_m": [round(ox * tf.kx, 2), round(oy * tf.ky, 2)]})
    attached = {sp for o in report["openings"] + faces["dropped_openings"] for sp in o["rooms"]}
    for r in rooms:
        if r.space not in attached:
            report["anomalies"].append({"type": "room_without_drawn_opening", "space": r.space, "label": r.label})
    
    margin = 2.0
    vx, vy = bbox[0] - margin, bbox[1] - margin
    vw, vh = bbox[2] - bbox[0] + 2 * margin, bbox[3] - bbox[1] + 2 * margin
    shared_mark = f' data-shared-faces="{SHARED_FACES_RULE}"' if shared_level is not None else ""
    header = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" data-presentation-only="false" data-generator-input="true" '
        f'viewBox="{fmt(vx)} {fmt(vy)} {fmt(vw)} {fmt(vh)}" width="{fmt(vw * 12)}" height="{fmt(vh * 12)}" '
        f'data-scale="1" data-scale-unit="m-per-svg-unit" data-grid-size="1" data-artifact-id="APPROVED-{sector_id}-SVG-01" '
        f'data-plan-style-id="caretaker-style-b-v1" data-sector-id="{sector_id}" data-level="{level["level_id"]}" '
        f'data-source-plan="{entry.get('plan') or 'overview'}" data-derivation="approved-plan-scaled-by-overview"{shared_mark}>',
        f'  <title>{sector_id} — метрический источник из утверждённого плана</title>',
        f'  <desc>+X восток, +Z юг, метры. Построено из {entry.get('plan') or 'общего плана этажа'}; масштаб и положение — по общему плану этажа. Геометрия не исправлялась.</desc>',
        '  <style>.floor{fill:#b9c9d2;fill-opacity:.55;stroke:none}.ceiling{fill:none;stroke:none}.wall{stroke:#253038;stroke-width:.12}</style>',
    ]
    svg = "\n".join(header + out + ["</svg>", ""])
    if shared_level is not None:
        geometry: dict[str, Any] = {"sector_id": sector_id, "walls": [], "openings": [],
                                    "edges": [e[:5] for e in room_edges_m(rooms, tf)]}
        for w in walls:
            axis = wall_axis(w["q"])
            if axis:
                geometry["walls"].append({"id": w["id"], "orient": axis[0], "fixed": axis[1], "lo": axis[2], "hi": axis[3]})
        for o in report["openings"]:
            axis = wall_axis(tuple(o["world_m"]))
            if axis:
                geometry["openings"].append({"id": o["id"], "orient": axis[0], "fixed": axis[1], "lo": axis[2], "hi": axis[3]})
        shared_level.append(geometry)
    target = V4 / "plans/generation" / level["folder"] / (sector_id.lower().replace("-", "_") + ".svg")
    return svg, report, target


def build_all(reg: dict[str, Any]) -> list[tuple[str, str, dict[str, Any], Path]]:
    """Build every sector in ownership order (the owners decide the shared faces): (sector_id, svg, report, target)."""
    levels: dict[str, list[dict[str, Any]]] = {}
    built = []
    for sector_id, entry in sorted(reg["sectors"].items(), key=lambda item: shared_face_rank(*item)):
        svg, report, target = build_sector(sector_id, entry, reg, shared_level=levels.setdefault(entry["level"], []))
        built.append((sector_id, svg, report, target))
    return built


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sector", action="append", help="build only these sector IDs")
    parser.add_argument("--report-dir", default=str(ROOT / "docs/design/complex_v4/review/data"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    reg = json.loads(REGISTRATION.read_text(encoding="utf-8"))
    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    wanted = set(args.sector or reg["sectors"])
    for sector_id, svg, report, target in build_all(reg):
        if sector_id not in wanted:
            continue
        if not args.dry_run:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(svg, encoding="utf-8", newline="\n")
        if True:
            (report_dir / f"{sector_id.lower()}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"{sector_id:22} rooms={len(report['rooms']):2d} openings={len(report['openings']):2d} anomalies={len(report['anomalies']):2d} "
              f"aniso={report['registration']['anisotropy_percent']}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
