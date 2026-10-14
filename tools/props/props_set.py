"""Wave 1 props: large set pieces of the opening sequence (rubble, duct, fan unit, pods, chair, gate)."""
from __future__ import annotations

import math
import random

from mathutils import Vector

from propkit import Kit
from props_start import led, uv
from registry import prop


# ----------------------------------------------------------------------------- P-004
@prop("rubble_set", "P-004", (4.5, 2.5, 1.8), "floor", 7000, tolerance=0.12)
def rubble_set(k: Kit):
    """A collapse that blocks a 4.5 m passage: heap of concrete lumps, leaning slabs, rebar and a fallen beam."""
    g = random.Random(4)
    half, depth, top = 2.25, 0.9, 2.45

    def surface(x, z):
        return top * max(0.0, 1.0 - (abs(x) / half) ** 2.2) ** 0.8 * max(0.25, 1.0 - (abs(z) / depth) ** 2)

    # base ring of big blocks, then smaller lumps scattered over the heap surface
    for i in range(70):
        x, z = g.uniform(-half * 0.95, half * 0.95), g.uniform(-depth * 0.9, depth * 0.9)
        s = g.uniform(0.18, 0.55) * (1.0 + 0.5 * (1 - abs(x) / half))
        y = surface(x, z) * g.uniform(0.0, 0.95)
        k.chunk((x, max(y, s * 0.55), z), (s * g.uniform(0.8, 1.5), s * g.uniform(0.5, 0.9), s * g.uniform(0.7, 1.3)),
                seed=100 + i, rot=(g.uniform(-25, 25), g.uniform(0, 360), g.uniform(-25, 25)))
    # leaning slabs from the ceiling collapse
    for x, z, w, h, tilt, yaw in ((-0.7, 0.35, 1.5, 0.22, 38, 10), (0.55, -0.1, 1.3, 0.2, -32, -15), (1.4, 0.3, 1.0, 0.18, 55, 25)):
        k.box((w, h, 0.7), (x, surface(x, z) * 0.7 + 0.35, z), "concrete_rubble", 0.02, rot=(8, yaw, tilt))
    # fallen beam across the front
    k.box((3.0, 0.3, 0.3), (0.2, 0.42, 0.62), "concrete_rubble", 0.015, rot=(0, -8, 6))
    # rebar sticking out of the heap and slabs
    for i in range(10):
        x = g.uniform(-1.8, 1.8)
        z = g.uniform(-0.6, 0.7)
        y = surface(x, z) * 0.75
        ln = g.uniform(0.5, 1.1)
        d = Vector((g.uniform(-0.4, 0.4), 1.0, g.uniform(0.2, 0.7))).normalized()
        pts = [(x + d.x * ln * t / 6 + 0.04 * math.sin(t), y + d.y * ln * t / 6, z + d.z * ln * t / 6 + 0.03 * math.cos(t * 1.7)) for t in range(7)]
        k.tube(pts, 0.011, "rusted_steel", 6)
    k.box((0.5, 0.45, 0.45), (-1.9, 0.3, 0.45), "concrete_rubble", 0.03, rot=(0, 30, 10))
    lo, hi = k.bounds()
    k.rescale(4.5 / (hi.x - lo.x), 2.5 / (hi.y - lo.y), 1.8 / (hi.z - lo.z), centre_xz=True, ground=True)


