# Complex v3 sector scenes — validation report

Date: 2026-07-29
Issue: #36

## Composition

- 30 thin sector scenes correspond one-to-one with the 30 approved sector passports.
- Their generated room-space total is 139; stable sector and space IDs remain sourced from the verified metric handoff.
- One shared infrastructure scene owns 7 route spaces, inter-sector connectors, 7 vertical anchors and 8 transition records.
- Every sector scene contains a stable `AuthoredContent` root for manual additions; regeneration does not overwrite existing sector scenes.
- `T-CIRCULATION` has no independent room spaces in the handoff. Its standalone scene previews shared infrastructure, while the full assembly keeps only one infrastructure instance.

## Automated validation

- Static passport/catalog/assembly comparison: passed — 30 scenes, 139 spaces, one infrastructure instance.
- Sector runtime sweep: passed — all 30 scenes load and validate; summed traversable portals equal 147.
- View modes: passed — `FULL`, `SECTOR` and `NEIGHBORS` produce the expected visible-sector counts.
- Full blockout regression: passed — 139 spaces, 7 route spaces, 7 anchors, 8 transitions, 145 floors, 1,254 walls and 1,566 colliders.
- Portal physics regression: passed — all 147 traversable passages accept the test capsule.
- Startup guard: passed — `scenes/underground_research_complex.tscn` remains the unchanged project startup scene.

## Visual validation

Reproducible Godot renders were inspected for:

- `U-MEDBAY` with upper-level neighbors;
- `L-OLD-CORE` with lower-level neighbors;
- `T-UTILITIES` with technical-level neighbors.

All three renders show coherent zone boundaries, readable openings and the expected neighboring context. The captures are written outside the repository to `user://complex_v3_sector_captures`.

Godot emitted the host root-certificate-store warning during command-line runs. No project, scene, script, resource or physics errors were produced.
