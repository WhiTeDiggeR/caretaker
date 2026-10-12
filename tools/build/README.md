# Building the game

Issue #168. Presets are in `export_presets.cfg`; output goes to `build/` (ignored by git).

| Command | Result |
| --- | --- |
| `bash tools/build/export_windows.sh` | `build/windows/caretaker.exe` + `caretaker.pck` |
| `bash tools/build/export.sh linux` | `build/linux/caretaker.x86_64` + `caretaker.pck` |
| `BUILD_DEBUG=1 bash tools/build/export.sh windows` | debug template: debug output and the test range in the menu |
| `bash tools/build/smoke_test.sh build/linux/caretaker.x86_64` | runs the Linux build headless, fails on a crash, a script error or a missing version line |

The script imports the project, writes the short commit hash to `build_info.json` (removed after the export, read by `scenes/shell/build_info.gd`) and exports with the release template. The `.exe` and `.pck` must stay together.

## Export templates

Godot needs the 4.7.stable export templates once per machine:

- Editor: **Editor → Manage Export Templates → Download and Install**.
- Manually: unpack `Godot_v4.7-stable_export_templates.tpz` (a zip) from the
  [4.7-stable release](https://github.com/godotengine/godot-builds/releases/tag/4.7-stable) and put the files from its
  `templates/` folder into `%APPDATA%\Godot\export_templates\4.7.stable\` (Windows) or
  `~/.local/share/godot/export_templates/4.7.stable/` (Linux).

## On Windows

Run the script from Git Bash with the **console** Godot executable (keep its original file name):

```sh
GODOT_BIN="/c/Tools/Godot/Godot_v4.7-stable_win64_console.exe" bash tools/build/export_windows.sh
```

Without Git Bash the same export is one command in `cmd`/PowerShell from the repository root (no commit hash then, the menu shows `dev`):

```bat
Godot_v4.7-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/windows/caretaker.exe
```

Or in the editor: **Project → Export → Windows Desktop → Export Project**.

## What is not in the build

`tests/`, `tools/`, `docs/` (except the complex handoff JSON that `complex_v4_blockout.gd` reads at runtime), `gen/shared/` reports, regeneration fixtures and the editor-only addons `addons/complex_v4_*`. Editor plugins are never enabled in exported games; their folders are excluded as well. `scenes/sandbox/` stays in the build: the menu offers it only in debug builds (`OS.is_debug_build()`), so a debug export keeps a working test range.
