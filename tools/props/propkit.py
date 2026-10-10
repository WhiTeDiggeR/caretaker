"""Blender (bpy) toolkit for building the game props of docs/art/prop-catalog.md.

Geometry is authored in **Godot coordinates** (metres, +Y up, front = +Z). Primitives are merged into named
groups; a group with a `pivot` becomes a movable node (Door, Lid, Wheel ...) whose origin sits on its rotation axis.
UVs are box-projected in world metres divided by the material's tile size, so every prop gets the same texel density.
Materials are exported as names only; `finish_gltf()` rewrites them into full PBR definitions that point at the shared
textures in loads/textures (no per-prop texture copies).
"""
from __future__ import annotations

import json
import math
import os
import random
from pathlib import Path

import bpy  # noqa: I001  (must precede bmesh)
import bmesh
from mathutils import Euler, Matrix, Vector

REPO = Path(__file__).resolve().parents[2]
TEX_DIR = REPO / "loads" / "textures"
PROPS_DIR = REPO / "loads" / "props"

from materials_def import ATLAS, EMIT, PLAIN, TILE  # noqa: E402


def g2b(v) -> Vector:
    """Godot (x, y up, z front) -> Blender (X, Y, Z up); glTF export maps it straight back."""
    return Vector((v[0], -v[2], v[1]))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Group:
    def __init__(self, name: str, pivot=(0.0, 0.0, 0.0)):
        self.name, self.pivot = name, Vector(pivot)
        self.bm = bmesh.new()
        self.mats: list[str] = []
        self.parent: str | None = None

    def mat_index(self, m: str) -> int:
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)


