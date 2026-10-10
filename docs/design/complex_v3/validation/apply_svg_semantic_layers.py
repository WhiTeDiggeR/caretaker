#!/usr/bin/env python3
"""Wrap editable SVG objects in stable semantic layer groups without reordering."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "docs/design/complex_v3"
SHAPE_PATTERN = re.compile(
    r"<(rect|line|path|polygon|polyline|circle|ellipse|text)\b([^>]*?)(/\s*>|>([\s\S]*?)</\1>)",
    flags=re.I,
)


def plans() -> list[Path]:
    return sorted((PACKAGE / "plans/overview").glob("*/current/*.svg")) + sorted(
        (PACKAGE / "plans/sectors").glob("*/*.svg")
    )


def category(tag: str, attrs: str) -> str:
    kind_match = re.search(r'\bdata-kind="([^"]+)"', attrs, re.I)
    kind = kind_match.group(1).lower() if kind_match else ""
    classes = " ".join(re.findall(r'\bclass="([^"]+)"', attrs, re.I)).lower()
    semantic = f"{kind} {classes}"
    if tag.lower() == "text" or "label" in semantic:
        return "labels"
    if "opening" in semantic or "door" in semantic or "gap" in semantic or "gate" in semantic:
        return "openings"
    if "wall" in semantic or "partition" in semantic or "barrier" in semantic or "reinforce" in semantic:
        return "walls"
    if "equipment" in semantic or any(token in semantic for token in ("screen", "counter", "steps", "stairs", "rubble")):
        return "equipment"
    if "annotation" in semantic or tag.lower() in {"line", "polyline"}:
        return "annotations"
    return "rooms"


def main() -> None:
    for path in plans():
        svg = path.read_text(encoding="utf-8")
        if 'data-semantic-layer-contract="per-object-v1"' in svg:
            continue

        def wrap(match: re.Match[str]) -> str:
            tag, attrs, closing, content = match.group(1), match.group(2), match.group(3), match.group(4)
            id_match = re.search(r'\bid="([^"]+)"', attrs, re.I)
            if not id_match:
                raise ValueError(f"{path}: editable {tag} has no stable ID")
            element_id = id_match.group(1)
            layer = category(tag, attrs)
            original = f"<{tag}{attrs}{closing}" if content is None else f"<{tag}{attrs}>{content}</{tag}>"
            return (
                f'<g id="layer-for-{element_id}" class="layer layer-{layer}" data-layer="{layer}" '
                f'data-object-ref="{element_id}">{original}</g>'
            )

        svg = SHAPE_PATTERN.sub(wrap, svg)
        root_end = svg.find(">")
        svg = svg[:root_end] + ' data-semantic-layer-contract="per-object-v1"' + svg[root_end:]
        path.write_text(svg, encoding="utf-8")
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
