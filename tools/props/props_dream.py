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


# ============================================================================= third wave (#199): ПР-5, ПР-8, ПР-9
CLOTH = "fabric_dark"        # the rotted cloak
CAP = "red_paint_worn"       # the recognisable cap of the world's hero (Д-3, Д-7)
WOOD = "wood_old"


# ----------------------------------------------------------------------------- З-1 rubble in an arch
@prop("dream_rubble_arch", "З-1", (5.2, 6.26, 2.63), "floor", 4000, views=VIEWS_WIDE,
      notes="Rubble filling a 4 × 6 m arch of the yard's south wall up to the lintel; origin on the floor in the middle "
            "of the arch (world 62, 1.2, 9.5); collision stays the blockout's stones")
def dream_rubble_arch(k: Kit):
    seed = 300
    rows = ((0.6, 6, 0.75), (1.7, 5, 0.7), (2.8, 5, 0.65), (3.9, 4, 0.62), (4.9, 4, 0.55), (5.6, 3, 0.45))
    for y, n, r in rows:
        for i in range(n):
            seed += 1
            x = -2.0 + (i + 0.5) * 4.0 / n + ((seed * 37) % 11 - 5) * 0.03
            z = ((seed * 53) % 7 - 3) * 0.08 + 0.3 - y * 0.04
            k.chunk((x, y, z), (r * 1.4, r * 1.1, r * 1.25), seed, STONE, 18)
    k.prism_x([(-0.5, 0.0), (0.35, 0.0), (0.15, 5.2), (-0.3, 5.5)], 3.3, 0.0, ROCK, 0.0)   # packed core behind the stones
    for x, z, r in ((-1.6, 0.9, 0.45), (0.3, 1.0, 0.4), (1.5, 0.8, 0.5), (-0.6, -0.9, 0.4), (1.0, -0.95, 0.38)):
        seed += 1
        k.chunk((x, r * 0.6, z), (r, r * 0.7, r * 0.9), seed, STONE, 8)        # stones rolled off the pile
    k.box((0.9, 0.5, 0.6), (-0.9, 0.6, 0.95), STONE, 0.03, 1, rot=(0, 18, 9))  # dressed blocks of the fallen arch
    k.box((0.8, 0.45, 0.55), (1.1, 3.3, 0.5), STONE, 0.03, 1, rot=(12, -25, 6))
    k.cyl(0.05, 1.8, (0.4, 2.2, 0.75), "x", IRON, 6, rot=(0, 20, 28))          # bent iron cramp
    k.rescale(ground=True)


# ----------------------------------------------------------------------------- З-2 lowered portcullis
GRATE_W, GRATE_H = 3.0, 5.2


@prop("dream_grate", "З-2", (3.36, 5.42, 0.36), "floor", 3000,
      notes="Lowered portcullis 3 × 5.2 m, bars every 0.45 m with spiked feet; node Gate (pivot at the top) for a later "
            "raise; origin on the floor in the middle, bars across X (world 90.5, 1.2, 0 turned 90°)")
def dream_grate(k: Kit):
    k.group("Gate", pivot=(0, GRATE_H, 0))
    n = 7
    for i in range(n):
        x = -(n - 1) * 0.45 / 2 + i * 0.45
        k.box((0.12, GRATE_H - 0.2, 0.12), (x, 0.1 + (GRATE_H - 0.2) / 2 + 0.1, 0), IRON, 0.01, 1)
        k.cyl(0.07, 0.22, (x, 0.11, 0), "y", IRON, 4, r2=0.0, rot=(180, 0, 0))    # teeth bite the floor
    for y in (1.4, 2.9, 4.4):
        k.box((GRATE_W, 0.16, 0.2), (0, y, 0), IRON, 0.01, 1)
        for i in range(n):
            x = -(n - 1) * 0.45 / 2 + i * 0.45
            k.box((0.2, 0.2, 0.26), (x, y, 0), IRON, 0.01, 1)                  # rivet plates
    k.box((GRATE_W + 0.24, 0.3, 0.36), (0, GRATE_H + 0.07, 0), IRON, 0.02, 1)  # head beam
    for s in (-1, 1):
        k.box((0.12, 0.6, 0.3), (s * 1.62, GRATE_H - 0.2, 0), IRON, 0.01, 1)
    k.body()


