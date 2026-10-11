"""Wave 2 props: modular kits and corrected furniture (docs/art/prop-catalog.md, sections 2 and 3).

Kit pieces use anchor "free": the origin is the start of the run (pipes, trays, ducts) so level scripts can chain them.
"""
from __future__ import annotations

import math

from propkit import Kit
from props_start import led, uv
from registry import prop


def flange(k: Kit, centre, r=0.115, axis="x", bolts=8, bolt_r=0.09):
    k.cyl(r, 0.03, centre, axis, "steel_bare", 20, cap_bevel=0.004)
    for i in range(bolts):
        t = 2 * math.pi * i / bolts
        a, b = bolt_r * math.cos(t), bolt_r * math.sin(t)
        pos = {"x": (centre[0], centre[1] + a, centre[2] + b), "y": (centre[0] + a, centre[1], centre[2] + b),
               "z": (centre[0] + a, centre[1] + b, centre[2])}[axis]
        k.hex_bolt(pos, 0.009, 0.014, axis)


# ----------------------------------------------------------------------------- P-201
@prop("pipe_straight", "P-201a", (2.0, 0.23, 0.23), "free", 2500, tolerance=0.1)
def pipe_straight(k: Kit):
    """2 m pipe run along +X from the origin, flanges at both ends, a clamp at the middle."""
    k.cyl(0.08, 1.94, (1.0, 0, 0), "x", "rusted_steel", 20)
    for x in (0.015, 1.985):
        flange(k, (x, 0, 0))
    k.torus(0.085, 0.012, (1.0, 0, 0), "x", "steel_bare", 20, 6)
    k.box((0.04, 0.03, 0.04), (1.0, 0.1, 0.0), "painted_metal", 0.004)


@prop("pipe_elbow", "P-201b", (0.61, 0.61, 0.23), "free", 3500, tolerance=0.1)
def pipe_elbow(k: Kit):
    """90-degree bend: enters along +X, leaves along +Y."""
    R, stub = 0.3, 0.2
    pts = [(0.0, 0, 0), (stub, 0, 0)]
    for i in range(1, 13):
        a = math.radians(90 * i / 12)
        pts.append((stub + R * math.sin(a), R * (1 - math.cos(a)), 0))
    pts.append((stub + R, R + stub, 0))
    k.tube(pts, 0.08, "rusted_steel", 14)
    flange(k, (0.015, 0, 0))
    flange(k, (stub + R, R + stub - 0.015, 0), axis="y")


@prop("pipe_tee", "P-201c", (1.0, 0.71, 0.23), "free", 4000, tolerance=0.1)
def pipe_tee(k: Kit):
    k.cyl(0.08, 0.94, (0.5, 0, 0), "x", "rusted_steel", 20)
    k.cyl(0.08, 0.5, (0.5, 0.3, 0), "y", "rusted_steel", 20)
    k.sphere(0.095, (0.5, 0, 0), "painted_metal", 14)
    for x in (0.015, 0.985):
        flange(k, (x, 0, 0))
    flange(k, (0.5, 0.585, 0), axis="y")
    k.torus(0.085, 0.012, (0.5, 0.25, 0), "y", "steel_bare", 20, 6)


# ----------------------------------------------------------------------------- P-202
def tray(k: Kit, length=2.0, x0=0.0, cables=5):
    w = 0.3
    k.box((length, 0.012, w), (x0 + length / 2, -0.006, 0), "painted_metal", 0.003)
    for sz in (-1, 1):
        k.box((length, 0.05, 0.012), (x0 + length / 2, 0.019, sz * (w / 2 - 0.006)), "painted_metal", 0.003)
    for i in range(int(length / 0.5) + 1):
        k.box((0.02, 0.012, w), (x0 + i * 0.5 * (length / (int(length / 0.5) or 1)) / 0.5 * 0.5, -0.003, 0), "steel_bare", 0.002)
    for c in range(cables):
        z = -0.1 + c * 0.05
        pts = [(x0 + length * t / 12, 0.02 + 0.012 * math.sin(t * 1.3 + c), z + 0.01 * math.sin(t * 0.7 + c * 2)) for t in range(13)]
        k.tube(pts, 0.011 if c % 2 else 0.014, "rubber_black", 7, caps=False)


