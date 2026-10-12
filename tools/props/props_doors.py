"""Door controls and cable supports (issue #157).

Door leaves and frames are sized per door, so `objects/doors/door_art.gd` builds them in Godot from boxes with the
shared triplanar materials; the fixed-size parts (control panel, hand wheel, handle, hinge) are props here.
Control origins sit on the wall face behind them (z = 0), front = +Z; the door script turns the back-side copy by 180°.
"""
from __future__ import annotations

import math

from propkit import Kit
from props_kits import tray
from props_start import uv
from registry import prop

LAMP_R = 0.022  # the door script adds an emissive lens of this radius in front of the bezel


def bolts(k: Kit, w, h, y0, z, r=0.009):
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.hex_bolt((sx * w, y0 + sy * h, z), r, 0.007)


# ----------------------------------------------------------------------------- powered door
@prop("door_panel", "P-210a", (0.3, 0.63, 0.1), "free", 4000, tolerance=0.08,
      notes="Door control panel; origin on the wall face at the lamp-panel centre; lamp lens at (0, 0.1, 0.072)")
def door_panel(k: Kit):
    k.box((0.3, 0.46, 0.012), (0, 0, 0.006), "steel_bare", 0.003)                         # back plate
    bolts(k, 0.13, 0.21, 0.0, 0.015)
    k.box((0.26, 0.4, 0.055), (0, 0, 0.012 + 0.0275), "painted_metal", 0.008)             # housing
    k.box((0.22, 0.05, 0.004), (0, 0.165, 0.069), "plastic_panel", 0.001)                # label strip
    k.decal((0, 0.165, 0.071), (0.2, 0.045), "panel_labels", uv("panel_labels", "ДВЕРЬ"))
    k.torus(LAMP_R + 0.006, 0.006, (0, 0.1, 0.068), "z", "chrome_dull", 20, 6)            # lamp bezel
    # push button with a guard collar
    k.cyl(0.042, 0.012, (0, 0.0, 0.073), "z", "steel_bare", 24, cap_bevel=0.003)
    k.cyl(0.03, 0.022, (0, 0.0, 0.084), "z", "red_paint_worn", 24, cap_bevel=0.006)
    for sx in (-1, 1):
        k.box((0.012, 0.09, 0.03), (sx * 0.052, 0.0, 0.082), "steel_bare", 0.003)
    # card reader
    k.box((0.14, 0.1, 0.02), (0, -0.125, 0.077), "plastic_panel", 0.004)
    k.box((0.1, 0.008, 0.012), (0, -0.105, 0.088), "rubber_black", 0.001)
    k.decal((0, -0.15, 0.087), (0.1, 0.025), "panel_labels", uv("panel_labels", "ДОПУСК"))
    # conduit up into the wall
    k.cyl(0.016, 0.2, (0.08, 0.3, 0.035), "y", "steel_bare", 12)
    k.box((0.05, 0.03, 0.03), (0.08, 0.215, 0.035), "steel_bare", 0.004)
    k.box((0.05, 0.02, 0.05), (0.08, 0.37, 0.025), "steel_bare", 0.003)                   # wall clip
    k.cyl(0.016, 0.02, (0.08, 0.385, 0.035), "y", "steel_bare", 12)
    k.box((0.07, 0.012, 0.02), (0.08, 0.39, 0.012), "steel_bare", 0.002)


# ----------------------------------------------------------------------------- mechanical door
@prop("door_wheel", "P-210b", (0.52, 0.66, 0.33), "free", 6000, tolerance=0.08,
      notes="Hand wheel on a gearbox; origin on the wall face at the wheel axis; node Wheel spins about +Z; "
            "lamp lens at (0, 0.36, 0.05)")
def door_wheel(k: Kit):
    k.box((0.24, 0.3, 0.012), (0, 0.02, 0.006), "steel_bare", 0.003)                       # wall plate
    bolts(k, 0.1, 0.13, 0.02, 0.015)
    k.box((0.18, 0.2, 0.11), (0, 0.0, 0.067), "painted_metal_green", 0.012)               # gearbox
    k.box((0.2, 0.025, 0.12), (0, 0.1, 0.066), "painted_metal_green", 0.006)              # cover flange
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.hex_bolt((sx * 0.075, 0.1 + sy * 0.001, 0.127), 0.007, 0.006)
    k.cyl(0.05, 0.04, (0, 0, 0.14), "z", "steel_bare", 20, cap_bevel=0.004)               # bearing
    k.cyl(0.018, 0.12, (0, 0, 0.19), "z", "steel_bare", 12)                                # shaft
    # lamp and label above the wheel
    k.box((0.1, 0.09, 0.04), (0, 0.36, 0.026), "painted_metal", 0.006)
    k.torus(LAMP_R + 0.006, 0.006, (0, 0.36, 0.047), "z", "chrome_dull", 20, 6)
    k.box((0.2, 0.05, 0.006), (0, 0.27, 0.009), "plastic_panel", 0.002)
    k.decal((0, 0.27, 0.012), (0.18, 0.045), "panel_labels", uv("panel_labels", "РУЧНОЙ"))
    # rotation arrows painted on the wall plate
    k.decal((0, -0.11, 0.012), (0.2, 0.04), "hazard_stripes", uv("hazard_stripes", "yellow_black"))
    k.group("Wheel", pivot=(0, 0, 0.24))
    R = 0.24
    k.torus(R, 0.019, (0, 0, 0.24), "z", "red_paint_worn", 36, 10)                         # rim
    for a in range(5):
        t = a * 2 * math.pi / 5 + math.pi / 2
        k.cyl(0.011, R - 0.02, (math.cos(t) * R / 2, math.sin(t) * R / 2, 0.24), "y", "red_paint_worn", 8,
              rot=(0, 0, math.degrees(t) - 90))
    k.cyl(0.045, 0.06, (0, 0, 0.24), "z", "steel_bare", 20, cap_bevel=0.006)               # hub
    k.hex_bolt((0, 0, 0.272), 0.016, 0.01)
    k.cyl(0.018, 0.09, (R * math.cos(-0.5), R * math.sin(-0.5), 0.285), "z", "rubber_black", 12, cap_bevel=0.006)
    k.body()