class Kit:
    def __init__(self, prop_id: str, seed: int = 1):
        reset()
        self.id = prop_id
        self.rnd = random.Random(seed)
        self.groups: dict[str, Group] = {"Body": Group("Body")}
        self.cur = self.groups["Body"]

    # ------------------------------------------------------------ groups
    def group(self, name: str, pivot=(0.0, 0.0, 0.0), parent: str | None = None) -> Group:
        if name not in self.groups:
            self.groups[name] = Group(name, pivot)
            self.groups[name].parent = parent
        self.cur = self.groups[name]
        return self.cur

    def body(self) -> Group:
        self.cur = self.groups["Body"]
        return self.cur

    # ------------------------------------------------------------ primitives
    def _commit(self, tmp: bmesh.types.BMesh, m: str, uv: str = "box", tile: float | None = None, uv_offset=(0.0, 0.0)):
        g = self.cur
        tile = tile or TILE.get(m, 1.0)
        tmp.verts.index_update()
        tmp.edges.index_update()
        tmp.faces.index_update()
        tmp.normal_update()
        tmp.edges.ensure_lookup_table()
        # flat shading across hard corners, smooth across bevel facets
        sharp = {e.index for e in tmp.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(40)}
        vmap = {}
        mi = g.mat_index(m)
        layer = g.bm.loops.layers.uv.verify()
        tl = tmp.loops.layers.uv.verify() if uv == "given" else None
        faces = []
        for f in tmp.faces:
            vs = []
            for v in f.verts:
                if v.index not in vmap:
                    vmap[v.index] = g.bm.verts.new(v.co - g.pivot)
                vs.append(vmap[v.index])
            try:
                nf = g.bm.faces.new(vs)
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = True
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for loop, src in zip(nf.loops, f.loops):
                if uv == "given" and tl is not None:
                    loop[layer].uv = src[tl].uv
                else:
                    p = src.vert.co
                    a, b = ((p.y, p.z), (p.x, p.z), (p.x, p.y))[ax]
                    if ax == 0 and n.x < 0:
                        a = -a
                    if ax == 2 and n.z < 0:
                        a = -a
                    loop[layer].uv = (a / tile + uv_offset[0], b / tile + uv_offset[1])
            faces.append((nf, f))
        g.bm.edges.ensure_lookup_table()
        # carry the sharp marks over by vertex pair
        for e in tmp.edges:
            if e.index in sharp:
                a, b = vmap.get(e.verts[0].index), vmap.get(e.verts[1].index)
                if a and b:
                    ge = g.bm.edges.get((a, b))
                    if ge:
                        ge.smooth = False
        tmp.free()

    @staticmethod
    def _xf(bm, center, rot):
        m = Matrix.Translation(Vector(center)) @ Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)

    def box(self, size, center=(0, 0, 0), m="painted_metal", bevel=0.008, seg=2, rot=(0, 0, 0), uv_offset=None):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        if bevel > 0:
            bevel = min(bevel, min(size) * 0.45)
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=seg, affect="EDGES")
        self._xf(bm, center, rot)
        self._commit(bm, m, uv_offset=uv_offset or (self.rnd.random(), self.rnd.random()))

    def cyl(self, r, h, center=(0, 0, 0), axis="y", m="steel_bare", seg=24, r2=None, cap_bevel=0.0, rot=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        if cap_bevel > 0:
            cap = [e for e in bm.edges if all(abs(abs(v.co.z) - h / 2) < 1e-6 for v in e.verts)]
            bmesh.ops.bevel(bm, geom=cap, offset=cap_bevel, segments=2, affect="EDGES")
        axis_rot = {"z": (0, 0, 0), "y": (-90, 0, 0), "x": (0, 90, 0)}[axis]
        bmesh.ops.transform(bm, matrix=Euler(tuple(math.radians(a) for a in axis_rot), "XYZ").to_matrix().to_4x4(), verts=bm.verts)
        self._xf(bm, center, rot)
        self._commit(bm, m, uv_offset=(self.rnd.random(), self.rnd.random()))

    def sphere(self, r, center=(0, 0, 0), m="steel_bare", seg=16, scale=(1, 1, 1)):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=r)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
        self._xf(bm, center, (0, 0, 0))
        self._commit(bm, m, uv_offset=(self.rnd.random(), self.rnd.random()))

    def prism(self, pts, depth, center=(0, 0, 0), m="painted_metal", axis="z", bevel=0.0, seg=2):
        """Extrudes the polygon `pts` (2D, counter-clockwise, in the plane perpendicular to `axis`) by `depth`."""
        area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
        if area < 0:
            pts = list(reversed(pts))
        bm = bmesh.new()
        top = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
        bot = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        n = len(pts)
        for i in range(n):
            bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=seg, affect="EDGES")
        rot = {"z": (0, 0, 0), "y": (90, 0, 0), "x": (0, 90, 0)}[axis]
        bmesh.ops.transform(bm, matrix=Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4(), verts=bm.verts)
        self._xf(bm, center, (0, 0, 0))
        self._commit(bm, m, uv_offset=(self.rnd.random(), self.rnd.random()))

    def prism_x(self, zy, width, center_x=0.0, m="painted_metal", bevel=0.004):
        """Extrudes a side profile given as (z, y) points along X (a console body, a wedge, a ramp)."""
        self.prism([(-z, y) for z, y in zy], width, (center_x, 0, 0), m, axis="x", bevel=bevel)

    def chunk(self, center, radii, seed=0, m="concrete_rubble", points=11, rot=(0, 0, 0)):
        """A random convex rock/concrete lump (convex hull of jittered points on an ellipsoid)."""
        g = random.Random(seed)
        bm = bmesh.new()
        for _ in range(points):
            v = Vector((g.gauss(0, 1), g.gauss(0, 1), g.gauss(0, 1)))
            v.normalize()
            v *= g.uniform(0.72, 1.0)
            bm.verts.new((v.x * radii[0], v.y * radii[1], v.z * radii[2]))
        res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
        junk = [e for e in set(res["geom_interior"]) | set(res["geom_unused"]) if isinstance(e, bmesh.types.BMVert)]
        if junk:
            bmesh.ops.delete(bm, geom=junk, context="VERTS")
        self._xf(bm, center, rot)
        self._commit(bm, m, tile=2.0, uv_offset=(g.random(), g.random()))

    def hex_bolt(self, center, r=0.01, h=0.006, axis="z", m="steel_bare"):
        self.cyl(r, h, center, axis, m, seg=6)

    def tube(self, pts, r, m="steel_bare", seg=10, caps=True, tile=None):
        """Sweeps a circle (radius r, or per-point list) along the polyline `pts` with rotation-minimising frames."""
        P = [Vector(p) for p in pts]
        rad = r if isinstance(r, (list, tuple)) else [r] * len(P)
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.verify()
        tangents = []
        for i in range(len(P)):
            a = P[max(i - 1, 0)]
            b = P[min(i + 1, len(P) - 1)]
            tangents.append((b - a).normalized())
        ref = Vector((0, 1, 0)) if abs(tangents[0].y) < 0.9 else Vector((1, 0, 0))
        normal = tangents[0].cross(ref).normalized()
        rings, dist, ds = [], 0.0, [0.0]
        for i in range(1, len(P)):
            ds.append(ds[-1] + (P[i] - P[i - 1]).length)
        for i, p in enumerate(P):
            if i:
                axis = tangents[i - 1].cross(tangents[i])
                if axis.length > 1e-6:
                    ang = tangents[i - 1].angle(tangents[i])
                    normal = (Matrix.Rotation(ang, 3, axis.normalized()) @ normal).normalized()
            binorm = tangents[i].cross(normal)
            ring = []
            for k in range(seg):
                t = 2 * math.pi * k / seg
                ring.append(bm.verts.new(p + (normal * math.cos(t) + binorm * math.sin(t)) * rad[i]))
            rings.append(ring)
        tile = tile or TILE.get(m, 1.0)
        for i in range(len(P) - 1):
            for k in range(seg):
                k2 = (k + 1) % seg
                f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
                for loop in f.loops:
                    vi = loop.vert
                    ri = i if vi in rings[i] else i + 1
                    kk = rings[ri].index(vi)
                    loop[uvl].uv = (ds[ri] / tile, kk / seg * 2 * math.pi * rad[ri] / tile)
        if caps:
            for ring in (rings[0], list(reversed(rings[-1]))):
                f = bm.faces.new(ring if ring is rings[0] else ring)
                for loop in f.loops:
                    loop[uvl].uv = (loop.vert.co.x / tile, loop.vert.co.y / tile)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._commit(bm, m, uv="given", tile=tile)

    def torus(self, R, r, center=(0, 0, 0), axis="y", m="steel_bare", seg=24, rseg=8):
        pts = [(R * math.cos(2 * math.pi * i / seg), 0.0, R * math.sin(2 * math.pi * i / seg)) for i in range(seg + 1)]
        c = Vector(center)
        circle = [Vector(p) for p in pts]
        # a closed tube: reuse tube() on a loop, duplicating the first point so the rings meet
        saved_caps = False
        rot = {"y": Matrix.Identity(3), "z": Matrix.Rotation(math.radians(90), 3, "X"), "x": Matrix.Rotation(math.radians(90), 3, "Z")}[axis]
        self.tube([c + rot @ p for p in circle], r, m=m, seg=rseg, caps=saved_caps)

    def decal(self, center, size, atlas: str, rect, normal="+z", offset=0.0015, flip_u=False, tilt=0.0, roll=0.0):
        """A flat quad textured with a rect (u0, v0, u1, v1; v from the top of the image) of an atlas material."""
        w, h = size
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.verify()
        axes = {"+z": ((1, 0, 0), (0, 1, 0), (0, 0, 1)), "-z": ((-1, 0, 0), (0, 1, 0), (0, 0, -1)),
                "+x": ((0, 0, -1), (0, 1, 0), (1, 0, 0)), "-x": ((0, 0, 1), (0, 1, 0), (-1, 0, 0)),
                "+y": ((1, 0, 0), (0, 0, -1), (0, 1, 0)), "-y": ((1, 0, 0), (0, 0, 1), (0, -1, 0))}[normal]
        ux, uy, un = (Vector(a) for a in axes)
        if tilt:  # rotate the quad about its own u axis (positive tilts the top away from the viewer)
            r = Matrix.Rotation(math.radians(tilt), 3, ux)
            uy, un = r @ uy, r @ un
        if roll:
            r = Matrix.Rotation(math.radians(roll), 3, un)
            ux, uy = r @ ux, r @ uy
        c = Vector(center) + un * offset
        corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        vs = [bm.verts.new(c + ux * (sx * w / 2) + uy * (sy * h / 2)) for sx, sy in corners]
        f = bm.faces.new(vs)
        u0, v0, u1, v1 = rect
        if flip_u:
            u0, u1 = u1, u0
        uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
        for loop, uv in zip(f.loops, uvs):
            loop[uvl].uv = uv
        self._commit(bm, atlas, uv="given")

    # ------------------------------------------------------------ output
    def rescale(self, sx=1.0, sy=1.0, sz=1.0, centre_xz=False, ground=False):
        """Scales every group (vertices and pivots) and optionally recentres on x/z and drops the lowest point to y = 0."""
        for g in self.groups.values():
            for v in g.bm.verts:
                v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
            g.pivot = Vector((g.pivot.x * sx, g.pivot.y * sy, g.pivot.z * sz))
        lo, hi = self.bounds()
        dx = -(lo.x + hi.x) / 2 if centre_xz else 0.0
        dz = -(lo.z + hi.z) / 2 if centre_xz else 0.0
        dy = -lo.y if ground else 0.0
        for g in self.groups.values():   # vertices are stored relative to their group pivot, so only pivots move
            g.pivot += Vector((dx, dy, dz))

    def tri_count(self) -> int:
        return sum(len(f.verts) - 2 for g in self.groups.values() for f in g.bm.faces)

    def bounds(self):
        pts = [v.co + g.pivot for g in self.groups.values() for v in g.bm.verts]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return lo, hi

    def build_objects(self):
        self.bbox = self.bounds()
        coll = bpy.context.scene.collection
        objs = {}
        for name, g in self.groups.items():
            if not g.bm.faces:
                continue
            g.bm.normal_update()
            me = bpy.data.meshes.new(name)
            # Godot -> Blender coordinates
            for v in g.bm.verts:
                v.co = g2b(v.co)
            g.bm.to_mesh(me)
            me.update()
            for m in g.mats:
                me.materials.append(blender_material(m))
            for poly in me.polygons:
                poly.use_smooth = True
            ob = bpy.data.objects.new(name, me)
            ob.location = g2b(g.pivot)
            coll.objects.link(ob)
            objs[name] = ob
        for name, g in self.groups.items():
            if g.parent and g.parent in objs and name in objs:
                objs[name].parent = objs[g.parent]
                objs[name].matrix_parent_inverse = objs[g.parent].matrix_world.inverted()
        return objs