@prop("cable_tray_straight", "P-202a", (2.01, 0.33, 0.38), "free", 3500, tolerance=0.1)
def cable_tray_straight(k: Kit):
    tray(k)
    for x in (0.5, 1.5):
        k.box((0.03, 0.06, 0.34), (x, -0.03, 0), "steel_bare", 0.003)
        for sz in (-1, 1):
            k.box((0.03, 0.25, 0.03), (x, -0.15, sz * 0.17), "steel_bare", 0.003)


# ----------------------------------------------------------------------------- P-203
@prop("duct_straight", "P-203a", (2.0, 0.83, 0.66), "free", 2200, tolerance=0.1)
def duct_straight(k: Kit):
    w, h, t, L = 0.6, 0.5, 0.012, 2.0
    for sy in (-1, 1):
        k.box((L, t, w), (L / 2, sy * (h / 2 - t / 2), 0), "duct_galvanized", 0.003)
    for sz in (-1, 1):
        k.box((L, h, t), (L / 2, 0, sz * (w / 2 - t / 2)), "duct_galvanized", 0.003)
    for x in (0.0, 1.0, 2.0):
        xx = min(max(x, 0.025), L - 0.025)
        for sy in (-1, 1):
            k.box((0.05, 0.03, w + 0.06), (xx, sy * (h / 2 + 0.01), 0), "painted_metal", 0.003)
        for sz in (-1, 1):
            k.box((0.05, h + 0.06, 0.03), (xx, 0, sz * (w / 2 + 0.01)), "painted_metal", 0.003)
    for sz in (-1, 1):
        k.box((0.03, 0.3, 0.004), (0.5, h / 2 + 0.15, sz * (w / 2)), "rusted_steel", 0.0)


# ----------------------------------------------------------------------------- P-205
@prop("floor_grate", "P-205", (1.0, 0.05, 1.0), "floor", 3000, tolerance=0.05)
def floor_grate(k: Kit):
    s = 1.0
    for sx in (-1, 1):
        k.box((0.05, 0.05, s), (sx * (s / 2 - 0.025), 0.025, 0), "painted_metal", 0.004)
    for sz in (-1, 1):
        k.box((s - 0.1, 0.05, 0.05), (0, 0.025, sz * (s / 2 - 0.025)), "painted_metal", 0.004)
    n = 20
    for i in range(n):
        z = -0.45 + 0.9 * i / (n - 1)
        k.box((0.9, 0.03, 0.012), (0, 0.025, z), "steel_bare", 0.001)
    for i in range(4):
        k.box((0.012, 0.012, 0.9), (-0.36 + i * 0.24, 0.012, 0), "steel_bare", 0.0)
    k.box((0.012, 0.03, 0.9), (0.0, 0.015, 0), "steel_bare", 0.0)


# ----------------------------------------------------------------------------- P-206
@prop("fluorescent_light", "P-206a", (1.2, 0.09, 0.14), "ceiling", 1200)
def fluorescent_light(k: Kit):
    k.box((1.2, 0.05, 0.14), (0, -0.025, 0), "painted_metal", 0.006)
    for sx in (-1, 1):
        k.box((0.03, 0.06, 0.14), (sx * 0.585, -0.03, 0), "plastic_panel", 0.004)
    k.box((1.0, 0.01, 0.1), (0, -0.054, 0), "steel_bare", 0.002)                              # reflector
    k.group("Emit_Tube", pivot=(0, -0.06, 0))
    k.cyl(0.016, 1.08, (0, -0.07, 0), "x", "emit_lamp_cold", 10)
    k.body()
    for sx in (-0.45, 0.45):
        k.box((0.03, 0.02, 0.1), (sx, -0.077, 0), "steel_bare", 0.002)


