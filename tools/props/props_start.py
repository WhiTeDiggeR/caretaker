"""Wave 1 props: the start of the game (docs/art/prop-catalog.md, section 1)."""
from __future__ import annotations

import json
import math

from propkit import TEX_DIR, Kit
from registry import prop


def uv(atlas: str, name: str):
    return json.loads((TEX_DIR / "decals" / f"{atlas}.json").read_text(encoding="utf-8"))[name]


# ----------------------------------------------------------------------------- P-001
@prop("emergency_cabinet", "P-001", (0.8, 1.9, 0.45), "floor", 6000,
      views=[((1.6, 1.5, 2.4), (0, 0.95, 0)), ((-1.8, 1.2, 1.6), (0, 1.0, 0)), ((0.2, 1.2, -2.2), (0, 0.9, 0))])
def emergency_cabinet(k: Kit):
    w, h, d, t = 0.8, 1.9, 0.4, 0.02
    # carcass
    k.box((w, 0.08, d), (0, 0.04, 0), "painted_metal", 0.006)                        # plinth
    k.box((t, h - 0.08, d), (-w / 2 + t / 2, 0.08 + (h - 0.08) / 2, 0), "painted_metal", 0.004)
    k.box((t, h - 0.08, d), (w / 2 - t / 2, 0.08 + (h - 0.08) / 2, 0), "painted_metal", 0.004)
    k.box((w, t, d), (0, h - t / 2, 0), "painted_metal", 0.006)                      # top
    k.box((w - 2 * t, 0.012, d - 0.03), (0, 0.09, -0.005), "painted_metal", 0.0)    # floor of the cabinet
    k.box((w - 2 * t, h - 0.1, 0.015), (0, 0.09 + (h - 0.1) / 2, -d / 2 + 0.0075), "painted_metal", 0.0)  # back
    # shelves with first-aid supplies, seen through the glass
    for i, y in enumerate((0.62, 1.05, 1.45)):
        k.box((w - 2 * t, 0.012, d - 0.06), (0, y, -0.02), "steel_bare", 0.0)
    for x, y, bw in ((-0.22, 1.50, 0.26), (0.12, 1.50, 0.3), (-0.2, 1.10, 0.3), (0.2, 1.10, 0.22)):
        k.box((bw, 0.18, 0.16), (x, y + 0.095, -0.03), "white_paint_worn", 0.01)
        k.box((bw * 0.5, 0.03, 0.005), (x, y + 0.12, 0.052), "red_paint_worn", 0.0)
        k.box((0.03, bw * 0.5 * 0.35, 0.005), (x, y + 0.12, 0.053), "red_paint_worn", 0.0)
    k.box((0.22, 0.26, 0.2), (-0.2, 0.745, -0.02), "red_paint_worn", 0.012)         # trauma bag
    k.cyl(0.07, 0.34, (0.22, 0.79, -0.04), "y", "steel_bare", 16)                    # oxygen bottle
    k.cyl(0.03, 0.05, (0.22, 0.985, -0.04), "y", "chrome_dull", 12)
    # door: hinge on the left edge, opens about +Y
    hx, z = -w / 2 + 0.005, d / 2 - 0.004
    k.group("Door", pivot=(hx, 0.0, z))
    dw, dt = w - 0.01, 0.026
    cx = hx + dw / 2
    k.box((dw, 0.9, dt), (cx, 0.54, z), "painted_metal", 0.008)                      # lower solid panel
    k.box((dw, 0.07, dt), (cx, 1.015, z), "painted_metal", 0.006)                    # rail
    k.box((dw, 0.07, dt), (cx, 1.845, z), "painted_metal", 0.006)
    k.box((0.07, 0.8, dt), (hx + 0.035, 1.43, z), "painted_metal", 0.006)            # stiles
    k.box((0.07, 0.8, dt), (hx + dw - 0.035, 1.43, z), "painted_metal", 0.006)
    k.box((dw - 0.12, 0.78, 0.004), (cx, 1.43, z - 0.004), "glass_dirty", 0.0)       # glass
    k.box((0.04, 0.2, 0.03), (hx + dw - 0.09, 0.98, z + 0.025), "steel_bare", 0.006)  # handle
    k.cyl(0.013, 0.2, (hx + dw - 0.09, 0.98, z + 0.045), "y", "steel_bare", 10)
    for y in (0.3, 1.0, 1.7):
        k.cyl(0.014, 0.1, (hx - 0.006, y, z), "y", "steel_bare", 10)
    k.decal((cx, 0.62, z + dt / 2), (0.5, 0.25), "signs_ru", uv("signs_ru", "first_aid"))
    k.decal((cx, 0.26, z + dt / 2), (0.3, 0.12), "panel_labels", uv("panel_labels", "АВАРИЯ"))
    k.body()
