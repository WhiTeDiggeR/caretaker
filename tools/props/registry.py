"""Prop registry: id -> specification (expected size, anchor, triangle budget) and builder.

Every builder takes a `propkit.Kit` and fills it in Godot coordinates. `validate_props.py` re-reads the exported glTF and
checks it against this specification, so a model cannot drift away from docs/art/prop-catalog.md unnoticed.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

PROPS: dict[str, "PropSpec"] = {}
# preview directions (camera position relative to the target; distance is fitted to the prop's size)
DEFAULT_VIEWS = [((1.0, 0.55, 1.5), (0, 0, 0)), ((-1.1, 0.6, 1.4), (0, 0, 0)), ((0.4, 0.8, -1.6), (0, 0, 0))]


@dataclass
class PropSpec:
    id: str
    catalog: str                 # P-001 ...
    size: tuple[float, float, float]   # expected bounding box (x, y, z), metres
    anchor: str                  # floor: min y = 0, centre x/z = 0 | wall: back plane z = 0 | ceiling: max y = 0 | free: no anchor check
    tris_max: int
    builder: Callable
    views: list = field(default_factory=list)  # preview cameras: (location, target) in Godot coordinates
    tolerance: float = 0.06      # relative size tolerance
    notes: str = ""
    center_z: bool = True        # floor props: require the footprint to be centred on z as well


def prop(id: str, catalog: str, size, anchor: str, tris_max: int, views=None, tolerance: float = 0.06, notes: str = "", center_z: bool = True):
    def deco(fn):
        PROPS[id] = PropSpec(id, catalog, tuple(size), anchor, tris_max, fn, views or DEFAULT_VIEWS, tolerance, notes, center_z)
        return fn
    return deco


SPECS_FILE = __import__("pathlib").Path(__file__).with_name("specs.json")


def dump_specs(ids=None):
    """Merges the specification of `ids` (default: all) into specs.json, which validate_props.py reads without Blender."""
    import json
    data = json.loads(SPECS_FILE.read_text(encoding="utf-8")) if SPECS_FILE.exists() else {}
    for pid in ids or PROPS:
        s = PROPS[pid]
        data[pid] = {"catalog": s.catalog, "size": list(s.size), "anchor": s.anchor, "tris_max": s.tris_max,
                     "tolerance": s.tolerance, "center_z": s.center_z}
    SPECS_FILE.write_text(json.dumps(dict(sorted(data.items())), indent=1) + "\n", encoding="utf-8")
