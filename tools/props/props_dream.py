"""Bowser's dream S, second production wave (issue #195; docs/art/dream-bowser-s.md §4, §7 ПР-4, ПР-6, ПР-7, ПР-10).

Fortress kit К-01…К-07 (stone Д-1: dark with a lilac tint, block 1 × 2 m — the joints come from `dream_stone_wall`),
path М-01…М-03, the seal ПЧ-1 with its wheels ПЧ-2 and the Bowser overlay А-01 for the shared `DreamGate`.
Godot coordinates, front +Z. The modules are tiled over the blockout boxes by `objects/dream/dream_kit_fill.gd`,
so their sizes are the tiling step, not the size of a whole wall.
"""
from __future__ import annotations

import math

import bmesh

from propkit import Kit
from registry import prop

STONE = "dream_stone_wall"   # DT-01
FLOOR = "dream_stone_floor"  # DT-02
ROCK = "dream_rock"          # DT-03
BONE = "dream_spike_bone"    # DT-01b
IRON = "dream_iron"          # DT-05
CHAIN = "steel_bare"         # DT-06 (chain.tres darkens it by colour)
BRONZE = "dream_bronze"      # DT-07
WHITE = "emit_dream_white"

VIEWS_WIDE = [((1.0, 0.45, 1.4), (0, 0, 0)), ((-1.2, 0.5, 1.2), (0, 0, 0)), ((0.2, 1.4, 0.6), (0, 0, 0))]


