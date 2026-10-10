#!/usr/bin/env python3
"""Generates the shared tiling PBR materials of docs/art/texture-catalog.md.

Usage: python3 tools/props/make_textures.py [material ...] [--out loads/textures] [--size 1024]
Each material writes <out>/<id>/<id>_albedo.jpg, _normal.png and _orm.jpg (R=occlusion, G=roughness, B=metallic).
Deterministic: every recipe uses fixed seeds. Colours are authored directly in sRGB (see docs/art/style-guide.md).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import texlib as T  # noqa: E402


def _c(*rgb):
    return np.array(rgb, np.float32)


def _scratches(seed, n_fine=260, n_deep=40, base_angle=0.0, jitter=0.3):
    fine = T.lines(seed, n_fine, (30, 160), 1.0, jitter, base_angle)
    deep = T.lines(seed + 1, n_deep, (90, 380), 1.6, jitter * 0.6, base_angle)
    return fine, deep


def _rib_profile(size, count, sharp):
    p = (np.arange(size, dtype=np.float32) / size * count) % 1.0
    prof = np.exp(-((p - 0.5) ** 2) / sharp)
    return prof[None, :] * np.ones((size, 1), np.float32)


def painted_metal(size):
    fb, fine = T.fbm(11, 2.6), T.fbm(12, 1.2)
    seams = T.grid_seams(size, 2, 2.2)
    seam_soft = T.blur(seams, 3.0)
    riv = T.rivets(size, 2, 22, 3.6, per_edge=5)
    streak = T.fbm(13, 2.2, stretch=(1.0, 0.04))  # vertical drip streaks
    wear = T.smoothstep(0.58, 0.70, T.fbm(14, 2.0) * 0.7 + seam_soft * 0.35 + T.fbm(15, 0.8) * 0.25)
    scr_fine, scr_deep = _scratches(16)
    wear = np.clip(wear + scr_deep * 0.9, 0, 1)

    paint = T.lerp(_c(0.085, 0.09, 0.095), _c(0.17, 0.175, 0.18), fb[..., None]) * (0.9 + 0.2 * fine[..., None])
    paint = paint * (1.0 - 0.28 * T.smoothstep(0.35, 0.9, streak)[..., None])
    steel = T.lerp(_c(0.30, 0.30, 0.31), _c(0.46, 0.45, 0.43), fine[..., None])
    rust = T.colorize(T.fbm(17, 1.6), [(0.0, (0.16, 0.07, 0.03)), (1.0, (0.34, 0.15, 0.06))])
    rusty = T.smoothstep(0.55, 0.8, T.fbm(18, 2.4)) * wear
    base = steel * (1 - rusty[..., None]) + rust * rusty[..., None]
    albedo = paint * (1 - wear[..., None]) + base * wear[..., None]
    albedo = albedo * (1 - 0.35 * seams[..., None])
    albedo = np.clip(albedo + scr_fine[..., None] * 0.07, 0, 1)

    height = 0.5 - seams * 0.25 + riv * 0.22 + fine * 0.04 - wear * 0.05 - scr_deep * 0.08
    rough = T.lerp(0.62, 0.8, fine) * (1 - wear) + T.lerp(0.4, 0.62, fine) * wear
    rough = np.clip(rough + rusty * 0.3 - scr_fine * 0.1, 0.2, 1)
    metal = np.clip(wear * (1 - rusty * 0.7), 0, 1)
    return albedo, height, T.cavity(height) * (1 - 0.3 * seams), rough, metal, 3.5


def steel_bare(size):
    br, fine, blotch = T.fbm(21, 1.6, stretch=(0.03, 1.0)), T.fbm(22, 1.0, stretch=(0.08, 1.0)), T.fbm(23, 2.6)
    scr_fine, scr_deep = _scratches(24, 420, 70, 0.0, 0.12)
    albedo = T.lerp(_c(0.34, 0.34, 0.35), _c(0.52, 0.52, 0.52), (0.6 * br + 0.4 * fine)[..., None])
    albedo = albedo * (0.82 + 0.3 * blotch[..., None])
    stain = T.smoothstep(0.62, 0.85, T.fbm(25, 2.8))
    albedo = albedo * (1 - 0.45 * stain[..., None]) + _c(0.2, 0.12, 0.07) * (0.45 * stain[..., None])
    albedo = np.clip(albedo + scr_fine[..., None] * 0.08 + scr_deep[..., None] * 0.12, 0, 1)
    height = 0.5 + br * 0.05 + fine * 0.03 - scr_deep * 0.1 - scr_fine * 0.04
    rough = np.clip(T.lerp(0.32, 0.55, br) + stain * 0.2 - scr_fine * 0.12, 0.15, 1)
    metal = np.clip(1.0 - stain * 0.3, 0, 1)
    return albedo, height, T.cavity(height, 4), rough, metal, 4.0


def rusted_steel(size):
    n1, n2, n3 = T.fbm(31, 2.4), T.fbm(32, 1.4), T.fbm(33, 0.9)
    patch = T.smoothstep(0.35, 0.65, n1)
    t = np.clip(n2 * 0.7 + n3 * 0.5, 0, 1)
    rust = T.colorize(t, [(0.0, (0.10, 0.045, 0.02)), (0.45, (0.26, 0.11, 0.045)),
                          (0.8, (0.40, 0.19, 0.07)), (1.0, (0.46, 0.27, 0.12))])
    steel = T.lerp(_c(0.13, 0.13, 0.135), _c(0.26, 0.26, 0.27), n3[..., None])
    albedo = steel * (1 - patch[..., None]) + rust * patch[..., None]
    pit = T.smoothstep(0.7, 0.9, T.fbm(34, 0.6)) * patch
    albedo = albedo * (1 - 0.4 * pit[..., None])
    height = 0.5 + n2 * 0.1 * patch + n3 * 0.07 - pit * 0.15
    rough = np.clip(0.55 + patch * 0.4 + n3 * 0.05, 0.3, 1)
    metal = np.clip(0.9 - patch * 0.85, 0, 1)
    return albedo, height, T.cavity(height, 5) * (1 - pit * 0.4), rough, metal, 4.0


def diamond_plate(size):
    cells = 8
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cs = size / cells
    u, v = (xx % cs) / cs - 0.5, (yy % cs) / cs - 0.5
    alt = (((xx // cs).astype(int) + (yy // cs).astype(int)) % 2) == 0
    ang = np.where(alt, 0.785398, -0.785398)
    ru = u * np.cos(ang) - v * np.sin(ang)
    rv = u * np.sin(ang) + v * np.cos(ang)
    lug = T.smoothstep(0.0, 0.35, np.clip(1.0 - np.sqrt((ru / 0.34) ** 2 + (rv / 0.09) ** 2), 0, 1))
    n1, n2 = T.fbm(41, 2.4), T.fbm(42, 1.2)
    dirt = T.smoothstep(0.4, 0.8, n1) * (1 - lug * 0.6)
    scr_fine, scr_deep = _scratches(43, 300, 50)
    albedo = np.full((size, size, 3), 0.30, np.float32) * (0.8 + 0.4 * n2[..., None])
    albedo = albedo * (1 - 0.65 * dirt[..., None]) + lug[..., None] * 0.06
    albedo = np.clip(albedo + scr_fine[..., None] * 0.1, 0, 1)
    height = lug * 0.6 + n2 * 0.02 - scr_deep * 0.05
    rough = np.clip(0.42 + dirt * 0.4 - lug * 0.1 - scr_fine * 0.1, 0.15, 1)
    metal = np.clip(0.95 - dirt * 0.5, 0, 1)
    return albedo, height, T.cavity(height, 8) * (1 - 0.4 * dirt), rough, metal, 3.0


def rubber_black(size):
    fine, mid = T.fbm(51, 0.8), T.fbm(52, 2.2)
    scr_fine, _ = _scratches(53, 200, 8)
    albedo = np.full((size, size, 3), 0.032, np.float32) * (0.8 + 0.5 * fine[..., None]) + mid[..., None] * 0.012
    albedo = albedo + scr_fine[..., None] * 0.02
    height = 0.5 + fine * 0.08 + mid * 0.05
    rough = np.clip(0.72 + fine * 0.2 - scr_fine * 0.15, 0.3, 1)
    return albedo, height, T.cavity(height, 3), rough, np.zeros_like(rough), 4.0


def plastic_panel(size):
    fine, mid = T.fbm(61, 1.0), T.fbm(62, 2.4)
    seams = T.grid_seams(size, 2, 1.4)
    scr_fine, scr_deep = _scratches(63, 380, 60)
    grime = T.smoothstep(0.5, 0.85, T.fbm(64, 2.6))
    albedo = np.full((size, size, 3), 0.062, np.float32) * (0.85 + 0.35 * mid[..., None])
    albedo = albedo * (1 - 0.25 * seams[..., None]) * (1 - 0.3 * grime[..., None])
    albedo = np.clip(albedo + scr_fine[..., None] * 0.09 + scr_deep[..., None] * 0.14, 0, 1)
    height = 0.5 - seams * 0.15 + fine * 0.04 - scr_deep * 0.06
    rough = np.clip(0.48 + fine * 0.18 + grime * 0.25 - scr_fine * 0.12, 0.2, 1)
    return albedo, height, T.cavity(height, 4) * (1 - 0.2 * seams), rough, np.zeros_like(rough), 4.0


def vinyl_worn(size):
    f1, f2, _ = T.voronoi(71, 56)
    crease = T.smoothstep(0.06, 0.0, f2)  # cell borders = fine creases
    mid, fine = T.fbm(72, 2.6), T.fbm(73, 1.0)
    wear = T.smoothstep(0.55, 0.78, T.fbm(74, 2.0))
    crack = T.smoothstep(0.03, 0.0, T.voronoi(75, 9)[1]) * T.smoothstep(0.45, 0.7, T.fbm(76, 2.0))
    base = T.lerp(_c(0.055, 0.05, 0.05), _c(0.12, 0.105, 0.095), mid[..., None])
    grain = np.clip(f1, 0, 1)
    albedo = base * (0.85 + 0.3 * (1 - grain)[..., None]) * (1 - 0.35 * crease[..., None])
    albedo = albedo + wear[..., None] * 0.035 - crack[..., None] * 0.04
    height = 0.5 + (1 - grain) * 0.18 - crease * 0.12 - crack * 0.12 + fine * 0.02
    rough = np.clip(0.5 + wear * 0.18 + crease * 0.15 + fine * 0.05, 0.25, 1)
    return albedo, height, T.cavity(height, 4) * (1 - 0.3 * crease), rough, np.zeros_like(rough), 3.0


def duct_galvanized(size):
    _, f2, ident = T.voronoi(81, 14)
    spangle = 0.8 + 0.4 * ident  # crystalline zinc spangle
    ribs = _rib_profile(size, 4, 0.0008)
    n1, n2 = T.fbm(82, 2.4), T.fbm(83, 1.2)
    streak = T.fbm(84, 2.2, stretch=(0.04, 1.0))
    grime = T.smoothstep(0.45, 0.85, n1 * 0.6 + streak * 0.5)
    scr_fine, scr_deep = _scratches(85, 300, 40, 0.0, 0.2)
    rustp = T.smoothstep(0.7, 0.88, T.fbm(86, 2.8)) * (0.4 + 0.6 * ribs)
    albedo = np.full((size, size, 3), 0.31, np.float32) * spangle[..., None] * (0.85 + 0.25 * n2[..., None])
    albedo = albedo * (1 - 0.5 * grime[..., None])
    albedo = albedo * (1 - rustp[..., None]) + _c(0.30, 0.13, 0.05) * rustp[..., None]
    albedo = np.clip(albedo + scr_fine[..., None] * 0.06, 0, 1)
    height = 0.5 + ribs * 0.35 - T.smoothstep(0.02, 0.0, f2) * 0.04 + n2 * 0.02 - scr_deep * 0.05
    rough = np.clip(0.42 + grime * 0.3 + rustp * 0.4 - scr_fine * 0.1, 0.2, 1)
    metal = np.clip(0.95 - rustp * 0.8 - grime * 0.2, 0, 1)
    return albedo, height, T.cavity(height, 6) * (1 - 0.3 * grime), rough, metal, 2.5


def concrete_rubble(size):
    big, mid, fine, grit = T.fbm(91, 2.8), T.fbm(92, 2.0), T.fbm(93, 1.0), T.fbm(94, 0.4)
    _, f2, _ = T.voronoi(95, 7)
    crack = T.smoothstep(0.07, 0.0, f2) * T.smoothstep(0.35, 0.6, T.fbm(96, 2.0))
    agg = T.smoothstep(0.78, 0.9, grit)  # aggregate stones
    dust = T.smoothstep(0.5, 0.85, T.fbm(97, 3.0))
    base = T.lerp(_c(0.13, 0.13, 0.135), _c(0.26, 0.255, 0.25), (0.5 * big + 0.5 * mid)[..., None])
    albedo = base * (0.9 + 0.2 * fine[..., None]) + agg[..., None] * 0.08 + dust[..., None] * 0.05 - crack[..., None] * 0.1
    height = 0.5 + big * 0.35 + mid * 0.18 + fine * 0.05 + agg * 0.05 - crack * 0.3
    rough = np.clip(0.88 + fine * 0.08 - agg * 0.1, 0.5, 1)
    return albedo, height, T.cavity(height, 8) * (1 - crack * 0.6), rough, np.zeros_like(rough), 5.0


def paper_aged(size):
    fib1, fib2 = T.fbm(101, 0.8, stretch=(1.0, 0.25)), T.fbm(102, 0.8, stretch=(0.25, 1.0))
    blot = T.fbm(103, 2.6)
    stain = T.smoothstep(0.55, 0.8, T.fbm(104, 2.2))
    fold = np.exp(-(((np.arange(size, dtype=np.float32) / size) - 0.5) ** 2) / 0.00002)[None, :] * np.ones((size, 1), np.float32)
    albedo = _c(0.60, 0.57, 0.50) * (0.9 + 0.06 * (fib1 + fib2)[..., None]) * (0.88 + 0.2 * blot[..., None])
    albedo = albedo * (1 - 0.5 * stain[..., None]) + _c(0.30, 0.20, 0.10) * (0.5 * stain[..., None])
    albedo = albedo * (1 - 0.18 * fold[..., None])
    height = 0.5 + (fib1 + fib2) * 0.03 - fold * 0.08
    rough = np.clip(0.88 + fib1 * 0.06, 0.6, 1)
    return albedo, height, T.cavity(height, 2), rough, np.zeros_like(rough), 2.5


RECIPES = {
    "painted_metal": painted_metal, "steel_bare": steel_bare, "rusted_steel": rusted_steel,
    "diamond_plate": diamond_plate, "rubber_black": rubber_black, "plastic_panel": plastic_panel,
    "vinyl_worn": vinyl_worn, "duct_galvanized": duct_galvanized, "concrete_rubble": concrete_rubble,
    "paper_aged": paper_aged,
}


def write_material(name: str, out_dir: Path, size: int) -> list[Path]:
    albedo, height, ao, rough, metal, strength = RECIPES[name](size)
    d = out_dir / name
    d.mkdir(parents=True, exist_ok=True)
    paths = []
    p = d / f"{name}_albedo.jpg"
    Image.fromarray((np.clip(albedo, 0, 1) * 255 + 0.5).astype(np.uint8)).save(p, quality=92, subsampling=0, optimize=True)
    paths.append(p)
    p = d / f"{name}_normal.png"
    Image.fromarray((T.normal_from_height(height, strength) * 255 + 0.5).astype(np.uint8)).save(p, optimize=True)
    paths.append(p)
    orm = np.stack([np.clip(ao, 0, 1), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], axis=-1)
    p = d / f"{name}_orm.jpg"
    Image.fromarray((orm * 255 + 0.5).astype(np.uint8)).save(p, quality=95, subsampling=0, optimize=True)
    paths.append(p)
    return paths


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("materials", nargs="*")
    ap.add_argument("--out", default="loads/textures")
    ap.add_argument("--size", type=int, default=T.SIZE)
    a = ap.parse_args()
    T.SIZE = a.size
    for n in a.materials or list(RECIPES):
        paths = write_material(n, Path(a.out), a.size)
        print(n, [f"{p.name} {p.stat().st_size // 1024}K" for p in paths])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
