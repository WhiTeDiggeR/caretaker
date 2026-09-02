# Complex v3 regeneration editor

The dock is a thin Godot 4.7 editor client for `tools/complex_v3_regeneration/safe_regenerate.py`. It does not implement geometry generation in GDScript.

- `Regenerate Sector` blocks while the active scene UndoRedo version differs from its last saved version.
- `Validate Sector` calls the same CLI with `--validate-only`.
- Sector identity comes from root metadata `complex_v3_sector_id`/`sector_id`, or one unambiguous manifest `output_resource_dir` match. Conflicts block.
- The dock shows the current stage, process exit code, status, and absolute report path. It never offers Agent Fix for a clean result.
- A successful live result triggers an EditorFileSystem scan and reloads the active scene only when that scene belongs to the promoted sector. Failures leave the open scene untouched.
- Bind/Rebind require an explicit anchor ID and delegate to the T07 `ComplexV3AnchorEditorOperations`, preserving its Undo/Redo and no-guessing rules.

Configure the Python executable and canonical SVG/stair tool roots in the dock before regeneration. Reports are written under `user://complex_v3_regeneration_reports/` and can be opened with `Show Last Report`.

Headless fixture check:

```powershell
godot --headless --path . --script res://addons/complex_v3_regeneration_editor/regeneration_editor_check.gd
```

For manual editor workflow checks, open `fixtures/fixture_scene.tscn`. Its root carries `complex_v3_sector_id`; the fixture manifest, source SVG, composition input, and clean machine report are colocated. The fixture manifest is for editor behavior tests, not production generation.
