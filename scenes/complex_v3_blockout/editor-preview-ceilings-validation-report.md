# Complex v3 editor-preview ceilings validation

Issue: #38

Godot: 4.7.1 stable

Date: 2026-07-29

## Result

- `editor_preview_show_ceilings` is exposed in the sector root Inspector.
- The setting defaults to `false`, so standalone sector previews are open from above.
- Changing the setting rebuilds only the transient `Generated` subtree.
- `AuthoredContent` remains untouched.
- Runtime continues to use `include_ceilings` and builds all ceilings normally.

## Verification

- Editor controls: `U-MEDBAY`, `L-OLD-CORE`, and `T-UTILITIES` had zero ceilings by default, created ceilings when enabled, and removed them when disabled again.
- Editor preview: `COMPLEX_V3_EDITOR_PREVIEW_OK zones=3 collisions=0 transient=true ceilings=toggle`.
- Runtime: 139 spaces, 7 routes, 7 anchors, 8 transitions, 145 floors, 145 ceilings, and 1,566 colliders.
- Sector composition: 30 sectors, 139 spaces, and 147 portals.
- Portal capsule checks: 147 passed.
- Static source and sector validators: passed.
- `git diff --check`: passed.

Godot emitted the existing host warning about the Windows root certificate store; it did not affect editor or runtime validation.
