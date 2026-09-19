# Complex v3 regeneration editor

The dock is a thin Godot 4.7 editor client for `tools/complex_v3_regeneration/safe_regenerate.py`. It does not implement geometry generation in GDScript.

- `Regenerate Sector` blocks while the active scene UndoRedo version differs from its last saved version.
- `Validate Sector` calls the same CLI with `--validate-only`.
- Sector identity comes from root metadata `complex_v3_sector_id`/`sector_id`, or one unambiguous manifest `output_resource_dir` match. Conflicts block.
- The main dock shows sector, canonical source, toolchain readiness, `Clean`/`Blocked`/`Failed`, and problem count. Persistent paths, stage/exit diagnostics, and manual binding controls are kept under collapsible `Settings`.
- A successful regeneration waits for `EditorFileSystem` import, replaces the loaded architecture/stairs resources, rebuilds `Generated`, reloads `AnchorRegistry`, applies authored bindings, and reloads the same saved sector scene. Failed CLI transactions never trigger a scan or scene reload.
- `Agent Fix` is hidden for clean/warning-only reports and for source semantics, toolchain/version, stair, resource, or generated-geometry failures. It is visible only when composition validation produced a current repair queue whose every open blocker belongs to authored content/bindings and has an allowlisted missing-anchor, bounds, collision/passage, support, or mount code. The runner itself is supplied by T25.
- Bind/Rebind require an explicit anchor ID and delegate to the T07 `ComplexV3AnchorEditorOperations`, preserving its Undo/Redo and no-guessing rules.

Tool paths are persistent `EditorSettings`, configured once in the dock's Settings
section:

- `complex_v3_regeneration/python_executable`
- `complex_v3_regeneration/svg_tool_root`
- `complex_v3_regeneration/stair_tool_root`
- `complex_v3_regeneration/agent_launcher`

Each value resolves in this order: EditorSettings, its `COMPLEX_V3_*` environment
variable, then a compatible installed Codex skill. The panel shows detected
versions and `Ready` only for `svg_to_godot3d >= 1.19.0` and
`generate_godot_stairs >= 2.9.0`; missing or incompatible tools block before the
CLI can create staging. Reports are written under
`user://complex_v3_regeneration_reports/` and can be opened with `Show Report`.

Headless fixture check:

```powershell
godot --headless --path . --script res://addons/complex_v3_regeneration_editor/regeneration_editor_check.gd
```

For manual editor workflow checks, open `fixtures/fixture_scene.tscn`. Its root carries `complex_v3_sector_id`; the fixture manifest, source SVG, composition input, and clean machine report are colocated. The fixture manifest is for editor behavior tests, not production generation.
