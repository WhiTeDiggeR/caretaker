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
python_suite tools/complex_v4/tests
python_suite tools/complex_v4/composition_validator/tests
python_suite tools/complex_v4/repair_package/tests
python_suite tools/complex_v3_pilots/tests
python_suite tools/dream/tests
python_script "scene index matches the passports" scenes/complex_v4/validate_sector_scenes.py
python_script "generated sounds match their recipes" tools/audio/make_sfx.py --check
python_script "floor plan page builds from the canonical SVGs" tools/complex_v4/floor_plans/build_floor_plans.py --check
python_script "art props: sizes, anchors, budgets, provenance" tools/props/validate_props.py
python_script "git lfs: new binaries are LFS pointers" tools/ci/lfs_check.py
python_script "textures: loads/ imported as 3D (VRAM + mipmaps, <= 2048 px)" tools/ci/texture_import_check.py
# The registry exits 2 while verticals are unresolved; it must still build (exit 0 or 2) and list them.
registry_output=$(python tools/complex_v4/vertical_registry.py --json 2>&1); registry_code=$?
if [ $registry_code -le 2 ] && echo "$registry_output" | grep -q '"verticals"'; then record "vertical registry builds" 0; else echo "$registry_output" | tail -15; record "vertical registry builds" 1; fi

# Git logic of the branch preview tool (tools/dev/open_branch.ps1, issue #175) on a temporary repository.
if command -v pwsh >/dev/null 2>&1; then
  output=$(pwsh -NoProfile -File tools/dev/tests/open_branch_test.ps1 2>&1); code=$?
  if [ $code -eq 0 ] && echo "$output" | grep -Eq "OPEN_BRANCH_TEST checks=[0-9]+ failures=0"; then
    record "branch preview: open_branch.ps1 git logic" 0
  else
    echo "$output" | grep -E -A6 "^FAIL" | head -40
    record "branch preview: open_branch.ps1 git logic" 1
  fi
else
  echo "SKIP  branch preview: pwsh is not installed"
fi

echo "== Godot import"
"$GODOT" --headless --editor --path . --quit >/dev/null 2>&1
record "godot editor import" $?

echo "== Godot scenes"
# The startup scene (main menu) and the new-game scene load headless without errors (#173).
scene_smoke() { # label, [scene]
  local label="$1" output code; shift
  output=$(timeout 300 "$GODOT" --headless --path . "$@" --quit-after 5 2>&1); code=$?
  if [ $code -eq 0 ] && ! echo "$output" | grep -Eq "^(ERROR|SCRIPT ERROR)"; then
    record "$label" 0
  else
    echo "$output" | grep -E -A1 "^(ERROR|SCRIPT ERROR)" | head -20
    record "$label (exit $code or errors)" 1
  fi
}
scene_smoke "godot startup scene (main menu)"
scene_smoke "godot complex scene" res://scenes/underground_research_complex.tscn

echo "== Godot checks"
while IFS='|' read -r resource marker; do
  [ -z "$resource" ] && continue
  godot_check "$resource" "$marker"
done <<'CHECKS'
res://addons/complex_v4_regeneration_editor/regeneration_editor_check.gd|COMPLEX_V4_REGENERATION_EDITOR_CHECK_OK
res://addons/complex_v4_anchor_editor/editor_operations_check.gd|COMPLEX_V4_EDITOR_BINDING_OK
res://scenes/complex_v4/regeneration/anchor_runtime_check.gd|COMPLEX_V4_ANCHOR_RUNTIME_OK
res://scenes/complex_v4/regeneration/anchor_surface_check.gd|COMPLEX_V4_SURFACE_CHECK checks=[0-9]+ failures=0
res://scenes/complex_v4/regeneration/sector_anchor_controller_check.tscn|COMPLEX_V4_SECTOR_ANCHOR_CONTROLLER_OK
res://scenes/complex_v4/regeneration/production_anchor_binding_check.tscn|COMPLEX_V4_PRODUCTION_ANCHOR_BINDINGS_OK
res://scenes/complex_v4/regeneration/door_binding_check.gd|DOOR_BINDING_CHECK doors=0 errors=0
res://scenes/complex_v4/regeneration/door_frame_prefab_check.gd|DOOR_FRAME_PREFAB_CHECK doors=0 .* errors=0
res://scenes/complex_v4/regeneration/surface_conflict_check.gd|SURFACE_CONFLICT_CHECK sectors=32 findings=[0-9]+ errors=0
res://scenes/complex_v4/regeneration/rollout/shared/combined_check.gd|SHARED_COMBINED checks=[0-9]+ errors=0
res://tools/complex_v4/tests/production_matrix_check.gd|PRODUCTION_MATRIX generated=32 sectors=32 errors=0
res://tools/complex_v4/tests/coplanar_check.gd|COPLANAR_CHECK meshes=[0-9]+ overlaps=0
res://scenes/complex_v4/sector_wrapper_contract_check.gd|COMPLEX_V4_SECTOR_WRAPPER_CONTRACT_OK
res://scenes/complex_v4/set_dressing/set_dressing_scene_check.gd|SET_DRESSING_GODOT_SCENES_OK
res://scenes/complex_v4/complex_v4_sector_check.gd|COMPLEX_V4_SECTORS_OK sectors=32
res://scenes/complex_v4/review/opening_route_check.gd|OPENING_ROUTE_CHECK mode=report legs=[0-9]+ passable=[0-9]+
res://tests/opening/opening_checks.tscn|OPENING_CHECKS checks=[0-9]+ failures=0
res://tests/opening/dream_e2e.tscn|DREAM_E2E_OK
res://tests/dreams/bowser_dream_check.tscn|BOWSER_DREAM_CHECK_OK checks=[0-9]+
res://tests/dreams/bowser_dream_mood_check.tscn|BOWSER_DREAM_MOOD_OK checks=[0-9]+
res://tests/dreams/bowser_dream_fx_check.tscn|BOWSER_DREAM_FX_OK checks=[0-9]+
res://tests/opening/shell_e2e.tscn|SHELL_E2E_OK
res://tests/debug/moments_check.tscn|DEBUG_MOMENTS_OK moments=[0-9]+
res://tests/review/review_hub_check.tscn|REVIEW_HUB_OK stations=[0-9]+
res://tools/props/check_props.gd|PROPS_CHECK props=[0-9]+ errors=0
CHECKS

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "ALL CHECKS PASSED ($passed)"
  exit 0
fi
echo "FAILED (${#failed[@]} of $((passed + ${#failed[@]}))):"
printf '  - %s\n' "${failed[@]}"
exit 1
