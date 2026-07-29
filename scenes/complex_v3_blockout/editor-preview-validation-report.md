# Complex v3 sector editor-preview validation

Issue: #37

Godot: 4.7.1 stable

Date: 2026-07-29

## Result

- All 30 sector scenes have `editor_preview_enabled = true`.
- Opening a sector scene in the editor builds a transient `Generated` subtree.
- The preview subtree has no owner and is therefore not serialized into the sector scene.
- Editor preview creates no `StaticBody3D` collision bodies.
- `AuthoredContent` remains present and is never cleared by preview rebuilding.
- The full assembly disables previews on its 30 child sector scenes.

## Editor controls

The editor-only harness opened and built one sector from every level:

- `U-MEDBAY`: 5 room spaces.
- `L-OLD-CORE`: 4 room spaces.
- `T-UTILITIES`: 7 room spaces.

Result: `COMPLEX_V3_EDITOR_PREVIEW_OK zones=3 collisions=0 transient=true`.

## Regression checks

- Sector scenes: 30 sectors, 139 room spaces, 147 portals, 3 viewing modes.
- Full blockout: 139 spaces, 7 route spaces, 7 anchors, 8 transitions, 1,566 colliders.
- Portal capsule checks: 147 passed.
- Godot headless editor import: passed.
- Startup scene smoke test: passed; startup scene remains `res://scenes/underground_research_complex.tscn`.
- `git diff --check`: passed.

Godot emitted the existing host warning about the Windows root certificate store; it did not affect import, preview generation, or runtime checks.