# ----------------------------------------------------------------------------- P-005
@prop("fallen_duct", "P-005", (3.8, 1.6, 0.69), "free", 8000, tolerance=0.1)
def fallen_duct(k: Kit):
    """Ventilation duct torn off at one end: still strapped to the ceiling on the left, hanging low across the passage."""
    w, h, t = 0.6, 0.5, 0.012
    length = 3.4
    tilt = -18.0  # degrees about Z: the right end sags so that its lower edge hangs at ~1.25 m (crouch passage)

    def place(local):
        """Duct-local (x along the duct, y, z) -> world, tilted about a ceiling anchor at x = -1.7."""
        a = math.radians(tilt)
        x, y, z = local
        return (-1.7 + x * math.cos(a) - y * math.sin(a), 2.55 + x * math.sin(a) + y * math.cos(a), z)

    cx = length / 2
    for sy, sz, size in ((1, 0, (length, t, w)), (-1, 0, (length, t, w))):
        k.box(size, place((cx, sy * (h / 2 - t / 2), 0)), "duct_galvanized", 0.003, rot=(0, 0, tilt))
    for sz in (-1, 1):
        k.box((length, h, t), place((cx, 0, sz * (w / 2 - t / 2))), "duct_galvanized", 0.003, rot=(0, 0, tilt))
    # flanges every ~1.1 m and the torn lip at the free end
    for i, x in enumerate((0.0, 1.1, 2.2)):
        for sy in (-1, 1):
            k.box((0.05, 0.03, w + 0.06), place((x + 0.03, sy * (h / 2 + 0.01), 0)), "painted_metal", 0.003, rot=(0, 0, tilt))
        for sz in (-1, 1):
            k.box((0.05, h + 0.06, 0.03), place((x + 0.03, 0, sz * (w / 2 + 0.01))), "painted_metal", 0.003, rot=(0, 0, tilt))
    g = random.Random(9)
    for i in range(7):  # jagged torn tabs bent outwards
        a = (g.random() - 0.5) * 50
        k.box((0.18, 0.05 + g.random() * 0.08, 0.002), place((length + 0.04, -h / 2 + 0.07 + i * 0.07, w / 2 + 0.03)), "duct_galvanized", 0.0,
              rot=(a, 40 * (g.random() - 0.3), tilt))
    # straps from the ceiling
    for x in (0.25, 1.45):
        for sz in (-1, 1):
            top = place((x, h / 2 + 0.03, sz * (w / 2)))
            k.box((0.03, 2.85 - top[1], 0.004), (top[0], (top[1] + 2.85) / 2, top[2]), "rusted_steel", 0.0)
    k.box((0.7, 0.04, 0.5), (-1.7, 2.83, 0), "painted_metal", 0.006)                               # ceiling bracket


# ----------------------------------------------------------------------------- P-006
@prop("ventilation_unit", "P-006", (1.5, 1.5, 1.03), "floor", 9000, center_z=False)
def ventilation_unit(k: Kit):
    w, h, d = 1.5, 1.5, 0.85
    for x in (-0.6, 0.6):
        for z in (-0.3, 0.3):
            k.box((0.18, 0.12, 0.18), (x, 0.06, z), "painted_metal", 0.006)                      # feet
    k.box((w, 1.2, d), (0, 0.72, 0), "painted_metal", 0.014)                                    # housing
    # round intake on the front: dark flat disc, fan in front of it, shroud lips and a guard
    cy, front = 0.72, d / 2
    k.cyl(0.52, 0.012, (0, cy, front + 0.006), "z", "steel_bare", 36)                             # backing plate
    k.cyl(0.47, 0.012, (0, cy, front + 0.012), "z", "rubber_black", 36)                           # dark intake
    k.torus(0.5, 0.035, (0, cy, front + 0.03), "z", "steel_bare", 36, 8)                          # shroud lip
    k.torus(0.5, 0.02, (0, cy, front + 0.13), "z", "steel_bare", 36, 8)
    k.group("Fan", pivot=(0, cy, front + 0.07))
    k.cyl(0.09, 0.08, (0, cy, front + 0.07), "z", "steel_bare", 18, cap_bevel=0.006)
    for i in range(7):
        a_ = math.radians(i * 360 / 7)
        k.box((0.36, 0.12, 0.012), (0.27 * math.cos(a_), cy + 0.27 * math.sin(a_), front + 0.07),
              "steel_bare", 0.003, rot=(25, 0, math.degrees(a_)))
    k.body()
    for r in (0.18, 0.32, 0.46):
        k.torus(r, 0.007, (0, cy, front + 0.13), "z", "steel_bare", 28, 6)
    for i in range(10):
        a_ = i * 36
        ca, sa = math.cos(math.radians(a_)), math.sin(math.radians(a_))
        k.box((0.5, 0.014, 0.014), (0.25 * ca, cy + 0.25 * sa, front + 0.13), "steel_bare", 0.002, rot=(0, 0, a_))
    # side access hatch, motor on the left, flexible duct on top
    k.box((0.5, 0.5, 0.03), (0.0, 0.5, -d / 2 + 0.01), "painted_metal", 0.008)
    for i in range(6):
        k.hex_bolt((0.72, 0.2 + i * 0.22, d / 2 + 0.002), 0.012, 0.012)
        k.hex_bolt((-0.72, 0.2 + i * 0.22, d / 2 + 0.002), 0.012, 0.012)
    k.cyl(0.2, 0.18, (-0.35, 1.41, -0.1), "y", "rubber_black", 20)                               # flexible duct collar
    for i in range(4):
        k.torus(0.205, 0.012, (-0.35, 1.34 + i * 0.045, -0.1), "y", "rubber_black", 20, 6)
    k.box((0.3, 0.3, 0.3), (0.5, 0.3, -0.3), "plastic_panel", 0.01)                              # junction box
    k.decal((0.55, 1.27, front + 0.001), (0.3, 0.075), "panel_labels", uv("panel_labels", "ПОДАЧА"), offset=0.0)
    k.decal((-0.55, 0.22, front + 0.001), (0.3, 0.15), "signs_ru", uv("signs_ru", "ventilation"), offset=0.0)


