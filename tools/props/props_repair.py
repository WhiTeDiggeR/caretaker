"""Wave 1 props: repair elements, chains, cables, small items (docs/art/prop-catalog.md, section 1)."""
from __future__ import annotations

import json
import math

from propkit import TEX_DIR, Kit
from props_start import uv
from registry import prop


# ----------------------------------------------------------------------------- P-010
@prop("valve_wheel", "P-010", (0.4, 0.3, 0.26), "free", 3300)
def valve_wheel(k: Kit):
    """Wall-mounted pipe valve; the handwheel axis points at the player (+Z). Origin = wheel centre."""
    # pipe along X behind the wheel
    k.cyl(0.045, 0.4, (0, 0, -0.12), "x", "rusted_steel", 20)
    for sx in (-1, 1):
        k.cyl(0.07, 0.03, (sx * 0.16, 0, -0.12), "x", "steel_bare", 20, cap_bevel=0.004)   # flanges
        for a in range(6):
            t = a * math.pi / 3
            k.hex_bolt((sx * 0.16, 0.058 * math.sin(t), -0.12 + 0.058 * math.cos(t)), 0.008, 0.012, "x")
    k.sphere(0.075, (0, 0, -0.12), "painted_metal", 18)                                    # valve body
    k.cyl(0.04, 0.09, (0, 0, -0.06), "z", "painted_metal", 16, cap_bevel=0.004)           # bonnet
    k.cyl(0.012, 0.16, (0, 0, 0.0), "z", "steel_bare", 10)                                  # stem
    k.group("Wheel", pivot=(0, 0, 0.0))
    k.torus(0.135, 0.011, (0, 0, 0), "z", "painted_metal", 28, 8)                           # rim
    for a in range(4):
        t = a * math.pi / 2 + math.pi / 4
        k.cyl(0.0075, 0.26, (0, 0, 0), "y", "painted_metal", 8, rot=(0, 0, math.degrees(t) - 90))
    k.cyl(0.03, 0.04, (0, 0, 0.012), "z", "steel_bare", 14, cap_bevel=0.004)
    k.body()
    k.cyl(0.006, 0.08, (0.1, 0.02, -0.04), "z", "steel_bare", 8)                            # tag hook


# ----------------------------------------------------------------------------- P-011
@prop("pressure_gauge", "P-011", (0.2, 0.2, 0.09), "wall", 2000)
def pressure_gauge(k: Kit):
    r = 0.095
    k.cyl(0.03, 0.04, (0, 0, 0.02), "z", "steel_bare", 14)                                  # connection stud into the wall
    k.cyl(r, 0.05, (0, 0, 0.045), "z", "painted_metal", 28, cap_bevel=0.004)               # case
    k.cyl(r + 0.004, 0.012, (0, 0, 0.068), "z", "chrome_dull", 28, cap_bevel=0.003)        # bezel
    k.cyl(r - 0.012, 0.004, (0, 0, 0.0738), "z", "plastic_panel", 28)
    k.decal((0, 0, 0.0765), (2 * r - 0.008, 2 * r - 0.008), "instrument_faces", uv("instrument_faces", "pressure"), offset=0.0)
    k.cyl(r - 0.004, 0.003, (0, 0, 0.0795), "z", "glass_dirty", 28)
    k.group("Needle", pivot=(0, 0, 0.0765))
    k.box((0.006, 0.075, 0.003), (0, 0.025, 0.0775), "red_paint_worn", 0.0, rot=(0, 0, -50))
    k.box((0.006, 0.02, 0.003), (0, -0.01, 0.0775), "red_paint_worn", 0.0, rot=(0, 0, -50))
    k.body()
    k.cyl(0.012, 0.012, (0, 0, 0.082), "z", "steel_bare", 10)


# ----------------------------------------------------------------------------- P-012
@prop("start_lever", "P-012", (0.4, 1.2, 0.3), "floor", 3000)
def start_lever(k: Kit):
    k.box((0.4, 0.14, 0.3), (0, 0.07, 0), "painted_metal", 0.008)
    k.box((0.34, 0.03, 0.24), (0, 0.155, 0), "steel_bare", 0.004)
    k.box((0.04, 0.012, 0.2), (0, 0.176, 0), "rubber_black", 0.002)                        # guide slot
    for x in (-0.15, 0.15):
        for z in (-0.1, 0.1):
            k.hex_bolt((x, 0.172, z), 0.012, 0.01, "y")
    for x in (-0.07, 0.07):
        k.box((0.025, 0.08, 0.05), (x, 0.2, 0), "painted_metal", 0.004)                    # clevis
    k.group("Lever", pivot=(0, 0.2, 0))
    k.cyl(0.015, 1.0, (0, 0.7, 0), "y", "steel_bare", 14, rot=(0, 0, 0))
    k.cyl(0.02, 0.28, (0, 1.06, 0), "y", "rubber_black", 14)                              # grip
    k.sphere(0.028, (0, 1.2 - 0.028, 0), "rubber_black", 12)
    k.cyl(0.03, 0.08, (0, 0.2, 0), "x", "steel_bare", 14)
    k.body()
    k.decal((0, 0.1, 0.1505), (0.2, 0.05), "panel_labels", uv("panel_labels", "ПУСК"), offset=0.0)


