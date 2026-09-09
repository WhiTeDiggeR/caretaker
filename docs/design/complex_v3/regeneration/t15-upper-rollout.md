# T15 — Upper-floor regeneration rollout

T15 brings every non-pilot upper sector into the T01/T10 pipeline. The existing
presentation SVGs remain visual controls: their page-space coordinates and door
arcs are not generator inputs. Metric sources are derived from the reviewed
`complex-handoff.json`, with explicit portal sides and stable IDs derived from
handoff space and portal identifiers.

## Scope and ownership

- `Generated/`, `anchor_frames.json`, and generation manifests under `gen/u/`
  are generator-owned and may be replaced only by staged promotion.
- `AuthoredContent/*/composition.json`, `object_bindings.json`, the existing
  dressing scenes, and all 149 `object_id` values are authored-owned.
- Existing materials and presentation plans are unchanged.
- The rollout does not modify the startup scene, the two completed upper pilots,
  lower/technical floors, or cross-sector runtime composition.

## Sectors

`U-CENTRAL-CORE`, `U-CHAMBER-4`, `U-CHAMBER-6`, `U-CONTROL`, `U-DOMESTIC`,
`U-EAST-SUPPORT`, `U-EMERGENCY`, `U-FREIGHT`, and `U-SECURITY` are ready entries
in `upper_generation_manifest.json`.

Every door emits `center`, `threshold_inside`, and `threshold_outside`. No hinge
is emitted because the handoff does not author a hinge side. Missing anchors use
`on_missing_anchor: block`; no nearest-anchor fallback exists.

## Known reviewed exception

`U-EMERGENCY` contains adjacent 3.4 m and 3.8 m spaces. Its source assigns exact
per-surface ceiling elevations and per-wall heights. The generic nearest-wall
ceiling warning is retained for audit but is not promoted to strict failure for
that sector because it cannot represent the reviewed height step. Wall overlap,
binding, composition, and staging checks remain strict.

Wall-mounted props and portal frames declare bounded `wall_integration`; only
their referenced wall normal may consume the declared depth. Undeclared,
over-depth, or unrelated-wall intersections block promotion.

## Verification

The rollout test checks the exact nine-sector inventory, 149 unique preserved
object IDs, one binding per object, blocking missing-anchor policy, globally
unique generated anchor IDs, all three required door frames, absence of guessed
hinges, stable semantic IDs across resize/reorder, and byte-identical source and
manifest rebuilds. The Godot check loads every generated architecture and every
unchanged dressing scene, verifies collision resources, and captures before/after
views for Control, Emergency, and Freight.
