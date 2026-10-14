#!/usr/bin/env python3
"""Downloads the Poly Haven materials listed in sourced_textures.json and writes them in the project format.

Usage: python3 tools/props/import_textures.py [material ...]
Output per material (same paths as make_textures.py, so every model picks them up unchanged):
  loads/textures/<m>/<m>_albedo.jpg (graded into the palette), <m>_normal.png (OpenGL), <m>_orm.jpg (Poly Haven ARM =
  occlusion, roughness, metal). Optional "blocks": [length, height] cuts running-bond joints into the scan. Writes the tile size in metres (Poly Haven real-world dimensions) to sourced_tiles.json
  and records provenance in manifest.json. Licence: CC0 (polyhaven.com/license).
"""
from __future__ import annotations

import io
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
UA = {"User-Agent": "caretaker-art-pipeline/1.0"}
RES = "1k"


def fetch(url: str) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()


def grade(img: Image.Image, sat: float, lum: float, tint=None, tint_mix: float = 0.0) -> Image.Image:
    a = np.asarray(img.convert("RGB"), np.float32) / 255.0
    y = (a @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    a = y + (a - y) * sat
    if tint is not None and tint_mix > 0:
        a = a * (1 - tint_mix) + (y / max(float(y.mean()), 1e-4)) * np.array(tint, np.float32) * tint_mix
    cur = float((a @ np.array([0.2126, 0.7152, 0.0722], np.float32)).mean())
    a = np.clip(a * (lum / max(cur, 1e-4)), 0, 1)
    return Image.fromarray((a * 255 + 0.5).astype(np.uint8))


def block_joints(size: int, tile: float, block: list[float], width_m: float = 0.035) -> np.ndarray:
    """Running-bond joints of `block` = [length, height] metres over one tile: 1 in the joint, 0 on the block face."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) * (tile / size)
    row = np.floor(yy / block[1])
    u = (xx + (row % 2) * block[0] * 0.5) % block[0]
    v = yy % block[1]
    d = np.minimum(np.minimum(u, block[0] - u), np.minimum(v, block[1] - v))
    return np.clip(1.0 - d / width_m, 0.0, 1.0)


def add_blocks(albedo: Image.Image, normal: Image.Image, orm: Image.Image, tile: float, block: list[float]):
    """Cuts large block joints (decision D-1) into a scan: darker albedo, a groove in the normal map, less AO."""
    sys.path.insert(0, str(HERE))
    import texlib as T
    j = block_joints(albedo.width, tile, block)
    a = np.asarray(albedo, np.float32) / 255.0 * (1.0 - 0.6 * j[..., None])
    groove = T.normal_from_height(1.0 - T.blur(j, 1.5), 3.0) * 2.0 - 1.0
    n = np.asarray(normal.resize(albedo.size), np.float32) / 127.5 - 1.0
    n = n + groove * np.array([1.0, 1.0, 0.0], np.float32)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    o = np.asarray(orm.resize(albedo.size), np.float32) / 255.0
    o[..., 0] *= 1.0 - 0.5 * j
    o[..., 1] = np.maximum(o[..., 1], 0.85 * j)
    to8 = lambda x: Image.fromarray((np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8))
    return to8(a), to8(n * 0.5 + 0.5), to8(o)


def import_material(name: str, cfg: dict, manifest: dict, tiles: dict):
    asset = cfg["asset"]
    files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset}"))
    info = json.loads(fetch(f"https://api.polyhaven.com/info/{asset}"))
    out = REPO / "loads" / "textures" / name
    out.mkdir(parents=True, exist_ok=True)
    diff = Image.open(io.BytesIO(fetch(files["Diffuse"][RES]["jpg"]["url"])))
    albedo = grade(diff, cfg["sat"], cfg["lum"], cfg.get("tint"), cfg.get("tint_mix", 0.0))
    normal = Image.open(io.BytesIO(fetch(files["nor_gl"][RES]["jpg"]["url"]))).convert("RGB")
    orm = Image.open(io.BytesIO(fetch(files["arm"][RES]["jpg"]["url"]))).convert("RGB")
    dims = info.get("dimensions") or [2000, 2000]
    tiles[name] = cfg.get("tile") or round(max(dims[0], dims[1]) / 1000.0, 3)
    if cfg.get("blocks"):
        albedo, normal, orm = add_blocks(albedo, normal, orm, tiles[name], cfg["blocks"])
    albedo.save(out / f"{name}_albedo.jpg", quality=92, subsampling=0, optimize=True)
    normal.save(out / f"{name}_normal.png", optimize=True)
    orm.save(out / f"{name}_orm.jpg", quality=95, subsampling=0, optimize=True)
    manifest["entries"] = [e for e in manifest["entries"] if e.get("glob") != f"loads/textures/{name}/*"]
    manifest["entries"].insert(0, {
        "glob": f"loads/textures/{name}/*", "kind": "texture", "source": f"https://polyhaven.com/a/{asset}",
        "author": ", ".join(info.get("authors", {}).keys()) or "Poly Haven", "license": "CC0-1.0",
        "modified": f"graded into the palette by tools/props/import_textures.py ({RES}, sat {cfg['sat']}, lum {cfg['lum']}"
                    + (f", tint {cfg['tint']} x {cfg.get('tint_mix', 0.0)}" if cfg.get("tint") else "")
                    + (f", block joints {cfg['blocks'][0]} x {cfg['blocks'][1]} m" if cfg.get("blocks") else "") + ")"})
    print(f"{name:20s} <- {asset:24s} tile {tiles[name]} m  by {manifest['entries'][0]['author']}")


def main() -> int:
    cfg = json.loads((HERE / "sourced_textures.json").read_text(encoding="utf-8"))["materials"]
    manifest_path = HERE / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    tiles_path = HERE / "sourced_tiles.json"
    tiles = json.loads(tiles_path.read_text(encoding="utf-8")) if tiles_path.exists() else {}
    for name in sys.argv[1:] or cfg:
        import_material(name, cfg[name], manifest, tiles)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tiles_path.write_text(json.dumps(dict(sorted(tiles.items())), indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
