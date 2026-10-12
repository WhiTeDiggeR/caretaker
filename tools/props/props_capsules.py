"""Prisoner sleep capsules v2 (#162), after the concept sheets of the capsules (object No. 3 and No. 4).

One serial architecture for every prisoner (canon: standardised modules adapted per prisoner, docs/world/03-complex.md),
built by the same hands as the staff capsule (staff_pod): the same painted metal, rounded-rectangle canopy with frame
hoops, the "КАПСУЛА" plate, hazard stripes and hoses that end in fittings.
  - a horizontal rounded hull; its front is a bulkhead with a large stadium window in a heavy frame;
  - round end drums with a stepped port that shows the series emblem;
  - a console under the window: sleep monitor, emblem tile, vent, status lights;
  - roof modules with light strips; hoses between them and the drums;
  - every hose ends in a fitting: front hoses run into junction boxes on the plinth, rear hoses into floor connector
    boxes whose flanges at the back edge (`ROOM_LINKS`) are where a room connects its own cables and pipes.
The sleeper is NOT part of the capsule: `sleeper_herobrine` / `sleeper_bowser` are separate props placed at the
capsule's `SOCKET` (objects/containment/prisoner_capsule_*.tscn), so a sleeper can be replaced on its own.
Units: metres, length along X, floor at y = 0, front +Z. Movable/switchable nodes: Glass, Screen, Port, Emit_*.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

from propkit import Kit
from props_start import uv
from registry import prop


# ============================================================================ geometry helpers
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
    contour runs from the opening top over the roof, back and floor to the opening bottom, the inner one returns."""
    assert yc - h / 2 + r <= y0 < y1 <= yc + h / 2 - r, "opening must sit on the flat front side"
    outer = [(d / 2, y1)] + rrect_contour(d, h, r, yc, n)[1:] + [(d / 2, y0)]
    di, hi, ri = d - 2 * t, h - 2 * t, max(r - t, 0.02)
    inner = [(di / 2, y1)] + rrect_contour(di, hi, ri, yc, n)[1:] + [(di / 2, y0)]
    return _dedup(outer + list(reversed(inner)))


def _dedup(poly):
    out = []
    for p in poly:
        if not out or abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6:
            out.append(p)
    return out


def stadium(w, h, r, cy, n=8):
    """Rounded rectangle in the (x, y) plane centred on (0, cy), counter-clockwise from the middle of the +x side."""
    return rrect_contour(w, h, r, cy, n)


def ring_plate(ow, oy0, oy1, inner, cy):
    """A rectangle (x in +-ow/2, y in oy0..oy1) with the hole `inner` (a contour that starts on the +x side at cy),
    joined by a zero-width slit so it extrudes as one polygon."""
    outer = [(ow / 2, cy), (ow / 2, oy1), (-ow / 2, oy1), (-ow / 2, oy0), (ow / 2, oy0), (ow / 2, cy)]
    return _dedup(outer + list(reversed(inner + [inner[0]])))


def hose(k: Kit, pts, r, m="rubber_black", collar=True):
    """A hose with steel fittings at both ends (the staff capsule's hoses, made heavier)."""
    k.tube(pts, r, m, 10)
    if collar:
        for a, b in ((pts[0], pts[1]), (pts[-1], pts[-2])):
            d = [b[i] - a[i] for i in range(3)]
            ln = math.sqrt(sum(c * c for c in d)) or 1.0
            e = [a[i] + d[i] / ln * 0.07 for i in range(3)]
            k.tube([a, e], r * 1.35, "steel_bare", 12)


def light_slot(k: Kit, c, w, h, axis, emit, depth=0.07):
    """A bolted housing with a glowing slot (the light pods of the concept sheets). axis = facing direction."""
    if axis == "z":
        k.box((w + 0.08, h + 0.08, depth), c, "painted_metal", 0.012)
        k.box((w, h, 0.01), (c[0], c[1], c[2] + depth / 2 + 0.003), emit, 0.0)
    elif axis == "-z":
        k.box((w + 0.08, h + 0.08, depth), c, "painted_metal", 0.012)
        k.box((w, h, 0.01), (c[0], c[1], c[2] - depth / 2 - 0.003), emit, 0.0)
    elif axis == "x+":
        k.box((depth, h + 0.08, w + 0.08), c, "painted_metal", 0.012)
        k.box((0.01, h, w), (c[0] + depth / 2 + 0.003, c[1], c[2]), emit, 0.0)
    else:
        k.box((depth, h + 0.08, w + 0.08), c, "painted_metal", 0.012)
        k.box((0.01, h, w), (c[0] - depth / 2 - 0.003, c[1], c[2]), emit, 0.0)


