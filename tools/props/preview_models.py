#!/usr/bin/env python3
"""Renders a contact sheet of exported glTF props (any source) with the preview lighting of propkit.

Usage: python3 tools/props/preview_models.py OUT.jpg [glob ...]   (default glob: loads/props/ph_*/*.gltf)
Runs in the `bpy` module; Cycles CPU, one front-three-quarter view per model.
"""
from __future__ import annotations

import sys
from pathlib import Path

import bpy  # noqa: I001
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
W, H = 480, 360


def setup(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.055, 0.065, 1)
    scene.world = world


def render(path: Path, out_png: Path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    setup(scene)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre, radius = (lo + hi) / 2, max((hi - lo).length / 2, 0.05)
    bpy.ops.mesh.primitive_plane_add(size=max(8, radius * 8), location=(centre.x, centre.y, lo.z - 0.001))
    g = bpy.data.materials.new("ground")
    g.use_nodes = True
    g.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.12, 0.13, 1)
    bpy.context.active_object.data.materials.append(g)
    for loc, energy, color in (((2.5, -3.5, 3.0), 260, (1.0, 0.92, 0.82)), ((-3.0, 1.5, 2.2), 90, (0.6, 0.75, 1.0))):
        ld = bpy.data.lights.new("L", "AREA")
        ld.energy, ld.color, ld.size = energy * max(radius, 0.4) ** 2, color, 2.5 * max(radius, 0.4)
        lo_ = bpy.data.objects.new("L", ld)
        lo_.location = centre + Vector(loc) * max(radius, 0.4)
        lo_.rotation_euler = (centre - lo_.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo_)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.lens = 40
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = centre + Vector((1.0, -1.5, 0.55)).normalized() * radius * 2.8
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)


def main() -> int:
    out = Path(sys.argv[1])
    patterns = sys.argv[2:] or ["loads/props/ph_*/*.gltf"]
    files = sorted({p for pat in patterns for p in REPO.glob(pat)})
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    cols = 6
    sheet = Image.new("RGB", (W * cols, H * ((len(files) + cols - 1) // cols)), (15, 15, 15))
    tmp = out.with_suffix(".tmp.png")
    for i, f in enumerate(files):
        render(f, tmp)
        im = Image.open(tmp).convert("RGB")
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, W, 22), fill=(0, 0, 0))
        label = f.parent.name if f.stem == f.parent.name else f"{f.parent.name}/{f.stem}"
        d.text((5, 2), label, font=font, fill=(235, 235, 225))
        sheet.paste(im, ((i % cols) * W, (i // cols) * H))
        print(f"{i + 1}/{len(files)} {label}", flush=True)
    tmp.unlink(missing_ok=True)
    sheet.save(out, quality=86)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
