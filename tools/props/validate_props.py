#!/usr/bin/env python3
"""Validates exported props against tools/props/registry.py and checks asset provenance.

Usage: python3 tools/props/validate_props.py [prop_id ...]   (needs no Blender: reads glTF + .bin directly)
Checks: bounding box vs. catalog size, anchor (floor / wall / ceiling), triangle budget, known materials,
existing texture files, and that every file under loads/props and loads/textures is listed in manifest.json.
Exit code 1 on any failure.
"""
from __future__ import annotations

import fnmatch
import json
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def accessor(data, buffers, idx):
    a = data["accessors"][idx]
    bv = data["bufferViews"][a["bufferView"]]
    raw = buffers[bv["buffer"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    stride = bv.get("byteStride", size * n)
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = []
    for i in range(a["count"]):
        out.append(struct.unpack_from("<" + fmt * n, raw, off + i * stride))
    return out


def node_world(data, i, parent=(0.0, 0.0, 0.0)):
    n = data["nodes"][i]
    t = n.get("translation", [0, 0, 0])
    return tuple(parent[k] + t[k] for k in range(3))


def analyse(gltf: Path):
    data = json.loads(gltf.read_text(encoding="utf-8"))
    buffers = [(gltf.parent / b["uri"]).read_bytes() for b in data["buffers"]]
    parents = {}
    for i, n in enumerate(data["nodes"]):
        for c in n.get("children", []):
            parents[c] = i
    lo, hi, tris = [1e9] * 3, [-1e9] * 3, 0
    for i, n in enumerate(data["nodes"]):
        if "mesh" not in n:
            continue
        off = (0.0, 0.0, 0.0)
        j = i
        chain = []
        while j is not None:
            chain.append(j)
            j = parents.get(j)
        for j in chain:
            off = node_world(data, j, off)
        for p in data["meshes"][n["mesh"]]["primitives"]:
            for v in accessor(data, buffers, p["attributes"]["POSITION"]):
                for k in range(3):
                    lo[k] = min(lo[k], v[k] + off[k])
                    hi[k] = max(hi[k], v[k] + off[k])
            tris += data["accessors"][p["indices"]]["count"] // 3 if "indices" in p else data["accessors"][p["attributes"]["POSITION"]]["count"] // 3
    return data, lo, hi, tris


def check_prop(spec, errors, notes):
    from registry import PropSpec  # noqa: F401
    gltf = REPO / "loads" / "props" / spec.id / f"{spec.id}.gltf"
    if not gltf.exists():
        errors.append(f"{spec.id}: {gltf.relative_to(REPO)} is missing (run build_props.py)")
        return
    data, lo, hi, tris = analyse(gltf)
    size = [hi[k] - lo[k] for k in range(3)]
    for k, axis in enumerate("xyz"):
        want = spec.size[k]
        if abs(size[k] - want) > max(0.02, want * spec.tolerance):
            errors.append(f"{spec.id}: size {axis} = {size[k]:.3f} m, catalog says {want:.3f} m")
    cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    if spec.anchor == "floor":
        if abs(lo[1]) > 0.012:
            errors.append(f"{spec.id}: floor prop must sit on y = 0, min y = {lo[1]:.3f}")
        if abs(cx) > 0.05 * max(spec.size[0], 1) or abs(cz) > 0.05 * max(spec.size[2], 1):
            errors.append(f"{spec.id}: floor prop must be centred on x/z, centre = ({cx:.3f}, {cz:.3f})")
    elif spec.anchor == "wall":
        if abs(lo[2]) > 0.012:
            errors.append(f"{spec.id}: wall prop must have its back on z = 0, min z = {lo[2]:.3f}")
        if abs(cx) > 0.05 * max(spec.size[0], 1):
            errors.append(f"{spec.id}: wall prop must be centred on x, centre x = {cx:.3f}")
    elif spec.anchor == "ceiling":
        if abs(hi[1]) > 0.012:
            errors.append(f"{spec.id}: ceiling prop must hang from y = 0, max y = {hi[1]:.3f}")
    if tris > spec.tris_max:
        errors.append(f"{spec.id}: {tris} triangles exceed the budget {spec.tris_max}")
    from propkit import ATLAS, EMIT, PLAIN, TILE
    known = set(TILE) | set(ATLAS) | set(EMIT) | set(PLAIN)
    for m in data.get("materials", []):
        if m["name"] not in known:
            errors.append(f"{spec.id}: unknown material '{m['name']}'")
    for im in data.get("images", []):
        if not (gltf.parent / im["uri"]).resolve().exists():
            errors.append(f"{spec.id}: texture {im['uri']} does not exist")
    if re.search(r"\.\d{3}$", json.dumps([m["name"] for m in data.get("materials", [])])):
        errors.append(f"{spec.id}: duplicated material names")
    kb = sum(p.stat().st_size for p in gltf.parent.iterdir()) / 1024
    notes.append(f"{spec.id:20s} {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} m  {tris:6d} tris  {kb:6.0f} KB")


def check_manifest(errors):
    manifest = json.loads((Path(__file__).with_name("manifest.json")).read_text(encoding="utf-8"))
    pats = []
    for e in manifest["entries"]:
        g = e["glob"]
        # expand {a,b,c} groups
        m = re.search(r"\{([^}]*)\}", g)
        variants = [g.replace(m.group(0), v) for v in m.group(1).split(",")] if m else [g]
        pats += [(v, e) for v in variants]
        for key in ("source", "license", "author"):
            if not e.get(key):
                errors.append(f"manifest: entry '{g}' lacks '{key}'")
    for root in ("loads/props", "loads/textures"):
        base = REPO / root
        if not base.exists():
            continue
        for f in base.rglob("*"):
            if not f.is_file() or f.suffix in (".import", ".uid"):
                continue
            rel = f.relative_to(REPO).as_posix()
            if not any(fnmatch.fnmatch(rel, p) or fnmatch.fnmatch(rel, p.replace("**", "*")) for p, _ in pats):
                errors.append(f"manifest: {rel} has no provenance entry")


def main() -> int:
    import props_start  # noqa: F401
    for mod in ("props_repair", "props_set", "props_fix"):
        try:
            __import__(mod)
        except ModuleNotFoundError:
            pass
    from registry import PROPS
    ids = sys.argv[1:] or list(PROPS)
    errors, notes = [], []
    for pid in ids:
        check_prop(PROPS[pid], errors, notes)
    check_manifest(errors)
    print("\n".join(notes))
    if errors:
        print("\nFAILED:")
        print("\n".join("  " + e for e in errors))
        return 1
    print(f"\nOK: {len(ids)} props validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
