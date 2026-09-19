#!/usr/bin/env python3
"""Render deterministic top-down SVG review sheets for T18 shared frames."""
from __future__ import annotations

import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FRAMES = ROOT / "gen/shared/anchor_frames.json"
OUTPUT = ROOT / "scenes/complex_v3_regeneration/rollout/shared/review"
LEVELS = {"LV-U": 0.0, "LV-L": -6.0, "LV-T": -11.5}
COLORS = {"floor": "#247ba0", "shaft": "#f25f5c", "door": "#ffe066", "stair_entry": "#70c1b3", "stair_exit": "#70c1b3", "point": "#ffffff"}


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def applies(anchor: dict, y: float) -> bool:
    if anchor["type"] == "shaft":
        bounds = anchor["bounds"]
        return bounds["bottom_m"] <= y <= bounds["top_m"]
    return abs(float(anchor["origin"][1]) - y) < 0.01


def render(level: str, y: float, anchors: list[dict]) -> str:
    active = [anchor for anchor in anchors if applies(anchor, y)]
    xs: list[float] = []
    zs: list[float] = []
    for anchor in active:
        xs.append(float(anchor["origin"][0])); zs.append(float(anchor["origin"][2]))
        bounds = anchor["bounds"]
        for point in bounds.get("polygon_xz", bounds.get("footprint_xz", [])):
            xs.append(float(point[0])); zs.append(float(point[1]))
    min_x, max_x = min(xs) - 3.0, max(xs) + 3.0
    min_z, max_z = min(zs) - 3.0, max(zs) + 3.0
    scale = min(1050.0 / (max_x - min_x), 680.0 / (max_z - min_z))
    sx = lambda x: 75.0 + (x - min_x) * scale
    sz = lambda z: 80.0 + (z - min_z) * scale
    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="820" viewBox="0 0 1200 820">',
        '<rect width="1200" height="820" fill="#111827"/>',
        f'<text x="45" y="42" fill="#f9fafb" font-family="sans-serif" font-size="24">complex_v3 shared frames — {level} (Y={y:g} m)</text>',
        '<text x="45" y="68" fill="#9ca3af" font-family="sans-serif" font-size="13">Blue: sector-owned route surfaces · Red: blocked vertical envelopes · dots: stable portal/entry frames</text>',
    ]
    for anchor in active:
        bounds = anchor["bounds"]
        polygon = bounds.get("polygon_xz", bounds.get("footprint_xz"))
        color = COLORS.get(anchor["type"], "#ffffff")
        if polygon:
            points = " ".join(f"{sx(float(p[0])):.2f},{sz(float(p[1])):.2f}" for p in polygon)
            fill_opacity = "0.16" if anchor["type"] == "floor" else "0.08"
            out.append(f'<polygon points="{points}" fill="{color}" fill-opacity="{fill_opacity}" stroke="{color}" stroke-width="1.5"/>')
        else:
            x, z = sx(float(anchor["origin"][0])), sz(float(anchor["origin"][2]))
            out.append(f'<circle cx="{x:.2f}" cy="{z:.2f}" r="3.5" fill="{color}"/>')
    labels = [anchor for anchor in active if anchor["type"] in {"shaft", "door", "stair_entry", "stair_exit"}]
    for index, anchor in enumerate(labels):
        x, z = sx(float(anchor["origin"][0])), sz(float(anchor["origin"][2]))
        dy = -7 if index % 2 == 0 else 14
        out.append(f'<text x="{x + 6:.2f}" y="{z + dy:.2f}" fill="#e5e7eb" font-family="monospace" font-size="9">{esc(anchor["anchor_id"])}</text>')
    out.append(f'<text x="45" y="800" fill="#9ca3af" font-family="sans-serif" font-size="12">anchors shown: {len(active)} · source: gen/shared/anchor_frames.json · geometry is not duplicated in this package</text>')
    out.append("</svg>\n")
    return "\n".join(out)


def main() -> int:
    anchors = json.loads(FRAMES.read_text(encoding="utf-8"))["anchors"]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for level, y in LEVELS.items():
        (OUTPUT / f"shared-frames-{level.lower()}.svg").write_text(render(level, y, anchors), encoding="utf-8", newline="\n")
    print(f"SHARED_REVIEW_OK renders={len(LEVELS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