# ----------------------------------------------------------------------------- З-3 collapsed stair
@prop("dream_stair_collapsed", "З-3", (6.72, 5.8, 2.66), "free", 3000, views=VIEWS_WIDE,
      notes="Stair along the north wall to the +6 m gallery, broken off after 2 m of rise: fine steps over the "
            "blockout's four 1 × 0.5 m steps, a jagged stump, steps hanging from the wall above, debris; origin on the "
            "floor at the foot (world 63, 1.2, -8.25), climbing +X")
def dream_stair_collapsed(k: Kit):
    for i in range(8):                                                          # 0.5 run × 0.25 rise
        top = 0.25 * (i + 1)
        k.box((0.5, top, 1.5), (0.25 + i * 0.5, top / 2, 0), STONE, 0.02, 1)
        k.box((0.54, 0.06, 1.54), (0.25 + i * 0.5, top - 0.03, 0.0), FLOOR, 0.01, 1)
    k.chunk((4.2, 1.9, 0.0), (0.45, 0.55, 0.75), 401, STONE, 9)               # jagged stump
    k.chunk((4.5, 1.2, -0.2), (0.4, 0.6, 0.6), 402, STONE, 9)
    for i in range(4):                                                          # the flight still keyed into the wall
        top = 4.6 + 0.25 * i
        k.box((0.5, 0.6, 1.2), (4.95 + i * 0.5, top - 0.3, -0.15), STONE, 0.02, 1)
    k.box((2.2, 0.3, 1.4), (6.4 - 0.9, 5.65, -0.1), FLOOR, 0.02, 1)          # broken landing slab
    k.chunk((5.0, 4.2, -0.15), (0.35, 0.35, 0.55), 403, STONE, 8)             # broken underside
    for x, z, r, s in ((4.6, 1.3, 0.45, 404), (5.0, 0.8, 0.32, 405), (4.0, 1.6, 0.3, 406), (3.6, 1.2, 0.3, 407)):
        k.chunk((x, r * 0.6, z), (r * 1.2, r * 0.7, r), s, STONE, 8)           # steps lying where they fell
    k.box((0.5, 0.25, 1.5), (4.8, 0.2, 1.1), STONE, 0.02, 1, rot=(0, 30, 8))


# ----------------------------------------------------------------------------- Н-01 remains of the world's hero
@prop("dream_hero_remains", "Н-01", (1.86, 1.16, 1.86), "floor", 6000, views=[((0.9, 0.6, 1.4), (0, 0, 0)), ((-1.2, 0.8, 0.9), (0, 0, 0))],
      notes="Remains sitting against the niche wall under a rotted cloak, no face (Д-3); the recognisable cap lies at "
            "the knee, the hero's mallet beside; origin on the floor under the body, back to -Z")
def dream_hero_remains(k: Kit):
    # cloak: one draped shape from the floor folds to the hood, slumped forward
    lathe(k, [(0.0, 0.0), (0.56, 0.0), (0.5, 0.12), (0.42, 0.35), (0.34, 0.58), (0.24, 0.72), (0.15, 0.8), (0.19, 0.9),
              (0.17, 1.02), (0.08, 1.1), (0.0, 1.12)], CLOTH, 20, center=(0.0, 0.0, -0.25))
    k.sphere(0.13, (0.0, 0.9, -0.1), "collar_black", 10, scale=(0.9, 1.0, 0.45))   # the empty dark of the hood
    for i, (x, z) in enumerate(((-0.5, 0.0), (0.46, -0.05), (-0.25, 0.3), (0.35, -0.55), (0.0, 0.25))):
        k.chunk((x, 0.04, z - 0.2), (0.24, 0.07, 0.2), 500 + i, CLOTH, 8)        # folds on the floor
    # legs: knees up out of the cloak
    for s in (-1, 1):
        knee = (s * 0.17, 0.36, 0.38)
        k.tube([(s * 0.14, 0.2, -0.05), knee], 0.045, BONE, 8)
        k.tube([knee, (s * 0.2, 0.06, 0.72)], 0.038, BONE, 8)
        k.sphere(0.055, knee, BONE, 8)
        k.box((0.1, 0.05, 0.22), (s * 0.2, 0.025, 0.82), BONE, 0.01, 1)
    # arms: the right one reaching down to the floor (to the note), the left one on the knee
    k.tube([(0.3, 0.6, -0.15), (0.44, 0.36, 0.1), (0.38, 0.06, 0.45)], 0.034, BONE, 8)
    for f in range(4):
        k.tube([(0.35 + f * 0.022, 0.05, 0.47), (0.33 + f * 0.03, 0.02, 0.56)], 0.011, BONE, 5)
    k.tube([(-0.3, 0.6, -0.15), (-0.34, 0.42, 0.18), (-0.2, 0.4, 0.38)], 0.034, BONE, 8)
    # the cap (Д-3): round crown and a peak, fallen by the right knee
    k.sphere(0.16, (-0.55, 0.06, 0.45), CAP, 16, scale=(1.0, 0.6, 1.0))
    k.cyl(0.165, 0.02, (-0.55, 0.06, 0.45), "y", CAP, 20)
    k.box((0.24, 0.02, 0.13), (-0.55, 0.035, 0.63), CAP, 0.005, 1, rot=(0, 0, 6))
    k.cyl(0.05, 0.004, (-0.55, 0.155, 0.53), "x", "white_paint_worn", 14, rot=(0, 0, 0))  # blank badge (emblem: ПР-12)
    # the hero's mallet beside him
    k.cyl(0.025, 0.7, (0.72, 0.03, 0.15), "x", WOOD, 8, rot=(0, -35, 0))
    k.cyl(0.11, 0.3, (0.98, 0.11, 0.33), "z", WOOD, 12, rot=(0, -35, 0), cap_bevel=0.015)
    k.torus(0.11, 0.012, (0.98, 0.11, 0.33), "z", IRON, 14, 4)
    k.rescale(centre_xz=True, ground=True)


