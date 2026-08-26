# Complex v3 sector regeneration backend

`regenerate_sector.py` builds exactly one sector package under a caller-provided empty staging directory. It never promotes staging, edits a live sector scene, or writes authored content; atomic promotion belongs to T10.

Required invocation:

```powershell
python tools/complex_v3_regeneration/regenerate_sector.py `
  --sector U-MEDBAY `
  --staging <empty-directory> `
  --svg-tool-root <canonical-svg-plan-to-godot-source>
```

Add `--stair-tool-root <canonical-generate-godot-stairs-source>` when the selected sector declares a vertical generator. Installed skill caches are not implicit inputs.

The backend runs strict SVG inspection and conversion with one shared argument list, requires identical `spatial_handoff`, blocks `anchor_frame_issues`, converts frames through an exact declared `local_to_world`, and writes:

- `Generated/Architecture/` and optionally `Generated/Stairs/`;
- `anchor_frames.json` in world coordinates;
- `generation_manifest.json` with input hashes and effective geometry settings;
- `regeneration_report.json` with commands and exit codes.

`sector_generation_manifest.json` inventories all 30 production sector sources. Its entries intentionally remain `blocked` while the current canonical SVGs and exact SVG-to-world transforms are not integrated. `data-scale="relative"` is not accepted as a metric transform. Remove a blocker only after filling `metric_settings` (scale, origin, elevation), exact `local_to_world`, reviewed semantic and material mappings, and every related vertical generator. Non-empty material overrides are currently blocked because converter 1.19 has no explicit material-override input; the backend never guesses them.

Exit code `0` means the staging package passed this backend's checks. Exit code `2` means no usable package was produced; a caller must not promote it.

## Verification fixtures

`tests/fixtures/fixture_generation_manifest.json` contains one ordinary sector and one vertical sector with exact transforms. They are deliberately separate from the blocked production inventory. Run the unit suite with:

```powershell
python -m unittest discover -s tools/complex_v3_regeneration/tests -v
```

For an integration check, invoke `regenerate_sector.py` with that fixture manifest, `--sector FIXTURE-ORDINARY` or `FIXTURE-VERTICAL`, and explicit canonical roots. Run the ordinary fixture twice into different empty staging directories and compare `anchor_frames.json` plus `generation_manifest.json` byte-for-byte; `regeneration_report.json` intentionally records staging-specific command paths.
