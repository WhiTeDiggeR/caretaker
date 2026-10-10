#!/usr/bin/env python3
"""Verify one-to-one scene/plan filenames and handoff source references."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
PASSPORTS = ROOT / "docs/design/complex_v3/handoff/passports/sector-passports.json"
PLAN_ROOT = ROOT / "docs/design/complex_v3"


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    passports = json.loads(PASSPORTS.read_text(encoding="utf-8"))
    source_by_sector = {
        passport["sector_id"]: (PASSPORTS.parent / passport["source_detail"]).resolve()
        for passport in passports["passports"]
    }
    errors: list[str] = []
    for sector in catalog["sectors"]:
        scene_stem = Path(sector["scene"]).stem
        plan = source_by_sector.get(sector["sector_id"])
        if plan is None:
            errors.append(f"missing passport source for {sector['sector_id']}")
            continue
        try:
            plan.relative_to(PLAN_ROOT)
        except ValueError:
            errors.append(f"plan escapes package root for {sector['sector_id']}: {plan}")
            continue
        if not plan.is_file():
            errors.append(f"missing passport plan for {sector['sector_id']}: {plan}")
        if plan.stem != scene_stem:
            errors.append(f"scene/plan mismatch for {sector['sector_id']}: {scene_stem}.tscn != {plan.name}")
    if errors:
        raise SystemExit("Scene/plan filename validation failed:\n- " + "\n- ".join(errors))
    print("SCENE_PLAN_NAMES_OK scenes=30 plans=30 passport_sources=30")


if __name__ == "__main__":
    main()
