# Complex v3 blockout — validation report

Date: 2026-07-29
Issue: #35

## Result

- Handoff parity: 139 spaces, 7 route spaces, 7 vertical anchors and 8 transition volumes.
- Generated geometry: 145 floor surfaces, 1,254 wall segments and 1,566 collision shapes.
- Portal physics: all 147 traversable internal and external portal passages accept the test capsule.
- Source guard: the blockout reads the approved metric handoff; `scenes/underground_research_complex.tscn` remains unchanged.
- Godot 4.7 validation: editor import and five-second standalone scene smoke test passed.
- Visual QA: overview and isolated `LV-U`, `LV-L` and `LV-T` views were inspected in the running test scene.
- Handoff regressions: stage 1, stage 2 and portable map-package validation passed after resolving physical route overlaps and paired-portal alignment.

The host emitted a root certificate-store warning during headless startup. It did not produce project, script, resource, scene or physics errors.

## Intentional blockout limits

- Lift and stair anchors are collision envelopes; detailed flights, slab openings and working lift cars are deferred.
- The cable gallery is a non-floor service overlay.
- Generated connection corridors provide collision floors without side walls, so their walls cannot cross adjoining rooms or block approved portal passages.
