# T16 — Lower-floor regeneration rollout

T16 connects all eleven non-pilot lower sectors to Safe Regenerate while leaving
`L-ARCHIVE-A`, the startup scene, upper/technical outputs, existing dressing
scenes, and materials unchanged.

Metric SVGs are derived from the reviewed handoff rather than presentation-plan
coordinates. Generated files live under `gen/l/`; authored compositions and
bindings live under `scenes/complex_v3_regeneration/rollout/lower/AuthoredContent`.
Stable floor, ceiling, wall, portal, object, and binding identities depend on
semantic handoff IDs, never generation order or OBJ names.

## Closed transition policy

The handoff declares `PX-E-L13-L-CHAMBER-2`, `PX-E-L14-L-CHAMBER-3`, and
`PX-E-L16-L-CHAMBER-5` closed and non-traversable. They are emitted as explicit
`sealed_portal` point markers carrying the unchanged handoff portal ID. They do
not emit door frames, do not appear in a wall's `opening_anchor_ids`, and do not
cut generated wall geometry. Their existing authored gate frames are preserved
as bounded mounts on the exact wall anchor, with `portal_semantics` recording
`state: closed` and `traversable: false`.

Any portal with contradictory state/traversability, ambiguous side, missing
wall, missing authored footprint, or non-unique wall-face placement blocks the
build or promotion. Missing anchors retain their old ID and block; no automatic
nearest-anchor selection is permitted.

## Verification scope

Tests cover the exact eleven-sector inventory, all 110 unique authored object
IDs and scene references, blocking missing-anchor policies, exact handoff portal
centers and widths, required door frames for traversable portals, sealed markers
and solid-wall behavior for all three closed transitions, semantic ID stability,
second-pass no-op regeneration, Godot loading/collisions, and visual comparisons
of Old Core, Chamber 2, and Old Receiving.

Verified: 49 regeneration unit tests passed; aggregate validation passed for
11 sectors, 423 anchors and 110 bindings; every second pass returned ready/noop.
Godot 4.7 imported the final packages, loaded all eleven scenes with nonempty
meshes and collision shapes, and passed startup smoke. Six before/after images
were manually compared: reviewed geometry and dressing positions align, with
neutral generated materials replacing the legacy architectural appearance.

Scope caveat: upper-floor generation retains T15 behavior for compatibility.
Two closed upper portals discovered during regression testing require explicit
review in the final rollout audit; T16 does not silently alter upper packages.
