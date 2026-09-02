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