# ----------------------------------------------------------------------------- manual door
@prop("door_handle", "P-210c", (0.17, 0.26, 0.08), "free", 1500, tolerance=0.1,
      notes="Door lever handle; origin on the leaf face at the handle axis; node Handle turns about +Z; "
            "lamp lens at (0, 0.09, 0.022)")
def door_handle(k: Kit):
    k.box((0.07, 0.26, 0.014), (0, 0.0, 0.007), "steel_bare", 0.004)                       # escutcheon
    for y in (-0.105, 0.105):
        k.hex_bolt((0, y, 0.014), 0.007, 0.005)
    k.cyl(0.012, 0.012, (0, -0.06, 0.016), "z", "rubber_black", 12)                         # key hole
    k.torus(LAMP_R * 0.7 + 0.005, 0.005, (0, 0.09, 0.017), "z", "chrome_dull", 16, 6)
    k.group("Handle", pivot=(0, 0, 0.03))
    k.cyl(0.022, 0.03, (0, 0, 0.03), "z", "chrome_dull", 16, cap_bevel=0.004)
    k.cyl(0.012, 0.05, (0, 0, 0.055), "z", "chrome_dull", 12)
    k.box((0.14, 0.024, 0.022), (0.065, 0, 0.074), "chrome_dull", 0.008)
    k.body()


# ----------------------------------------------------------------------------- swing door hinge
@prop("door_hinge", "P-210d", (0.1, 0.2, 0.04), "free", 800, tolerance=0.1,
      notes="Hinge knuckle with its frame leaf; origin at the hinge axis")
def door_hinge(k: Kit):
    k.cyl(0.022, 0.18, (0, 0, 0), "y", "steel_bare", 16, cap_bevel=0.004)
    k.cyl(0.012, 0.2, (0, 0, 0), "y", "chrome_dull", 10)
    k.box((0.06, 0.16, 0.008), (-0.045, 0, 0.0), "steel_bare", 0.002)
    for y in (-0.05, 0.05):
        k.hex_bolt((-0.055, y, 0.005), 0.006, 0.004)


# ----------------------------------------------------------------------------- cable supports (P-202)
def strut(k: Kit, x, z0, z1, y):
    """Slotted C-channel across the run at height y (top face), from z0 to z1."""
    L, w = z1 - z0, 0.041
    zc = (z0 + z1) / 2
    k.box((w, 0.006, L), (x, y - 0.003, zc), "steel_bare", 0.002)
    for sx in (-1, 1):
        k.box((0.005, w, L), (x + sx * (w / 2 - 0.0025), y - w / 2, zc), "steel_bare", 0.002)
    k.box((0.012, 0.004, L - 0.04), (x, y - 0.001, zc), "rubber_black", 0.0)              # slot shadow


def cable_ties(k: Kit, length=2.0, x0=0.0, step=0.5, z0=0.0):
    for i in range(int(length / step)):
        x = x0 + step / 2 + i * step
        k.box((0.012, 0.006, 0.27), (x, 0.045, z0), "rubber_black", 0.002)


@prop("cable_tray_straight", "P-202a", (2.0, 0.6, 0.43), "free", 6000, tolerance=0.1,
      notes="Ceiling-hung tray: origin at the start of the run on the tray bottom; the anchor plates touch the "
            "ceiling at y = +0.55, so place the piece at ceiling height - 0.55")
def cable_tray_straight(k: Kit):
    tray(k)
    cable_ties(k)
    top = 0.55
    for x in (0.5, 1.5):
        strut(k, x, -0.21, 0.21, -0.012)
        for sz in (-1, 1):
            z = sz * 0.185
            k.cyl(0.006, top + 0.04, (x, (top - 0.04) / 2 - 0.02, z), "y", "steel_bare", 8)   # threaded rod
            for y in (-0.06, -0.006):
                k.cyl(0.011, 0.01, (x, y, z), "y", "steel_bare", 6)                          # nuts
            k.box((0.07, 0.008, 0.07), (x, top - 0.004, z), "steel_bare", 0.002)            # ceiling anchor
            k.cyl(0.011, 0.012, (x, top - 0.014, z), "y", "steel_bare", 6)


@prop("cable_tray_wall", "P-202b", (2.0, 0.28, 0.4), "free", 6000, tolerance=0.1,
      notes="Wall-bracket tray: origin at the start of the run on the wall face (z = 0) at the tray bottom height")
def cable_tray_wall(k: Kit):
    zc = 0.2
    tray(k, z0=zc)
    cable_ties(k, z0=zc)
    for x in (0.5, 1.5):
        k.box((0.06, 0.26, 0.008), (x, -0.1, 0.004), "steel_bare", 0.002)                   # wall plate
        for y in (-0.02, -0.19):
            k.hex_bolt((x, y, 0.009), 0.008, 0.006)
        strut(k, x, 0.008, zc + 0.2, -0.012)                                                  # arm
        # diagonal brace from under the arm end down to the wall plate
        a, b = (x, -0.05, zc + 0.12), (x, -0.2, 0.012)
        d = math.dist(a, b)
        ang = math.degrees(math.atan2(a[1] - b[1], a[2] - b[2]))
        k.box((0.03, 0.006, d), (x, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), "steel_bare", 0.002, rot=(-ang, 0, 0))