# ============================================================================ the serial capsule
@dataclass(frozen=True)
class Capsule:
    obj: str            # object number ("3", "4"): screen, emblem and module sign
    d: float            # hull depth (z)
    h: float            # hull height
    r: float            # hull corner radius
    yc: float           # hull axis height
    win_w: float        # window opening (inner) width
    win_y0: float       # window bottom
    win_y1: float       # window top
    win_r: float        # window corner radius
    length: float       # middle hull (window section) length
    drum_r: float       # end drum radius
    emit: str           # accent light material
    haze: str           # interior back-light material
    glass: str          # window glass material
    accent: str         # painted accent parts (bands, collars)

    @property
    def socket(self):
        """Where the sleeper prop's origin goes (centre of the window, on the hull axis plane z = 0)."""
        return (0.0, round((self.win_y0 + self.win_y1) / 2, 3), 0.0)

    @property
    def drum_x(self):
        return self.length / 2 + 0.12          # inner face of a drum (after the collar band)


HEROBRINE = Capsule("3", d=2.1, h=2.3, r=0.38, yc=1.7, win_w=3.0, win_y0=1.0, win_y1=2.4, win_r=0.42, length=3.5,
                    drum_r=1.28, emit="emit_cold_blue", haze="emit_haze_blue", glass="glass_blue", accent="painted_metal")
BOWSER = Capsule("4", d=2.4, h=2.7, r=0.45, yc=1.9, win_w=3.3, win_y0=1.08, win_y1=2.72, win_r=0.5, length=3.8,
                 drum_r=1.48, emit="emit_led_green", haze="emit_haze_green", glass="glass_green", accent="painted_metal_green")
DRUM_LEN, DISC_LEN, PORT_LEN = 0.5, 0.1, 0.06


def plinth_size(c: Capsule):
    x = c.drum_x + DRUM_LEN + 0.08
    return 2 * x, (-c.d / 2 - 0.15, c.d / 2 + 0.3)                         # length, (z back, z front)


def room_links(c: Capsule):
    """Flange centres (x, y, z) at the back edge where the room's own cables and pipes connect."""
    zb = plinth_size(c)[1][0]
    return [(sx * 0.9, 0.14, zb - 0.27) for sx in (-1, 1)]


