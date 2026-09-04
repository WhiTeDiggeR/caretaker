# U-MEDBAY regeneration pilot ledger

- Mode: create selected isolated conversion artifact; uninterrupted verification.
- Canonical pilot SVG: `u_medbay_pilot.svg`; existing `plans/sectors/upper/u_medbay.svg` is a control and is not edited.
- Style: `caretaker-style-b-v1`; metre coordinates, SVG X → Godot X, SVG Y → Godot Z, Godot +Y up.
- Source hierarchy: `geometry/complex-handoff.json` geometry and IDs; sector passport semantics; T01 regeneration contract; this pilot ledger only chooses object-binding policies.
- Fixed: sector bounds `[-94, 7, -80, 15]`, seven space bounds, ten canonical wall centerlines at `0.30 m`, seven portal segments `1.20 × 2.40 m`, floor `Y=0`, ceiling underside `Y=3.4`.
- Inferred/provisional inherited unchanged: all stage-2 metric dimensions and their recorded `0.25 m` adjustment tolerance. The pilot does not consume that tolerance by moving geometry.
- Explicit side policy: wall normals select the named finished face. Internal door `inside` points to the clean corridor for portals 01–05 and to triage for portal 06. The external east door `inside` points west into U-MEDBAY. No hinge is declared. These choices are source annotations, never inferred by the converter.
- Engine profile: `generic`, scale `1`, origin `none`, elevation `0`, +Z not inverted; floor thickness `0.20`, ceiling thickness `0.20`, strict ceiling alignment and wall overlap checks.
- Forbidden: editing the control sector/startup, deriving IDs from generated order, guessing a missing side, or treating the viewer as geometry.
- Required validation: SVG/viewer structure, strict inspector/converter equality, handoff coordinate comparison, generated resources, Godot import/runtime, move/resize/remove/failure scenarios, and visual before/after comparison.

Status: verified on 2026-09-04 by the automated and Godot checks recorded in
`../reports/verification-summary.json`. This is implementation verification,
not a replacement for human art-direction approval.
