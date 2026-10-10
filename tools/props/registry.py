"""Prop registry: id -> specification (expected size, anchor, triangle budget) and builder.

Every builder takes a `propkit.Kit` and fills it in Godot coordinates. `validate_props.py` re-reads the exported glTF and
checks it against this specification, so a model cannot drift away from docs/art/prop-catalog.md unnoticed.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

PROPS: dict[str, "PropSpec"] = {}


@dataclass
class PropSpec:
    id: str
    catalog: str                 # P-001 ...
    size: tuple[float, float, float]   # expected bounding box (x, y, z), metres
    anchor: str                  # floor: min y = 0, centre x/z = 0 | wall: back plane z = 0 | ceiling: max y = 0
    tris_max: int
    builder: Callable
    views: list = field(default_factory=list)  # preview cameras: (location, target) in Godot coordinates
    tolerance: float = 0.06      # relative size tolerance
    notes: str = ""


def prop(id: str, catalog: str, size, anchor: str, tris_max: int, views=None, tolerance: float = 0.06, notes: str = ""):
    def deco(fn):
        PROPS[id] = PropSpec(id, catalog, tuple(size), anchor, tris_max, fn, views or [], tolerance, notes)
        return fn
    return deco