# ----------------------------------------------------------------------------- P-015
# Matches the gameplay placeholder objects/props/staff_capsule.gd (Р-16): base 1.2 x 0.5 x 2.6, tub walls up to the
# rim at 0.8, bed 1.0 x 2.3, lid 0.55 high hinged on the +X rim (rotation about Z), panel stand at the feet (+Z).
POD_L, POD_W, POD_BASE, POD_RIM, POD_LID = 2.6, 1.2, 0.5, 0.8, 0.55


@prop("staff_pod", "P-015", (1.25, 1.35, 3.0), "floor", 14000, tolerance=0.05, center_z=False)
def staff_pod(k: Kit):
    """Emergency staff sleep capsule (Р-16 sizes): base, tub, bed, hinged glass lid (Lid), panel stand at the feet."""
    L, W = POD_L, POD_W

    def rrect(w, h, r, n=5):
        pts = []
        for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
            for i in range(n + 1):
                a = math.radians(a0 + 90 * i / n)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return pts

    k.box((W - 0.1, 0.08, L - 0.1), (0, 0.04, 0), "painted_metal", 0.008)                          # recessed plinth
    k.box((W, POD_BASE - 0.08, L), (0, 0.08 + (POD_BASE - 0.08) / 2, 0), "painted_metal", 0.012)  # base
    k.box((1.0, 0.06, 2.3), (0, POD_BASE + 0.03, 0), "vinyl_worn", 0.02)                            # bed
    k.box((0.5, 0.07, 0.32), (0, POD_BASE + 0.095, -0.92), "vinyl_worn", 0.03)                      # pillow
    tub_h = POD_RIM - POD_BASE
    for sx in (-1, 1):
        k.box((0.06, tub_h, L), (sx * (W / 2 - 0.03), POD_BASE + tub_h / 2, 0), "painted_metal", 0.008)
    for sz in (-1, 1):
        k.box((W, tub_h, 0.06), (0, POD_BASE + tub_h / 2, sz * (L / 2 - 0.03)), "painted_metal", 0.008)
    k.box((W + 0.01, 0.025, L + 0.01), (0, POD_RIM - 0.0125, 0), "steel_bare", 0.004)              # rim seal
    for sz in (-1, 1):                                                                               # hinge blocks
        k.box((0.05, 0.06, 0.12), (W / 2 + 0.01, POD_RIM - 0.03, sz * 0.9), "steel_bare", 0.006)
    # lid: hinge line on the +X rim; frosted canopy in a frame
    k.group("Lid", pivot=(W / 2, POD_RIM, 0))
    cy = POD_RIM + POD_LID / 2
    k.prism(rrect(W - 0.08, POD_LID - 0.04, 0.18), L - 0.12, (0, cy - 0.01, 0), "glass_dirty", "z")
    for sz in (-1, 1):
        k.box((W, POD_LID, 0.05), (0, cy, sz * (L / 2 - 0.025)), "painted_metal", 0.01)               # end frames
    for sx in (-1, 1):
        k.box((0.05, 0.05, L), (sx * (W / 2 - 0.025), POD_RIM + 0.025, 0), "painted_metal", 0.008)   # lower frame rails
    gap, hw, hh, rr = 0.012, (W - 0.08) / 2, (POD_LID - 0.04) / 2, 0.18
    arch = [(hw + gap, POD_RIM + 0.05)]
    for cx, a0 in ((hw - rr, 0), (-(hw - rr), 90)):
        for i in range(9):
            a = math.radians(a0 + 90 * i / 8)
            arch.append((cx + (rr + gap) * math.cos(a), cy - 0.01 + (hh - rr) + (rr + gap) * math.sin(a)))
    arch.append((-(hw + gap), POD_RIM + 0.05))
    for z in (-0.65, 0.0, 0.65):                                                                      # frame hoops
        k.tube([(x, y, z) for x, y in arch], 0.016, "painted_metal", 8)
    k.box((0.04, 0.08, 0.3), (-W / 2 - 0.0, POD_RIM + 0.06, 0.4), "steel_bare", 0.006)                # latch (free edge)
    k.body()
    # panel stand at the feet (as in the placeholder: post 1.0 high, panel at 1.1 tilted 20 degrees)
    pz = L / 2 + 0.12
    tilt = 20.0
    pc = (0.0, 1.1, pz + 0.02)

    def on_panel(x, v, d):
        """A point on the tilted panel: x across, v up its face, d out of it (0.035 is the front face)."""
        a = math.radians(tilt)
        return (pc[0] + x, pc[1] + v * math.cos(a) + d * math.sin(a), pc[2] - v * math.sin(a) + d * math.cos(a))

    k.box((0.12, 1.0, 0.12), (0, 0.5, pz), "painted_metal", 0.01)
    k.box((0.46, 0.34, 0.07), pc, "painted_metal", 0.012, rot=(-tilt, 0, 0))
    k.decal(on_panel(0, -0.01, 0.035), (0.34, 0.17), "screens", uv("screens", "terminal_boot"), tilt=-tilt, offset=0.003)
    for i, m in enumerate(("emit_led_green", "emit_led_amber", "emit_led_red")):
        k.cyl(0.011, 0.012, on_panel(-0.12 + i * 0.12, -0.13, 0.039), "z", m, 10, rot=(-tilt, 0, 0))
    k.decal(on_panel(0, 0.125, 0.035), (0.26, 0.06), "panel_labels", uv("panel_labels", "КАПСУЛА"), tilt=-tilt, offset=0.003)
    # service hoses at the head end
    for x in (-0.25, 0.0, 0.25):
        pts = [(x, 0.4, -L / 2), (x * 1.2, 0.3, -L / 2 - 0.08), (x * 1.3, 0.1, -L / 2 - 0.12), (x * 1.3, 0.03, -L / 2 - 0.13)]
        k.tube(pts, 0.035, "rubber_black", 8)
    k.decal((0.45, 0.3, L / 2), (0.16, 0.08), "signs_ru", uv("signs_ru", "danger"))
    k.decal((0, 0.3, L / 2), (0.36, 0.06), "hazard_stripes", uv("hazard_stripes", "yellow_black"))


