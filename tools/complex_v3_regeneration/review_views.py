"""Per-sector visual walkthrough: the current canonical plan and each proposed variant.

A *view* is a title plus a list of edits applied to a copy of the sector data. Nothing here
changes a plan; images are written to docs/design/complex_v4/review/sectors/img/.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "docs/design/complex_v4/review"
FONT = "C:/Windows/Fonts/arial.ttf"
PALETTE = {
    "personnel": (214, 196, 160), "support": (200, 210, 190), "corridor": (225, 225, 225), "passenger": (225, 225, 225),
    "containment": (190, 225, 190), "airlock": (210, 210, 235), "security": (230, 200, 200), "command": (225, 200, 225),
    "heavy": (205, 220, 240), "old": (214, 196, 160), "energy": (200, 215, 235), "utility": (190, 220, 205),
}
DOOR, OPEN, WIN = (200, 50, 40), (40, 150, 70), (50, 100, 220)
BLOCKED, NEW = (120, 0, 120), (255, 200, 40)


def load_all() -> dict[str, dict]:
    return {p.stem.upper(): json.loads(p.read_text(encoding="utf-8")) for p in (REVIEW / "data").glob("*.json")}


def font(size: int):
    return ImageFont.truetype(FONT, size)


class Edit:
    """Mutations applied to a deep copy of the sector report."""

    def __init__(self):
        self.ops: list[tuple] = []

    def rect(self, slug: str, rect): self.ops.append(("rect", slug, rect)); return self
    def remove(self, slug: str): self.ops.append(("remove", slug)); return self
    def add(self, rect, label: str, color=NEW): self.ops.append(("add", rect, label, color)); return self
    def door(self, idx: int, **kw): self.ops.append(("door", idx, kw)); return self
    def add_door(self, line, kind="door", state="", label=""): self.ops.append(("adddoor", line, kind, state, label)); return self
    def note(self, x, z, text, color=(150, 0, 0)): self.ops.append(("note", x, z, text, color)); return self
    def line(self, x1, z1, x2, z2, color=(90, 90, 90), dashed=True): self.ops.append(("line", x1, z1, x2, z2, color, dashed)); return self


def draw_sector(R: dict, sid: str, edit: Edit | None, title: str, ppm: float = 20.0, pad: float = 6.0, show_neighbours: bool = True,
                box: tuple[float, float, float, float] | None = None) -> Image.Image:
    rep = copy.deepcopy(R[sid])
    rooms = {rm["space_id"].split("/")[1]: dict(rm) for rm in rep["rooms"]}
    doors = [dict(o) for o in rep["openings"]]
    extras: list[tuple] = []
    notes: list[tuple] = []
    def key(prefix: str) -> str:
        return next(k for k in rooms if k.startswith(prefix))

    for op in (edit.ops if edit else []):
        if op[0] == "rect":
            rooms[key(op[1])]["world_m"] = list(op[2])
        elif op[0] == "remove":
            k = key(op[1])
            rooms.pop(k, None)
            doors = [d for d in doors if not any(s.endswith("/" + k) for s in d["rooms"])]
        elif op[0] == "add":
            extras.append(("room", op[1], op[2], op[3]))
        elif op[0] == "door":
            doors[op[1]].update(op[2])
        elif op[0] == "adddoor":
            doors.append({"type": op[2], "world_m": list(op[1]), "state": op[3], "label": op[4], "rooms": [], "new": True})
        elif op[0] == "note":
            notes.append(op[1:])
        elif op[0] == "line":
            extras.append(("line", *op[1:]))
    xs = [v for r in rooms.values() for v in (r["world_m"][0], r["world_m"][0] + r["world_m"][2])]
    zs = [v for r in rooms.values() for v in (r["world_m"][1], r["world_m"][1] + r["world_m"][3])]
    for e in extras:
        if e[0] == "room":
            xs += [e[1][0], e[1][0] + e[1][2]]; zs += [e[1][1], e[1][1] + e[1][3]]
    x0, x1, z0, z1 = (min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad) if box is None else (box[0], box[2], box[1], box[3])
    w, h = int((x1 - x0) * ppm), int((z1 - z0) * ppm) + 30
    im = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(im, "RGBA")

    def T(x, z): return ((x - x0) * ppm, (z - z0) * ppm + 28)

    gx = int(x0 // 5) * 5
    while gx < x1:
        d.line([T(gx, z0), T(gx, z1)], fill=(235, 235, 235, 255), width=1); gx += 5
    gz = int(z0 // 5) * 5
    while gz < z1:
        d.line([T(x0, gz), T(x1, gz)], fill=(235, 235, 235, 255), width=1); gz += 5
    d.text((6, 5), title, fill=(0, 0, 0, 255), font=font(15))
    if show_neighbours:
        for other, rep2 in R.items():
            if other == sid or rep2["level"] != rep["level"]:
                continue
            for rm in rep2["rooms"]:
                a, b, c, e = rm["world_m"]
                if a + c < x0 or a > x1 or b + e < z0 or b > z1:
                    continue
                d.rectangle([T(a, b), T(a + c, b + e)], fill=(240, 240, 240, 255), outline=(190, 190, 190, 255))
                d.text(T(a + 0.2, b + 0.1), other, fill=(170, 170, 170, 255), font=font(9))
    for slug, rm in rooms.items():
        a, b, c, e = rm["world_m"]
        d.rectangle([T(a, b), T(a + c, b + e)], fill=PALETTE.get(rm["class"], (200, 210, 220)) + (255,), outline=(40, 50, 60, 255), width=2)
        lab = (rm["label"].split(" / ")[0] or slug)[:26]
        d.text(T(a + 0.25, b + 0.15), lab, fill=(0, 0, 0, 255), font=font(10))
        d.text(T(a + 0.25, b + 0.15 + 0.9), f"{c:.1f}×{e:.1f} м", fill=(70, 70, 70, 255), font=font(9))
    for e in extras:
        if e[0] == "room":
            a, b, c, f = e[1]
            d.rectangle([T(a, b), T(a + c, b + f)], fill=tuple(e[3]) + (210,), outline=(150, 100, 0, 255), width=2)
            d.text(T(a + 0.25, b + 0.15), e[2], fill=(0, 0, 0, 255), font=font(10))
            d.text(T(a + 0.25, b + 1.05), f"{c:.1f}×{f:.1f} м", fill=(70, 70, 70, 255), font=font(9))
        else:
            d.line([T(e[1], e[2]), T(e[3], e[4])], fill=tuple(e[5]) + (255,), width=3)
    for dr in doors:
        a, b, c, e = dr["world_m"]
        col = {"door": DOOR, "opening": OPEN, "window": WIN}.get(dr["type"], DOOR)
        if dr.get("state") == "blocked":
            col = BLOCKED
        if dr.get("new"):
            col = NEW if not dr.get("state") else BLOCKED
        d.line([T(a, b), T(c, e)], fill=col + (255,), width=6)
        width = max(abs(c - a), abs(e - b))
        txt = dr.get("label") or f"{width:.1f}"
        if dr.get("state") == "blocked" and not dr.get("label"):
            txt += " ✕"
        d.text(T((a + c) / 2 + 0.2, (b + e) / 2 - 0.5), txt, fill=col + (255,), font=font(10))
    for n in notes:
        d.text(T(n[0], n[1]), n[2], fill=tuple(n[3]) + (255,), font=font(11))
    # scale bar
    d.line([T(x0 + 1, z1 - 1), T(x0 + 6, z1 - 1)], fill=(0, 0, 0, 255), width=3)
    d.text(T(x0 + 1, z1 - 2.2), "5 м", fill=(0, 0, 0, 255), font=font(10))
    return im


def sheet(panels: list[Image.Image], cols: int = 2, gap: int = 14) -> Image.Image:
    rows = [panels[i:i + cols] for i in range(0, len(panels), cols)]
    rw = [max(sum(p.width for p in r) + gap * (len(r) - 1), 1) for r in rows]
    W = max(rw)
    H = sum(max(p.height for p in r) for r in rows) + gap * (len(rows) - 1)
    im = Image.new("RGB", (W, H), "white")
    y = 0
    for r in rows:
        x = 0
        for p in r:
            im.paste(p, (x, y)); x += p.width + gap
        y += max(p.height for p in r) + gap
    return im


def save(im: Image.Image, name: str) -> Path:
    out = REVIEW / "sectors" / "img"
    out.mkdir(parents=True, exist_ok=True)
    path = out / name
    im.save(path)
    return path
