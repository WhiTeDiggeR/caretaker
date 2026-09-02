#!/usr/bin/env python3
"""Embed a renderer-independent concrete Style B palette in current plans."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "docs/design/complex_v3"
STYLE_ID = "plan-render-fallback"
STYLE = r"""
/* Renderer-independent Caretaker style B fallback. Geometry is untouched. */
.plan-root { background: #191c1f !important; font-family: "Segoe UI", Arial, sans-serif; font-size: 14px; }
.plan-root text {
  fill: #f1f3f5 !important;
  font-family: "Segoe UI", Arial, sans-serif !important;
  font-size: 14px;
}
.plan-root .tiny, .plan-root .small, .plan-root .minor,
.plan-root .context, .plan-root .dimtext { fill: #aeb4ba !important; }
.plan-root .shell { fill: #202428 !important; stroke: #d9dde0 !important; }
.plan-root .room, .plan-root .lab, .plan-root .late,
.plan-root .equipment-room, .plan-root .containment { fill: #3b4147 !important; stroke: #d9dde0 !important; }
.plan-root .old { fill: #51493f !important; stroke: #d9dde0 !important; }
.plan-root .personnel { fill: #3b4650 !important; stroke: #d9dde0 !important; }
.plan-root .research { fill: #51486a !important; stroke: #d9dde0 !important; }
.plan-root .support { fill: #3f4a4f !important; stroke: #d9dde0 !important; }
.plan-root .medical, .plan-root .utility, .plan-root .service { fill: #356352 !important; stroke: #d9dde0 !important; }
.plan-root .domestic { fill: #4c533d !important; stroke: #d9dde0 !important; }
.plan-root .security { fill: #5b3f43 !important; stroke: #d9dde0 !important; }
.plan-root .command { fill: #3c4d63 !important; stroke: #d9dde0 !important; }
.plan-root .heavy, .plan-root .work, .plan-root .cargo { fill: #6b5235 !important; stroke: #d9dde0 !important; }
.plan-root .energy { fill: #2e5778 !important; stroke: #d9dde0 !important; }
.plan-root .corridor, .plan-root .passenger, .plan-root .mixed,
.plan-root .controlled { fill: #3a4045 !important; stroke: #d9dde0 !important; }
.plan-root .shaft, .plan-root .vertical, .plan-root .stair,
.plan-root .lift { fill: #2b2e33 !important; stroke: #d9dde0 !important; }
.plan-root .airlock, .plan-root .checkpoint { fill: #42484e !important; stroke: #d9dde0 !important; }
.plan-root .gallery, .plan-root .cable { fill: #185d68 !important; stroke: #d9dde0 !important; }
.plan-root .context-zone { fill: #2b3035 !important; stroke: #8e969d !important; }
.plan-root .void { fill: #17191b !important; stroke: #8e969d !important; }
.plan-root .canvas { fill: #191c1f !important; stroke: none !important; }
.plan-root .outer { fill: none !important; stroke: #d9dde0 !important; }
.plan-root .walkway { fill: #2f353a !important; stroke: #d9dde0 !important; }
.plan-root .store { fill: #5b3f43 !important; stroke: #d9dde0 !important; }
.plan-root .counter { fill: none !important; stroke: #aeb4ba !important; }
.plan-root .screen { fill: #17222c !important; stroke: #aeb4ba !important; }
.plan-root .opening { fill: #3a4045 !important; stroke: none !important; }
.plan-root .equipment, .plan-root .door, .plan-root .gate,
.plan-root .gate-thin, .plan-root .window, .plan-root .wall,
.plan-root .partition, .plan-root .dimension, .plan-root .scale,
.plan-root .steps, .plan-root .stairs, .plan-root .flow,
.plan-root .barrier, .plan-root .reinforce { fill: none !important; stroke: #aeb4ba !important; }
.plan-root .thin, .plan-root .step { fill: none !important; stroke: #aeb4ba !important; }
.plan-root .down { fill: #aeb4ba !important; stroke: none !important; }
.plan-root .door { stroke: #d9dde0 !important; }
.plan-root .door-gap { stroke: #3a4045 !important; }
.plan-root .room-gap { stroke: #3b4147 !important; }
.plan-root .support-gap { stroke: #3f4a4f !important; }
.plan-root .energy-gap { stroke: #2e5778 !important; }
.plan-root .utility-gap { stroke: #356352 !important; }
.plan-root .work-gap, .plan-root .cargo-gap { stroke: #6b5235 !important; }
.plan-root .equip-gap { stroke: #3b4147 !important; }
.plan-root .stair-gap { stroke: #2b2e33 !important; }
.plan-root .floor-opening, .plan-root .ceiling-opening {
  fill: none !important; stroke: #f2c14e !important; stroke-width: 2 !important; stroke-dasharray: 8 5 !important;
}
.plan-root .damaged, .plan-root .rubble { fill: #6b6158 !important; stroke: #d9dde0 !important; }
.plan-root .blocked { fill: none !important; stroke: #d9dde0 !important; }
""".strip()


def plans() -> list[Path]:
    return sorted((PACKAGE / "plans/overview").glob("*/current/*.svg")) + sorted(
        (PACKAGE / "plans/sectors").glob("*/*.svg")
    )


def make_css_standalone(svg: str) -> str:
    """Retarget selectors that depended on the removed HTML wrapper."""
    wrapper_ids = set(re.findall(r"#([A-Za-z_][\w-]*)\s+svg\b", svg))
    for wrapper_id in wrapper_ids:
        svg = re.sub(rf"#{re.escape(wrapper_id)}\s+svg\b", ".plan-root", svg)
        svg = re.sub(rf"#{re.escape(wrapper_id)}\b", ".plan-root", svg)
    return svg


def main() -> None:
    marker = f'<style id="{STYLE_ID}"><![CDATA['
    for path in plans():
        svg = path.read_text(encoding="utf-8")
        svg = make_css_standalone(svg)
        block = f"\n<style id=\"{STYLE_ID}\"><![CDATA[\n{STYLE}\n]]></style>\n"
        if marker in svg:
            start = svg.index(marker)
            end = svg.index("</style>", start) + len("</style>")
            svg = svg[:start] + block.strip() + svg[end:]
        else:
            defs_end = svg.find("</defs>")
            if defs_end < 0:
                raise ValueError(f"{path}: defs block missing")
            svg = svg[:defs_end] + block + svg[defs_end:]
        svg = "\n".join(line.rstrip() for line in svg.splitlines()) + "\n"
        path.write_text(svg, encoding="utf-8")
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