# ----------------------------------------------------------------------------- P-016
@prop("immersion_chair", "P-016", (1.0, 2.2, 1.2), "floor", 16000, tolerance=0.1)
def immersion_chair(k: Kit):
    """Metal chair under a technical arch; a crystal floats above the head, two hoops (head and arm) hang ready."""
    k.cyl(0.42, 0.1, (0, 0.05, 0), "y", "painted_metal", 28, cap_bevel=0.01)                       # base disc
    k.cyl(0.12, 0.35, (0, 0.27, 0.05), "y", "steel_bare", 16)                                       # pedestal
    k.box((0.56, 0.09, 0.56), (0, 0.5, 0.05), "vinyl_worn", 0.03)                                   # seat
    k.box((0.5, 0.7, 0.1), (0, 0.9, -0.2), "vinyl_worn", 0.035, rot=(-12, 0, 0))                    # back
    k.box((0.34, 0.26, 0.1), (0, 1.42, -0.27), "vinyl_worn", 0.035, rot=(-12, 0, 0))                # headrest
    k.box((0.12, 0.14, 0.1), (0, 1.26, -0.22), "painted_metal", 0.01)
    for sx in (-1, 1):
        k.box((0.08, 0.06, 0.52), (sx * 0.34, 0.76, 0.03), "painted_metal", 0.01)                   # armrests
        k.box((0.06, 0.3, 0.06), (sx * 0.34, 0.6, -0.1), "painted_metal", 0.008)
        k.box((0.1, 0.014, 0.4), (sx * 0.34, 0.795, 0.03), "vinyl_worn", 0.004)
    for sx in (-1, 1):                                                                              # strap clamps on the armrests
        k.box((0.12, 0.05, 0.1), (sx * 0.36, 0.82, 0.18), "steel_bare", 0.006)
    k.box((0.34, 0.04, 0.24), (0, 0.18, 0.4), "painted_metal", 0.006)                               # footrest
    k.box((0.04, 0.3, 0.04), (0, 0.33, 0.35), "steel_bare", 0.004)
    # technical arch behind the chair carrying the crystal
    for sx in (-1, 1):
        k.box((0.08, 2.0, 0.12), (sx * 0.46, 1.05, -0.45), "painted_metal", 0.01)
    k.box((1.0, 0.14, 0.14), (0, 2.08, -0.45), "painted_metal", 0.012)
    k.box((0.7, 0.08, 0.5), (0, 2.12 - 0.0, -0.22), "painted_metal", 0.01)                          # emitter housing
    k.cyl(0.06, 0.18, (0, 1.99, -0.12), "y", "chrome_dull", 14)
    k.group("Crystal", pivot=(0, 1.78, -0.12))
    k.sphere(0.12, (0, 1.78, -0.12), "crystal_core", 6, scale=(0.75, 1.5, 0.75))
    for a in range(3):
        t = math.radians(a * 120 + 20)
        k.sphere(0.035, (0.2 * math.cos(t), 1.78 + 0.05 * a, -0.12 + 0.2 * math.sin(t)), "crystal_core", 6, scale=(0.7, 1.4, 0.7))
    k.body()
    k.group("Hoop1", pivot=(0, 1.62, -0.12))
    k.torus(0.2, 0.014, (0, 1.62, -0.12), "y", "chrome_dull", 32, 8)
    k.box((0.012, 0.3, 0.012), (0, 1.77, -0.12), "chrome_dull", 0.0)
    k.body()
    k.group("Hoop2", pivot=(0.36, 0.9, 0.2))
    k.torus(0.07, 0.012, (0.36, 0.9, 0.2), "z", "chrome_dull", 20, 8)
    k.body()
    for sx in (-1, 1):                                                                              # cables from the arch to the chair
        pts = [(sx * 0.46, 1.9, -0.45), (sx * 0.44, 1.5, -0.55), (sx * 0.3, 0.9, -0.5), (sx * 0.2, 0.4, -0.3), (sx * 0.12, 0.1, -0.1)]
        k.tube(pts, 0.025, "rubber_black", 8)
    k.decal((0.0, 2.08, -0.375), (0.5, 0.1), "hazard_stripes", uv("hazard_stripes", "yellow_black"), offset=0.0, normal="+z")


