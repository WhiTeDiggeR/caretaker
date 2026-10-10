#!/usr/bin/env python3
"""Builds props: python3 tools/props/build_props.py [prop_id ...] [--preview DIR] [--out loads/props]

Runs inside the `bpy` Python module. Without ids, builds every registered prop.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import propkit  # noqa: E402
from propkit import Kit  # noqa: E402
from registry import PROPS  # noqa: E402
import props_start  # noqa: E402,F401  (registers wave 1)

for _mod in ("props_repair", "props_set", "props_fix"):
    try:
        __import__(_mod)
    except ModuleNotFoundError:
        pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--preview", help="directory for contact-sheet renders")
    ap.add_argument("--out", default=None)
    ap.add_argument("--samples", type=int, default=24)
    a = ap.parse_args()
    ids = a.ids or list(PROPS)
    for pid in ids:
        spec = PROPS[pid]
        kit = Kit(pid)
        spec.builder(kit)
        out = Path(a.out) / pid if a.out else None
        path = propkit.export_gltf(kit, out)
        print(f"{pid}: {kit.tri_count()} tris -> {path.relative_to(propkit.REPO) if path.is_relative_to(propkit.REPO) else path}")
        if a.preview and spec.views:
            propkit.render_preview(kit, Path(a.preview) / f"{pid}.png", spec.views, samples=a.samples)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
