"""Parts of the console props sit on their body (#207): nothing floats, sticks out of the body or overlaps a neighbour.

Reads the exported glTF + .bin (no Blender). The body is the `k.prism_x(profile, width, ...)` side profile of the
prop's builder, read from the source with `ast`, so the test follows the generator. Every connected mesh part is:
- inside the body's footprint (x, z) and the catalog height (with its tolerance);
- inside the body, or mounted on one of its faces (touching that plane, within its bounds), or touching
  (closer than TOUCH, or poking into) a part that is;
- not partly covering another part mounted on the same face (a part fully on top of another one is fine).
"""
from __future__ import annotations

import ast
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROPS = HERE.parent
REPO = PROPS.parents[1]
sys.path.insert(0, str(PROPS))

from validate_props import accessor  # noqa: E402

SLOPED = {"control_desk": "props_start.py", "terminal_console": "props_start.py"}
FOOTPRINT_MARGIN = 0.025   # bolts, labels and glands may stand proud of the body by this much
MOUNT_ABOVE = 0.008        # a part whose lowest point is at most this far above a face plane rests on it
MOUNT_BELOW = 0.12         # ... and that is not sunk deeper than this into it
FACE_TOL = 0.003
TOUCH = 0.006
OVERLAP_TOL = 0.002


def _profile(pid: str, module: str):
    """(z, y) profile and width of the first k.prism_x call in the builder of `pid`."""
    tree = ast.parse((PROPS / module).read_text(encoding="utf-8"))
    fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == pid)
    names = {}
    for node in ast.walk(fn):
        if isinstance(node, ast.Assign):
            if isinstance(node.targets[0], ast.Name):
                try:
                    names[node.targets[0].id] = ast.literal_eval(node.value)
                except ValueError:
                    pass
            elif isinstance(node.targets[0], ast.Tuple) and isinstance(node.value, ast.Tuple):
                for t, v in zip(node.targets[0].elts, node.value.elts):
                    try:
                        names[t.id] = ast.literal_eval(v)
                    except ValueError:
                        pass
    call = next(n for n in ast.walk(fn) if isinstance(n, ast.Call) and getattr(n.func, "attr", "") == "prism_x")

    def value(arg):
        return names[arg.id] if isinstance(arg, ast.Name) else ast.literal_eval(arg)

    return [tuple(p) for p in value(call.args[0])], float(value(call.args[1]))


def _parts(gltf: Path):
    """Connected parts of every mesh node: lists of world-space triangles (vertices welded by position)."""
    data = json.loads(gltf.read_text(encoding="utf-8"))
    buffers = [(gltf.parent / b["uri"]).read_bytes() for b in data["buffers"]]
    parts = []
    for node in data["nodes"]:
        if "mesh" not in node:
            continue
        assert "children" not in node and "rotation" not in node and "scale" not in node, "flat translated nodes only"
        t = node.get("translation", [0.0, 0.0, 0.0])
        tris = []
        for prim in data["meshes"][node["mesh"]]["primitives"]:
            pos = [(p[0] + t[0], p[1] + t[1], p[2] + t[2]) for p in accessor(data, buffers, prim["attributes"]["POSITION"])]
            idx = [i[0] for i in accessor(data, buffers, prim["indices"])]
            tris += [(pos[idx[i]], pos[idx[i + 1]], pos[idx[i + 2]]) for i in range(0, len(idx), 3)]
        key = {}
        parent = []

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        tri_keys = []
        for tri in tris:
            ks = []
            for p in tri:
                k = tuple(round(c * 1e4) for c in p)
                if k not in key:
                    key[k] = len(parent)
                    parent.append(len(parent))
                ks.append(key[k])
            tri_keys.append(ks)
            a = find(ks[0])
            for k in ks[1:]:
                parent[find(k)] = a
        groups = {}
        for tri, ks in zip(tris, tri_keys):
            groups.setdefault(find(ks[0]), []).append((tri, ks))
        for items in groups.values():
            parts.append(Part(node.get("name", "?"), [tri for tri, _ in items], [ks for _, ks in items]))
    return parts


