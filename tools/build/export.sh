#!/usr/bin/env bash
# Exports the game with a preset from export_presets.cfg (issue #168).
#
#   bash tools/build/export.sh windows   # build/windows/caretaker.exe + caretaker.pck
#   bash tools/build/export.sh linux     # build/linux/caretaker.x86_64 + caretaker.pck
#
# Environment:
#   GODOT_BIN   Godot 4.7 executable (default: `godot` from PATH). On Windows use the console
#               wrapper Godot_v4.7-stable_win64_console.exe (see tools/build/README.md).
#   BUILD_DEBUG 1 exports with the debug template (keeps the test range and debug output).
#
# Needs the 4.7.stable export templates (Editor > Manage Export Templates, or unpack the .tpz into
# ~/.local/share/godot/export_templates/4.7.stable/ / %APPDATA%\Godot\export_templates\4.7.stable\).
# The short commit hash goes into res://build_info.json for the export only; the file is removed
# afterwards and is listed in .gitignore.
set -euo pipefail
cd "$(dirname "$0")/../.."

target="${1:-windows}"
case "$target" in
  windows) preset="Windows Desktop"; output="build/windows/caretaker.exe" ;;
  linux)   preset="Linux";           output="build/linux/caretaker.x86_64" ;;
  *) echo "usage: $0 windows|linux" >&2; exit 2 ;;
esac

GODOT="${GODOT_BIN:-godot}"
version_line="$("$GODOT" --headless --version 2>/dev/null | tail -n 1 | tr -d '\r')"
case "$version_line" in
  4.7.stable*) ;;
  *) echo "Godot 4.7 stable is required, got: '${version_line}' from ${GODOT}" >&2; exit 1 ;;
esac

commit="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
if [ "$commit" != dev ] && [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  commit="${commit}-dirty"
fi
trap 'rm -f build_info.json' EXIT
printf '{"commit": "%s"}\n' "$commit" > build_info.json

mode="--export-release"
[ "${BUILD_DEBUG:-0}" = 1 ] && mode="--export-debug"

rm -rf "$(dirname "$output")"
mkdir -p "$(dirname "$output")"
# Keep the editor from scanning previous builds as project files.
touch build/.gdignore
# Import first: exporting a project whose .godot/ cache is missing or stale can skip resources.
"$GODOT" --headless --path . --import
started=$(date +%s)
"$GODOT" --headless --path . "$mode" "$preset" "$output"
elapsed=$(( $(date +%s) - started ))

[ -f "$output" ] || { echo "Export failed: $output was not created" >&2; exit 1; }
echo "Exported ${preset} (${commit}) to $(dirname "$output") in ${elapsed}s:"
ls -l "$(dirname "$output")"
du -sh "$(dirname "$output")"
