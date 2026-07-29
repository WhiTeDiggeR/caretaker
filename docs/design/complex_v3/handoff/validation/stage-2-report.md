# Stage 2 validation report

Date: 2026-07-29

Map: `caretaker-complex-v3`

Gate: full 3D handoff, awaiting user approval

## Automated checks

- Stage 1 regression: passed — 3 levels, 7 anchors, 30 sectors, 5 routes, 49 topology connections.
- Stage 2 geometry: passed — 30 passports, 139 exact room spaces, 109 internal portals, 43 external portals.
- Physical topology coverage: passed — all 49 approved topology edges are represented by corridors, portals, stairs, lifts, shaft rules, or the old inclined tunnel.
- Positive-area room overlaps: none across all spaces on the same level.
- Portal contact: every internal portal lies on the exact shared boundary of its two rooms; every external portal lies on its owning room boundary.
- Vertical rules: passed — anchor sets agree, level rises agree within 0.05 m, the main lift has no LV-T stop, and the old incline remains below 16% grade.
- Portable map-package contract: passed — 36 graph spaces, 49 connections and 8 linked artifacts.

## Visual checks

- `overview/metric-overview.png`: inspected after the separate `U-MEDBAY` correction; zones remain opaque and readable, corridors remain separate and continuous.
- `vertical/vertical-section.png`: inspected at 1400×900; all three level datums, primary stairs, both lifts, no-stop technical shaft condition, and old inclined tunnel are legible.
- Style contract: passed for the overview and section under `caretaker-style-b-v1`.

## Cross-artifact checks

- Stable sector and anchor IDs match across the overview, topology graph, passports, vertical data and exact geometry.
- The approved topology is unchanged. `U-MEDBAY` is a post-approval identity correction for geometry already visible in the approved plan, with one short side-passage edge `E-U02A`; it does not alter the route concept.
- All metric room and transition dimensions remain provisional within the declared tolerance until the Godot traversal pass.

## Engine verification

Not performed at this gate. Godot greybox generation and runtime traversal are explicitly the next separately approved task after gate 2.

## Final package validation

Passed: `map-package.json` is internally consistent under the portable manifest contract supplied by the map-production skill.
