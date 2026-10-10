#!/usr/bin/env python3
"""Add editable-plan metadata to legacy handoff SVGs without changing geometry."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TARGETS = (
    ROOT / "docs/design/complex_v3/handoff/overview/metric-overview.svg",
    ROOT / "docs/design/complex_v3/handoff/vertical/vertical-section.svg",
)
SHAPE_PATTERN = re.compile(
    r"<(rect|line|path|polygon|polyline|circle|ellipse|text)\b([^>]*?)(/\s*>|>([\s\S]*?)</\1>)",
    flags=re.I,
)


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def kind_for(tag: str, attrs: str) -> str:
    semantic = " ".join(re.findall(r'\bclass="([^"]+)"', attrs, re.I)).lower()
    if tag.lower() == "text":
        return "label"
    if "door" in semantic or "opening" in semantic or "gate" in semantic:
        return "opening"
    if "wall" in semantic or "partition" in semantic or "barrier" in semantic:
        return "wall"
    if tag.lower() in {"line", "polyline"} or "axis" in semantic or "level" in semantic:
        return "annotation"
    if "shaft" in semantic or "room" in semantic or "zone" in semantic:
        return "area"
    return "diagram-element"


def layer_for(kind: str) -> str:
    return {
        "label": "labels",
        "opening": "openings",
        "wall": "walls",
        "annotation": "annotations",
        "area": "rooms",
    }.get(kind, "equipment")


def migrate(path: Path) -> None:
    svg = path.read_text(encoding="utf-8")
    if 'data-semantic-layer-contract="per-object-v1"' in svg:
        return
    counters: dict[str, int] = {}
    prefix = slug(path.stem)

    def wrap(match: re.Match[str]) -> str:
        tag, attrs, closing, content = match.group(1), match.group(2), match.group(3), match.group(4)
        kind_match = re.search(r'\bdata-kind="([^"]+)"', attrs, re.I)
        kind = kind_match.group(1) if kind_match else kind_for(tag, attrs)
        counters[kind] = counters.get(kind, 0) + 1
        id_match = re.search(r'\bid="([^"]+)"', attrs, re.I)
        element_id = id_match.group(1) if id_match else f"{prefix}-{slug(kind)}-{counters[kind]:03d}"
        additions = ""
        if not id_match:
            additions += f' id="{element_id}"'
        if not kind_match:
            additions += f' data-kind="{kind}"'
        updated_attrs = attrs + additions
        original = f"<{tag}{updated_attrs}{closing}" if content is None else f"<{tag}{updated_attrs}>{content}</{tag}>"
        layer = layer_for(kind)
        return (
            f'<g id="layer-for-{element_id}" class="layer layer-{layer}" data-layer="{layer}" '
            f'data-object-ref="{element_id}">{original}</g>'
        )

    svg = SHAPE_PATTERN.sub(wrap, svg)
    root_end = svg.find(">")
    root_attrs = (
        ' data-scale="relative" data-scale-policy="metric-handoff-authoritative"'
        ' data-grid-size="1" data-plan-style-id="caretaker-style-b-v1"'
        ' data-semantic-layer-contract="per-object-v1"'
    )
    svg = svg[:root_end] + root_attrs + svg[root_end:]
    path.write_text(svg, encoding="utf-8")
    print(path.relative_to(ROOT))


def main() -> None:
    for path in TARGETS:
        migrate(path)


if __name__ == "__main__":
    main()
