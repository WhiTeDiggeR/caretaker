# T18 — shared infrastructure rollout

Work starts from integrated T17 commit e0707f9. Startup and authored sector
content are untouched. The combined check proved that generating route-space and
connector prisms again in `complex_v3_infrastructure` duplicates the accepted
sector architecture. Ownership is therefore explicit: horizontal routes and
connectors belong to their sector rollout scenes; Route A geometry belongs to
its pilot. The shared package owns cross-sector frames, alias records, ownership
metadata, validation and diagnostics, but contains no duplicate meshes or
colliders.

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

`build_shared_contract.py` stages and atomically swaps a deterministic package at
`gen/shared`. It publishes 69 unique frames, a generation report and a Godot
contract scene. Repeating the build is byte-identical. Zero-length connectors
are retained as explicit aliases to source portal IDs, never as invented prisms.
The separate source audit remains a pre-generation inventory and intentionally
does not claim combined readiness.

## Explicit portal mapping result

`map_vertical_ports.py` compares source portal segments against declared shaft
boundaries without moving/projecting either source. A sector threshold outside
the generator shaft is valid and remains an independent frame; it is not used to
infer stair orientation. Generator-boundary ports and external thresholds are
classified separately. Missing explicit level-space mappings and stairs without
a boundary port remain blocking diagnostics. No anchor frames or stair geometry
are emitted for those unresolved generator ports.
Passenger LV-T remains pass-through without a threshold/stop. Route A continues
to reuse its integrated pilot. Tests cover line reversal, rejection of interior
and out-of-bounds segments, source ordering invariance and no invented stop.

Resolving these conflicts requires reviewed reconciliation of the geometry and
vertical handoffs, outside T18's generated/config/report ownership. Do not change
approved sector geometry or shaft dimensions silently to obtain a passing build.

## Verification result

- Combined Godot assembly loads all upper, lower, technical, U-MEDBAY and Route A
  outputs plus the shared contract: 142 checks, zero positive shared/sector or
  Route-A/shared collision overlaps.
- The 57-test complex_v3 suite passes (three fixture-dependent skips).
- Review diagrams are generated deterministically from `anchor_frames.json` for
  LV-U, LV-L and LV-T.
- Seven non-pilot vertical geometries remain explicitly blocked until their
  sector-owned floors/walls expose reviewed non-overlapping openings. Their
  threshold and shaft frames remain stable; no geometry or stop is guessed.
