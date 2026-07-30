#!/usr/bin/env python3
"""Render review images from the exact data consumed by complex_v3 sector scenes."""

from __future__ import annotations

import json
import math
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
DRESSING = ROOT / "scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json"
OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(tempfile.gettempdir()) / "caretaker-complex-v3-visual-audit" / "scenes"
CANVAS = 1024
MARGIN = 54

FAMILY_COLORS = {
    "medical": (92, 136, 142),
    "command": (76, 112, 158),
    "domestic": (151, 126, 84),
    "containment": (132, 92, 104),
    "freight": (148, 104, 66),
    "utility": (91, 111, 119),
    "historic": (112, 92, 72),
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def transform(bounds: list[float]):
    x0, z0, x1, z1 = map(float, bounds)
    scale = min((CANVAS - 2 * MARGIN) / (x1 - x0), (CANVAS - 2 * MARGIN) / (z1 - z0))
    ox = (CANVAS - (x1 - x0) * scale) * 0.5
    oz = (CANVAS - (z1 - z0) * scale) * 0.5

    def point(x: float, z: float) -> tuple[float, float]:
        return ox + (x - x0) * scale, oz + (z - z0) * scale

    return point, scale


def rotated_box(center: tuple[float, float], size: tuple[float, float], angle: float) -> list[tuple[float, float]]:
    cx, cy = center
    hx, hy = size[0] * 0.5, size[1] * 0.5
    result = []
    for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
        result.append((cx + x * math.cos(angle) - y * math.sin(angle), cy + x * math.sin(angle) + y * math.cos(angle)))
    return result


def draw_central_features(draw: ImageDraw.ImageDraw, point, scale: float, sector_id: str) -> None:
    if sector_id not in {"U-CENTRAL-CORE", "L-CENTRAL-CORE"}:
        return
    cabin_a = point(-5.8, 0.9)
    cabin_b = point(-3.2, 3.7)
    draw.rectangle((*cabin_a, *cabin_b), outline=(80, 205, 255), width=max(2, round(scale * 0.08)))
    for index in range(21):
        z = -2.5 + index * 0.3
        a = point(0.6, z)
        b = point(2.4, z)
        c = point(4.7, z)
        d = point(6.5, z)
        draw.line((*a, *b), fill=(238, 214, 151), width=max(1, round(scale * 0.035)))
        draw.line((*c, *d), fill=(238, 214, 151), width=max(1, round(scale * 0.035)))


def main() -> int:
    handoff = load(HANDOFF)
    catalog = load(CATALOG)
    dressing = load(DRESSING)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    spaces_by_sector: dict[str, list[dict]] = {}
    for space in handoff["spaces"]:
        spaces_by_sector.setdefault(space["sector_id"], []).append(space)
    spaces_by_sector["T-CIRCULATION"] = [
        route for route in handoff["route_spaces"] if route["level"] == "LV-T"
    ]
    portals_by_sector: dict[str, list[dict]] = {}
    space_lookup = {space["id"]: space for space in handoff["spaces"]}
    for portal in handoff["internal_portals"]:
        portals_by_sector.setdefault(space_lookup[portal["between"][0]]["sector_id"], []).append(portal)
    for portal in handoff["external_portals"]:
        portals_by_sector.setdefault(space_lookup[portal["space"]]["sector_id"], []).append(portal)
    dressing_by_sector = {sector["sector_id"]: sector for sector in dressing["sectors"]}
    bounds_by_sector = {sector["id"]: sector["bounds_xz"] for sector in handoff["sectors"]}
    font = ImageFont.load_default()

    for item in catalog["sectors"]:
        sector_id = item["sector_id"]
        bounds = bounds_by_sector.get(sector_id, [-110.0, 15.0, 32.0, 82.0])
        point, scale = transform(bounds)
        image = Image.new("RGB", (CANVAS, CANVAS), (12, 17, 24))
        draw = ImageDraw.Draw(image)
        family = dressing_by_sector[sector_id]["family"]
        fill = FAMILY_COLORS[family]
        for space in spaces_by_sector.get(sector_id, []):
            x0, z0, x1, z1 = map(float, space["bounds_xz"])
            a, b = point(x0, z0), point(x1, z1)
            draw.rectangle((*a, *b), fill=fill, outline=(215, 225, 232), width=max(2, round(scale * 0.08)))
        for portal in portals_by_sector.get(sector_id, []):
            a, b = portal["segment_xz"]
            pa, pb = point(float(a[0]), float(a[1])), point(float(b[0]), float(b[1]))
            color = (255, 174, 76) if "cargo" in str(portal.get("type", "")) or "freight" in str(portal.get("type", "")) else (104, 226, 176)
            draw.line((*pa, *pb), fill=color, width=max(4, round(scale * 0.16)))
        if sector_id == "T-CIRCULATION":
            for transition in handoff.get("controlled_technical_transitions", []):
                a, b = transition["centerline_xz"]
                pa, pb = point(float(a[0]), float(a[1])), point(float(b[0]), float(b[1]))
                draw.line((*pa, *pb), fill=(104, 226, 176), width=max(4, round(float(transition["width"]) * scale)))
        for placement in dressing_by_sector[sector_id]["placements"]:
            if placement["kind"] != "prop":
                continue
            x, _y, z = placement["position"]
            sx, sz = placement["footprint_xz"]
            center = point(float(x), float(z))
            polygon = rotated_box(center, (float(sx) * scale, float(sz) * scale), -float(placement["rotation_y"]))
            draw.polygon(polygon, fill=(43, 57, 69), outline=(130, 200, 238), width=max(1, round(scale * 0.05)))
        draw_central_features(draw, point, scale, sector_id)
        draw.rectangle((0, 0, CANVAS, 38), fill=(7, 10, 15))
        draw.text((12, 12), f"{sector_id} | source-data top-down", font=font, fill=(236, 241, 246))
        output = OUTPUT / f"{sector_id.lower().replace('-', '_')}.png"
        image.save(output)
        print(f"SCENE_TOPDOWN {sector_id} {output}")
    print(f"SCENE_TOPDOWNS_OK count={len(catalog['sectors'])} output={OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
