#!/usr/bin/env bash
# Runs an exported Linux build headless for a few seconds (issue #168) and fails when it crashes,
# logs any ERROR (including on quit, issue #171) or does not log its build version
# (BuildInfo.log_once in Shell._ready).
#
#   bash tools/build/smoke_test.sh build/linux/caretaker.x86_64
set -uo pipefail

binary="${1:-build/linux/caretaker.x86_64}"
frames="${SMOKE_FRAMES:-300}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

timeout 300 "$binary" --headless --quit-after "$frames" >"$log" 2>&1
code=$?
cat "$log"
echo "---"
errors=$(grep -c "^ERROR" "$log")
script_errors=$(grep -c "SCRIPT ERROR" "$log")
echo "exit=${code} errors=${errors} script_errors=${script_errors}"
[ "$code" -eq 0 ] || { echo "Smoke test failed: exit code ${code}" >&2; exit 1; }
[ "$errors" -eq 0 ] && [ "$script_errors" -eq 0 ] || { echo "Smoke test failed: errors in the log" >&2; exit 1; }
grep -q "^Сборка " "$log" || { echo "Smoke test failed: no build version in the log" >&2; exit 1; }
echo "Smoke test passed"