# ----------------------------------------------------------------------------- Н-04 brazier
@prop("dream_brazier", "Н-04", (1.02, 1.48, 1.04), "floor", 2000,
      notes="Iron brazier: bowl Ø 1 on three spiked legs, cold coals; DreamRemains lights its Fire (OmniLight3D) at "
            "0.8 m over the Brazier body, i.e. 1.3 m over the floor")
def dream_brazier(k: Kit):
    lathe(k, [(0.5, 1.3), (0.44, 1.05), (0.3, 0.9), (0.08, 0.86), (0.0, 0.86), (0.0, 0.92), (0.26, 0.96), (0.4, 1.1),
              (0.46, 1.3)], IRON, 24)
    lathe(k, [(0.15, 0.0), (0.2, 0.0), (0.2, 0.06), (0.15, 0.06)], IRON, 16)
    k.cyl(0.07, 0.86, (0, 0.43, 0), "y", IRON, 8)
    for i in range(3):
        a = 2 * math.pi * i / 3
        x, z = math.sin(a), math.cos(a)
        k.box((0.06, 0.95, 0.06), (x * 0.33, 0.55, z * 0.33), IRON, 0.005, 1, rot=(math.degrees(-0.35 * z), 0, math.degrees(0.35 * x)))
        spike(k, (x * 0.5, 1.28, z * 0.5), 0.2, 0.04, seg=5)
    k.torus(0.48, 0.03, (0, 1.29, 0), "y", BRONZE, 24, 4)
    for i in range(7):
        k.chunk((math.sin(i * 1.7) * 0.22, 1.05, math.cos(i * 1.7) * 0.22), (0.11, 0.07, 0.1), 600 + i, ROCK, 7)


# ----------------------------------------------------------------------------- guard niche frame (К-02 dressing)
@prop("dream_guard_niche", "К-02", (3.46, 4.4, 0.9), "floor", 1500, center_z=False,
      notes="Frame round a 2.5 × 3.5 m guard niche of the yard: jambs, spiked lintel, dark back; origin on the floor at "
            "the back of the niche, opening to +Z (#184 guards stand in front of it)")
def dream_guard_niche(k: Kit):
    for s in (-1, 1):
        k.box((0.4, 3.9, 0.6), (s * 1.5, 1.95, 0.3), STONE, 0.03, 1)
        k.box((0.46, 0.25, 0.62), (s * 1.5, 0.125, 0.31), STONE, 0.03, 1)
    k.box((3.4, 0.5, 0.6), (0, 4.15, 0.3), STONE, 0.03, 1)
    for x in (-1.0, 0.0, 1.0):
        spike(k, (x, 3.9, 0.55), 0.35, 0.07, "+z", BONE, 5)
    k.box((2.6, 0.1, 0.5), (0, 0.05, 0.25), FLOOR, 0.01, 1)