# ----------------------------------------------------------------------------- P-017
@prop("chamber1_gate", "P-017", (5.6, 4.5, 1.33), "floor", 24000, tolerance=0.12, center_z=False)
def chamber1_gate(k: Kit):
    """The wrecked gate of chamber No. 1: heavy frame, two bent bar leaves, torn out at the middle."""
    g = random.Random(17)
    W, H = 5.6, 4.5
    k.box((0.5, H, 0.6), (-W / 2 + 0.25, H / 2, 0), "painted_metal", 0.02)
    k.box((0.5, H, 0.6), (W / 2 - 0.25, H / 2, 0), "painted_metal", 0.02)
    k.box((W, 0.55, 0.7), (0, H - 0.275, 0), "painted_metal", 0.02)
    k.box((W, 0.2, 0.5), (0, 0.1, 0), "steel_bare", 0.01)
    for x in (-W / 2 + 0.25, W / 2 - 0.25):
        for y in (0.6, 1.8, 3.0, 4.0):
            k.cyl(0.06, 0.04, (x, y, 0.32), "z", "steel_bare", 6)
    # vertical bars: bent towards +Z around the middle, snapped at various heights
    n = 17
    for i in range(n):
        x = -W / 2 + 0.5 + (W - 1.0) * i / (n - 1)
        bend = max(0.0, 1.0 - abs(x) / 1.7)                    # strongest at the centre
        snapped = g.random() < 0.45 * bend + 0.05
        top = H - 0.55
        pts = []
        for j in range(15):
            t = j / 14
            y = 0.2 + (top - 0.2) * t
            dz = bend * (0.55 + 0.25 * g.random()) * math.sin(math.pi * t) ** 1.3 * 1.0
            dx = bend * 0.25 * math.sin(t * 5 + i) * t
            pts.append((x + dx * (1 if x > 0 else -1), y, dz))
        if snapped:
            cut = g.randint(7, 11)
            pts = pts[:cut]
        k.tube(pts, 0.04, "rusted_steel" if g.random() < 0.5 else "painted_metal", 8)
    # horizontal cross bars (some torn)
    for y in (0.9, 1.9, 2.9, 3.8):
        for seg in ((-W / 2 + 0.5, -0.9), (0.9, W / 2 - 0.5)):
            pts = [(seg[0] + (seg[1] - seg[0]) * t / 10, y + 0.05 * math.sin(t), 0.02 + 0.2 * max(0, 1 - abs((seg[0] + (seg[1] - seg[0]) * t / 10)) / 1.9)) for t in range(11)]
            k.tube(pts, 0.05, "painted_metal", 8)
    # torn-off lock housing lying on the floor in front of the gate, and a bent crossbeam
    k.box((0.5, 0.3, 0.9), (-0.7, 0.15, 0.45), "steel_bare", 0.03, rot=(0, 24, 0))
    k.box((2.4, 0.22, 0.22), (1.4, 0.18, 0.55), "painted_metal", 0.015, rot=(0, -16, 4))
    k.decal((-W / 2 + 0.25, 3.6, 0.301), (0.4, 0.2), "signs_ru", uv("signs_ru", "module_1"), offset=0.0)
