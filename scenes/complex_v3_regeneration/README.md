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

Contract v1 in this task resolves linear anchors (`wall`, `door`, `stair_entry`, `stair_exit`). Point/surface/shaft policies remain blocking until their exact parameterization is implemented; they are not approximated from coordinates.