class Part:
    def __init__(self, node: str, tris, keys):
        self.node, self.tris = node, tris
        self.verts = list({p for tri in tris for p in tri})
        self.lo = tuple(min(v[i] for v in self.verts) for i in range(3))
        self.hi = tuple(max(v[i] for v in self.verts) for i in range(3))
        self.centre = tuple((a + b) / 2 for a, b in zip(self.lo, self.hi))
        edges = {}
        for ks in keys:
            for a, b in ((ks[0], ks[1]), (ks[1], ks[2]), (ks[2], ks[0])):
                e = (min(a, b), max(a, b))
                edges[e] = edges.get(e, 0) + 1
        self.closed = len(tris) >= 12 and all(c == 2 for c in edges.values())

    def __repr__(self):
        lo = ", ".join(f"{v:.3f}" for v in self.lo)
        hi = ", ".join(f"{v:.3f}" for v in self.hi)
        return f"{self.node} part [{lo}]..[{hi}]"


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _point_tri_dist(p, tri):
    """Distance from p to a triangle (Ericson, Real-Time Collision Detection 5.1.5)."""
    a, b, c = tri
    ab, ac, ap = _sub(b, a), _sub(c, a), _sub(p, a)
    d1, d2 = _dot(ab, ap), _dot(ac, ap)
    if d1 <= 0 and d2 <= 0:
        q = a
    else:
        bp = _sub(p, b)
        d3, d4 = _dot(ab, bp), _dot(ac, bp)
        cp = _sub(p, c)
        d5, d6 = _dot(ab, cp), _dot(ac, cp)
        vc, vb, va = d1 * d4 - d3 * d2, d5 * d2 - d1 * d6, d3 * d6 - d5 * d4
        if d3 >= 0 and d4 <= d3:
            q = b
        elif d6 >= 0 and d5 <= d6:
            q = c
        elif vc <= 0 and d1 >= 0 and d3 <= 0:
            v = d1 / (d1 - d3)
            q = (a[0] + ab[0] * v, a[1] + ab[1] * v, a[2] + ab[2] * v)
        elif vb <= 0 and d2 >= 0 and d6 <= 0:
            w = d2 / (d2 - d6)
            q = (a[0] + ac[0] * w, a[1] + ac[1] * w, a[2] + ac[2] * w)
        elif va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0:
            w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
            q = (b[0] + (c[0] - b[0]) * w, b[1] + (c[1] - b[1]) * w, b[2] + (c[2] - b[2]) * w)
        else:
            denom = 1.0 / (va + vb + vc)
            v, w = vb * denom, vc * denom
            q = (a[0] + ab[0] * v + ac[0] * w, a[1] + ab[1] * v + ac[1] * w, a[2] + ab[2] * v + ac[2] * w)
    d = _sub(p, q)
    return _dot(d, d) ** 0.5


def _inside(p, part: Part) -> bool:
    """Ray parity along a slightly skewed +Y ray; only meaningful for closed parts."""
    if not part.closed or any(p[i] < part.lo[i] or p[i] > part.hi[i] for i in range(3)):
        return False
    direction = (0.0123, 1.0, 0.0371)
    hits = 0
    for a, b, c in part.tris:
        e1, e2 = _sub(b, a), _sub(c, a)
        h = _cross(direction, e2)
        det = _dot(e1, h)
        if abs(det) < 1e-12:
            continue
        s = _sub(p, a)
        u = _dot(s, h) / det
        if u < 0 or u > 1:
            continue
        q = _cross(s, e1)
        v = _dot(direction, q) / det
        if v < 0 or u + v > 1:
            continue
        if _dot(e2, q) / det > 1e-9:
            hits += 1
    return hits % 2 == 1


def _touches(a: Part, b: Part) -> bool:
    if any(a.lo[i] > b.hi[i] + TOUCH or b.lo[i] > a.hi[i] + TOUCH for i in range(3)):
        return False
    for x, y in ((a, b), (b, a)):
        for p in x.verts:
            if any(p[i] < y.lo[i] - TOUCH or p[i] > y.hi[i] + TOUCH for i in range(3)):
                continue
            if _inside(p, y) or min(_point_tri_dist(p, t) for t in y.tris) <= TOUCH:
                return True
    return False


