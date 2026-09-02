# Complex v3 anchor runtime

Runtime/editor-neutral implementation of regeneration contract 1.0.0:

- `anchor_registry.gd` validates and atomically indexes `caretaker.anchor_frames` major 1 documents in world metres (`XZ`, `+Y`). Invalid or duplicate frames never replace the current valid index.
- `anchor_placement.gd` is an Inspector-editable Resource for `normalized`, `from_start_m`, `from_end_m`, and `centered` linear policies, offsets, height, and YXZ rotation.
- `anchored_object_3d.gd` stores persistent object/anchor IDs, expected anchor type, placement, and a local authored correction. Resolution happens explicitly/on ready, never by a per-frame tree search.

Missing or wrong-kind anchors leave the current transform and original anchor ID unchanged. The registry never performs nearest/fuzzy lookup. Duplicate anchor IDs block document activation; duplicate object IDs block registration.

Run the deterministic fixture suite with Godot 4.7:

```powershell
godot --headless --path . --script res://scenes/complex_v3_regeneration/anchor_runtime_check.gd
```

Linear anchors (`wall`, `door`, `stair_entry`, `stair_exit`) retain the existing
resource fields and default `mode = linear`. Invalid/nonfinite axis parameters
now fail closed, including normalized fractions outside `[0, 1]`.

T13 adds `mode = surface` for `floor` and `ceiling`. Both `surface_u` and
`surface_v` must be explicit `ComplexV3AnchorAxisPlacement` resources; each
supports the same four policies. Frames must declare `bounds.u_range_m`,
`bounds.v_range_m`, the world-space `polygon_xz`, and all offset/height/rotation
limits. U is `forward`; V is `forward × up`. Neither ranges nor missing limits
are guessed. The object's basis is `(U, up, V)`, **not** `(forward, up, normal)`:
a surface's physical normal is parallel to up and cannot form that basis.

`footprint_m` must contain positive local box dimensions. The optional
`footprint_center_m` is its pivot-relative center (default zero); this supports
floor-pivot props without changing the authored transform. All eight transformed
corners, including YXZ rotation and author correction, are projected into XZ.
The entire convex footprint must fit the declared UV domain and exact polygon,
and must not overlap any explicitly declared `holes_xz`. Concave boundaries and
holes entirely enclosed by a footprint are checked through polygon intersection,
not just corner containment. This is a placement check, not a replacement for
combined-scene collision/support validation.

```powershell
godot --headless --path . --script res://scenes/complex_v3_regeneration/anchor_surface_check.gd
```

Old planar records may still be indexed as metadata, but cannot be used for
placement without this explicit parameterization. In particular converter 1.19
records still need an exact adapter for ranges and declared placement limits;
the runtime does not silently repair them. Point/shaft placement remains blocking.
