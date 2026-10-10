#!/usr/bin/env bash
# Runs every automated check of the repository (Python suites and headless Godot checks).
# Used by .github/workflows/godot-validation.yml and locally: `bash tools/ci/run_checks.sh`.
#
# Environment:
#   GODOT_BIN        Godot 4.7 executable (default: `godot` from PATH)
#   SVG_TOOL_ROOT    svg-plan-to-godot >= 1.19.0   (optional: enables the tests that need it)
#   STAIR_TOOL_ROOT  generate-godot-stairs >= 2.9.0 (optional: enables the real-generator tests)
# Checks that need the generation tools are skipped by their own tests when the roots are unset.
set -u
cd "$(dirname "$0")/../.."

GODOT="${GODOT_BIN:-godot}"
export GODOT_BIN="$GODOT"
failed=()
passed=0

record() { # name status
  if [ "$2" -eq 0 ]; then passed=$((passed + 1)); echo "PASS  $1"; else failed+=("$1"); echo "FAIL  $1"; fi
}

python_suite() { # directory
  local output
  output=$(python -m unittest discover -s "$1" 2>&1); local code=$?
  echo "$output" | grep -E "^(Ran |OK|FAILED)" | tr '\n' ' '; echo
  [ $code -ne 0 ] && echo "$output" | tail -40
  record "python $1" $code
}

python_script() { # label, args...
  local label="$1"; shift
  local output
  output=$(python "$@" 2>&1); local code=$?
  [ $code -ne 0 ] && echo "$output" | tail -20
  record "$label" $code
}

# A Godot check passes only when it exits with 0 AND prints its success marker.
godot_check() { # resource, marker-regex, [extra godot args]
  local resource="$1" marker="$2" output code
  if [[ "$resource" == *.tscn ]]; then
    output=$(timeout 300 "$GODOT" --headless --path . "$resource" 2>&1); code=$?
  else
    output=$(timeout 300 "$GODOT" --headless --path . --script "$resource" 2>&1); code=$?
  fi
  if [ $code -eq 0 ] && echo "$output" | grep -Eq "$marker"; then
    record "godot $resource" 0
  else
    echo "$output" | tail -25
    record "godot $resource (exit $code, marker /$marker/)" 1
  fi
}

echo "== Python suites"
python_suite tools/complex_v3_regeneration/tests
python_suite tools/complex_v3_composition_validator/tests
python_suite tools/complex_v3_repair_package/tests
python_script "scene index matches the passports" scenes/complex_v3_blockout/validate_sector_scenes.py
# The registry exits 2 while verticals are unresolved; it must still build (exit 0 or 2) and list them.
registry_output=$(python tools/complex_v3_regeneration/vertical_registry.py --json 2>&1); registry_code=$?
if [ $registry_code -le 2 ] && echo "$registry_output" | grep -q '"verticals"'; then record "vertical registry builds" 0; else echo "$registry_output" | tail -15; record "vertical registry builds" 1; fi

echo "== Godot import"
"$GODOT" --headless --editor --path . --quit >/dev/null 2>&1
record "godot editor import" $?

echo "== Godot checks"
while IFS='|' read -r resource marker; do
  [ -z "$resource" ] && continue
  godot_check "$resource" "$marker"
done <<'CHECKS'
res://addons/complex_v3_regeneration_editor/regeneration_editor_check.gd|COMPLEX_V3_REGENERATION_EDITOR_CHECK_OK
res://addons/complex_v3_anchor_editor/editor_operations_check.gd|COMPLEX_V3_EDITOR_BINDING_OK
res://scenes/complex_v3_regeneration/anchor_runtime_check.gd|COMPLEX_V3_ANCHOR_RUNTIME_OK
res://scenes/complex_v3_regeneration/anchor_surface_check.gd|COMPLEX_V3_SURFACE_CHECK checks=[0-9]+ failures=0
res://scenes/complex_v3_regeneration/sector_anchor_controller_check.tscn|COMPLEX_V3_SECTOR_ANCHOR_CONTROLLER_OK
res://scenes/complex_v3_regeneration/production_anchor_binding_check.tscn|COMPLEX_V3_PRODUCTION_ANCHOR_BINDINGS_OK
res://scenes/complex_v3_regeneration/door_binding_check.gd|DOOR_BINDING_CHECK doors=0 errors=0
res://scenes/complex_v3_regeneration/door_frame_prefab_check.gd|DOOR_FRAME_PREFAB_CHECK doors=0 .* errors=0
res://scenes/complex_v3_regeneration/surface_conflict_check.gd|SURFACE_CONFLICT_CHECK sectors=32 findings=[0-9]+ errors=0
res://scenes/complex_v3_regeneration/rollout/shared/combined_check.gd|SHARED_COMBINED checks=[0-9]+ errors=0
res://tools/complex_v3_regeneration/tests/production_matrix_check.gd|PRODUCTION_MATRIX generated=32 sectors=32 errors=0
res://scenes/complex_v3_blockout/sector_wrapper_contract_check.gd|COMPLEX_V3_SECTOR_WRAPPER_CONTRACT_OK
res://scenes/complex_v3_blockout/set_dressing/set_dressing_scene_check.gd|SET_DRESSING_GODOT_SCENES_OK
res://scenes/complex_v3_blockout/complex_v3_sector_check.gd|COMPLEX_V3_SECTORS_OK sectors=32
res://tests/opening/opening_checks.tscn|OPENING_CHECKS checks=[0-9]+ failures=0
res://tests/opening/dream_e2e.tscn|DREAM_E2E_OK
CHECKS

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "ALL CHECKS PASSED ($passed)"
  exit 0
fi
echo "FAILED (${#failed[@]} of $((passed + ${#failed[@]}))):"
printf '  - %s\n' "${failed[@]}"
exit 1
