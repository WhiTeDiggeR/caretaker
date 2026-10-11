"""Prisoner sleep capsules built by script (#130), after the text-to-3d originals in loads/*_capsule.

One serial architecture (canon: standardised modules, adapted per prisoner, docs/world/03-complex.md):
a horizontal rounded hull on cradle saddles, a long observation window on the front (+Z), heavy end drums with a
glowing port, a control console under the window, equipment on the roof and cables to the floor.
Bowser (object No. 4): heavy mechanics, massive clamps and pipes, green accents.
Herobrine (object No. 3, the first prototype): angular, cold blue light strips, blocky sleeper, floating shards.
Units: metres, length along X, floor at y = 0, front +Z. Movable/switchable nodes: Glass, Port, Screen.
"""
from __future__ import annotations

import math
import random

from propkit import Kit
from props_start import uv
from registry import prop


def rrect_contour(d, h, r, yc=0.0, n=8):
    """Closed rounded rectangle in the (z, y) plane, counter-clockwise starting at the middle of the front (+z) side."""
    pts = [(d / 2, yc)]
    corners = ((d / 2 - r, yc + h / 2 - r, 0), (-d / 2 + r, yc + h / 2 - r, 90), (-d / 2 + r, yc - h / 2 + r, 180), (d / 2 - r, yc - h / 2 + r, 270))
    for cz, cy, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cz + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def c_profile(d, h, r, yc, t, y0, y1, n=8):
    """Hull wall section with an opening on the front between y0 and y1 (both on the flat front side): the outer
    contour runs from the window top over the roof, back and floor to the window bottom, the inner contour returns."""
    assert yc - h / 2 + r <= y0 < y1 <= yc + h / 2 - r, "window must sit on the flat front side"
    outer = [(d / 2, y1)] + rrect_contour(d, h, r, yc, n)[1:] + [(d / 2, y0)]
    di, hi, ri = d - 2 * t, h - 2 * t, max(r - t, 0.02)
    inner = [(di / 2, y1)] + rrect_contour(di, hi, ri, yc, n)[1:] + [(di / 2, y0)]
    poly = outer + list(reversed(inner))
    out = []
    for p in poly:
        if not out or abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6:
            out.append(p)
    return out


def hull(k: Kit, L_win, L_end, d, h, r, yc, t, y0, y1, mat):
    """Middle section (with the window opening) plus two closed end sections."""
    k.prism_x(c_profile(d, h, r, yc, t, y0, y1), L_win, 0.0, mat, bevel=0.0)
    for sx in (-1, 1):
        k.prism_x(rrect_contour(d, h, r, yc)[1:], L_end, sx * (L_win / 2 + L_end / 2), mat, bevel=0.01)


def band(k: Kit, x, d, h, r, yc, width, mat):
    """A raised reinforcing band around the hull at position x."""
    k.prism_x(rrect_contour(d, h, r, yc)[1:], width, x, mat, bevel=0.008)


def helix(k: Kit, x0, x1, radius, yc, zc, turns, r_tube, mat, seg=10):
    pts = []
    n = int(turns * 28)
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * turns * t
        pts.append((x0 + (x1 - x0) * t, yc + radius * math.cos(a), zc + radius * math.sin(a)))
    k.tube(pts, r_tube, mat, seg)
    return pts[-1]


def port(k: Kit, x, yc, side, r, emit, glass):
    """End port: flange, bolt ring, recessed lens with a glowing iris (group Port)."""
    k.cyl(r + 0.08, 0.06, (x, yc, 0), "x", "steel_bare", 40, cap_bevel=0.01)
    for i in range(16):
        a = 2 * math.pi * i / 16
        k.hex_bolt((x + side * 0.035, yc + (r + 0.04) * math.cos(a), (r + 0.04) * math.sin(a)), 0.018, 0.02, "x")
    k.cyl(r, 0.04, (x + side * 0.03, yc, 0), "x", "rubber_black", 40)
    k.group("Port", pivot=(x + side * 0.06, yc, 0))
    k.torus(r * 0.72, 0.03, (x + side * 0.06, yc, 0), "x", emit, 40, 8)
    k.torus(r * 0.45, 0.018, (x + side * 0.065, yc, 0), "x", emit, 32, 6)
    k.cyl(r * 0.28, 0.03, (x + side * 0.06, yc, 0), "x", emit, 28)
    k.body()
    k.cyl(r * 0.85, 0.012, (x + side * 0.09, yc, 0), "x", glass, 40)


