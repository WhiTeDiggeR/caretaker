# complex_v3 canonical generation plans

This directory contains the only SVG geometry inputs accepted by the production
sector regenerator. There is exactly one metric SVG for each of the 30 sectors.
The `upper`, `lower` and `technical` directory names are part of the production
manifest contract.

Canonical files declare `data-generator-input="true"`, use metre coordinates
with a uniform numeric `data-scale`, and attach explicit stable `id` plus
`data-godot-type` to every drawable element. Moving or resizing an element must
not rename it. Splitting an element requires new reviewed IDs. Floors identify
their space with `data-space-id`; explicit anchors use `data-anchor-id`.
Decorative geometry must be explicitly typed `ignore`. Unknown or invalid
elements block regeneration. Floor and ceiling openings are independent.

SVG files under `plans/sectors` and `plans/overview` are presentation documents
only. They declare both `presentation_only=true` and `generator_input=false` and
must never be referenced by a production manifest.

Run the strict matrix with the installed canonical tool root:

```text
python tools/complex_v3_regeneration/validate_canonical_sources.py \
  --svg-tool-root <svg_to_godot3d-root> \
  --report docs/design/complex_v3/plans/generation/preflight-report.json
```
