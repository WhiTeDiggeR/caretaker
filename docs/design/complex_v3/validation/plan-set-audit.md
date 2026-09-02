# Complex v3 plan-set audit

Status: **PASS**

- Canonical plan pairs: 33 (3 overview + 30 detailed).
- Plan style: `caretaker-style-b-v1` throughout.
- Topology connections checked: 49.
- Sector passports checked: 30.
- Geometry policy: approved drawing geometry preserved; metric handoff controls shared anchors and shafts.
- Physical area boundaries checked: 158 areas, 249 exact shared centerlines, one thickness per common wall.
- Wall solids checked: 0 mixed-thickness overlaps; junction policy is trimmed butt contact.

## Fixed vertical footprints

| Transition | Anchor | Outer shaft XZ, m | Clear opening XZ, m |
|---|---|---|---|
| VT-MAIN-ELEVATOR | A-MAIN-CORE | [-6.9, -0.25, -2.1, 5.0] | [-6.72, -0.07, -2.28, 4.82] |
| VT-MAIN-STAIR | A-MAIN-CORE | [0.2, -5.0, 6.9, 9.5] | [0.38, -4.82, 6.72, 9.32] |
| VT-ROUTE-A | A-ROUTE-A | [-55.59, 5.91, -49.41, 13.09] | [-55.5, 6.0, -49.5, 13.0] |
| VT-OLD-STAIR | A-OLD-STAIR | [-93.09, 25.91, -86.91, 34.09] | [-93.0, 26.0, -87.0, 34.0] |
| VT-SERVICE-STAIR | A-SERVICE-STAIR | [-45.09, 45.91, -38.91, 54.09] | [-45.0, 46.0, -39.0, 54.0] |
| VT-EAST-STAIR | A-EAST-STAIR | [23.91, 6.41, 30.09, 14.59] | [24.0, 6.5, 30.0, 14.5] |
| VT-FREIGHT-LIFT | A-FREIGHT-LIFT | [16.5, 67.5, 23.5, 76.5] | [16.68, 67.68, 23.32, 76.32] |

## Result

No contradictions detected.