def build_capsule(k: Kit, c: Capsule):
    d, h, r, yc = c.d, c.h, c.r, c.yc
    half = c.length / 2
    top, bottom = yc + h / 2, yc - h / 2
    flat0, flat1 = yc - h / 2 + r, yc + h / 2 - r                           # flat part of the front side
    fz = d / 2                                                              # hull front plane
    t = 0.09
    pl_len, (zb, zf) = plinth_size(c)
    xd = c.drum_x
    R = c.drum_r

    # ---- plinth with a diamond-plate deck, drum cradles and hull saddles
    k.box((pl_len, 0.22, zf - zb), (0, 0.11, (zf + zb) / 2), "painted_metal", 0.012)
    k.box((pl_len - 0.1, 0.03, zf - zb - 0.05), (0, 0.235, (zf + zb) / 2 - 0.0), "diamond_plate", 0.004)
    deck = 0.25
    for sx in (-1, 1):
        cz = min(0.95, R * 0.75)
        prof = [(cz, deck)]
        for i in range(17):
            z = cz - 2 * cz * i / 16
            prof.append((z, yc - math.sqrt((R + 0.01) ** 2 - z * z)))
        prof.append((-cz, deck))
        k.prism_x(list(reversed(prof)), 0.42, sx * (xd + DRUM_LEN / 2), "painted_metal", bevel=0.01)
        for sz in (-1, 1):
            k.hex_bolt((sx * (xd + DRUM_LEN / 2) + 0.12, deck + 0.05, sz * (cz + 0.002)), 0.02, 0.02, "z")
        k.box((0.4, bottom - deck, d - 2 * r), (sx * half * 0.55, (bottom + deck) / 2, 0), "painted_metal", 0.01)
    k.decal((0, 0.11, zf), (pl_len - 0.4, 0.12), "hazard_stripes", uv("hazard_stripes", "yellow_black"))

    # ---- hull: window section with the opening, closed by collar bands; interior
    y0s, y1s = max(flat0, c.win_y0 - 0.05), min(flat1, c.win_y1 + 0.05)
    k.prism_x(c_profile(d, h, r, yc, t, y0s, y1s), c.length, 0.0, "painted_metal", bevel=0.0)
    for sx in (-1, 1):
        k.prism_x(rrect_contour(d + 0.08, h + 0.08, r + 0.04, yc)[1:], 0.24, sx * (half + 0.0), c.accent, bevel=0.012)
    # dark interior: a black liner on the back wall carries a framed glow panel, the backdrop the sleeper is seen
    # against; the floor is black rubber with light lines along the back, so the figure stays the brightest thing
    back_z, wy = -d / 2 + t, (c.win_y0 + c.win_y1) / 2
    k.box((c.length - 0.3, h - 2 * r, 0.03), (0, yc, back_z + 0.015), "rubber_black", 0.0)  # flat part of the back wall
    pw, ph = c.win_w - 0.15, c.win_y1 - c.win_y0 - 0.06                # a touch inside the window outline
    k.prism(stadium(pw, ph, min(c.win_r, ph / 2), wy), 0.02, (0, 0, back_z + 0.04), c.haze, "z", bevel=0.0)
    edge = stadium(pw + 0.04, ph + 0.04, min(c.win_r, ph / 2) + 0.02, wy, n=10)
    k.tube([(x, y, back_z + 0.05) for x, y in edge + [edge[0], edge[1]]], 0.016, "steel_bare", 8, caps=False)
    floor_y = c.win_y0 - 0.06
    k.box((c.length - 0.3, floor_y - (bottom + t), d - 2 * t - 0.1), (0, (floor_y + bottom + t) / 2, 0), "painted_metal", 0.01)
    k.box((c.length - 0.5, 0.012, d - 2 * t - 0.3), (0, floor_y + 0.006, 0), "rubber_black", 0.0)
    k.group("Emit_Interior", pivot=(0, floor_y, back_z + 0.1))
    for lz in (back_z + 0.1, back_z + 0.22):                              # light lines in the floor along the back
        k.box((c.length - 0.7, 0.008, 0.025), (0, floor_y + 0.016, lz), c.emit, 0.0)
    k.body()

    # ---- bulkhead with the stadium window, glass, frame ring and its bolted lugs
    inner = stadium(c.win_w, c.win_y1 - c.win_y0, c.win_r, (c.win_y0 + c.win_y1) / 2)
    k.prism(ring_plate(c.length, flat0, flat1, inner, (c.win_y0 + c.win_y1) / 2), 0.06, (0, 0, fz + 0.03), "painted_metal", "z", bevel=0.0)
    k.group("Glass", pivot=(0, (c.win_y0 + c.win_y1) / 2, fz))
    k.prism(stadium(c.win_w + 0.06, c.win_y1 - c.win_y0 + 0.06, c.win_r + 0.03, (c.win_y0 + c.win_y1) / 2), 0.03,
            (0, 0, fz - 0.025), c.glass, "z", bevel=0.0)
    k.body()
    ring = stadium(c.win_w + 0.12, c.win_y1 - c.win_y0 + 0.12, c.win_r + 0.06, (c.win_y0 + c.win_y1) / 2, n=10)
    k.tube([(x, y, fz + 0.1) for x, y in ring + [ring[0], ring[1]]], 0.045, "painted_metal", 10, caps=False)
    lugs = [(-0.5 * c.win_w / 2, c.win_y1 + 0.06), (0.5 * c.win_w / 2, c.win_y1 + 0.06), (0, c.win_y1 + 0.06),
            (-0.5 * c.win_w / 2, c.win_y0 - 0.06), (0.5 * c.win_w / 2, c.win_y0 - 0.06), (0, c.win_y0 - 0.06),
            (-c.win_w / 2 - 0.06, (c.win_y0 + c.win_y1) / 2), (c.win_w / 2 + 0.06, (c.win_y0 + c.win_y1) / 2)]
    for x, y in lugs:
        vertical = abs(x) > c.win_w / 2
        k.box((0.1, 0.2, 0.08) if vertical else (0.2, 0.1, 0.08), (x, y, fz + 0.13), "steel_bare", 0.012)
        for o in (-0.055, 0.055):
            k.hex_bolt((x, y + o, fz + 0.175) if vertical else (x + o, y, fz + 0.175), 0.015, 0.012)
    for sx in (-1, 1):                                                      # light pods beside the window
        light_slot(k, (sx * (c.win_w / 2 + 0.06 + 0.14), (c.win_y0 + c.win_y1) / 2, fz + 0.095), 0.05, 0.42, "z", c.emit)

    # ---- end drums: two rings, a stepped disc and the emblem port (group Port)
    for sx in (-1, 1):
        x0 = sx * (xd + DRUM_LEN / 2)
        k.cyl(R, DRUM_LEN, (x0, yc, 0), "x", "painted_metal", 56, cap_bevel=0.03)
        for o in (-0.18, 0.18):
            k.torus(R + 0.005, 0.03, (x0 + o, yc, 0), "x", "steel_bare", 56, 8)
        xe = sx * (xd + DRUM_LEN)
        k.cyl(R * 0.78, DISC_LEN, (xe + sx * DISC_LEN / 2, yc, 0), "x", c.accent, 48, cap_bevel=0.02)
        xp = xe + sx * DISC_LEN
        for i in range(12):
            a = 2 * math.pi * (i + 0.5) / 12
            k.hex_bolt((xp + sx * 0.005, yc + R * 0.7 * math.cos(a), R * 0.7 * math.sin(a)), 0.022, 0.02, "x")
        k.cyl(R * 0.36, PORT_LEN, (xp + sx * PORT_LEN / 2, yc, 0), "x", "steel_bare", 40, cap_bevel=0.01)
        for a in range(4):                                                  # light ticks N/E/S/W around the port
            ang = math.radians(90 * a)
            py, pz = yc + R * 0.5 * math.cos(ang), R * 0.5 * math.sin(ang)
            k.box((0.02, 0.05 if a % 2 == 0 else 0.12, 0.12 if a % 2 == 0 else 0.05), (xp + sx * 0.01, py, pz), c.emit, 0.0)
        for sz in (-1, 1):                                                  # clamp blocks on the disc rim
            k.box((0.12, 0.22, 0.16), (xp + sx * 0.04, yc, sz * R * 0.66), "steel_bare", 0.015)
        k.group("Port", pivot=(xp + sx * PORT_LEN, yc, 0))
        k.decal((xp + sx * PORT_LEN, yc, 0), (R * 0.46, R * 0.46), "capsule_screens", uv("capsule_screens", f"emblem_{c.obj}"),
                normal="+x" if sx > 0 else "-x", offset=0.003)
        k.body()
        light_slot(k, (x0, yc, R + 0.02), 0.05, 0.42, "z", c.emit)          # pod on the drum front
        light_slot(k, (x0, yc, -R - 0.02), 0.05, 0.42, "-z", c.emit)        # and on its back

    # ---- staff-capsule frame hoops over the roof (front frame top -> roof -> back, down to the saddles)
    hoop = rrect_contour(d + 0.07, h + 0.07, r + 0.035, yc, 10)
    start = next(i for i, (z, y) in enumerate(hoop) if y >= flat1 + 0.02)
    stop = next(i for i, (z, y) in enumerate(hoop) if i > start and z < 0 and y < bottom + 0.4)
    arc = hoop[start:stop]                                                  # front top, roof, back: no wrap to the front
    for x in (-half * 0.36, half * 0.36):
        k.tube([(x, y, z) for z, y in arc], 0.035, "painted_metal", 8)

    # ---- roof: central module with a light strip, two reservoir modules with handles, hoses to the drums
    mz = -0.12
    k.box((0.9, 0.3, 0.9), (0, top + 0.13, mz), "painted_metal", 0.02)
    light_slot(k, (0, top + 0.16, mz + 0.47), 0.45, 0.05, "z", c.emit, 0.04)
    for sx in (-1, 1):
        mx = sx * half * 0.7
        k.box((0.6, 0.2, 0.7), (mx, top + 0.08, mz), "painted_metal", 0.015)
        k.box((0.5, 0.04, 0.6), (mx, top + 0.2, mz), c.accent, 0.01)
        k.tube([(mx - 0.15, top + 0.22, mz + 0.2), (mx - 0.15, top + 0.32, mz + 0.2), (mx + 0.15, top + 0.32, mz + 0.2),
                (mx + 0.15, top + 0.22, mz + 0.2)], 0.018, "steel_bare", 8)           # handle
        k.decal((mx, top + 0.08, mz + 0.353), (0.36, 0.09), "panel_labels", uv("panel_labels", "КАПСУЛА"))
        hz = -0.32
        dy = math.sqrt(R * R - hz * hz)
        hx = sx * (xd + DRUM_LEN / 2)
        hose(k, [(sx * 0.45, top + 0.12, hz), (sx * 0.6, top + 0.12, hz), (sx * 0.75, top + 0.36, hz),
                 (hx - sx * 0.35, top + 0.36, hz), (hx, yc + dy + 0.2, hz), (hx, yc + dy - 0.02, hz)], 0.05)

    # ---- console under the window: sleep monitor, emblem tile, vent, status lights, labels
    cz0, cz1, cy0, cy1 = fz - 0.3, fz + 0.25, deck, flat0
    slope = 0.18
    prof = [(cz0, cy0), (cz1, cy0), (cz1, cy1 - slope), (cz1 - slope, cy1), (cz0, cy1)]
    cw = c.win_w + 0.2
    k.prism_x(prof, cw, 0.0, "painted_metal", bevel=0.012)
    face_h = cy1 - slope - cy0
    sy = cy0 + face_h / 2
    sh = min(0.46, face_h - 0.08)
    k.box((sh * 2 + 0.1, sh + 0.1, 0.03), (0, sy, cz1 + 0.015), "steel_bare", 0.008)
    k.group("Screen", pivot=(0, sy, cz1 + 0.03))
    k.decal((0, sy, cz1 + 0.03), (sh * 2, sh), "capsule_screens", uv("capsule_screens", f"module_{c.obj}"), offset=0.003)
    k.body()
    ex = sh + 0.45
    k.box((0.38, 0.38, 0.03), (ex, sy, cz1 + 0.015), "steel_bare", 0.008)
    k.decal((ex, sy, cz1 + 0.03), (0.32, 0.32), "capsule_screens", uv("capsule_screens", f"emblem_{c.obj}"), offset=0.003)
    k.box((0.38, 0.3, 0.03), (-ex, sy, cz1 + 0.015), "steel_bare", 0.008)  # vent grille
    for i in range(5):
        k.box((0.32, 0.018, 0.02), (-ex, sy - 0.1 + i * 0.05, cz1 + 0.035), "rubber_black", 0.0)
    for sx in (-1, 1):
        light_slot(k, (sx * (cw / 2 - 0.17), sy, cz1 + 0.035), 0.16, 0.05, "z", c.emit, 0.04)
        for i, m in enumerate(("emit_led_green", "emit_led_amber", "emit_led_red")):
            k.cyl(0.014, 0.02, (sx * (ex + 0.3), sy + 0.08 - i * 0.08, cz1 + 0.01), "z", m, 10)
    a = math.radians(45.0)
    on_slope = (cz1 - slope / 2, cy1 - slope / 2)
    k.decal((-ex, on_slope[1], on_slope[0]), (0.4, 0.1), "panel_labels", uv("panel_labels", "КАПСУЛА"), normal="+y", tilt=45.0, offset=0.004)
    k.decal((ex, on_slope[1], on_slope[0]), (0.24, 0.12), "signs_ru", uv("signs_ru", f"module_{c.obj}"), normal="+y", tilt=45.0, offset=0.004)
    del a

    # ---- front hoses: from the drum fronts down into junction boxes on the plinth corners
    for sx in (-1, 1):
        bx = sx * (xd + DRUM_LEN / 2)
        bz = zf - 0.2
        k.box((0.34, 0.36, 0.3), (bx, deck + 0.18, bz), "painted_metal", 0.015)
        k.box((0.24, 0.05, 0.2), (bx, deck + 0.385, bz), "steel_bare", 0.01)
        k.decal((bx, deck + 0.18, bz + 0.15), (0.2, 0.1), "signs_ru", uv("signs_ru", "high_voltage"), offset=0.003)
        ang = math.radians(28)
        hy, hz = yc + R * math.sin(ang), R * math.cos(ang)
        n = (math.sin(ang), math.cos(ang))
        hose(k, [(bx, hy - 0.02 * n[0], hz - 0.02 * n[1]), (bx, hy + 0.2 * n[0], hz + 0.2 * n[1]),
                 (bx, hy + 0.05, zf + 0.05), (bx, deck + 0.75, zf + 0.05), (bx, deck + 0.52, bz), (bx, deck + 0.41, bz)], 0.055)

    # ---- back: round service hatch with the emblem, rear hoses into the floor connector boxes (room links)
    k.cyl(0.62, 0.08, (0, yc, -fz - 0.04), "z", c.accent, 48, cap_bevel=0.012)
    for i in range(16):
        aa = 2 * math.pi * i / 16
        k.hex_bolt((0.55 * math.cos(aa), yc + 0.55 * math.sin(aa), -fz - 0.09), 0.018, 0.02)
    k.cyl(0.3, 0.05, (0, yc, -fz - 0.105), "z", "steel_bare", 32, cap_bevel=0.008)
    k.decal((0, yc, -fz - 0.13), (0.4, 0.4), "capsule_screens", uv("capsule_screens", f"emblem_{c.obj}"), normal="-z", offset=0.003)
    k.decal((-half * 0.6, yc + 0.3, -fz), (0.4, 0.2), "signs_ru", uv("signs_ru", "danger"), normal="-z", offset=0.004)
    for sx in (-1, 1):
        light_slot(k, (sx * 0.85, yc, -fz - 0.03), 0.05, 0.36, "-z", c.emit)
    for (lx, ly, lz) in room_links(c):
        k.box((0.34, 0.28, 0.3), (lx, ly, lz + 0.12), "painted_metal", 0.015)              # floor connector box
        k.cyl(0.12, 0.05, (lx, ly, lz - 0.05), "z", "steel_bare", 20, cap_bevel=0.006)     # room-link flange
        for i in range(6):
            aa = 2 * math.pi * i / 6
            k.hex_bolt((lx + 0.095 * math.cos(aa), ly + 0.095 * math.sin(aa), lz - 0.078), 0.012, 0.01)
        k.cyl(0.07, 0.012, (lx, ly, lz - 0.08), "z", "rubber_black", 16)                  # open socket
        yb = yc - 0.35
        hose(k, [(lx * 0.95, yb, -fz + 0.02), (lx * 0.95, yb, -fz - 0.18), (lx, yb - 0.25, -fz - 0.36),
                 (lx, ly + 0.45, lz + 0.12), (lx, ly + 0.17, lz + 0.12)], 0.06)