# ----------------------------------------------------------------------------- helpers
def lathe(k: Kit, profile, m: str, seg: int = 48, center=(0.0, 0.0, 0.0), closed: bool = True):
    """Revolves the (radius, y) `profile` about the vertical axis through `center`; `closed` joins last to first."""
    bm = bmesh.new()
    cx, cy, cz = center
    rings = []
    for r, y in profile:
        rings.append([bm.verts.new((cx + r * math.sin(2 * math.pi * i / seg), cy + y, cz + r * math.cos(2 * math.pi * i / seg)))
                      for i in range(seg)])
    pairs = len(rings) if closed else len(rings) - 1
    for j in range(pairs):
        a, b = rings[j], rings[(j + 1) % len(rings)]
        for i in range(seg):
            i2 = (i + 1) % seg
            try:
                bm.faces.new((a[i], a[i2], b[i2], b[i]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    k._commit(bm, m)


def spike(k: Kit, base, length: float, r: float, direction="up", m: str = BONE, seg: int = 6):
    """A cone from `base` along +Y ('up') or outward along ±X / ±Z."""
    x, y, z = base
    if direction == "up":
        k.cyl(r, length, (x, y + length / 2, z), "y", m, seg, r2=0.0)
    elif direction in ("+z", "-z"):
        s = 1 if direction == "+z" else -1
        k.cyl(r, length, (x, y, z + s * length / 2), "y", m, seg, r2=0.0, rot=(90 * s, 0, 0))
    else:
        s = 1 if direction == "+x" else -1
        k.cyl(r, length, (x + s * length / 2, y, z), "y", m, seg, r2=0.0, rot=(0, 0, -90 * s))


def sag(a, b, depth: float, n: int = 12):
    """Points of a hanging chain from `a` to `b` that dips `depth` below the chord in the middle."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(3)))
        pts[-1] = (pts[-1][0], pts[-1][1] - depth * 4 * t * (1 - t), pts[-1][2])
    return pts


# ----------------------------------------------------------------------------- К-01 wall section + crown
@prop("dream_wall", "К-01", (4.0, 4.0, 1.1), "floor", 2000, notes="Wall section 4 × 4 × 1 m, stacked by dream_kit_fill; "
      "the 2 × 1 m block joints come from the dream_stone_wall texture")
def dream_wall(k: Kit):
    k.box((4.0, 4.0, 1.0), (0, 2.0, 0), STONE, 0.02, 1)
    k.box((4.0, 0.3, 1.1), (0, 0.15, 0), STONE, 0.02, 1)                       # plinth course (joins the tiers)


@prop("dream_wall_crown", "К-01", (4.0, 1.9, 1.7), "floor", 1500, notes="Crenellated crown with bone spikes on top of "
      "an open-air wall; origin on the wall top")
def dream_wall_crown(k: Kit):
    k.box((4.0, 0.35, 1.3), (0, 0.175, 0), STONE, 0.03, 1)                     # cornice
    for x in (-1.0, 1.0):
        k.box((1.3, 1.0, 1.0), (x, 0.85, 0), STONE, 0.03, 1)                   # merlons
        spike(k, (x, 1.35, 0), 0.55, 0.14)
        for s in ("+z", "-z"):
            spike(k, (x, 0.9, 0.5 if s == "+z" else -0.5), 0.35, 0.09, s)
    k.box((0.7, 0.12, 1.32), (0, 0.41, 0), IRON, 0.01, 1)                      # iron cramp in the embrasure


# ----------------------------------------------------------------------------- К-02 wall with a guard niche
@prop("dream_wall_niche", "К-02", (4.0, 8.0, 1.1), "floor", 2500, center_z=False, notes="Wall section with a 3 × 5 m guard niche on "
      "the +Z face (0.6 deep, floor 0.5 m up); for the guard wave (#184), not placed by #195")
def dream_wall_niche(k: Kit):
    k.box((4.0, 8.0, 0.4), (0, 4.0, -0.3), STONE, 0.02, 1)                     # back
    k.box((0.5, 8.0, 0.6), (-1.75, 4.0, 0.2), STONE, 0.02, 1)
    k.box((0.5, 8.0, 0.6), (1.75, 4.0, 0.2), STONE, 0.02, 1)
    k.box((3.0, 0.5, 0.6), (0, 0.25, 0.2), STONE, 0.02, 1)                     # sill
    k.box((3.0, 2.5, 0.6), (0, 6.75, 0.2), STONE, 0.02, 1)                     # head
    k.box((3.3, 0.18, 0.12), (0, 5.55, 0.5), BRONZE, 0.01, 1)                  # bronze lintel trim
    for x in (-1.55, 1.55):
        k.box((0.18, 5.0, 0.12), (x, 3.0, 0.5), IRON, 0.01, 1)
        spike(k, (x, 5.7, 0.5), 0.45, 0.1)


# ----------------------------------------------------------------------------- К-03 column, К-03b fallen column
@prop("dream_column", "К-03", (2.6, 10.0, 2.6), "floor", 1500, notes="Column with a spiked iron collar at 6.5 m")
def dream_column(k: Kit):
    k.box((2.0, 0.6, 2.0), (0, 0.3, 0), STONE, 0.04, 1)                        # plinth
    k.cyl(0.78, 8.6, (0, 4.9, 0), "y", STONE, 8)                               # octagonal shaft
    k.box((2.0, 0.8, 2.0), (0, 9.6, 0), STONE, 0.04, 1)                        # capital
    k.torus(0.84, 0.09, (0, 6.5, 0), "y", IRON, 16, 6)
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        bx, bz = math.sin(a) * 0.86, math.cos(a) * 0.86
        k.cyl(0.12, 0.6, (bx + math.sin(a) * 0.28, 6.5, bz + math.cos(a) * 0.28), "z", BONE, 6, r2=0.0,
              rot=(0, math.degrees(a), 0))
    for y in (1.0, 9.0):
        k.torus(0.82, 0.05, (0, y, 0), "y", BRONZE, 16, 4)


@prop("dream_column_fallen", "К-03b", (5.1, 1.0, 1.75), "floor", 1500, notes="Fallen broken column lying along X")
def dream_column_fallen(k: Kit):
    k.cyl(0.45, 3.6, (-0.4, 0.45, 0), "x", STONE, 8)
    k.box((1.0, 1.0, 1.6), (2.0, 0.5, 0.0), STONE, 0.05, 1, rot=(0, 12, 0))  # capital broken off
    k.chunk((-2.35, 0.3, 0.3), (0.3, 0.3, 0.3), 3, STONE, 9)
    k.chunk((1.3, 0.2, -0.55), (0.25, 0.2, 0.22), 4, STONE, 9)
    k.torus(0.47, 0.03, (0.6, 0.5, 0), "x", IRON, 14, 4)


# ----------------------------------------------------------------------------- К-04 portal frame
@prop("dream_portal", "К-04", (8.2, 10.4, 2.06), "floor", 8000, views=VIEWS_WIDE,
      notes="Frame of a 5 × 7 m doorway laid over the wall: jambs, arch head, raised iron portcullis (Gate) in the head; "
            "the leaves of the art sheet are left out because the doorways of S stay open (collision is the wall's)")
def dream_portal(k: Kit):
    for s in (-1, 1):
        k.box((1.5, 7.0, 1.4), (s * 3.25, 3.5, 0), STONE, 0.04, 1)            # jambs
        k.box((1.7, 0.5, 1.5), (s * 3.25, 0.25, 0), STONE, 0.04, 1)           # bases
        k.box((1.7, 0.4, 1.5), (s * 3.25, 7.0, 0), BRONZE, 0.02, 1)           # imposts
        for y in (2.0, 4.5):
            k.box((1.56, 0.16, 1.46), (s * 3.25, y, 0), IRON, 0.01, 1)
            for z in (-0.73, 0.73):
                spike(k, (s * 3.25, y, z), 0.3, 0.07, "+z" if z > 0 else "-z")
    # arch head: voussoirs on a half circle over the 5 m span, then a flat course to 10 m
    span, rise = 2.5, 1.6
    n = 9
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        pts = []
        for a, rad in ((a0, 1.0), (a1, 1.0)):
            pts.append((-math.cos(a) * span * rad, 7.2 + math.sin(a) * rise * rad))
        outer = [(-math.cos(a) * (span + 1.0), 7.2 + math.sin(a) * (rise + 1.0)) for a in (a1, a0)]
        k.prism(pts + outer, 1.4, (0, 0, 0), STONE, "z", 0.02, 1)
    key = [(-0.4, 8.6), (0.4, 8.6), (0.55, 9.9), (-0.55, 9.9)]
    k.prism(key, 1.5, (0, 0, 0), BRONZE, "z", 0.02, 1)                         # keystone
    k.box((8.0, 0.5, 1.4), (0, 9.75, 0), STONE, 0.04, 1)
    for s in (-1, 1):
        k.prism([(s * 2.5, 7.2), (s * 4.0, 7.2), (s * 4.0, 9.5), (s * 2.9, 9.5)], 1.36, (0, 0, 0), STONE, "z", 0.02, 1)
    for x in (-3.5, -1.2, 1.2, 3.5):
        spike(k, (x, 10.0, 0), 0.4, 0.12)
    # raised portcullis, only its bottom teeth show under the arch
    k.group("Gate", pivot=(0, 7.2, 0))
    for i in range(9):
        x = -2.2 + i * 0.55
        k.box((0.1, 1.1, 0.1), (x, 7.6, 0.0), IRON, 0.01, 1)
        k.cyl(0.05, 0.25, (x, 6.925, 0.0), "y", IRON, 4, r2=0.0, rot=(180, 0, 0))
    k.box((4.8, 0.12, 0.12), (0, 7.3, 0), IRON, 0.01, 1)
    k.body()


# ----------------------------------------------------------------------------- К-06 floor plate, К-07 parapet
@prop("dream_floor_plate", "К-06", (4.0, 0.5, 4.0), "floor", 200, notes="Floor plate 4 × 4 m; layers of plates fill "
      "the blockout floors")
def dream_floor_plate(k: Kit):
    k.box((3.96, 0.5, 3.96), (0, 0.25, 0), FLOOR, 0.035, 1)


@prop("dream_parapet", "К-07", (4.0, 1.2, 0.6), "floor", 600, notes="Crenellated parapet with bone spikes")
def dream_parapet(k: Kit):
    k.box((4.0, 0.6, 0.6), (0, 0.3, 0), STONE, 0.03, 1)
    for x in (-1.0, 1.0):
        k.box((1.1, 0.45, 0.6), (x, 0.825, 0), STONE, 0.03, 1)
        spike(k, (x, 1.05, 0), 0.15, 0.07, seg=5)


# ----------------------------------------------------------------------------- М-01 ledge
@prop("dream_ledge", "М-01", (14.9, 5.7, 3.5), "free", 3000, views=VIEWS_WIDE,
      notes="Ledge of the path S2 over the lava: 10 m at y 0 and a 1.2 m step for the last 4 m; origin on the low top "
            "at the middle of the 10 m part (world 21, 0, 0)")
def dream_ledge(k: Kit):
    k.box((10.0, 0.3, 3.0), (0, -0.15, 0), FLOOR, 0.03, 1)                     # walking slabs
    k.box((4.0, 0.3, 3.0), (7.0, 1.05, 0), FLOOR, 0.03, 1)
    k.box((10.0, 3.5, 2.6), (0, -2.05, 0), ROCK, 0.0, 1)                       # rock body
    k.box((4.0, 4.7, 2.6), (7.0, -1.45, 0), ROCK, 0.0, 1)
    seed = 0
    for x in (-4.0, -1.5, 1.0, 3.5, 6.0, 8.0):
        for s in (-1, 1):
            seed += 1
            k.chunk((x, -1.8 - (seed % 3) * 0.4, s * 1.35), (1.4, 1.8, 0.5), seed, ROCK, 10)
    for x, y in ((-4.5, -3.6), (2.0, -3.8), (7.5, -3.5)):
        k.chunk((x, y, 0), (1.6, 1.0, 1.7), int(x * 7) & 0xFF, ROCK, 10)


# ----------------------------------------------------------------------------- М-02 chain bridge
@prop("dream_chain_bridge", "М-02", (17.1, 5.8, 2.8), "free", 6000, views=VIEWS_WIDE,
      notes="Chain bridge 16 × 2 m on four 5 m posts; origin on the deck top in the middle (world 38, 1.2, 0); "
            "the handrail chains sag 1 m between the posts, the deck stays flat (it is walked on)")
def dream_chain_bridge(k: Kit):
    for i in range(8):
        k.box((1.9, 0.25, 2.0), (-7.0 + i * 2.0, -0.125, 0), FLOOR, 0.02, 1)    # deck plates
    for z in (-1.0, 1.0):
        k.box((16.0, 0.25, 0.16), (0, -0.3, z), IRON, 0.01, 1)                  # stringers
    for i in range(9):
        k.box((0.16, 0.12, 2.2), (-8.0 + i * 2.0, -0.45, 0), IRON, 0.01, 1)     # cross beams
    top = 3.9
    for x in (-8.3, 8.3):
        for z in (-1.15, 1.15):
            k.box((0.34, 5.0, 0.34), (x, top - 2.5, z), IRON, 0.02, 1)
            k.box((0.5, 0.2, 0.5), (x, top + 0.1, z), BRONZE, 0.02, 1)
            spike(k, (x, top + 0.2, z), 0.6, 0.13)
            k.box((0.5, 0.3, 0.5), (x, -0.35, z), IRON, 0.02, 1)
    for z in (-1.15, 1.15):
        k.tube(sag((-8.3, 1.9, z), (8.3, 1.9, z), 1.0, 16), 0.05, CHAIN, 6)       # handrail chain
        k.tube(sag((-8.3, top - 0.3, z), (8.3, top - 0.3, z), 1.6, 16), 0.065, CHAIN, 6)  # suspension chain
        for i in range(1, 8):
            x = -8.0 + i * 2.0
            t = (x + 8.3) / 16.6
            ys = top - 0.3 - 1.6 * 4 * t * (1 - t)
            k.tube([(x, ys, z), (x, 0.0, z * 0.9)], 0.025, CHAIN, 5)          # hangers
        for x in (-8.3, 8.3):
            k.torus(0.08, 0.025, (x, 1.9, z), "z", CHAIN, 10, 4)


# ----------------------------------------------------------------------------- М-03 stone bridge to the bastion
@prop("dream_stone_bridge", "М-03", (3.22, 5.0, 12.0), "free", 2000, views=VIEWS_WIDE,
      notes="Stone bridge 3 × 12 m along Z with parapet rails 0.9 m; origin on the deck top in the middle "
            "(world 80, 1.2, -14)")
def dream_stone_bridge(k: Kit):
    k.box((3.0, 0.5, 12.0), (0, -0.25, 0), FLOOR, 0.03, 1)
    for s in (-1, 1):
        k.box((0.3, 0.75, 12.0), (s * 1.42, 0.375, 0), STONE, 0.03, 1)
        for z in (-4.5, -1.5, 1.5, 4.5):
            k.box((0.38, 0.25, 0.9), (s * 1.42, 0.875, z), STONE, 0.03, 1)
    # segmental arch under the deck (profile in z, y), extruded across the width
    prof = [(-6.0, -0.5), (6.0, -0.5), (6.0, -4.0), (4.6, -4.0)]
    for i in range(1, 8):
        a = math.pi * i / 8
        prof.append((4.6 * math.cos(a), -4.0 + 2.6 * math.sin(a)))
    prof += [(-4.6, -4.0), (-6.0, -4.0)]
    k.prism_x([(-z, y) for z, y in prof], 2.8, 0.0, STONE, 0.0)


# ----------------------------------------------------------------------------- ПЧ-1 seal, ПЧ-2 wheel
SEAL_R = 4.0
SEAL_CORE = 0.6
SEAL_DISC = 0.3
RING_TOPS = (0.45, 0.6, 0.75)  # absolute top of rings 1..3 (outer → inner), art sheet ПЧ-1
SOCKETS = 6


def ring_radii(i: int):
    width = (SEAL_R - SEAL_CORE) / 3
    outer = SEAL_R - width * i
    return outer - width, outer


@prop("dream_seal", "ПЧ-1", (8.4, 0.8, 8.4), "floor", 20000, views=[((0.4, 1.0, 1.0), (0, 0, 0)), ((1.2, 0.5, 0.6), (0, 0, 0))],
      notes="Seal disc Ø 8 with three stepped rings (tops 0.45 / 0.6 / 0.75): nodes Ring1..Ring3 pivot at the disc top "
            "(y 0.3) in the centre; each ring carries six empty glyph sockets for #188 at the angle k·60° from +Z, "
            "radius = ring middle, Ø 0.84 (where DreamSealRings lays its glyph images)")
def dream_seal(k: Kit):
    lathe(k, [(0.0, 0.0), (SEAL_R + 0.12, 0.0), (SEAL_R + 0.12, 0.2), (SEAL_R, SEAL_DISC), (0.0, SEAL_DISC)], FLOOR, 72)
    lathe(k, [(SEAL_R + 0.13, 0.04), (SEAL_R + 0.2, 0.04), (SEAL_R + 0.2, 0.16), (SEAL_R + 0.13, 0.16)], BRONZE, 72)
    lathe(k, [(SEAL_CORE - 0.05, SEAL_DISC), (SEAL_CORE, SEAL_DISC), (SEAL_CORE, 0.8), (SEAL_CORE - 0.05, 0.8)], BRONZE, 32)
    for i in range(3):
        name = f"Ring{i + 1}"
        k.group(name, pivot=(0, SEAL_DISC, 0))
        lo, hi = ring_radii(i)
        lo, hi, top = lo + 0.04, hi - 0.04, RING_TOPS[i]
        lathe(k, [(lo, SEAL_DISC), (hi, SEAL_DISC), (hi, top - 0.05), (hi - 0.05, top), (lo + 0.05, top), (lo, top - 0.05)],
              FLOOR, 72)
        lathe(k, [(hi - 0.02, top - 0.14), (hi + 0.015, top - 0.14), (hi + 0.015, top - 0.04), (hi - 0.02, top - 0.04)],
              BRONZE, 72)
        mid = (lo + hi) / 2
        for s in range(SOCKETS):
            a = 2 * math.pi * s / SOCKETS
            c = (math.sin(a) * mid, top, math.cos(a) * mid)
            k.torus(0.42, 0.03, (c[0], top + 0.006, c[2]), "y", BRONZE, 24, 4)
            k.cyl(0.4, 0.02, (c[0], top - 0.004, c[2]), "y", IRON, 24)
    k.body()


@prop("dream_seal_wheel", "ПЧ-2", (1.05, 1.64, 0.7), "floor", 1500,
      notes="Wheel on a pedestal; node Wheel spins about +Z, axis at (0, 1.05, 0.3), Ø 1.0 (the levers of DreamSealRings "
            "stand 1.2 m apart, so the Ø 1.2 of the sheet would touch)")
def dream_seal_wheel(k: Kit):
    k.box((0.6, 0.9, 0.6), (0, 0.45, 0), STONE, 0.03, 1)                       # pedestal
    k.box((0.7, 0.12, 0.7), (0, 0.06, 0), IRON, 0.02, 1)
    k.box((0.5, 0.25, 0.5), (0, 1.0, 0), IRON, 0.02, 1)                       # bearing block
    k.cyl(0.07, 0.25, (0, 1.05, 0.2), "z", IRON, 10)
    spike(k, (-0.22, 1.12, 0), 0.18, 0.05, seg=5)
    spike(k, (0.22, 1.12, 0), 0.18, 0.05, seg=5)
    k.group("Wheel", pivot=(0, 1.05, 0.3))
    R = 0.47
    k.torus(R, 0.035, (0, 1.05, 0.3), "z", BRONZE, 32, 6)
    for i in range(6):
        a = 2 * math.pi * i / 6
        k.cyl(0.022, R, (math.sin(a) * R / 2, 1.05 + math.cos(a) * R / 2, 0.3), "y", BRONZE, 6, rot=(0, 0, -math.degrees(a)))
        k.cyl(0.03, 0.12, (math.sin(a) * (R + 0.06), 1.05 + math.cos(a) * (R + 0.06), 0.3), "y", IRON, 6,
              rot=(0, 0, -math.degrees(a)))                                     # grip pegs
    k.cyl(0.09, 0.1, (0, 1.05, 0.3), "z", IRON, 12, cap_bevel=0.01)
    k.body()


# ----------------------------------------------------------------------------- А-01 gate overlay
@prop("dream_gate_bowser", "А-01", (7.1, 9.0, 1.32), "floor", 8000, views=VIEWS_WIDE,
      notes="Bowser overlay on the shared DreamGate silhouette (pillars ±1.6, 0.6 wide, lintel at 4.4): buttresses, "
            "pillar bands, spiked crown, chains and a white keystone line; origin = the gate origin; the passage "
            "(2.6 × 3.9) and its trigger stay canonical, so the 4 × 6.5 opening of the sheet is not taken")
def dream_gate_bowser(k: Kit):
    for s in (-1, 1):
        k.box((1.5, 6.4, 1.2), (s * 2.75, 3.2, 0), STONE, 0.04, 1)            # buttresses
        k.box((1.6, 0.5, 1.3), (s * 2.75, 0.25, 0), IRON, 0.02, 1)
        k.prism([(s * 2.0, 6.4), (s * 3.5, 6.4), (s * 3.5, 6.9), (s * 2.0, 7.6)], 1.2, (0, 0, 0), STONE, "z", 0.02, 1)
        spike(k, (s * 3.3, 6.9, 0), 0.9, 0.18)
        for y in (1.2, 2.6, 3.9):
            k.box((0.72, 0.14, 0.72), (s * 1.6, y, 0), IRON, 0.01, 1)          # bands round the canonical pillars
            for z in (-0.36, 0.36):
                spike(k, (s * 1.6, y, z), 0.22, 0.06, "+z" if z > 0 else "-z", IRON, 5)
        k.tube(sag((s * 2.05, 6.0, 0.62), (s * 0.4, 4.8, 0.62), 0.35, 8), 0.04, CHAIN, 6)
        k.tube(sag((s * 2.05, 6.0, -0.62), (s * 0.4, 4.8, -0.62), 0.35, 8), 0.04, CHAIN, 6)
    k.box((4.4, 0.25, 0.8), (0, 4.825, 0), IRON, 0.02, 1)                      # cap of the canonical lintel
    k.prism([(-2.0, 4.95), (2.0, 4.95), (1.2, 8.0), (-1.2, 8.0)], 1.0, (0, 0, 0), STONE, "z", 0.03, 1)  # crown
    k.box((0.36, 2.6, 1.04), (0, 6.45, 0), IRON, 0.02, 1)
    k.box((0.07, 2.2, 1.06), (0, 6.45, 0), WHITE, 0.0, 1)                       # white keystone line (Б-5)
    for x, h in ((-1.6, 0.7), (-0.8, 0.9), (0.0, 1.0), (0.8, 0.9), (1.6, 0.7)):
        y = 4.95 + (8.0 - 4.95) * (1 - abs(x) / 2.0) if abs(x) < 1.2 else 4.95 + (8.0 - 4.95) * (2.0 - abs(x)) / 0.8
        spike(k, (x, min(y, 8.0), 0), h, 0.16)
