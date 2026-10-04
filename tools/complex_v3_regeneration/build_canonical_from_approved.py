#!/usr/bin/env python3
"""Build the canonical metric SVG inputs of complex_v3 from the approved plans.

The approved presentation plans under ``docs/design/complex_v3/plans/sectors`` are the
only geometry source. Metric scale and world position are taken from the approved
overview plan of the same level (see ``approved_registration.json``). Nothing in the
approved geometry is corrected here: every inconsistency is written to the per-sector
extraction report so it can be reviewed and decided by a person.

Usage:
    python tools/complex_v3_regeneration/build_canonical_from_approved.py \
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
PLANS = ROOT / "docs/design/complex_v3/plans"          # approved v3 plans: the only geometry source
V4 = ROOT / "docs/design/complex_v4"                    # generated canonical inputs: complex version 4
REGISTRATION = Path(__file__).with_name("approved_registration.json")
NS = "{http://www.w3.org/2000/svg}"
SNAP_PX = 2.5

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
        if any(same_box(r.box, b) for b in exclude):
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


def build_sector(sector_id: str, entry: dict[str, Any], reg: dict[str, Any]) -> tuple[str, dict[str, Any], Path]:
    level = reg["levels"][entry["level"]]
    plan = parse_plan(PLANS / entry["plan"], set(reg["post_approval_ids"]))
    # u_route_a.svg carries pilot edits; the shared drawing is read from the untouched u_emergency plan.
    for rect in plan.rects:
        override = reg.get("rect_overrides", {}).get(rect.ident)
        if override:
            rect.h = float(override.get("height", rect.h))
            rect.w = float(override.get("width", rect.w))
    assign_labels(plan)
    tf, tf_info = build_transform(entry, level)
    for am in entry.get("amendments", []):
        if am["op"] == "room_add":
            x, z, w, h = am["rect_m"]
            plan.rects.append(Rect((x - tf.sx) / tf.kx + tf.ox, (z - tf.sy) / tf.ky + tf.oy, w / tf.kx, h / tf.ky, am.get("class", "support"), "space",
                                   f"amendment-{am['id']}", am["label"], "room"))
            continue
        if am["op"] not in {"rect_set", "rect_grow"}:
            continue
        target = next((r for r in plan.rects if r.label.upper().startswith(am["label"].upper())), None)
        if target is None:
            report_missing = True
            continue
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
    xs = cluster([v for r in rooms for v in (r.x, r.x2)], SNAP_PX)
    ys = cluster([v for r in rooms for v in (r.y, r.y2)], SNAP_PX)
    for r in rooms:
        nx1, nx2, ny1, ny2 = xs[r.x], xs[r.x2], ys[r.y], ys[r.y2]
        r.x, r.y, r.w, r.h = nx1, ny1, nx2 - nx1, ny2 - ny1
    seen: dict[str, int] = {}
    for r in rooms:
        base = slug(r.label.split(" / ")[0] if r.label else f"{r.cls}")
        seen[base] = seen.get(base, 0) + 1
        r.space = f"{sector_id}/{base}" + (f"-{seen[base]}" if seen[base] > 1 else "")

    report: dict[str, Any] = {
        "sector_id": sector_id, "level": level["level_id"], "source_plan": f"docs/design/complex_v3/plans/{entry['plan']}",
        "registration": tf_info, "wall_height_m": wall_h, "rooms": [], "openings": [], "ignored": [], "anomalies": [],
    }
    sid = sector_id.lower()
    out: list[str] = []
    bbox = [math.inf, math.inf, -math.inf, -math.inf]

    def grow(x: float, y: float) -> None:
        bbox[0], bbox[1], bbox[2], bbox[3] = min(bbox[0], x), min(bbox[1], y), max(bbox[2], x), max(bbox[3], y)

    floors: list[str] = []
    ceilings: list[str] = []
    for i, r in enumerate(rooms, 1):
        x, y = tf.px(r.x), tf.py(r.y)
        w, h = round(tf.px(r.x2) - x, 3), round(tf.py(r.y2) - y, 3)
        grow(x, y); grow(x + w, y + h)
        label = ET.Element("x", a=r.label).get("a").replace('"', "&quot;")
        floors.append(
            f'    <rect id="{sid}-floor-{i:02d}" class="floor" data-godot-type="floor" data-space-id="{r.space}" '
            f'data-label="{label}" data-source-id="{r.ident}" x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" />'
        )
        ceilings.append(
            f'    <rect id="{sid}-ceiling-{i:02d}" class="ceiling" data-godot-type="ceiling" data-ceiling-elevation="{fmt(level["elevation_m"] + wall_h)}" '
            f'x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" />'
        )
        report["rooms"].append({
            "id": f"{sid}-floor-{i:02d}", "space_id": r.space, "label": r.label, "class": r.cls, "source_id": r.ident,
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

    # --- walls: every room edge, merged into maximal collinear segments
    spans: dict[tuple[str, float], list[list[float]]] = {}
    sides: dict[tuple[str, float, str], dict[str, list[list[float]]]] = {}
    for r in rooms:
        for orient, fixed, lo, hi in edge_segments(r):
            key = (orient, round(fixed, 4))
            if r.group:
                low_side = (orient == "h" and abs(fixed - r.y2) < 1e-6) or (orient == "v" and abs(fixed - r.x2) < 1e-6)
                sides.setdefault((orient, round(fixed, 4), r.group), {"lo": [], "hi": []})["lo" if low_side else "hi"].append([lo, hi])
            else:
                spans.setdefault(key, []).append([lo, hi])

    def subtract(items: list[list[float]], cuts: list[list[float]]) -> list[list[float]]:
        out_: list[list[float]] = []
        for lo, hi in items:
            parts = [[lo, hi]]
            for c_lo, c_hi in cuts:
                nxt: list[list[float]] = []
                for a_, b_ in parts:
                    if c_hi <= a_ + 1e-9 or c_lo >= b_ - 1e-9:
                        nxt.append([a_, b_])
                        continue
                    if c_lo > a_ + 1e-9:
                        nxt.append([a_, c_lo])
                    if c_hi < b_ - 1e-9:
                        nxt.append([c_hi, b_])
                parts = nxt
            out_.extend(parts)
        return out_

    for (orient, fixed, _group), both in sides.items():
        shared = []
        for a_lo, a_hi in both["lo"]:
            for b_lo, b_hi in both["hi"]:
                lo_, hi_ = max(a_lo, b_lo), min(a_hi, b_hi)
                if hi_ - lo_ > 1e-9:
                    shared.append([lo_, hi_])
        for seg in subtract(both["lo"], shared) + subtract(both["hi"], shared):
            spans.setdefault((orient, fixed), []).append(seg)
    wall_items: list[tuple[str, float, float, float]] = []
    for (orient, fixed), segs in sorted(spans.items()):
        segs.sort()
        cur = list(segs[0])
        for lo, hi in segs[1:]:
            if lo <= cur[1] + 1e-6:
                cur[1] = max(cur[1], hi)
            else:
                wall_items.append((orient, fixed, cur[0], cur[1]))
                cur = [lo, hi]
        wall_items.append((orient, fixed, cur[0], cur[1]))
    wall_items.sort(key=lambda t: (t[0], t[2] if t[0] == "h" else t[1], t[1] if t[0] == "h" else t[2]))
    out.append(f'  <g id="{sid}-walls" data-layer="walls">')
    n_wall = 0
    for orient, fixed, lo, hi in wall_items:
        n_wall += 1
        if orient == "h":
            q = (tf.px(lo), tf.py(fixed), tf.px(hi), tf.py(fixed))
        else:
            q = (tf.px(fixed), tf.py(lo), tf.px(fixed), tf.py(hi))
        mid = (lo + hi) / 2
        # finished-face side: "normal" = room lies south of a horizontal / west of a vertical wall
        if orient == "h":
            low_side = any(abs(r.y2 - fixed) < 1e-6 and r.x <= mid <= r.x2 for r in rooms)   # room to the north
            high_side = any(abs(r.y - fixed) < 1e-6 and r.x <= mid <= r.x2 for r in rooms)   # room to the south
        else:
            low_side = any(abs(r.x2 - fixed) < 1e-6 and r.y <= mid <= r.y2 for r in rooms)   # room to the west
            high_side = any(abs(r.x - fixed) < 1e-6 and r.y <= mid <= r.y2 for r in rooms)   # room to the east
        normal = "normal" if (high_side and orient == "h") or (low_side and orient == "v") else "opposite"
        out.append(f'    <line id="{sid}-wall-{n_wall:02d}" class="wall" data-godot-type="wall" data-wall-height="{fmt(wall_h)}" '
                   f'data-surface-side-id="{sector_id}/wall-{n_wall:02d}" data-normal-side="{normal}" '
                   f'x1="{fmt(q[0])}" y1="{fmt(q[1])}" x2="{fmt(q[2])}" y2="{fmt(q[3])}" />')
    wall_lines = [l for l in plan.lines if l.cls in WALL_LINE]
    for am in entry.get("amendments", []):
        if am["op"] == "wall_shift":
            for l in wall_lines:
                if l.cls == am.get("class", "partition"):
                    l.y1 += am["dz_m"] / tf.ky
                    l.y2 += am["dz_m"] / tf.ky
    for am in entry.get("amendments", []):
        if am["op"] == "wall_replace":
            wall_lines = [l for l in wall_lines if l.cls != am.get("class", "partition")]
            for k, seg in enumerate(am["segments_m"], 1):
                wall_lines.append(Line((seg[0] - tf.sx) / tf.kx + tf.ox, (seg[1] - tf.sy) / tf.ky + tf.oy,
                                       (seg[2] - tf.sx) / tf.kx + tf.ox, (seg[3] - tf.sy) / tf.ky + tf.oy, "wall", "wall", f"amendment-{am['id']}-{k}"))
    for l in wall_lines:
        n_wall += 1
        q = (tf.px(l.x1), tf.py(l.y1), tf.px(l.x2), tf.py(l.y2))
        grow(q[0], q[1]); grow(q[2], q[3])
        out.append(f'    <line id="{sid}-wall-{n_wall:02d}" class="wall" data-godot-type="wall" data-wall-height="{fmt(wall_h)}" '
                   f'data-surface-side-id="{sector_id}/wall-{n_wall:02d}" data-normal-side="normal" '
                   f'data-source-id="{l.ident}" x1="{fmt(q[0])}" y1="{fmt(q[1])}" x2="{fmt(q[2])}" y2="{fmt(q[3])}" />')
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
    for am in entry.get("amendments", []):
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
        oid = f"{sid}-{gtype}-{n_open:02d}"
        attr = ""
        if gtype == "door":
            mid = (lo + hi) / 2
            if c["orient"] == "h":
                low = next((r for r in rooms if abs(r.y2 - fixed) < 1e-6 and r.x <= mid <= r.x2), None)    # north
                high = next((r for r in rooms if abs(r.y - fixed) < 1e-6 and r.x <= mid <= r.x2), None)    # south
            else:
                low = next((r for r in rooms if abs(r.x2 - fixed) < 1e-6 and r.y <= mid <= r.y2), None)    # west
                high = next((r for r in rooms if abs(r.x - fixed) < 1e-6 and r.y <= mid <= r.y2), None)    # east
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
        out.append(f'    <line id="{oid}" data-godot-type="{gtype}"{attr} data-source-id="{c["src"]}" x1="{fmt(p[0])}" y1="{fmt(p[1])}" x2="{fmt(p[2])}" y2="{fmt(p[3])}" />')
        report["openings"].append({
            "id": oid, "type": gtype, "source": c["source"], "source_id": c["src"], "width_m": round(width, 2),
            "rooms": sorted({h.space for h in hosts}), "world_m": [round(v, 3) for v in p],
        })
    out.append("  </g>")

    cuts = [am for am in entry.get("amendments", []) if am["op"] == "vertical_cut"]
    if cuts:
        out.append(f'  <g id="{sid}-vertical" data-layer="vertical">')
        for n, am in enumerate(cuts, 1):
            x, z, w, h = am["rect_m"]
            host = next((rm for rm in report["rooms"] if rm["world_m"][0] - 1e-6 <= x + w / 2 <= rm["world_m"][0] + rm["world_m"][2] + 1e-6
                         and rm["world_m"][1] - 1e-6 <= z + h / 2 <= rm["world_m"][1] + rm["world_m"][3] + 1e-6), None)
            space = f' data-space-id="{host["space_id"]}"' if host else ""
            grow(x, z); grow(x + w, z + h)
            out.append(f'    <rect id="{sid}-{am["kind"]}-{n:02d}" class="opening" data-godot-type="{am["kind"]}"{space} data-vertical-id="{am["vertical_id"]}" '
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
    report["unmapped_other_elements"] = len(plan.others)

    # --- anomalies on rooms
    for i, a in enumerate(rooms):
        for b in rooms[i + 1:]:
            ox = min(a.x2, b.x2) - max(a.x, b.x)
            oy = min(a.y2, b.y2) - max(a.y, b.y)
            if ox > SNAP_PX and oy > SNAP_PX:
                report["anomalies"].append({"type": "rooms_overlap", "a": a.space, "b": b.space,
                                            "overlap_m": [round(ox * tf.kx, 2), round(oy * tf.ky, 2)]})
    attached = {sp for o in report["openings"] for sp in o["rooms"]}
    for r in rooms:
        if r.space not in attached:
            report["anomalies"].append({"type": "room_without_drawn_opening", "space": r.space, "label": r.label})
    
    margin = 2.0
    vx, vy = bbox[0] - margin, bbox[1] - margin
    vw, vh = bbox[2] - bbox[0] + 2 * margin, bbox[3] - bbox[1] + 2 * margin
    header = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" data-presentation-only="false" data-generator-input="true" '
        f'viewBox="{fmt(vx)} {fmt(vy)} {fmt(vw)} {fmt(vh)}" width="{fmt(vw * 12)}" height="{fmt(vh * 12)}" '
        f'data-scale="1" data-scale-unit="m-per-svg-unit" data-grid-size="1" data-artifact-id="APPROVED-{sector_id}-SVG-01" '
        f'data-plan-style-id="caretaker-style-b-v1" data-sector-id="{sector_id}" data-level="{level["level_id"]}" '
        f'data-source-plan="{entry["plan"]}" data-derivation="approved-plan-scaled-by-overview">',
        f'  <title>{sector_id} — метрический источник из утверждённого плана</title>',
        f'  <desc>+X восток, +Z юг, метры. Построено из {entry["plan"]}; масштаб и положение — по общему плану этажа. Геометрия не исправлялась.</desc>',
        '  <style>.floor{fill:#b9c9d2;fill-opacity:.55;stroke:none}.ceiling{fill:none;stroke:none}.wall{stroke:#253038;stroke-width:.12}</style>',
    ]
    svg = "\n".join(header + out + ["</svg>", ""])
    target = V4 / "plans/generation" / level["folder"] / (sector_id.lower().replace("-", "_") + ".svg")
    return svg, report, target


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
    for sector_id, entry in reg["sectors"].items():
        if sector_id not in wanted:
            continue
        svg, report, target = build_sector(sector_id, entry, reg)
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