@prop("capsule_herobrine", "P-106s", (5.14, 3.26, 3.01), "floor", 40000, tolerance=0.05, center_z=False,
      views=[((1.1, 0.45, 1.5), (0, 0, 0)), ((-1.3, 0.7, 1.0), (0, 0, 0)), ((0.6, 0.6, -1.6), (0, 0, 0))])
def capsule_herobrine(k: Kit):
    build_capsule(k, HEROBRINE)


@prop("capsule_bowser", "P-106s", (5.44, 3.66, 3.31), "floor", 40000, tolerance=0.05, center_z=False,
      views=[((1.1, 0.45, 1.5), (0, 0, 0)), ((-1.3, 0.7, 1.0), (0, 0, 0)), ((0.6, 0.6, -1.6), (0, 0, 0))])
def capsule_bowser(k: Kit):
    build_capsule(k, BOWSER)


# ============================================================================ sleepers (separate props)
HB_PX = 0.07                    # one skin texel in metres: the figure is 32 texels = 2.24 m long


def _skin_quad(k: Kit, c, U, V, rect, xf):
    """A quad c +- U +- V (U x V = outward normal) textured with an atlas rect of sleeper_skins, mapped by xf."""
    from mathutils import Vector
    import bmesh
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    vs = []
    for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        p = [c[i] + su * U[i] + sv * V[i] for i in range(3)]
        vs.append(bm.verts.new(Vector(xf(p))))
    f = bm.faces.new(vs)
    u0, v0, u1, v1 = rect
    for loop, t in zip(f.loops, ((u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0))):
        loop[uvl].uv = t
    k._commit(bm, "sleeper_skins", uv="given")