_mat_cache: dict[str, bpy.types.Material] = {}


def blender_material(name: str):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    if name in EMIT:
        base, em, strength = EMIT[name]
        bsdf.inputs["Base Color"].default_value = (*base, 1)
        bsdf.inputs["Emission Color"].default_value = (*em, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
        if name == "crystal_core":
            bsdf.inputs["Alpha"].default_value = 0.75
            bsdf.inputs["Roughness"].default_value = 0.1
    elif name in PLAIN:
        rgb, rough, metal, alpha = PLAIN[name]
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Alpha"].default_value = alpha
    return m


# ------------------------------------------------------------------ export
def export_gltf(kit: Kit, out_dir: Path | None = None) -> Path:
    out_dir = out_dir or PROPS_DIR / kit.id
    out_dir.mkdir(parents=True, exist_ok=True)
    kit.build_objects()
    path = out_dir / f"{kit.id}.gltf"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLTF_SEPARATE", export_apply=False, export_yup=True,
                              export_materials="EXPORT", export_image_format="NONE", export_cameras=False,
                              export_lights=False, export_extras=False, export_texcoords=True, export_normals=True,
                              export_tangents=False, use_selection=False)
    finish_gltf(path)
    return path


def finish_gltf(path: Path):
    """Rewrites the exported materials so they point at the shared textures (relative URIs, no copies)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    rel = os.path.relpath(TEX_DIR, path.parent).replace(os.sep, "/")
    images, textures = [], []

    def tex(uri: str) -> int:
        if uri not in images:
            images.append(uri)
            textures.append({"source": len(images) - 1, "sampler": 0})
        return images.index(uri)

    for m in data.get("materials", []):
        name = m["name"].split(".")[0]
        m["name"] = name
        pbr = m.setdefault("pbrMetallicRoughness", {})
        if name in TILE:
            pbr["baseColorTexture"] = {"index": tex(f"{rel}/{name}/{name}_albedo.jpg")}
            pbr["metallicRoughnessTexture"] = {"index": tex(f"{rel}/{name}/{name}_orm.jpg")}
            pbr["baseColorFactor"] = [1, 1, 1, 1]
            pbr["metallicFactor"] = 1.0
            pbr["roughnessFactor"] = 1.0
            m["normalTexture"] = {"index": tex(f"{rel}/{name}/{name}_normal.png")}
            m["occlusionTexture"] = {"index": tex(f"{rel}/{name}/{name}_orm.jpg"), "strength": 0.8}
        elif name in ATLAS:
            uri, blend, emissive = ATLAS[name]
            pbr["baseColorTexture"] = {"index": tex(f"{rel}/{uri}")}
            pbr["baseColorFactor"] = [1, 1, 1, 1]
            pbr["metallicFactor"] = 0.0
            pbr["roughnessFactor"] = 0.7
            if blend:
                m["alphaMode"] = "BLEND"
            if emissive:
                m["emissiveTexture"] = {"index": tex(f"{rel}/{uri}")}
                m["emissiveFactor"] = [1, 1, 1]
                m.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {"emissiveStrength": emissive}
                data.setdefault("extensionsUsed", [])
                if "KHR_materials_emissive_strength" not in data["extensionsUsed"]:
                    data["extensionsUsed"].append("KHR_materials_emissive_strength")
        if name in PLAIN and PLAIN[name][3] < 1.0:
            m["alphaMode"] = "BLEND"
        m["doubleSided"] = name in ("glass_dirty",) or m.get("doubleSided", False)
    if images:
        data["images"] = [{"uri": u} for u in images]
        data["textures"] = textures
        data["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ preview
def _preview_material(m, name):
    """Textured Cycles material for previews only (never exported)."""
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def img(path, noncolor):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(str(path), check_existing=True)
        n.image.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
        n.interpolation = "Smart"
        return n

    if name in TILE:
        d = TEX_DIR / name
        a, o, nm = img(d / f"{name}_albedo.jpg", False), img(d / f"{name}_orm.jpg", True), img(d / f"{name}_normal.png", True)
        nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(o.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    elif name in ATLAS:
        uri, blend, emissive = ATLAS[name]
        t = img(TEX_DIR / uri, False)
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if blend:
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
        if emissive:
            nt.links.new(t.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emissive
        bsdf.inputs["Roughness"].default_value = 0.6
    else:
        old = blender_material(name)  # parameter material: rebuild defaults
        return


def render_preview(kit: Kit, path: Path, views, size=(720, 540), samples=24, ground=True):
    """views: list of (camera_location, look_at) in Godot coordinates; renders a contact sheet row per view."""
    for m in bpy.data.materials:
        base = m.name.split(".")[0]
        if base in TILE or base in ATLAS:
            m.use_nodes = True
            _preview_material(m, base)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.055, 0.065, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    if ground:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8)
        for v in bm.verts:
            v.co.z = kit.bbox[0].y - 0.001
        me = bpy.data.meshes.new("ground")
        bm.to_mesh(me)
        ob = bpy.data.objects.new("ground", me)
        scene.collection.objects.link(ob)
        gm = bpy.data.materials.new("ground_prev")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.12, 0.13, 1)
        gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
        me.materials.append(gm)

    def light(loc, energy, color, size_):
        ld = bpy.data.lights.new("L", "AREA")
        ld.energy, ld.color, ld.size = energy, color, size_
        lo = bpy.data.objects.new("L", ld)
        lo.location = g2b(loc)
        scene.collection.objects.link(lo)
        d = Vector((0, 0, 0.9)) - lo.location
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    light((2.5, 3.0, 3.5), 260, (1.0, 0.92, 0.82), 2.5)
    light((-3.0, 2.2, -1.5), 90, (0.6, 0.75, 1.0), 2.0)
    light((0.5, 2.8, -3.0), 40, (1.0, 0.3, 0.2), 1.0)
    cam_d = bpy.data.cameras.new("C")
    cam_d.lens = 35
    cam = bpy.data.objects.new("C", cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam
    from PIL import Image
    frames = []
    lo, hi = kit.bbox
    centre, radius = (lo + hi) / 2, (hi - lo).length / 2
    cam_d.lens = 40
    for i, (loc, target) in enumerate(views):
        direction = (Vector(loc) - Vector(target)).normalized()
        cam.location = g2b(centre + direction * radius * 2.6)
        d = g2b(centre) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(path.with_name(f"_v{i}.png"))
        bpy.ops.render.render(write_still=True)
        frames.append(Image.open(scene.render.filepath).convert("RGB"))
    sheet = Image.new("RGB", (size[0] * len(frames), size[1]))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * size[0], 0))
    sheet.save(path)
    for i in range(len(frames)):
        os.remove(path.with_name(f"_v{i}.png"))
