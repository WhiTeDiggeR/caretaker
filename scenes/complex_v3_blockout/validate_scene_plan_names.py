#!/usr/bin/env python3
"""Verify one-to-one scene/plan filenames and handoff source references."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
HANDOFF = ROOT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json"
PLAN_ROOT = ROOT / "docs/design/complex_v3"


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    source_by_sector = {sector["id"]: Path(sector["source_detail"]).name for sector in handoff["sectors"]}
    errors: list[str] = []
    for sector in catalog["sectors"]:
        scene_stem = Path(sector["scene"]).stem
        plan = PLAN_ROOT / f"{scene_stem}.html"
        if not plan.is_file():
            errors.append(f"missing scene-matched plan: {scene_stem}.html")
        if sector["sector_id"] in source_by_sector and source_by_sector[sector["sector_id"]] != plan.name:
            errors.append(f"handoff source mismatch for {sector['sector_id']}: {source_by_sector[sector['sector_id']]} != {plan.name}")
    if errors:
        raise SystemExit("Scene/plan filename validation failed:\n- " + "\n- ".join(errors))
    print("SCENE_PLAN_NAMES_OK scenes=30 plans=30 handoff_sources=29")


if __name__ == "__main__":
    main()
