#!/usr/bin/env python3
"""Lightweight copies of the text-to-3d prisoner capsules (#130). The originals stay untouched.

Usage: python3 tools/props/lighten_capsules.py [--tris 40000] [--tex 2048] [--bake]
For each capsule: decimates the ~2M-triangle mesh (collapse, UVs kept), optionally bakes the high-poly surface into a
tangent-space normal map on the low mesh, downsizes the textures and writes
loads/<capsule>/lod/<capsule>_lod.gltf (+ .bin, textures). Units and axes match the original GLB, so scenes that scale
the original by 5 can use the light copy the same way.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy  # noqa: I001

REPO = Path(__file__).resolve().parents[2]
CAPSULES = {"bowser_capsule": "Hitem3d-1782155776080.glb", "herobrine_capsule": "Hitem3d-1782239593585.glb"}


def tris(o) -> int:
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[-1]


def bake_normals(high, low, size: int) -> bpy.types.Image:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    img = bpy.data.images.new(f"{low.name}_nor_baked", size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    mat = low.active_material
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    select_only([high, low])
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = 0.01
    bake.max_ray_distance = 0.03
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
    # route the baked map into the material's normal input
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(node.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return img


def lighten(name: str, glb: str, target: int, tex: int, do_bake: bool):
    src = REPO / "loads" / name / glb
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    high = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    t0 = tris(high)
    select_only([high])
    bpy.ops.object.duplicate()
    low = bpy.context.view_layer.objects.active
    low.name = f"{name}_lod"
    mod = low.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = target / t0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if do_bake:
        bake_normals(high, low, tex)
    bpy.data.objects.remove(high)
    for img in bpy.data.images:
        if img.size[0] > tex:
            img.scale(tex, tex)
    out = REPO / "loads" / name / "lod" / f"{name}_lod.gltf"
    out.parent.mkdir(parents=True, exist_ok=True)
    for f in out.parent.glob("*"):
        f.unlink()
    select_only([low])
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLTF_SEPARATE", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=90, export_apply=True)
    size = sum(f.stat().st_size for f in out.parent.iterdir()) / 1e6
    print(f"{name}: {t0} -> {tris(low)} triangles, {size:.1f} MB -> {out.relative_to(REPO)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tris", type=int, default=40000)
    ap.add_argument("--tex", type=int, default=2048)
    ap.add_argument("--bake", action="store_true")
    a = ap.parse_args()
    for name, glb in CAPSULES.items():
        lighten(name, glb, a.tris, a.tex, a.bake)
    return 0


if __name__ == "__main__":
    sys.exit(main())
