# Route A vertical regeneration pilot

This isolated package proves Safe Regenerate across `U-ROUTE-A`,
`L-ARCHIVE-A`, and the generated `VT-ROUTE-A` switchback stair. It does not
replace either canonical sector scene and does not modify the startup scene.

- `source/` contains the editable metric SVG sources and the decision ledger.
- `upper/AuthoredContent/` and `lower/AuthoredContent/` remain author-owned.
- `scenes/cv3_route_a/{u,l}` are atomic generator-owned packages.
- `reports/` contains deterministic contract, composition, physics, and visual
  review evidence.

The manifest uses metre coordinates and the handoff's exact `6 x 7 m` clear
opening. The stair is rotated 180 degrees into world space; its lower entry,
upper exit, landings, and shaft frames retain generator semantics. Missing or
impossible shaft dimensions block before promotion.

Verification entry points:

```powershell
python tools/complex_v3_regeneration/pilots/route_a_vertical/verify_pilot.py
python -m unittest discover -s tools/complex_v3_regeneration/tests -v
godot --headless --editor --path . --quit
godot --headless --path . --script res://scenes/complex_v3_regeneration/pilots/route_a_vertical/combined_check.gd
```

The `0.09 m` wall argument is deliberate: the handoff declares the shaft
envelope as `6.18 x 7.18 m` around a `6 x 7 m` clear opening, leaving `0.09 m`
per face. The global `shaft_wall_thickness: 0.18` is not silently applied per
face because that would violate the explicit Route A bounds.