@prop("emergency_beacon", "P-206b", (0.16, 0.2, 0.11), "wall", 2000, tolerance=0.1)
def emergency_beacon(k: Kit):
    k.box((0.16, 0.2, 0.03), (0, 0.1, 0.015), "painted_metal", 0.006)
    k.cyl(0.055, 0.03, (0, 0.1, 0.045), "z", "painted_metal", 20, cap_bevel=0.004)
    k.group("Emit_Lamp", pivot=(0, 0.1, 0.06))
    k.sphere(0.052, (0, 0.1, 0.055), "emit_beacon_red", 16, scale=(1, 1, 0.75))
    k.body()
    for i in range(3):
        k.torus(0.058, 0.004, (0, 0.1, 0.065), "z", "steel_bare", 20, 5)
        break
    for a in range(6):
        t = a * math.pi / 3
        k.box((0.006, 0.006, 0.07), (0.056 * math.cos(t), 0.1 + 0.056 * math.sin(t), 0.075), "steel_bare", 0.0)
    for y in (0.03, 0.17):
        k.hex_bolt((0, y, 0.032), 0.01, 0.008)


# ----------------------------------------------------------------------------- P-101 / P-102
@prop("locker_tall", "P-101", (0.5, 1.9, 0.53), "floor", 5000, center_z=False)
def locker_tall(k: Kit):
    """Two-door personal locker; replaces the 0.3 m wide placeholder."""
    w, h, d = 0.5, 1.9, 0.5
    k.box((w, 0.1, d), (0, 0.05, 0), "painted_metal", 0.006)
    k.box((w, h - 0.1, d - 0.02), (0, 0.1 + (h - 0.1) / 2, -0.01), "painted_metal", 0.008)
    for i, sx in enumerate((-1, 1)):
        hx = sx * (w / 2 - 0.004)
        k.group(f"Door{i + 1}", pivot=(hx, 0.0, d / 2 - 0.004))
        cx = sx * (w / 4)
        k.box((w / 2 - 0.012, h - 0.14, 0.02), (cx, 0.1 + (h - 0.14) / 2 + 0.03, d / 2 - 0.004), "painted_metal", 0.006)
        for j in range(6):
            k.box((w / 2 - 0.08, 0.012, 0.012), (cx, 1.62 - j * 0.03, d / 2 + 0.008), "rubber_black", 0.001)  # vent slots
        k.box((0.016, 0.1, 0.02), (cx - sx * 0.07, 0.95, d / 2 + 0.018), "steel_bare", 0.003)               # handle
        k.box((0.05, 0.03, 0.004), (cx, 1.4, d / 2 + 0.008), "plastic_panel", 0.0)                           # number plate
        k.body()
    k.decal((-0.125, 1.4, d / 2 + 0.0105), (0.04, 0.02), "panel_labels", uv("panel_labels", "1"), offset=0.0)
    k.decal((0.125, 1.4, d / 2 + 0.0105), (0.04, 0.02), "panel_labels", uv("panel_labels", "2"), offset=0.0)


@prop("file_cabinet", "P-102", (0.5, 1.3, 0.48), "floor", 5000, center_z=False)
def file_cabinet(k: Kit):
    w, h, d = 0.5, 1.3, 0.45
    k.box((w, 0.05, d), (0, 0.025, 0), "painted_metal", 0.004)
    k.box((w, h - 0.05, d - 0.03), (0, 0.05 + (h - 0.05) / 2, -0.015), "painted_metal", 0.008)
    dh = (h - 0.1) / 4
    for i in range(4):
        yc = 0.07 + dh * i + dh / 2
        k.group(f"Drawer{i + 1}", pivot=(0, yc, d / 2 - 0.015))
        k.box((w - 0.03, dh - 0.015, 0.03), (0, yc, d / 2 - 0.005), "painted_metal", 0.006)
        k.box((0.16, 0.025, 0.03), (0, yc + dh * 0.12, d / 2 + 0.018), "steel_bare", 0.004)                  # handle
        k.box((0.1, 0.04, 0.003), (0, yc - dh * 0.05, d / 2 + 0.012), "plastic_panel", 0.0)                  # label holder
        k.body()
        k.decal((0, yc - dh * 0.05, d / 2 + 0.0135), (0.09, 0.03), "panel_labels", uv("panel_labels", ("A1", "A2", "B1", "B2")[i]), offset=0.0)