# ============================================================================ Bowser, object No. 4
B_L, B_D, B_H, B_R, B_YC = 3.0, 2.4, 2.3, 0.62, 1.6         # middle hull length, depth, height, corner radius, centre
B_Y0, B_Y1 = 1.08, 2.12                                       # window opening


@prop("capsule_bowser", "P-106s", (4.87, 3.22, 2.82), "floor", 60000, tolerance=0.05, center_z=False,
      views=[((1.1, 0.45, 1.5), (0, 0, 0)), ((-1.3, 0.7, 1.0), (0, 0, 0)), ((0.6, 0.6, -1.6), (0, 0, 0))])
def capsule_bowser(k: Kit):
    g = random.Random(4)
    d, h, r, yc = B_D, B_H, B_R, B_YC
    half = B_L / 2
    # ---- base: plinth, saddles, feet
    k.box((4.3, 0.12, 2.0), (0, 0.06, 0), "painted_metal", 0.012)
    k.box((4.1, 0.08, 1.8), (0, 0.16, 0), "diamond_plate", 0.006)
    for x in (-1.45, 0.0, 1.45):
        k.box((0.5, 0.42, 2.1), (x, 0.36, 0), "painted_metal", 0.02)                          # saddle blocks
        k.box((0.56, 0.06, 2.16), (x, 0.58, 0), "steel_bare", 0.008)
        for sz in (-1, 1):
            k.box((0.18, 0.5, 0.2), (x, 0.3, sz * 1.1), "painted_metal_green", 0.015)       # side chocks
            k.hex_bolt((x, 0.42, sz * 1.205), 0.025, 0.02)
    for x in (-2.05, 2.05):
        for z in (-0.9, 0.9):
            k.box((0.3, 0.1, 0.3), (x, 0.05, z), "rubber_black", 0.01)                         # anti-vibration feet
    k.decal((0, 0.12, 1.001), (3.8, 0.1), "hazard_stripes", uv("hazard_stripes", "yellow_black"))
    # ---- hull with the window opening, interior liner
    hull(k, B_L, 0.32, d, h, r, yc, 0.09, B_Y0, B_Y1, "painted_metal")
    k.box((B_L, h - 0.5, 0.04), (0, yc, -d / 2 + 0.12), "emit_haze_green", 0.0)               # inner back panel, glowing haze
    k.box((B_L - 0.1, 0.06, d - 0.5), (0, B_Y0 - 0.05, 0.05), "steel_bare", 0.0)              # inner floor
    k.group("Emit_Interior", pivot=(0, B_Y1 - 0.05, 0.2))
    k.box((B_L - 0.3, 0.03, 0.08), (0, B_Y1 - 0.04, 0.35), "emit_green_soft", 0.0)            # interior light strip
    k.body()
    # ---- sleeper: Bowser lying on his side, restrained (stylised: shell, spikes, head, horns, limbs)
    by = B_Y0 + 0.02
    k.box((2.5, 0.12, 0.9), (0, by + 0.06, 0.0), "vinyl_worn", 0.04)                           # padded cradle
    k.sphere(0.62, (0.25, by + 0.58, -0.18), "shell_green", 20, scale=(1.15, 0.78, 0.82))     # shell
    k.torus(0.62, 0.06, (0.25, by + 0.5, -0.05), "y", "horn_bone", 32, 8)                      # shell rim
    for i in range(7):
        a = math.radians(-60 + i * 20)
        sx, sy = 0.25 + 0.55 * math.cos(a) * 1.1, by + 0.58 + 0.45 * math.sin(a + 1.2) * 0.4 + 0.2
        k.cyl(0.07, 0.2, (sx, sy + 0.18, -0.35), "y", "horn_bone", 10, r2=0.0, rot=(-25, 0, g.uniform(-15, 15)))
    k.sphere(0.36, (0.35, by + 0.42, 0.22), "skin_yellow", 18, scale=(1.3, 0.75, 0.6))         # belly
    k.sphere(0.27, (-0.82, by + 0.42, 0.12), "skin_yellow", 18, scale=(1.2, 0.95, 1.0))        # head
    k.sphere(0.14, (-1.08, by + 0.36, 0.2), "skin_yellow", 14, scale=(1.3, 0.8, 1.0))          # snout
    for sz in (-1, 1):
        k.cyl(0.05, 0.28, (-0.8, by + 0.66, 0.12 + sz * 0.13), "y", "horn_bone", 10, r2=0.0, rot=(sz * 35, 0, -20))   # horns
    k.sphere(0.16, (-0.62, by + 0.62, 0.02), "hair_red", 10, scale=(1.4, 0.6, 1.2))            # hair
    for x, z in ((-0.3, 0.38), (0.9, 0.3), (1.05, -0.05)):
        k.sphere(0.15, (x, by + 0.2, z), "skin_yellow", 12, scale=(1.4, 0.8, 1.0))             # limbs
    for x in (-0.45, 0.55):                                                                    # restraint bands
        k.box((0.1, 0.06, 1.0), (x, by + 0.9, 0.0), "steel_bare", 0.01)
        for sz in (-1, 1):
            k.box((0.1, 0.8, 0.06), (x, by + 0.5, sz * 0.48), "steel_bare", 0.01)
    # ---- window: glass, frame, clamps (group Glass)
    k.group("Glass", pivot=(0, (B_Y0 + B_Y1) / 2, d / 2))
    k.box((B_L - 0.04, B_Y1 - B_Y0 - 0.04, 0.03), (0, (B_Y0 + B_Y1) / 2, d / 2 - 0.05), "glass_green", 0.0)
    k.body()
    fz = d / 2 + 0.04
    k.box((B_L + 0.2, 0.16, 0.14), (0, B_Y1 + 0.06, fz), "painted_metal", 0.02)
    k.box((B_L + 0.2, 0.16, 0.14), (0, B_Y0 - 0.06, fz), "painted_metal", 0.02)
    for sx in (-1, 1):
        k.box((0.16, B_Y1 - B_Y0 + 0.28, 0.14), (sx * (half + 0.02), (B_Y0 + B_Y1) / 2, fz), "painted_metal", 0.02)
    for i in range(6):
        x = -half + 0.25 + i * (B_L - 0.5) / 5
        for y, s in ((B_Y1 + 0.06, 1), (B_Y0 - 0.06, -1)):
            k.box((0.16, 0.22, 0.12), (x, y + s * 0.04, fz + 0.1), "steel_bare", 0.015)        # clamp jaws
            k.cyl(0.04, 0.16, (x, y + s * 0.04, fz + 0.12), "y", "painted_metal_green", 12)
            k.hex_bolt((x, y + s * 0.12, fz + 0.165), 0.022, 0.02)
    # ---- reinforcing bands on the end sections
    for x in (-half - 0.12, half + 0.12):
        band(k, x, d + 0.08, h + 0.08, r + 0.04, yc, 0.12, "painted_metal_green")
    # ---- end drums and ports
    for sx in (-1, 1):
        x0 = sx * (half + 0.32)
        k.cyl(1.0, 0.5, (x0 + sx * 0.25, yc, 0), "x", "painted_metal", 48, cap_bevel=0.03)
        for j, rr in enumerate((1.02, 1.02)):
            k.torus(rr, 0.035, (x0 + sx * (0.08 + j * 0.34), yc, 0), "x", "steel_bare", 48, 8)
        port(k, x0 + sx * 0.52, yc, sx, 0.42, "emit_led_green", "glass_green")
    # spiral cable around the +X drum, then down to the floor
    end = helix(k, half + 0.38, half + 0.75, 1.08, yc, 0.0, 2.25, 0.045, "rubber_black")
    k.tube([end, (end[0] + 0.05, end[1] - 0.4, end[2] - 0.2), (end[0] + 0.1, 0.25, -0.75), (end[0] + 0.12, 0.05, -1.0)], 0.045, "rubber_black", 10)
    # ---- roof: sedative reservoir, pipe stacks, lifting eyes, warning lamps
    top = yc + h / 2
    k.cyl(0.42, 0.12, (0, top + 0.06, -0.15), "y", "painted_metal_green", 32, cap_bevel=0.01)
    k.cyl(0.34, 0.26, (0, top + 0.25, -0.15), "y", "painted_metal", 32, cap_bevel=0.02)
    k.cyl(0.38, 0.05, (0, top + 0.4, -0.15), "y", "steel_bare", 32, cap_bevel=0.01)
    for i in range(12):
        a = 2 * math.pi * i / 12
        k.hex_bolt((0.36 * math.cos(a), top + 0.43, -0.15 + 0.36 * math.sin(a)), 0.016, 0.014, "y")
    for x in (-1.15, -0.65, 0.65, 1.15):
        k.cyl(0.07, 0.34, (x, top + 0.17, -0.45), "y", "steel_bare", 14)
        k.cyl(0.1, 0.05, (x, top + 0.02, -0.45), "y", "painted_metal", 14)
        k.tube([(x, top + 0.34, -0.45), (x, top + 0.42, -0.5), (x + 0.05 * math.copysign(1, x), top + 0.4, -0.7),
                (x + 0.08 * math.copysign(1, x), top - 0.1, -1.05)], 0.05, "rubber_black", 10)
        k.cyl(0.085, 0.06, (x, top + 0.34, -0.45), "y", "painted_metal_green", 14)
    for x in (-1.6, 1.6):
        k.torus(0.08, 0.025, (x, top + 0.1, 0), "z", "steel_bare", 16, 6)                       # lifting eyes
        k.box((0.12, 0.06, 0.2), (x, top + 0.02, 0), "steel_bare", 0.01)
    for x in (-0.4, 0.4):
        k.cyl(0.06, 0.08, (x, top + 0.04, 0.55), "y", "painted_metal", 14)
        k.sphere(0.055, (x, top + 0.12, 0.55), "emit_led_amber", 12)
    # ---- console under the window
    cz = d / 2 + 0.05
    tilt = 12.0
    k.box((1.7, 0.36, 0.3), (0, 0.78, cz + 0.05), "painted_metal", 0.02, rot=(-tilt, 0, 0))
    def face(x, dy):  # point on the tilted front face of the console, dy along the face
        a = math.radians(tilt)
        return (x, 0.78 + 0.15 * math.sin(a) + dy * math.cos(a), cz + 0.05 + 0.15 * math.cos(a) - dy * math.sin(a))
    k.group("Screen", pivot=face(0, 0.02))
    k.decal(face(0, 0.02), (0.62, 0.3), "capsule_screens", uv("capsule_screens", "module_4"), tilt=-tilt)
    k.body()
    for sx in (-1, 1):
        k.cyl(0.07, 0.03, face(sx * 0.52, 0.02), "z", "steel_bare", 20, rot=(-tilt, 0, 0))
        k.cyl(0.05, 0.06, face(sx * 0.52, 0.02), "z", "emit_led_red", 20, rot=(-tilt, 0, 0))
    for i in range(6):
        x, y = 0.66 + (i % 2) * 0.1, -0.09 + (i // 2) * 0.08
        k.cyl(0.014, 0.02, face(x, y), "z", ("emit_led_green", "emit_led_amber", "emit_led_green", "emit_led_green", "emit_led_red", "emit_led_green")[i], 10, rot=(-tilt, 0, 0))
        k.cyl(0.014, 0.02, face(-x, y), "z", "emit_led_green", 10, rot=(-tilt, 0, 0))
    k.decal((half + 0.16, yc + 0.15, d / 2), (0.26, 0.13), "signs_ru", uv("signs_ru", "module_4"))
    k.decal((-half + 0.35, B_Y0 - 0.06, fz + 0.075), (0.36, 0.09), "panel_labels", uv("panel_labels", "КАПСУЛА"))
    # rear: stiffening ribs and a bolted service hatch with a handwheel
    for y in (yc - 0.55, yc + 0.55):
        k.box((B_L + 0.6, 0.1, 0.1), (0, y, -d / 2 - 0.02), "painted_metal_green", 0.015)
    k.box((1.1, 0.8, 0.08), (0.3, yc, -d / 2 - 0.03), "painted_metal", 0.02)
    for i in range(10):
        a = 2 * math.pi * i / 10
        k.hex_bolt((0.3 + 0.48 * math.cos(a), yc + 0.33 * math.sin(a), -d / 2 - 0.075), 0.02, 0.02)
    k.torus(0.18, 0.02, (0.3, yc, -d / 2 - 0.12), "z", "steel_bare", 24, 6)
    k.cyl(0.04, 0.1, (0.3, yc, -d / 2 - 0.09), "z", "steel_bare", 12)
    k.decal((-1.0, yc, -d / 2 - 0.0), (0.4, 0.2), "signs_ru", uv("signs_ru", "danger"), normal="-z")
    # feed pipes along the lower hull with clamps, pressure gauges on the end sections
    for y, z in ((0.72, d / 2 - 0.12), (0.86, d / 2 - 0.02)):
        k.cyl(0.05, 4.0, (0, y, z), "x", "rusted_steel", 14)
        for x in (-1.7, -0.6, 0.6, 1.7):
            k.torus(0.055, 0.012, (x, y, z), "x", "steel_bare", 14, 5)
    for sx in (-1, 1):
        gx = sx * (half + 0.16)
        k.cyl(0.11, 0.06, (gx, yc - 0.35, d / 2 + 0.01), "z", "chrome_dull", 24, cap_bevel=0.006)
        k.decal((gx, yc - 0.35, d / 2 + 0.04), (0.19, 0.19), "instrument_faces", uv("instrument_faces", "pressure"))
        k.cyl(0.1, 0.004, (gx, yc - 0.35, d / 2 + 0.048), "z", "glass_dirty", 24)
    # side service boxes
    for sx in (-1, 1):
        k.box((0.3, 0.4, 0.22), (sx * 1.9, 0.75, d / 2 - 0.05), "painted_metal", 0.015)
        k.decal((sx * 1.9, 0.82, d / 2 + 0.065), (0.2, 0.1), "signs_ru", uv("signs_ru", "high_voltage"))


# ============================================================================ Herobrine, object No. 3
H_L, H_D, H_H, H_R, H_YC = 3.1, 2.6, 1.8, 0.26, 1.3
H_Y0, H_Y1 = 0.8, 1.82


@prop("capsule_herobrine", "P-106s", (5.06, 2.54, 3.29), "floor", 60000, tolerance=0.05, center_z=False,
      views=[((1.1, 0.45, 1.5), (0, 0, 0)), ((-1.3, 0.7, 1.0), (0, 0, 0)), ((0.6, 0.6, -1.6), (0, 0, 0))])
def capsule_herobrine(k: Kit):
    g = random.Random(3)
    d, h, r, yc = H_D, H_H, H_R, H_YC
    half = H_L / 2
    # ---- base: low wide plinth with blue edge light
    k.box((4.5, 0.14, 2.4), (0, 0.07, 0), "painted_metal", 0.012)
    k.box((4.3, 0.06, 2.2), (0, 0.17, 0), "diamond_plate", 0.006)
    for x in (-1.5, 0.0, 1.5):
        k.box((0.6, 0.28, 2.3), (x, 0.32, 0), "painted_metal", 0.015)
    k.group("Emit_Base", pivot=(0, 0.1, 1.2))
    k.box((4.3, 0.025, 0.02), (0, 0.13, 1.205), "emit_cold_blue", 0.0)
    k.box((4.3, 0.025, 0.02), (0, 0.13, -1.205), "emit_cold_blue", 0.0)
    k.body()
    # ---- angular hull
    hull(k, H_L, 0.3, d, h, r, yc, 0.08, H_Y0, H_Y1, "painted_metal")
    k.box((H_L, h - 0.3, 0.04), (0, yc, -d / 2 + 0.11), "emit_haze_blue", 0.0)
    k.box((H_L - 0.1, 0.05, d - 0.4), (0, H_Y0 - 0.04, 0.05), "plastic_panel", 0.0)
    k.group("Emit_Interior", pivot=(0, H_Y1 - 0.05, 0.2))
    k.box((H_L - 0.3, 0.025, 0.06), (0, H_Y1 - 0.03, 0.4), "emit_cold_blue", 0.0)
    k.body()
    # ---- sleeper: blocky figure lying on its back, glowing eyes, shards hovering around it
    by = H_Y0 + 0.02
    k.box((2.3, 0.1, 0.9), (0, by + 0.05, 0.0), "vinyl_worn", 0.03)
    k.box((0.42, 0.42, 0.42), (-0.95, by + 0.31, 0.0), "skin_tan", 0.01)                         # head
    k.box((0.42, 0.06, 0.42), (-0.95, by + 0.55, 0.0), "fabric_dark", 0.005)                      # hair
    for sz in (-1, 1):
        k.box((0.02, 0.05, 0.08), (-0.95, by + 0.36, sz * 0.09), "emit_eye_white", 0.0, rot=(0, 0, 0))
    k.box((0.02, 0.06, 0.1), (-0.736, by + 0.36, -0.09), "emit_eye_white", 0.0)
    k.box((0.02, 0.06, 0.1), (-0.736, by + 0.36, 0.09), "emit_eye_white", 0.0)
    k.box((0.7, 0.24, 0.46), (-0.38, by + 0.22, 0.0), "cloth_teal", 0.01)                         # torso
    for sz in (-1, 1):
        k.box((0.7, 0.2, 0.2), (-0.38, by + 0.2, sz * 0.34), "cloth_teal", 0.01)                   # arms
        k.box((0.18, 0.2, 0.2), (0.0, by + 0.2, sz * 0.34), "skin_tan", 0.01)                      # hands
        k.box((0.7, 0.22, 0.22), (0.33, by + 0.21, sz * 0.12), "cloth_navy", 0.01)                 # legs
        k.box((0.14, 0.24, 0.24), (0.74, by + 0.22, sz * 0.12), "plastic_panel", 0.01)            # boots
    for i in range(14):                                                                            # anomaly shards
        s = g.uniform(0.04, 0.11)
        k.box((s, s, s), (g.uniform(-1.2, 1.2), by + g.uniform(0.5, 0.85), g.uniform(-0.5, 0.45)), "crystal_core", 0.0,
              rot=(g.uniform(0, 90), g.uniform(0, 90), g.uniform(0, 90)))
    for x in (-0.6, 0.2):
        k.box((0.08, 0.05, 1.0), (x, by + 0.38, 0.0), "steel_bare", 0.008)
    # ---- window
    k.group("Glass", pivot=(0, (H_Y0 + H_Y1) / 2, d / 2))
    k.box((H_L - 0.04, H_Y1 - H_Y0 - 0.04, 0.03), (0, (H_Y0 + H_Y1) / 2, d / 2 - 0.05), "glass_blue", 0.0)
    k.body()
    fz = d / 2 + 0.03
    k.box((H_L + 0.16, 0.1, 0.1), (0, H_Y1 + 0.04, fz), "painted_metal", 0.01)
    k.box((H_L + 0.16, 0.1, 0.1), (0, H_Y0 - 0.04, fz), "painted_metal", 0.01)
    for sx in (-1, 1):
        k.box((0.1, H_Y1 - H_Y0 + 0.18, 0.1), (sx * (half + 0.03), (H_Y0 + H_Y1) / 2, fz), "painted_metal", 0.01)
    k.group("Emit_Frame", pivot=(0, H_Y1, fz + 0.05))
    k.box((H_L + 0.1, 0.018, 0.012), (0, H_Y1 + 0.04, fz + 0.056), "emit_cold_blue", 0.0)
    k.box((H_L + 0.1, 0.018, 0.012), (0, H_Y0 - 0.04, fz + 0.056), "emit_cold_blue", 0.0)
    for sx in (-1, 1):
        k.box((0.018, H_Y1 - H_Y0 + 0.08, 0.012), (sx * (half + 0.03), (H_Y0 + H_Y1) / 2, fz + 0.056), "emit_cold_blue", 0.0)
    k.body()
    # ---- angular end caps: stepped rounded-square drums with ring grooves and a blue port
    for sx in (-1, 1):
        x0 = sx * (half + 0.3)
        for j, (dd, hh, w) in enumerate(((d - 0.1, h - 0.1, 0.18), (d - 0.3, h - 0.3, 0.16), (d - 0.55, h - 0.55, 0.12))):
            k.prism_x(rrect_contour(dd, hh, 0.22 - 0.05 * j, yc)[1:], w, x0 + sx * (0.09 + 0.17 * j), "painted_metal", bevel=0.01)
        for j in range(3):
            k.prism_x(rrect_contour(d - 0.18 - 0.2 * j, h - 0.18 - 0.2 * j, 0.2, yc)[1:], 0.02, x0 + sx * (0.19 + 0.17 * j), "emit_cold_blue" if j == 1 else "steel_bare", bevel=0.0)
        port(k, x0 + sx * 0.52, yc, sx, 0.3, "emit_cold_blue", "glass_blue")
    end = helix(k, half + 0.32, half + 0.62, 1.0, yc, 0.0, 2.0, 0.04, "rubber_black")
    k.tube([end, (end[0] + 0.05, end[1] - 0.3, end[2] - 0.2), (end[0] + 0.08, 0.2, -0.95), (end[0] + 0.1, 0.05, -1.1)], 0.04, "rubber_black", 10)
    # ---- roof modules: three sealed blocks with vents and blue windows
    top = yc + h / 2
    for i, (x, w) in enumerate(((-0.95, 0.7), (0.0, 0.9), (0.95, 0.7))):
        k.box((w, 0.22, 0.9), (x, top + 0.11, -0.2), "painted_metal", 0.02)
        k.box((w - 0.1, 0.04, 0.8), (x, top + 0.24, -0.2), "plastic_panel", 0.01)
        for j in range(4):
            k.box((w - 0.2, 0.012, 0.03), (x, top + 0.262, -0.45 + j * 0.08), "rubber_black", 0.0)
        k.box((w * 0.5, 0.06, 0.02), (x, top + 0.12, 0.255), "emit_cold_blue", 0.0)
    k.box((0.5, 0.2, 0.4), (1.5, top + 0.1, 0.4), "plastic_panel", 0.02)
    k.tube([(1.5, top + 0.2, 0.2), (1.5, top + 0.3, 0.0), (1.3, top + 0.28, -0.4), (1.25, top - 0.05, -0.85)], 0.04, "rubber_black", 10)
    # roof seams and edge rails, cable bundles from the modules into the end caps
    for z in (-d / 2 + 0.2, d / 2 - 0.2):
        k.box((H_L + 0.5, 0.05, 0.06), (0, top + 0.02, z), "steel_bare", 0.008)
    for x in (-1.4, -0.5, 0.5, 1.4):
        k.box((0.04, 0.02, d - 0.6), (x, top + 0.005, -0.1), "rubber_black", 0.0)
    for sx in (-1, 1):
        for zz in (-0.45, -0.25):
            k.tube([(sx * 1.2, top + 0.15, zz), (sx * 1.5, top + 0.2, zz), (sx * 1.75, top + 0.05, zz), (sx * 1.85, top - 0.25, zz)], 0.03, "rubber_black", 8)
    # anomaly: shards hanging in the air around the +X port, slowly drifting (animated by the game, group Shards)
    k.group("Shards", pivot=(half + 0.9, yc, 0.4))
    for i in range(9):
        s_ = g.uniform(0.05, 0.12)
        a = g.uniform(0, 2 * math.pi)
        k.box((s_, s_ * g.uniform(1.0, 2.2), s_), (half + 0.75 + g.uniform(0.0, 0.25), yc + 0.6 * math.sin(a), 0.6 * math.cos(a) + 0.3),
              "crystal_core", 0.0, rot=(g.uniform(0, 90), g.uniform(0, 90), g.uniform(0, 90)))
    k.body()
    # rear service cabinet (the prototype's diagnostics)
    k.box((2.2, 1.2, 0.4), (0, 0.85, -d / 2 - 0.22), "painted_metal", 0.02)
    for i in range(6):
        k.box((1.8, 0.015, 0.03), (0, 0.5 + i * 0.12, -d / 2 - 0.43), "rubber_black", 0.0)
    for x in (-0.6, 0.0, 0.6):
        k.tube([(x, 1.4, -d / 2 - 0.2), (x, 1.6, -d / 2 - 0.1), (x, 1.75, -d / 2 + 0.05)], 0.035, "rubber_black", 8)
    # ---- console
    cz = d / 2 + 0.04
    tilt = 14.0
    k.box((1.5, 0.3, 0.26), (0, 0.62, cz + 0.04), "painted_metal", 0.015, rot=(-tilt, 0, 0))
    def face(x, dy):
        a = math.radians(tilt)
        return (x, 0.62 + 0.13 * math.sin(a) + dy * math.cos(a), cz + 0.04 + 0.13 * math.cos(a) - dy * math.sin(a))
    k.group("Screen", pivot=face(0, 0.0))
    k.decal(face(0, 0.0), (0.52, 0.26), "capsule_screens", uv("capsule_screens", "module_3"), tilt=-tilt)
    k.body()
    for sx in (-1, 1):
        k.box((0.12, 0.12, 0.04), face(sx * 0.52, 0.0), "plastic_panel", 0.01, rot=(-tilt, 0, 0))
        k.box((0.07, 0.07, 0.03), face(sx * 0.52, 0.0), "emit_cold_blue", 0.0, rot=(-tilt, 0, 0))
    k.decal((half + 0.15, yc + 0.2, d / 2), (0.26, 0.13), "signs_ru", uv("signs_ru", "module_3"))
    k.decal((-half + 0.4, H_Y0 - 0.04, fz + 0.055), (0.36, 0.08), "panel_labels", uv("panel_labels", "КАПСУЛА"))
