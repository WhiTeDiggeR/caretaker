# T27 automated E2E evidence

Date: 2026-09-19

This record covers the automated portion of T27. It does not replace the manual
editor demonstration required by the overall Definition of Done.

## Production matrix

- Canonical SVG strict preflight: 30/30 sectors ready, 0 errors, converter and
  inspector version 1.19.0.
- First regeneration pass: 30/30 sectors returned exit code 0; 29 packages were
  promoted and the already-current U-CONTROL package returned `noop`.
- Second regeneration pass: 30/30 sectors returned `noop` with `ready: true`.
- Godot resource matrix: 30 generated architecture scenes, 30 sector scenes,
  and the 30-sector assembly loaded; `PRODUCTION_MATRIX ... errors=0`.
- Shared/vertical combined check: 142 checks, 0 duplicate geometry or collision
  errors.

## Regression suites

- `tools/complex_v3_regeneration/tests`: 66 passed.
- `tools/complex_v3_composition_validator/tests`: 9 passed.
- `tools/complex_v3_repair_package/tests`: 10 passed.
- Godot 4.7 editor import exited 0.
- Godot 4.7 runtime smoke exited 0; it reported two ObjectDB instances leaked
  during shutdown, without a load or script failure.

The regeneration suite was run with the production-compatible tools:

- `svg_to_godot3d` 1.19.0;
- `generate_godot_stairs` 2.9.0;
- Godot 4.7 stable.

## Remaining acceptance gates

- T26 remains blocked until the missing stair directions/sides and elevator
  stop/pass-through data are approved. No values are inferred.
- The complete manual editor scenario (source-plan launch, visible reload,
  deliberate authored conflict, explicit Agent Fix, and final clean assembly)
  still requires a human-operated Godot session. T27 must not be marked done
  until that demonstration is recorded.
