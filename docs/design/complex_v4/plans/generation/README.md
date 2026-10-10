# Complex version 4 canonical generation plans

One metric SVG per sector (30). They are generated from the approved v3 plans by
`tools/complex_v3_regeneration/build_canonical_from_approved.py`; do not hand-edit them
before the review in `../../review/README.md` is confirmed, then edit them in Inkscape as usual.

Rules (unchanged from the generator contract): metres, `data-scale="1"`, explicit `id` and
`data-godot-type` on every drawable, `data-space-id` on floors, `data-source-id` points back to the
approved plan element. Context (trunk corridors, neighbours, furniture) is typed `ignore`.

```text
python tools/complex_v3_regeneration/validate_canonical_sources.py \
  --svg-tool-root <svg_to_godot3d-root> \
  --report docs/design/complex_v4/plans/generation/preflight-report.json
```
