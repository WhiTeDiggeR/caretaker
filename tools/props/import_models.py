#!/usr/bin/env python3
"""Brings the Poly Haven models of sourced_models.json into the project standard (runs in the `bpy` module).

Usage: python3 tools/props/import_models.py [id ...] [--preview DIR]
For every entry: downloads the 1k glTF, applies transforms, optionally splits a modular kit into pieces, rotates the
front to Godot +Z, puts the origin on the anchor (floor / wall / ceiling / free, docs/game_design/02-prop-standard.md §5),
decimates above the triangle budget, grades the albedo into the palette and exports
loads/props/ph_<id>/<piece>.gltf with its own textures. Writes specs.json entries and manifest.json provenance (CC0).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

import bpy  # noqa: I001  (must precede bmesh / mathutils users)
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
UA = {"User-Agent": "caretaker-art-pipeline/1.0"}
CACHE = Path("/tmp/caretaker_polyhaven_cache")
RES = "1k"


def fetch(url: str) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180).read()


def download(asset: str) -> tuple[Path, dict]:
    info = json.loads(fetch(f"https://api.polyhaven.com/info/{asset}"))
    d = CACHE / asset
    gltf = d / f"{asset}.gltf"
    if not gltf.exists():
        files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset}"))
        g = files["gltf"][RES]["gltf"]
        d.mkdir(parents=True, exist_ok=True)
        for rel, inc in g.get("include", {}).items():
            (d / rel).parent.mkdir(parents=True, exist_ok=True)
            (d / rel).write_bytes(fetch(inc["url"]))
        gltf.write_bytes(fetch(g["url"]))
    return gltf, info


def snake(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def tri_count(objs) -> int:
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def world_bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def grade_images(objs, sat: float, val: float, done: set):
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.use_nodes:
                continue
            for link in m.node_tree.links:
                if link.to_socket.name == "Base Color" and link.from_node.type == "TEX_IMAGE":
                    img = link.from_node.image
                    if img is None or img.name in done:
                        continue
                    done.add(img.name)
                    px = np.empty(len(img.pixels), np.float32)
                    img.pixels.foreach_get(px)
                    a = px.reshape(-1, 4)
                    y = (a[:, :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32))[:, None]
                    a[:, :3] = np.clip((y + (a[:, :3] - y) * sat) * val, 0, 1)
                    img.pixels.foreach_set(a.ravel())
                    img.update()


def place(objs, anchor: str, rot_deg: float):
    """Rotates about the vertical axis and moves the geometry so the origin sits on the anchor (Blender Z-up,
    Godot front +Z = Blender -Y)."""
    rot = Matrix.Rotation(np.radians(rot_deg), 4, "Z")
    for o in objs:
        o.data.transform(rot)
    lo, hi = world_bounds(objs)
    c = (lo + hi) / 2
    if anchor == "floor":
        off = Vector((-c.x, -c.y, -lo.z))
    elif anchor == "wall":
        off = Vector((-c.x, -hi.y, -lo.z))       # back plane (Godot z = 0) is Blender max Y
    elif anchor == "ceiling":
        off = Vector((-c.x, -c.y, -hi.z))
    else:
        off = -c
    for o in objs:
        o.data.transform(Matrix.Translation(off))


def export(objs, path: Path):
    select_only(objs)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                              export_apply=True, export_image_format="JPEG", export_jpeg_quality=88,
                              export_cameras=False, export_lights=False, export_extras=False)


def import_entry(e: dict, defaults: dict, specs: dict, manifest: dict, preview: Path | None):
    pid = "ph_" + e["id"]
    gltf, info = download(e["asset"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(gltf))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    select_only(meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    # some source files carry a stray scale: trust Poly Haven's real-world dimensions (mm) when they disagree by > 20 %
    real = max(info.get("dimensions") or [0]) / 1000.0
    if real > 0:
        lo, hi = world_bounds(meshes)
        got = max(hi - lo)
        if got > 0 and not 0.8 < got / real < 1.25:
            k = real / got
            for o in meshes:
                o.data.transform(Matrix.Scale(k, 4))
            print(f"{e['id']}: rescaled x{k:.3f} to match {real:.2f} m")
    grade_images(meshes, e.get("sat", defaults["sat"]), e.get("val", defaults["val"]), set())
    groups = [[o] for o in meshes] if e.get("split") else [meshes]
    out_dir = REPO / "loads" / "props" / pid
    for old in out_dir.glob("*") if out_dir.exists() else []:
        old.unlink()
    for g in groups:
        if len(g) > 1:
            select_only(g)
            bpy.ops.object.join()
            g = [bpy.context.view_layer.objects.active]
        obj = g[0]
        piece = pid if not e.get("split") else f"{pid}__{snake(obj.name.replace(e['asset'], '').replace(e.get('strip', '#'), ''))}"
        obj.name = piece.split("__")[-1] if e.get("split") else "Body"
        place(g, e["anchor"], e.get("rot", defaults["rot"]))
        tris = tri_count(g)
        if tris > e["tris"]:
            mod = obj.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = max(0.05, e["tris"] / tris * 0.97)
            select_only(g)
            bpy.ops.object.modifier_apply(modifier=mod.name)
            tris = tri_count(g)
        lo, hi = world_bounds(g)
        size = [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)]  # Godot x, y, z
        name = piece.split("__")[-1] if e.get("split") else pid
        path = out_dir / f"{name}.gltf"
        export(g, path)
        specs[piece] = {"catalog": e.get("catalog", "P-3xx"), "size": size, "anchor": e["anchor"], "tris_max": e["tris"],
                        "tolerance": 0.03, "center_z": True, "external": True,
                        "gltf": str(path.relative_to(REPO / "loads" / "props")).replace("\\", "/")}
        print(f"{piece:44s} {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}  {tris:6d} tris")
    authors = ", ".join(info.get("authors", {}).keys()) or "Poly Haven"
    manifest["entries"] = [x for x in manifest["entries"] if x.get("glob") != f"loads/props/{pid}/*"]
    manifest["entries"].insert(0, {"glob": f"loads/props/{pid}/*", "kind": "model", "source": f"https://polyhaven.com/a/{e['asset']}",
                                   "author": authors, "license": "CC0-1.0",
                                   "modified": f"{RES} textures graded (sat {e.get('sat', defaults['sat'])}, val {e.get('val', defaults['val'])}), "
                                               f"origin on the {e['anchor']} anchor, decimated to <= {e['tris']} triangles by tools/props/import_models.py"})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--preview")
    a = ap.parse_args()
    cfg = json.loads((HERE / "sourced_models.json").read_text(encoding="utf-8"))
    specs_path, manifest_path = HERE / "specs.json", HERE / "manifest.json"
    specs = json.loads(specs_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = [m for m in cfg["models"] if not a.ids or m["id"] in a.ids]
    for e in entries:
        pid = "ph_" + e["id"]
        for k in [k for k in specs if k == pid or k.startswith(pid + "__")]:
            del specs[k]
        try:
            import_entry(e, cfg["defaults"], specs, manifest, Path(a.preview) if a.preview else None)
        except Exception as exc:  # keep going; report at the end
            print(f"FAILED {e['id']}: {exc!r}", file=sys.stderr)
    specs_path.write_text(json.dumps(dict(sorted(specs.items())), indent=1) + "\n", encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
