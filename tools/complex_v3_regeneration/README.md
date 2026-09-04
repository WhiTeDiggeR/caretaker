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

## Safe one-command orchestration

`safe_regenerate.py` is the promoting entry point. A ready sector must add a reviewed composition source to its manifest entry:

```json
"safe_regeneration": {
  "composition_input": "docs/design/complex_v3/composition/u_medbay.json"
}
```

The path is project-relative and may point into preserved live `AuthoredContent`. The composition document remains authored input: the orchestrator writes a temporary resolved copy, replaces its `generation_id` and `anchors` with the staged values, and passes that copy to the canonical composition validator. Missing, duplicate, wrong-kind, or otherwise invalid bindings block promotion; no fallback anchor is selected. `--report` must point outside the live sector package so reporting itself cannot mutate live content.

```powershell
python tools/complex_v3_regeneration/safe_regenerate.py `
  --sector U-MEDBAY `
  --manifest tools/complex_v3_regeneration/sector_generation_manifest.json `
  --svg-tool-root <canonical-svg-plan-to-godot-source> `
  --stair-tool-root <canonical-generate-godot-stairs-source> `
  --report <machine-report.json>
```

The transaction is:

1. validate the selected source and manifest entry;
2. invoke the T04 backend into an empty sibling staging directory;
3. validate generated manifests, anchor IDs, and stair reports;
4. copy the live package to a sibling candidate, replacing only generator-owned `Generated/`, `anchor_frames.json`, `generation_manifest.json`, and `regeneration_report.json`;
5. validate all candidate Godot resource links, resolve bindings in a temporary document, and run the T09 composition validator;
6. atomically rename live to backup and candidate to live on the same filesystem; restore backup if the second rename fails.

The validations logically associated with bindings and composition run against the exact promotion candidate before the rename. This preserves the T01 invariant that any validation failure leaves live content unchanged. Only a promoted, unchanged, or validate-only-clean live package is `ready: true`; every failure and dry run is `ready: false` (`candidate_validated: true` distinguishes a clean dry run). The fixed subprocesses are the declared Python backend and composition validator only—no coding agent is invoked.

`--dry-run` executes generation and every validation but skips promotion. `--validate-only` validates the current live package without running a generator. The machine report uses `caretaker.safe_regeneration_report` version `1.0.0` and records stage results, input/output SHA-256 hashes, live hashes, mode, status, readiness, and errors.

Semantic equality covers `Generated/`, `anchor_frames.json`, and `generation_manifest.json`. The backend diagnostic report is excluded because operational evidence does not define geometry. When semantic output is unchanged, status is `noop` and the live directory is not renamed or overwritten. Files outside the generator-owned set—including `AuthoredContent`, `Materials`, and arbitrary user files—are preserved byte-for-byte in the candidate.

### Durable diagnostics (T13 integration correction)

Orchestrator 1.1.0 includes the optional `validation_artifacts` report field without
changing schema 1.0.0. Once composition validation runs, both its JSON report and
`repair_queue.json` are retained in a fresh `<report-stem>.evidence-*` directory
beside the requested machine report, outside live and transaction staging.
Each entry records the absolute path and SHA-256. This also happens when the
validator exits 2; transaction cleanup must not erase removed-anchor evidence.
Failure to preserve diagnostics blocks promotion. Failure reports record the
post-attempt live hash as well as the original hash.

The current machine report points only to evidence from that attempt. A clean
attempt points to a new empty repair queue; an earlier-stage failure has an empty
`validation_artifacts` object. Older evidence is retained for audit and is not
implicitly overwritten or deleted. Consumers must follow the current report,
not search neighboring directories for a queue. Authored bindings are unchanged,
and no candidate anchor IDs are invented for a deleted reference.

When a ready sector declares project-relative `bindings_input` beside
`composition_input`, `resolve_bindings.py` applies the T01 policies to staged
frames, recalculates authored transforms/bounds and generated infrastructure,
and sends that exact candidate document to validation. Missing IDs retain their
original reference and old bounds so the validator emits a repair item; no nearby
anchor is selected.

## Verification fixtures

`tests/fixtures/fixture_generation_manifest.json` contains one ordinary sector and one vertical sector with exact transforms. They are deliberately separate from the blocked production inventory. Run the unit suite with:

```powershell
python -m unittest discover -s tools/complex_v3_regeneration/tests -v
```

For an integration check, invoke `regenerate_sector.py` with that fixture manifest, `--sector FIXTURE-ORDINARY` or `FIXTURE-VERTICAL`, and explicit canonical roots. Run the ordinary fixture twice into different empty staging directories and compare the package byte-for-byte. Backend, converter, preflight, and scene metadata paths are normalized to `$PROJECT_ROOT`, `$STAGING`, `$SVG_TOOL_ROOT`, `$STAIR_TOOL_ROOT`, and `$PYTHON`, so reports do not retain a developer's worktree path.
