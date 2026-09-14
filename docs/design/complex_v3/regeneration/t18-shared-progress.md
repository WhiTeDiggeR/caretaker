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