def _skin_box(k: Kit, lo, hi, faces, xf):
    """A blocky limb from texel corner lo to hi (standing frame: x = figure's left, y up, z front)."""
    p = HB_PX
    cx, cy, cz = ((lo[i] + hi[i]) / 2 * p for i in range(3))
    hx, hy, hz = ((hi[i] - lo[i]) / 2 * p for i in range(3))
    sk = {n: uv("sleeper_skins", n) for n in set(faces.values())}
    fr = lambda n: sk[n]  # noqa: E731
    flip = lambda r: (r[2], r[1], r[0], r[3])  # noqa: E731
    _skin_quad(k, (cx, cy, cz + hz), (hx, 0, 0), (0, hy, 0), fr(faces["front"]), xf)
    _skin_quad(k, (cx, cy, cz - hz), (-hx, 0, 0), (0, hy, 0), fr(faces["back"]), xf)
    _skin_quad(k, (cx - hx, cy, cz), (0, 0, hz), (0, hy, 0), fr(faces["side"]), xf)
    _skin_quad(k, (cx + hx, cy, cz), (0, 0, -hz), (0, hy, 0), flip(fr(faces["side"])), xf)
    _skin_quad(k, (cx, cy + hy, cz), (hx, 0, 0), (0, 0, -hz), fr(faces["top"]), xf)
    _skin_quad(k, (cx, cy - hy, cz), (hx, 0, 0), (0, 0, hz), fr(faces["bottom"]), xf)


