# Route A vertical pilot ledger

- Source of truth: `geometry/complex-handoff.json`,
  `vertical/vertical-transitions.json`, and the T01 regeneration contract.
- Fixed geometry: upper/lower space bounds, seven portal segments, shaft center
  `[-52.5, 9.5]`, clear opening `[-55.5, 6, -49.5, 13]`, rise `6 m`, two
  flights of 20 risers at `0.15 m`, tread `0.25 m`, clear width `1.5 m`.
- Coordinate policy: SVG X maps to world X and SVG Y to world Z. The lower SVG
  has elevation `-6`; the stair local origin is transformed by a 180 degree
  rotation around Y and translation `[-52.5, -6, 9.5]`.
- Door policy: every inside side is explicit; no hinge is invented.
- Opening policy: the full shaft is removed from upper floor and lower ceiling.
  The lower floor also has an exact `1.5 x 0.25 m` pocket beneath the first
  riser; the tread owns that walking surface.
- Ownership: SVG conversion owns floor/wall/ceiling geometry. The stair
  generator owns flights, landings, railings, gap-band shaft walls, and all
  stair/shaft frames. Authored objects and bindings remain outside Generated.
- Placement decision: stair shaft-wall normals point into their physical wall;
  they are validation frames, not guessed mounting faces. The beacon therefore
  uses the explicit east ventilation wall frame. The landing kit uses the
  generator-owned landing frame.
- Wall thickness decision: explicit Route A outer bounds leave `0.09 m` per
  shaft face. This local envelope wins over the global `0.18 m` default.
- Collision adapter: generated SVG floor triangles are normalized to upward
  Godot front faces and ceiling triangles to downward front faces. Geometry,
  resource IDs, and visual meshes are unchanged.
- Forbidden: deriving IDs from OBJ order, converting entry forward into a width
  axis, letting an SVG opening cut a generator landing, guessing missing shaft
  bounds, or promoting any failed candidate.
