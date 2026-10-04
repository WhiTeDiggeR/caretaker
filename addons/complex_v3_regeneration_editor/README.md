# Complex v3 regeneration editor

The dock is a thin Godot 4.7 editor client for `tools/complex_v3_regeneration/safe_regenerate.py`. It does not implement geometry generation in GDScript.

The Russian-language dock is ordered as the work happens:

1. **Сектор** — sector id and source plan file; if the scene is not a sector scene a hint says which scene to open.
2. **Работа с планом** — `1. Открыть план в Inkscape`, `2. Проверить сектор` (`--validate-only`), `3. Пересоздать сектор`.
3. **Результат** — coloured status (`✔` clean, `✖` blocked/failed), problem count, human-readable stage, exit code, a selectable read-only list of problems with `Копировать ошибку` (copies the status and details to the clipboard), `Показать отчёт` and, when offered, `Исправить агентом`.
4. **Привязка объектов** (collapsed) — `Привязать двери по ID` plus manual Bind/Rebind/Unbind with an explicit anchor ID.
5. **Инструменты** — generator readiness (`Ready` only with `svg_to_godot3d >= 1.19.0` and `generate_godot_stairs >= 2.9.0`), the resolved Inkscape and the selected Agent Fix agent (Claude, Codex or custom) with the `Выбрать агентом Claude` button, which writes the Claude Code launcher and hides itself once Claude is selected.
6. **Настройки** (collapsed) — every field has a one-line explanation.

- `Пересоздать сектор` blocks while the active scene UndoRedo version differs from its last saved version.
- Sector identity comes from root metadata `complex_v3_sector_id`/`sector_id`, or one unambiguous manifest `output_resource_dir` match. Conflicts block.
- `Открыть план в Inkscape` starts Inkscape on the source SVG. The executable is resolved from the `inkscape_executable` setting, then `COMPLEX_V3_INKSCAPE`, then the standard install locations and the Microsoft Store package (found through `Get-AppxPackage`). The dock shows where it was found; if nothing is found it asks for the path. No browser fallback is used.
- A successful regeneration waits for `EditorFileSystem` import, replaces the loaded architecture/stairs resources, rebuilds `Generated`, reloads `AnchorRegistry`, applies authored bindings, and reloads the same saved sector scene. Failed CLI transactions never trigger a scan or scene reload.
- `Исправить агентом` is hidden for clean/warning-only reports and for source semantics, toolchain/version, stair, resource, or generated-geometry failures. It is visible only when composition validation produced a current repair queue whose every open blocker belongs to authored content/bindings and has an allowlisted code.
- `Привязать двери по ID` uses `ComplexV3DoorBindingBuilder` (see `scenes/complex_v3_regeneration/README.md`), writes the sector's bindings file and applies it immediately. Manual Bind/Rebind delegate to the T07 `ComplexV3AnchorEditorOperations`, preserving Undo/Redo and the no-guessing rules.

Tool paths are persistent `EditorSettings`, configured once in the dock's Settings
section:

- `complex_v3_regeneration/python_executable`
- `complex_v3_regeneration/svg_tool_root`
- `complex_v3_regeneration/stair_tool_root`
- `complex_v3_regeneration/agent_launcher`
- `complex_v3_regeneration/inkscape_executable`

Each value resolves in this order: EditorSettings, then its `COMPLEX_V3_*` environment
variable. There is no default skill directory: the tool roots must point at the
skills the user's agent actually has installed, and the panel stays blocked with a
request for the missing path until they are set. The panel shows detected
versions and `Ready` only for `svg_to_godot3d >= 1.19.0` and
`generate_godot_stairs >= 2.9.0`; missing or incompatible tools block before the
CLI can create staging. Reports are written under
`user://complex_v3_regeneration_reports/` and can be opened with `Show Report`.

Headless fixture check:

```powershell
godot --headless --path . --script res://addons/complex_v3_regeneration_editor/regeneration_editor_check.gd
```

For manual editor workflow checks, open `fixtures/fixture_scene.tscn`. Its root carries `complex_v3_sector_id`; the fixture manifest, source SVG, composition input, and clean machine report are colocated. The fixture manifest is for editor behavior tests, not production generation.
