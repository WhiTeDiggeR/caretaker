#!/usr/bin/env python3
"""Check lift shafts marked in the SVG plans against the canonical vertical transitions.

A lift shaft is a cut in the floor and ceiling of the rooms it passes through, marked on
`floor-opening` / `ceiling-opening` rects with data-vertical-id and data-vertical-role="shaft"
(docs/design/complex_v3/regeneration/vertical-markup.md). This tool only reports what is missing
or inconsistent; it never edits plans.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

try:
    from .vertical_resolver import FOOTPRINT_TOLERANCE_M, VerticalError, read_markup
except ImportError:
    try:
        from tools.complex_v3_regeneration.vertical_resolver import FOOTPRINT_TOLERANCE_M, VerticalError, read_markup
    except ImportError:
        from vertical_resolver import FOOTPRINT_TOLERANCE_M, VerticalError, read_markup

ROOT = Path(__file__).resolve().parents[2]
LIFT_KINDS = {"passenger_elevator", "freight_elevator"}
CANONICAL_TOLERANCE_M = 0.25


def _rect_text(rect: tuple[float, float, float, float]) -> str:
    return "(" + ", ".join(f"{value:g}" for value in (round(v, 3) for v in rect)) + ")"


def _candidate_spaces(handoff: dict[str, Any], elevation: float, bounds: list[float]) -> list[str]:
    x0, z0, x1, z1 = bounds
    result = []
    for space in handoff.get("spaces", []):
        sx0, sz0, sx1, sz1 = space["bounds_xz"]
        if abs(float(space.get("floor_y", 1e9)) - elevation) < 1e-6 and sx0 < x1 and sx1 > x0 and sz0 < z1 and sz1 > z0:
            result.append(space["id"])
    return sorted(result)


def validate_lifts(
    manifest: dict[str, Any], transitions: dict[str, Any], handoff: dict[str, Any], project_root: Path
) -> list[str]:
    datums = transitions["level_datums"]
    sectors = [item for item in manifest["sectors"] if isinstance(item, dict)]
    diagnostics: list[str] = []
    for transition in transitions["transitions"]:
        if transition.get("kind") not in LIFT_KINDS:
            continue
        vertical_id = transition["id"]
        levels = sorted(set(transition.get("stops", [])) | set(transition.get("pass_through", [])), key=lambda level: -datums[level])
        if len(levels) < 2:
            continue
        canonical = transition["clear_opening_bounds_xz"]
        marked: dict[str, dict[str, list[tuple[str, tuple[float, float, float, float]]]]] = {level: {"floor-opening": [], "ceiling-opening": []} for level in levels}
        for sector in sectors:
            level = sector.get("level")
            if level not in marked:
                continue
            try:
                markup = read_markup(project_root / sector["source_svg"], vertical_id)
            except (VerticalError, OSError) as exc:
                diagnostics.append(f"{vertical_id}: {sector['sector_id']}: {exc}")
                continue
            for shaft in markup["shafts"]:
                marked[level][shaft["kind"]].append((sector["sector_id"], shaft["rect"]))
        rects: list[tuple[str, str, tuple[float, float, float, float]]] = []
        for index, level in enumerate(levels):
            needs = []
            if index == 0 or 0 < index < len(levels) - 1:
                needs.append("floor-opening")
            if index > 0:
                needs.append("ceiling-opening")
            for kind in needs:
                found = marked[level][kind]
                if len(found) == 0:
                    hint = _candidate_spaces(handoff, float(datums[level]), canonical)
                    where = f"; rooms there: {', '.join(hint)}" if hint else "; no room covers the shaft at this level in the handoff"
                    diagnostics.append(f"{vertical_id} {level}: no {kind} marked{where}")
                elif len(found) > 1:
                    diagnostics.append(f"{vertical_id} {level}: {len(found)} {kind} elements marked in {', '.join(item[0] for item in found)}")
                else:
                    rects.append((level, kind, found[0][1]))
            for kind in ("floor-opening", "ceiling-opening"):
                if kind not in needs and marked[level][kind]:
                    diagnostics.append(f"{vertical_id} {level}: unexpected {kind} marked (the shaft does not cut it)")
        if rects:
            reference = rects[0][2]
            for level, kind, rect in rects[1:]:
                if any(abs(a - b) > FOOTPRINT_TOLERANCE_M for a, b in zip(rect, reference)):
                    diagnostics.append(f"{vertical_id} {level} {kind}: footprint {_rect_text(rect)} differs from {_rect_text(reference)}")
            cx0, cz0, cx1, cz1 = canonical
            if not (reference[0] <= cx0 + CANONICAL_TOLERANCE_M and reference[1] <= cz0 + CANONICAL_TOLERANCE_M
                    and reference[2] >= cx1 - CANONICAL_TOLERANCE_M and reference[3] >= cz1 - CANONICAL_TOLERANCE_M
                    and reference[0] >= cx0 - 1.0 and reference[1] >= cz0 - 1.0 and reference[2] <= cx1 + 1.0 and reference[3] <= cz1 + 1.0):
                diagnostics.append(f"{vertical_id}: footprint {_rect_text(reference)} does not match the canonical clear opening {_rect_text(tuple(canonical))}")
    return diagnostics


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "tools/complex_v3_regeneration/sector_generation_manifest.json")
    parser.add_argument("--transitions", type=Path, default=ROOT / "docs/design/complex_v3/handoff/vertical/vertical-transitions.json")
    parser.add_argument("--handoff", type=Path, default=ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json")
    parser.add_argument("--project-root", type=Path, default=ROOT)
    options = parser.parse_args(argv)
    load = lambda path: json.loads(path.read_text(encoding="utf-8"))  # noqa: E731
    diagnostics = validate_lifts(load(options.manifest), load(options.transitions), load(options.handoff), options.project_root)
    for line in diagnostics:
        print(f"MISSING: {line}")
    print(f"LIFT_SHAFTS status={'blocked' if diagnostics else 'ready'} diagnostics={len(diagnostics)}")
    return 2 if diagnostics else 0


if __name__ == "__main__":
    sys.exit(main())
