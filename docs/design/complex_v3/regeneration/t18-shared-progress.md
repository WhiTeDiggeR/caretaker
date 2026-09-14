# T18 — shared infrastructure audit checkpoint

Work starts from integrated T17 commit e0707f9. Shared architecture has one owner,
`complex_v3_infrastructure`; sector copies are forbidden. T-CIRCULATION remains
the user-approved authored-only interface. Startup and authored sector content
are untouched.

The reproducible `audit_shared_inputs.py` reads reviewed geometry and vertical
handoffs. Current inventory: 47 shared sources (38 connection corridors), eight
vertical transitions, five positive XZ bounds intersection candidates between
route and sector spaces. Bounds candidates are not proof of physics overlaps;
they must be clipped/unioned with single ownership before combined-scene QA.
Zero-length connectors alias existing explicit portal sources and produce no
invented corridor prism.

Four non-pilot stair transitions lack explicit entry/exit side configuration.
Two elevators require exact per-stop threshold mapping; the main passenger
elevator must not gain a technical stop on its pass-through level. These are
pending blocking diagnostics, not claims that shaft dimensions are absent.
Resolve them using explicit portal geometry or reviewed configuration; never
guess sides, change dimensions, or silently rebind retired anchors. Route A uses
its existing integrated pilot rather than duplicate stair geometry.

Status: audit only. Shared generated geometry, atomic regeneration, complete
cross-floor frames, combined test assembly, collision/runtime proof and visual
review are not yet implemented/verified. The audit deliberately reports
`not_ready_for_combined_assembly` and `combined_collision_verification: not_run`.

## Explicit portal mapping result

`map_vertical_ports.py` now compares source portal segments against declared
shaft boundaries without moving/projecting either source. It records 19 portal
candidates and 17 blocking diagnostics (boundary conflicts, missing explicit
level-space mappings and multiple valid portals needing role selection).
For example P-U-FREIGHT-03 is on X=13.5 while VT-FREIGHT-LIFT's shaft starts at
X=16.5. A same-name room is not proof that its door is a valid shaft threshold.
No anchor frames or stair/lift geometry are emitted for conflicting candidates.
Passenger LV-T remains pass-through without a threshold/stop. Route A continues
to reuse its integrated pilot. Tests cover line reversal, rejection of interior
and out-of-bounds segments, source ordering invariance and no invented stop.

Resolving these conflicts requires reviewed reconciliation of the geometry and
vertical handoffs, outside T18's generated/config/report ownership. Do not change
approved sector geometry or shaft dimensions silently to obtain a passing build.
