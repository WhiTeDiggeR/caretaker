# Stage 2 validation report

Date: 2026-07-30 (central-core trace revision, Issue #41)

Map: `caretaker-complex-v3`

Gate: full 3D handoff approved on 2026-07-29; central passenger core revised from its approved SVG on 2026-07-30

## Automated checks

- Stage 1 regression: passed — 3 levels, 7 anchors, 30 sectors, 5 routes, 49 topology connections.
- Stage 2 geometry: passed — 30 passports, 143 exact room spaces, 113 internal portals, 43 external portals.
- Physical topology coverage: passed — all 49 approved topology edges are represented by corridors, portals, stairs, lifts, shaft rules, or the old inclined tunnel.
- Positive-area room overlaps: none across all spaces on the same level.
- Engine follow-up regression: passed — exact technical-sector footprints were clipped to the real boundary of `T-TECH`; no room overlaps a physical route. The cable gallery remains an explicitly non-floor service overlay.
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

Performed for the Issue #41 revision: Godot 4.7 imported the project, built 143 room spaces and 151 traversable sector passages, validated all 151 with the player capsule, and passed the startup smoke test. Editor-preview also confirmed the central staircase, lift cabin and ceiling toggle.

## Final package validation

Passed: `map-package.json` is internally consistent under the portable manifest contract supplied by the map-production skill.