@prop("sleeper_herobrine", "P-106s", (2.24, 1.12, 0.57), "free", 2000, tolerance=0.03,
      views=[((0.0, 0.0, 1.0), (0, 0, 0)), ((0.6, 0.35, 0.9), (0, 0, 0)), ((-0.8, 0.3, 0.7), (0, 0, 0))])
def sleeper_herobrine(k: Kit):
    """Object No. 3 asleep: the blocky figure (8-texel head, 32 texels tall) floating on its side with the face to the
    window, head towards +X, glowing white eyes. Origin = figure centre = the capsule's SOCKET."""
    def xf(p):  # standing frame -> lying: up becomes +X, the figure's left becomes -Y
        return (p[1] - 16 * HB_PX, -p[0], p[2])

    head = {"front": "head_front", "back": "head_back", "side": "head_side", "top": "head_top", "bottom": "head_bottom"}
    body = {"front": "body_front", "back": "body_back", "side": "body_side", "top": "body_end", "bottom": "body_end"}
    arm = {"front": "arm_side", "back": "arm_side", "side": "arm_side", "top": "arm_top", "bottom": "arm_end"}
    leg = {"front": "leg_side", "back": "leg_side", "side": "leg_side", "top": "leg_top", "bottom": "leg_end"}
    _skin_box(k, (-4, 24, -4), (4, 32, 4), head, xf)
    _skin_box(k, (-4, 12, -2), (4, 24, 2), body, xf)
    for sx in (-1, 1):
        _skin_box(k, (4 if sx > 0 else -8, 12, -2), (8 if sx > 0 else -4, 24, 2), arm, xf)
        _skin_box(k, (0 if sx > 0 else -4, 0, -2), (4 if sx > 0 else 0, 12, 2), leg, xf)
    # the eyes glow: thin emissive plates over the white eye texels (row 4 of the face, columns 1-2 and 5-6)
    k.group("Emit_Eyes", pivot=xf((0, 27.5 * HB_PX, 4 * HB_PX)))
    for ex in (-2, 2):
        c = xf((ex * HB_PX, 27.5 * HB_PX, 4 * HB_PX + 0.004))
        k.box((HB_PX * 0.92, HB_PX * 1.84, 0.004), c, "emit_eye_white", 0.0)
    k.body()