# ----------------------------------------------------------------------------- С-01 shadow guard
@prop("dream_shade_guard", "С-01", (1.79, 2.6, 1.27), "floor", 15000, center_z=False, views=[((0.8, 0.5, 1.4), (0, 0, 0)), ((-1.2, 0.4, -1.0), (0, 0, 0))],
      notes="Armoured warrior 2.6 m (Д-2): spiked carapace on the back, horned helm, claws; one material (DreamEnemy "
            "overrides it with the shadow shader DT-12), no skeleton; origin on the floor, front +Z")
def dream_shade_guard(k: Kit):
    m = BONE
    for s in (-1, 1):                                                           # legs
        k.cyl(0.14, 0.62, (s * 0.24, 0.42, 0.04), "y", m, 10, r2=0.11)
        k.sphere(0.13, (s * 0.24, 0.76, 0.06), m, 10)
        k.cyl(0.17, 0.55, (s * 0.25, 1.02, 0.0), "y", m, 10, r2=0.14)
        k.box((0.26, 0.14, 0.42), (s * 0.24, 0.07, 0.1), m, 0.03, 1)
        for c in (-0.08, 0.0, 0.08):
            spike(k, (s * 0.24 + c, 0.06, 0.31), 0.12, 0.03, "+z", m, 4)
        spike(k, (s * 0.24, 0.8, 0.17), 0.16, 0.05, "+z", m, 5)                 # knee spikes
    k.sphere(0.36, (0, 1.38, 0.0), m, 14, scale=(1.0, 0.65, 0.85))             # hips
    k.sphere(0.48, (0, 1.78, 0.02), m, 16, scale=(1.0, 0.95, 0.8))            # chest
    k.box((0.5, 0.3, 0.12), (0, 1.62, 0.37), m, 0.04, 1)                       # belly plates
    k.box((0.44, 0.22, 0.12), (0, 1.36, 0.3), m, 0.04, 1)
    k.sphere(0.58, (0, 1.82, -0.3), m, 18, scale=(1.05, 1.1, 0.55))           # carapace
    k.torus(0.5, 0.05, (0, 1.82, -0.42), "z", m, 24, 5)
    for y, xs in ((2.25, (-0.25, 0.25)), (1.9, (-0.42, 0.0, 0.42)), (1.5, (-0.3, 0.3))):
        for x in xs:
            spike(k, (x, y, -0.55), 0.38, 0.1, "-z", m, 6)
    for s in (-1, 1):                                                           # pauldrons and arms
        k.sphere(0.24, (s * 0.58, 2.1, 0.0), m, 12, scale=(1.0, 0.8, 1.0))
        spike(k, (s * 0.62, 2.22, 0.0), 0.3, 0.07, "up", m, 5)
        spike(k, (s * 0.72, 2.12, 0.0), 0.24, 0.06, "+x" if s > 0 else "-x", m, 5)
        k.cyl(0.11, 0.5, (s * 0.66, 1.78, 0.04), "y", m, 8, r2=0.1)
        k.cyl(0.1, 0.5, (s * 0.7, 1.32, 0.12), "y", m, 8, r2=0.12, rot=(-15, 0, 0))
        k.torus(0.12, 0.03, (s * 0.7, 1.3, 0.12), "y", m, 12, 4)
        k.sphere(0.12, (s * 0.71, 1.0, 0.2), m, 10)
        for c in (-0.05, 0.0, 0.05):
            k.cyl(0.02, 0.2, (s * 0.71 + c, 0.88, 0.27), "y", m, 4, r2=0.0, rot=(180, 0, 0))   # claws
    k.cyl(0.13, 0.16, (0, 2.3, 0.04), "y", m, 8)                               # neck
    k.sphere(0.24, (0, 2.46, 0.08), m, 14, scale=(0.95, 0.85, 1.05))           # helm
    k.box((0.3, 0.12, 0.2), (0, 2.34, 0.26), m, 0.03, 1)                       # jaw guard
    for s in (-1, 1):
        k.tube([(s * 0.16, 2.55, 0.05), (s * 0.34, 2.62, 0.0), (s * 0.44, 2.75, -0.08), (s * 0.4, 2.6 + 0.0, -0.18)],
               0.045, m, 8)                                                     # curled horns
        k.cyl(0.05, 0.1, (s * 0.4, 2.56, -0.2), "y", m, 6, r2=0.0, rot=(180, 0, 0))
    spike(k, (0, 2.62, 0.0), 0.14, 0.05, "up", m, 5)
    f = 2.6 / 2.79                                                              # horns and crest end at 2.6 m
    k.rescale(f, f, f, ground=True)
