#!/usr/bin/env bash
# Runs an exported Linux build headless twice (issues #168, #171, #173):
#   1. the startup scene (main menu) for a few frames;
#   2. a new game (`-- --new-game`, see Shell.NEW_GAME_ARG) until the complex is loaded, then quit.
# Fails when the build crashes, logs any ERROR (including on quit), does not log its build version
# (BuildInfo.log_once in Shell._ready) or does not reach the complex.
#
#   bash tools/build/smoke_test.sh build/linux/caretaker.x86_64
set -uo pipefail

binary="${1:-build/linux/caretaker.x86_64}"
menu_frames="${SMOKE_FRAMES:-300}"
game_frames="${SMOKE_GAME_FRAMES:-1500}"
complex="res://scenes/underground_research_complex.tscn"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
failed=0

run() { # label, frames, required log line, [user args]
  local label="$1" frames="$2" required="$3" code errors script_errors; shift 3
  timeout 300 "$binary" --headless --quit-after "$frames" "$@" >"$log" 2>&1
  code=$?
  echo "== ${label}"
  cat "$log"
  errors=$(grep -c "^ERROR" "$log")
  script_errors=$(grep -c "SCRIPT ERROR" "$log")
  echo "--- ${label}: exit=${code} errors=${errors} script_errors=${script_errors}"
  if [ "$code" -ne 0 ] || [ "$errors" -ne 0 ] || [ "$script_errors" -ne 0 ]; then
    echo "Smoke test failed (${label}): exit code or errors in the log" >&2; failed=1
  elif ! grep -qF "$required" "$log"; then
    echo "Smoke test failed (${label}): no '${required}' in the log" >&2; failed=1
  fi
}

run "main menu" "$menu_frames" "Сборка "
run "new game" "$game_frames" "Сцена: ${complex}" -- --new-game

[ "$failed" -eq 0 ] || exit 1
echo "Smoke test passed"