# ----------------------------------------------------------------------------- P-013
@prop("wall_breaker", "P-013", (0.25, 0.35, 0.12), "wall", 1500)
def wall_breaker(k: Kit):
    k.box((0.25, 0.35, 0.06), (0, 0.175, 0.03), "painted_metal", 0.006)
    k.box((0.2, 0.3, 0.04), (0, 0.175, 0.08), "plastic_panel", 0.006)
    k.box((0.12, 0.2, 0.012), (0, 0.175, 0.102), "steel_bare", 0.002)
    for i in range(2):
        k.hex_bolt((-0.095 + i * 0.19, 0.04, 0.1), 0.01, 0.008)
    k.group("Handle", pivot=(0, 0.175, 0.108))
    k.box((0.02, 0.1, 0.012), (0, 0.225, 0.114), "rubber_black", 0.003, rot=(0, 0, 0))
    k.box((0.026, 0.035, 0.016), (0, 0.285, 0.114), "red_paint_worn", 0.004)
    k.cyl(0.01, 0.03, (0, 0.175, 0.108), "x", "steel_bare", 10)
    k.body()
    k.decal((0, 0.07, 0.1005), (0.12, 0.03), "panel_labels", uv("panel_labels", "ПИТАНИЕ"), offset=0.0)


# ----------------------------------------------------------------------------- P-014
@prop("chain_hanging", "P-014a", (0.07, 1.2, 0.07), "ceiling", 3500)
def chain_hanging(k: Kit):
    """Rusty chain hanging from a ceiling eye; the lower end is broken off."""
    k.cyl(0.04, 0.02, (0, -0.01, 0), "y", "painted_metal", 14)
    n, step = 14, 0.083
    for i in range(n):
        y = -0.05 - i * step
        axis = "x" if i % 2 == 0 else "z"
        # a link: two rails and two end arcs, made of tubes
        pts = []
        for j in range(17):
            t = 2 * math.pi * j / 16
            if axis == "x":
                pts.append((0.0, y + 0.048 * math.cos(t), 0.0 + 0.017 * math.sin(t)))
            else:
                pts.append((0.017 * math.sin(t), y + 0.048 * math.cos(t), 0.0))
        k.tube(pts, 0.0065, "rusted_steel", 5, caps=False)
    k.cyl(0.012, 0.03, (0, -0.05 - n * step, 0), "y", "rusted_steel", 8)


@prop("cable_hang", "P-014b", (0.36, 1.54, 0.12), "ceiling", 5000)
def cable_hang(k: Kit):
    """Three severed cables sagging from a ceiling clamp, bare copper at the ends."""
    k.box((0.3, 0.05, 0.12), (0, -0.025, 0), "painted_metal", 0.005)
    for x in (-0.1, 0.1):
        k.hex_bolt((x, -0.052, 0), 0.012, 0.008, "y")
    for i, (x0, drift, ln) in enumerate(((-0.08, -0.12, 1.45), (0.0, 0.1, 1.1), (0.08, 0.05, 0.8))):
        pts = []
        for j in range(21):
            t = j / 20
            pts.append((x0 + drift * t * t, -0.05 - ln * t, 0.03 * math.sin(t * 3 + i) * t))
        k.tube(pts, [0.018 - 0.004 * t / 20 for t in range(21)], "rubber_black", 8, caps=False)
        e = pts[-1]
        k.cyl(0.010, 0.05, (e[0], e[1] - 0.02, e[2]), "y", "chrome_dull", 8)
    k.cyl(0.04, 0.08, (-0.08, -0.07, 0), "y", "rubber_black", 10)


# ----------------------------------------------------------------------------- P-018
@prop("personal_key", "P-018", (0.09, 0.025, 0.006), "free", 700, tolerance=0.2)
def personal_key(k: Kit):
    k.torus(0.011, 0.0035, (-0.03, 0, 0), "z", "steel_bare", 14, 6)
    k.box((0.06, 0.007, 0.006), (0.015, 0, 0), "steel_bare", 0.001)
    for i, h in enumerate((0.009, 0.006, 0.011)):
        k.box((0.006, h, 0.006), (0.032 + i * 0.01, -0.0035 - h / 2, 0), "steel_bare", 0.0005)


# ----------------------------------------------------------------------------- P-019
@prop("document_sheet", "P-019", (0.42, 0.012, 0.3), "free", 600, tolerance=0.2)
def document_sheet(k: Kit):
    k.box((0.3, 0.003, 0.21), (0.03, 0.0015, 0.03), "paper_aged", 0.0005, rot=(0, 4, 0))
    k.box((0.3, 0.004, 0.21), (0.0, 0.005, 0.0), "paper_aged", 0.0005, rot=(0, -3, 0))
    k.box((0.2, 0.0015, 0.004), (0.0, 0.0072, -0.05), "rubber_black", 0.0)
    for i in range(5):
        k.box((0.18 - 0.02 * (i % 2), 0.0012, 0.003), (0.0, 0.0073, -0.02 + i * 0.022), "rubber_black", 0.0)