def _limb(k: Kit, pts, radii, m, seg=14):
    """A tapered organic limb: a tube through `pts` whose radius follows `radii`, capped by spheres at both ends."""
    k.tube(pts, list(radii), m, seg)
    k.sphere(radii[0], pts[0], m, seg)
    k.sphere(radii[-1], pts[-1], m, max(8, seg // 2))


def _spike(k: Kit, base, direction, length, r, m="horn_bone"):
    ln = math.sqrt(sum(c * c for c in direction))
    tip = tuple(base[i] + direction[i] / ln * length for i in range(3))
    mid = tuple(base[i] + direction[i] / ln * length * 0.45 for i in range(3))
    k.tube([base, mid, tip], [r, r * 0.6, 0.004], m, 12)


def _on_ellipsoid(c, rad, az, el):
    """Point and outward normal on an ellipsoid; az around Y from +X towards -Z, el from the equator up."""
    n = (math.cos(el) * math.cos(az), math.sin(el), -math.cos(el) * math.sin(az))
    p = tuple(c[i] + rad[i] * n[i] for i in range(3))
    nn = tuple(n[i] / rad[i] for i in range(3))
    return p, nn


@prop("sleeper_bowser", "P-106s", (3.11, 1.61, 2.11), "free", 30000, tolerance=0.06,
      views=[((0.0, 0.1, 1.0), (0, 0, 0)), ((0.7, 0.4, 0.8), (0, 0, 0)), ((-0.8, 0.3, 0.6), (0, 0, 0))])
def sleeper_bowser(k: Kit):
    """Object No. 4 asleep: the spiked turtle-dragon lying on its belly, head on its forearms towards -X and turned to
    the window, spiked shell on its back, tail curled at +X. Built from tapered tubes and ellipsoids.
    Origin = the capsule's SOCKET (window centre); the lowest point rests on the capsule floor (y = -0.86)."""
    fl = -0.86                                                        # capsule floor relative to the socket
    # ---- body, belly, shell with its rim and spikes
    k.sphere(0.5, (0.15, fl + 0.5, 0.05), "skin_yellow", 28, scale=(1.85, 1.0, 1.25))
    k.sphere(0.4, (-0.05, fl + 0.46, 0.36), "belly_cream", 24, scale=(1.6, 0.95, 0.9))
    for i in range(5):                                                # belly plates
        x = -0.55 + i * 0.27
        k.tube([(x, fl + 0.2, 0.62 - abs(x + 0.05) * 0.18), (x - 0.02, fl + 0.5, 0.72 - abs(x + 0.05) * 0.2),
                (x - 0.03, fl + 0.78, 0.6 - abs(x + 0.05) * 0.18)], 0.016, "skin_yellow", 6)
    sc, sr = (0.2, fl + 0.82, -0.22), (0.98, 0.56, 0.7)
    k.sphere(1.0, sc, "shell_green", 32, scale=sr)
    rim = [(sc[0] + (sr[0] + 0.03) * math.cos(t), sc[1] - 0.2 + 0.06 * math.sin(2 * t), sc[2] + (sr[2] + 0.03) * math.sin(t))
           for t in (2 * math.pi * i / 40 for i in range(41))]
    k.tube(rim, 0.075, "belly_cream", 10, caps=False)
    for el, azs in ((math.radians(30), (-60, -15, 30, 80, 125, 170, 215)), (math.radians(62), (0, 72, 144, 216, 288))):
        for az in azs:
            p, n = _on_ellipsoid(sc, sr, math.radians(az), el)
            if p[2] > 0.25:                                           # keep the spikes off the window side
                continue
            if el > 1.0:
                k.torus(0.1, 0.025, p, "y", "belly_cream", 16, 6)
            _spike(k, p, n, 0.26 if el < 1.0 else 0.3, 0.1)
    # ---- neck collar with spikes
    nc = (-0.72, fl + 0.6, 0.18)
    k.sphere(0.3, nc, "skin_yellow", 18, scale=(1.0, 1.0, 1.1))
    k.torus(0.31, 0.08, nc, "x", "collar_black", 32, 8)
    for i in range(8):
        a = 2 * math.pi * i / 8
        n = (0.0, math.cos(a), math.sin(a))
        b = (nc[0], nc[1] + 0.34 * n[1], nc[2] + 0.34 * n[2])
        _spike(k, b, n, 0.12, 0.04, "chrome_dull")
    # ---- head (large, as the character is drawn): cranium, snout with the big nose, jaw, closed eyes, brows, horns,
    # mane, fangs. Authored around hc at unit scale, then scaled by HS and pulled back from the glass.
    hc, HS = (-1.05, fl + 0.62, 0.3), 1.3
    shift = (0.0, 0.13, -0.12)

    def hp(x, y, z):
        return tuple(hc[i] + ((x, y, z)[i] - hc[i]) * HS + shift[i] for i in range(3))

    def hr(*r):
        return tuple(v * HS for v in r) if len(r) > 1 else r[0] * HS

    k.sphere(hr(0.3), hp(*hc), "skin_yellow", 26, scale=(1.0, 0.95, 1.0))
    k.sphere(hr(0.25), hp(-1.07, fl + 0.55, 0.6), "skin_yellow", 24, scale=(1.15, 0.85, 1.2))
    k.sphere(hr(0.13), hp(-1.07, fl + 0.64, 0.86), "skin_yellow", 18, scale=(1.3, 1.0, 0.9))       # nose
    for sx in (-1, 1):
        k.sphere(hr(0.025), hp(-1.07 + sx * 0.07, fl + 0.66, 0.97), "collar_black", 8)             # nostrils
    k.sphere(hr(0.22), hp(-1.06, fl + 0.36, 0.55), "belly_cream", 22, scale=(1.15, 0.6, 1.25))      # jaw
    k.tube([hp(-1.32, fl + 0.43, 0.55), hp(-1.2, fl + 0.44, 0.76), hp(-1.07, fl + 0.45, 0.84), hp(-0.94, fl + 0.44, 0.76),
            hp(-0.82, fl + 0.43, 0.55)], hr(0.012), "collar_black", 6)                              # mouth line
    for sx in (-1, 1):
        _spike(k, hp(-1.07 + sx * 0.16, fl + 0.46, 0.76), (0, -1, 0.15), hr(0.1), hr(0.03))         # fangs
        ex = -1.05 + sx * 0.17
        k.tube([hp(ex - 0.07, fl + 0.74, 0.52), hp(ex, fl + 0.72, 0.56), hp(ex + 0.07, fl + 0.74, 0.52)], hr(0.016), "collar_black", 6)
        _limb(k, [hp(ex - sx * 0.06, fl + 0.8, 0.5), hp(ex + sx * 0.05, fl + 0.85, 0.5), hp(ex + sx * 0.14, fl + 0.9, 0.44)],
              hr(0.05, 0.05, 0.03), "hair_red", 8)                                                 # brows
        _limb(k, [hp(hc[0] + sx * 0.2, fl + 0.82, 0.22), hp(hc[0] + sx * 0.36, fl + 0.98, 0.12), hp(hc[0] + sx * 0.44, fl + 1.16, -0.1)],
              hr(0.095, 0.065, 0.012), "horn_bone", 12)                                            # horns
    for i in range(6):                                                                              # flame mane
        x = hc[0] - 0.25 + i * 0.1
        _limb(k, [hp(x, fl + 0.8, 0.18), hp(x + 0.02, fl + 0.95 + 0.04 * (i % 2), -0.05), hp(x + 0.05, fl + 1.02 + 0.06 * (i % 3), -0.25)],
              hr(0.09, 0.07, 0.01), "hair_red", 10)
    # ---- arms: the head rests on them; spiked cuffs, clawed hands
    for sh, hand in (((-0.55, fl + 0.5, 0.48), (-0.82, fl + 0.18, 0.74)), ((0.25, fl + 0.45, 0.58), (0.05, fl + 0.17, 0.84))):
        el = ((sh[0] + hand[0]) / 2 + 0.06, fl + 0.3, (sh[2] + hand[2]) / 2)
        _limb(k, [sh, el, hand], (0.2, 0.16, 0.15), "skin_yellow", 16)
        cuff = tuple(el[i] * 0.4 + hand[i] * 0.6 for i in range(3))
        k.cyl(0.23, 0.16, cuff, "z", "collar_black", 24, rot=(-30, 0, 0), cap_bevel=0.02)
        for j in range(7):
            a = 2 * math.pi * j / 7
            n = (math.cos(a), math.sin(a) * 0.87, -math.sin(a) * 0.5)
            if n[1] < -0.4:                                           # no spikes into the floor
                continue
            _spike(k, tuple(cuff[i] + 0.22 * n[i] for i in range(3)), n, 0.12, 0.045, "chrome_dull")
        for j in (-1, 0, 1):
            _spike(k, (hand[0] + j * 0.08, hand[1] - 0.04, hand[2] + 0.1), (j * 0.2, -0.3, 1), 0.1, 0.035)  # claws
    # ---- legs: big thigh, foot with claws
    k.sphere(0.34, (0.85, fl + 0.36, 0.42), "skin_yellow", 22, scale=(1.0, 1.0, 1.05))
    k.sphere(0.2, (1.0, fl + 0.12, 0.68), "skin_yellow", 18, scale=(1.2, 0.6, 1.4))
    for j in (-1, 0, 1):
        _spike(k, (1.0 + j * 0.1, fl + 0.08, 0.92), (j * 0.2, -0.2, 1), 0.1, 0.04)
    # ---- tail curling out at +X with small spikes
    tail = [(0.95, fl + 0.45, -0.25), (1.2, fl + 0.3, -0.25), (1.38, fl + 0.18, -0.02), (1.36, fl + 0.12, 0.25), (1.2, fl + 0.1, 0.42)]
    _limb(k, tail, (0.2, 0.15, 0.1, 0.06, 0.02), "skin_yellow", 14)
    for p, n in ((tail[1], (0.3, 1, -0.3)), (tail[2], (0.5, 1, 0))):
        _spike(k, (p[0], p[1] + 0.12, p[2]), n, 0.1, 0.04)
