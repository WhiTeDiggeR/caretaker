# T17 — technical rollout interface

Architecture inputs are reviewed metric handoff data, not presentation SVG
coordinates. Six sectors own their generated architecture under `gen/t/`:
T-EAST-VERTICAL, T-ENERGY, T-FREIGHT, T-OLD-ACCESS, T-UTILITIES and T-WORKSHOP.
Their 58 authored object identities and original dressing scenes are preserved.
All anchor bindings block on missing ID; no nearest-anchor fallback exists.

## Circulation ownership decision

The user authorized T-CIRCULATION as the seventh, authored-only sector interface.
It is not a seventh independently regenerated architecture package. The metric
handoff has no T-CIRCULATION sector/spaces; the existing zone previews shared
infrastructure and contains one freely positioned pipe cluster. Its exact world
transform and persistent object ID are recorded in
`technical_circulation_interface.json`. T18 owns circulation architecture once;
T17 must not copy shared route walls/floors into a sector package. Combined
circulation validation remains explicitly pending T18.

## Equipment and ambiguity

The reviewed inventory contains explicit single-space floor footprints for all
non-portal technical props. They are floor-bound, never heuristically wall-bound.
This is a single support anchor, not evidence of a multi-construction constraint.
There are no reviewed multi-anchor equipment declarations to solve in this
inventory. If such a constraint is introduced, do not approximate it with one
wall: require an explicit reviewed exception, source object ID, required anchors,
fixed world transform and blocking diagnostic until the constraint is supported.
The sole current free-binding exception is the circulation pipe cluster: missing
space/support semantics are preserved as free placement, not fabricated.

## Routes and checks

The three shared technical routes T-TECH, T-FRT and T-CABLE-GALLERY retain their
handoff bounds, widths and IDs and belong to T18. Regression tests verify none of
the six sectors' authored prop footprints enters those route rectangles. Sector
composition validation checks generated geometry and authored footprints before
promotion. Dedicated regression checks reserve the full portal segment with
0.3 m approach depth on either face against authored prop footprints.
Closed/non-traversable gates remain solid
walls and sealed markers, not guessed traversable openings.

Commands: `build_floor_rollout.py --level technical`, per-sector
`safe_regenerate.py --manifest rollouts/technical_generation_manifest.json`,
`python -m unittest discover -s tools/complex_v3_regeneration/tests`, Godot editor
import, `floor_rollout_check.gd -- --level=technical` and `--visual`, then
`verify_floor_rollout.py --level technical` with verified evidence flags.
The shared/startup scenes, upper/lower outputs and original dressing are unchanged.

Godot 4.7 sector smoke passed: six architecture packages, 58 authored objects,
nonempty meshes/collision shapes. Six before/after images for Utilities, East
Vertical and Old Access were manually compared; geometry/dressing align, with
neutral generated architecture materials. Startup smoke exited successfully
with the existing warning about two ObjectDB leaks. Combined shared route and
circulation runtime validation is deferred explicitly to T18.

Test caveat: the existing upper byte-hash determinism test fails on the first
fresh Windows CRLF checkout, then passes after the builder writes canonical LF.
This is a newline-only fixture comparison, not an upper geometry change. T17
does not edit shared tests or deliver regenerated upper inputs.
