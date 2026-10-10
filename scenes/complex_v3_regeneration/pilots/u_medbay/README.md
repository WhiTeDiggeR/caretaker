# U-MEDBAY regeneration pilot

This isolated package proves the T01 regeneration contract without replacing the
existing U-MEDBAY or the startup scene.

- `source/` is the editable metric SVG, viewer, and decision ledger.
- `live/Generated/` plus the three JSON files in `live/` are generator-owned.
- `AuthoredContent/` and `pilot_scene.tscn` are authored and must survive regeneration.
- `reports/baseline/` is deterministic clean composition evidence; `reports/visuals/`
  contains the reviewed Godot before/after captures.

The canonical command uses
`tools/complex_v3_regeneration/pilots/u_medbay/pilot_generation_manifest.json`
with explicit roots for `svg-plan-to-godot` and Python. A clean run must report
`ready: true`, `agent_invoked: false`; the immediately repeated run must be
`noop` with equal before/after live hashes.

Verification entry points:

```powershell
python tools/complex_v3_regeneration/pilots/u_medbay/verify_pilot.py --project-root .
python -m unittest tools.complex_v3_regeneration.tests.test_u_medbay_pilot -v
godot --headless --editor --path . --quit
godot --headless --path . --script res://scenes/complex_v3_regeneration/pilots/u_medbay/u_medbay_runtime_check.gd
```

The editor import must run after regeneration because the atomic replacement of
generator-owned OBJ files invalidates the previous import cache. The runtime
check fails unless the imported Mesh resources and CollisionShape3D resources
are actually present.
