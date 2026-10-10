#!/usr/bin/env python3
"""Compose side-by-side plan and scene-source renders for visual review."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
AUDIT_ROOT = Path(sys.argv[1])
PLANS = AUDIT_ROOT / "plans"
SCENES = AUDIT_ROOT / "scenes"
COMPARISONS = AUDIT_ROOT / "comparisons"
SHEETS = AUDIT_ROOT / "sheets"
PANEL = (620, 620)


def fit(source: Image.Image) -> Image.Image:
    return ImageOps.pad(source.convert("RGB"), PANEL, method=Image.Resampling.LANCZOS, color=(238, 238, 236))


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    COMPARISONS.mkdir(parents=True, exist_ok=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default()
    comparisons: list[Path] = []
    for sector in catalog["sectors"]:
        sector_id = sector["sector_id"]
        slug = sector_id.lower().replace("-", "_")
        plan = fit(Image.open(PLANS / f"{slug}.png"))
        scene = fit(Image.open(SCENES / f"{slug}.png"))
        image = Image.new("RGB", (PANEL[0] * 2, PANEL[1] + 34), (18, 22, 28))
        image.paste(plan, (0, 34))
        image.paste(scene, (PANEL[0], 34))
        draw = ImageDraw.Draw(image)
        draw.text((12, 12), f"{sector_id} | PLAN", font=font, fill=(240, 244, 248))
        draw.text((PANEL[0] + 12, 12), "SCENE SOURCE", font=font, fill=(240, 244, 248))
        output = COMPARISONS / f"{slug}.png"
        image.save(output)
        comparisons.append(output)
    for sheet_index in range(0, len(comparisons), 6):
        chunk = comparisons[sheet_index:sheet_index + 6]
        sheet = Image.new("RGB", (PANEL[0] * 2, (PANEL[1] + 34) * len(chunk)), (8, 11, 16))
        for row, path in enumerate(chunk):
            sheet.paste(Image.open(path), (0, row * (PANEL[1] + 34)))
        output = SHEETS / f"sheet_{sheet_index // 6 + 1:02d}.png"
        sheet.save(output)
        print(f"VISUAL_AUDIT_SHEET {output}")
    print(f"VISUAL_AUDIT_COMPARISONS_OK count={len(comparisons)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
