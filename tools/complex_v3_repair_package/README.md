# Complex v3 repair package builder

`build_repair_package.py` converts a T09 composition report and repair queue into minimal, deterministic context plus a restricted agent prompt. It never invokes an agent and never edits source scenes.

Required inputs are the composition report/input, repair queue, normative bindings, generated anchor frames, one authored sector scene, project root, an empty output directory, and a validation command encoded as a JSON string array. Without `--object-id`, all open blocking object IDs are included; repeated `--object-id` selects a subset and rejects IDs not present in the open blocking queue.

```powershell
python tools/complex_v3_repair_package/build_repair_package.py `
  --composition-report <validation_report.json> `
  --repair-queue <repair_queue.json> `
  --composition-input <composition_input.json> `
  --bindings <object_bindings.json> `
  --anchor-frames <anchor_frames.json> `
  --authored-scene <sector.tscn> `
  --project-root . `
  --validate-command-json '["python","tools/complex_v3_composition_validator/validate_composition.py","--input","resolved.json","--output","reports"]' `
  --output <empty-package-directory>
```

The builder requires unique object and binding identities, exactly one binding per selected object, and identical map/sector/generation context. It copies only filtered diagnostics, repairs, objects, bindings, relevant anchors, the authored sector scene, and explicitly allowlisted non-scene files. A second `.tscn` is rejected as a neighboring scene. The package contract marks `Generated/**`, SVG, anchor frames, converter settings, and neighboring sectors read-only/forbidden.

Run tests with:

```powershell
python -m unittest discover -s tools/complex_v3_repair_package/tests -v
```

## Explicit Agent Fix runner

`run_agent_fix.py` is the only orchestration entry point that invokes an agent,
and it must be started by an explicit editor action. It accepts the latest T24
safe report, rejects clean or non-composition failures, verifies current source
and sector-config hashes plus every evidence artifact, and builds a persistent
minimal package inside that attempt's evidence directory.

```powershell
python tools/complex_v3_repair_package/run_agent_fix.py `
  --sector U-CONTROL `
  --manifest tools/complex_v3_regeneration/sector_generation_manifest.json `
  --safe-report <latest-safe-report.json> `
  --python <python> `
  --svg-tool-root <svg-tool-root> `
  --stair-tool-root <stair-tool-root> `
  --agent-launcher <configured-launcher>
```

The launcher may be one executable path or a JSON string array containing an
executable and fixed arguments. The runner appends `--project-root`,
`--repair-package`, and `--prompt`; a production Codex wrapper must accept those
arguments and return the agent exit code.

Before and after the launcher, the runner hashes project files and immutable
attempt evidence. Only the current sector authored scene, its bindings, and
explicit `safe_regeneration.agent_allow_files`/`--allow-file` entries may change.
Any other change blocks revalidation. A successful agent exit always triggers a
new full `safe_regenerate.py` run—never `--validate-only` and never validation of
the old live package. The editor may reload only when that run returns a ready
`success` or `noop` report. The final safe report records agent invocation,
command, exit code, changed allowlisted files, forbidden changes, package path,
and the complete revalidation result.