class Body:
    """The extruded side profile: faces are its edges swept along X."""

    def __init__(self, profile, width):
        self.profile, self.half = profile, width / 2
        cz = sum(z for z, _ in profile) / len(profile)
        cy = sum(y for _, y in profile) / len(profile)
        self.faces = []
        for i, (z1, y1) in enumerate(profile):
            z2, y2 = profile[(i + 1) % len(profile)]
            length = ((z2 - z1) ** 2 + (y2 - y1) ** 2) ** 0.5
            nz, ny = (y2 - y1) / length, -(z2 - z1) / length
            if nz * (cz - z1) + ny * (cy - y1) > 0:
                nz, ny = -nz, -ny
            if ny < -0.5:
                continue   # the bottom stands on the floor
            self.faces.append(((z1, y1), ((z2 - z1) / length, (y2 - y1) / length), (nz, ny), length))
        self.z_lo, self.z_hi = min(z for z, _ in profile), max(z for z, _ in profile)

    def contains(self, p) -> bool:
        if abs(p[0]) > self.half:
            return False
        z, y, inside = p[2], p[1], False
        for i, (z1, y1) in enumerate(self.profile):
            z2, y2 = self.profile[(i + 1) % len(self.profile)]
            if (y1 > y) != (y2 > y) and z < z1 + (y - y1) * (z2 - z1) / (y2 - y1):
                inside = not inside
        return inside

    @staticmethod
    def local(face, p):
        (z1, y1), (tz, ty), (nz, ny), _ = face
        dz, dy = p[2] - z1, p[1] - y1
        return p[0], dz * tz + dy * ty, dz * nz + dy * ny   # across, along the face, out of it

    def mount(self, part: Part):
        """(face index, (x lo, x hi, s lo, s hi)) of the face the part rests on, or None."""
        best = None
        for i, face in enumerate(self.faces):
            loc = [self.local(face, v) for v in part.verts]
            d_lo, d_hi = min(q[2] for q in loc), max(q[2] for q in loc)
            if not (-MOUNT_BELOW <= d_lo <= MOUNT_ABOVE and d_hi >= -FACE_TOL):
                continue
            rect = (min(q[0] for q in loc), max(q[0] for q in loc), min(q[1] for q in loc), max(q[1] for q in loc))
            cs = (rect[2] + rect[3]) / 2
            if not (abs((rect[0] + rect[1]) / 2) <= self.half and 0 <= cs <= face[3]):
                continue
            if best is None or abs(d_lo) < best[0]:
                best = (abs(d_lo), i, rect)
        return None if best is None else (best[1], best[2])


class SlopedPropsTest(unittest.TestCase):
    def test_parts_sit_on_the_body(self):
        specs = json.loads((PROPS / "specs.json").read_text(encoding="utf-8"))
        for pid, module in SLOPED.items():
            with self.subTest(prop=pid):
                self.assertEqual([], _problems(pid, module, specs[pid]))


def _problems(pid, module, spec):
    body = Body(*_profile(pid, module))
    parts = _parts(REPO / "loads" / "props" / pid / f"{pid}.gltf")
    problems, attached, mounted, loose = [], [], {}, []
    for part in parts:
        lo, hi = part.lo, part.hi
        if (lo[0] < -body.half - FOOTPRINT_MARGIN or hi[0] > body.half + FOOTPRINT_MARGIN or
                lo[2] < body.z_lo - FOOTPRINT_MARGIN or hi[2] > body.z_hi + FOOTPRINT_MARGIN or
                hi[1] > spec["size"][1] * (1 + spec["tolerance"]) or lo[1] < -FACE_TOL):
            problems.append(f"{part}: outside the body footprint / catalog height")
        if body.contains(part.centre):
            attached.append(part)
            continue
        m = body.mount(part)
        if m is None:
            loose.append(part)
            continue
        face, rect = m
        if rect[0] < -body.half - FACE_TOL or rect[1] > body.half + FACE_TOL or rect[2] < -FACE_TOL or \
                rect[3] > body.faces[face][3] + FACE_TOL:
            problems.append(f"{part}: runs off the face {face} it is mounted on {tuple(round(v, 3) for v in rect)}")
        mounted.setdefault(face, []).append((part, rect))
        attached.append(part)
    changed = True
    while loose and changed:
        changed = False
        for part in list(loose):
            if any(_touches(part, other) for other in attached):
                loose.remove(part)
                attached.append(part)
                changed = True
    problems += [f"{part}: floats (touches neither the body nor another part)" for part in loose]
    for face, items in mounted.items():
        for i, (a, ra) in enumerate(items):
            for b, rb in items[i + 1:]:
                ox = min(ra[1], rb[1]) - max(ra[0], rb[0])
                os_ = min(ra[3], rb[3]) - max(ra[2], rb[2])
                if ox <= OVERLAP_TOL or os_ <= OVERLAP_TOL:
                    continue
                inner = [r for r, o in ((ra, rb), (rb, ra)) if r[0] >= o[0] - OVERLAP_TOL and r[1] <= o[1] + OVERLAP_TOL
                         and r[2] >= o[2] - OVERLAP_TOL and r[3] <= o[3] + OVERLAP_TOL]
                if not inner:
                    problems.append(f"{a} and {b} overlap on face {face}")
    return problems


if __name__ == "__main__":
    unittest.main()
