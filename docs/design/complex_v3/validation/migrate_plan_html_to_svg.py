#!/usr/bin/env python3
"""Create canonical editable SVG sources from the approved legacy HTML plans.

The migration is deliberately source-preserving: it extracts the current SVG
markup, adds only the metadata required by the plan contract, and keeps the
original drawing order.  Existing IDs, classes and unknown editor attributes
are never removed.
"""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "docs/design/complex_v3"
PASSPORTS = PACKAGE / "handoff/passports/sector-passports.json"
STYLE_ID = "caretaker-style-b-v1"
SHAPES = {"rect", "line", "path", "polygon", "polyline", "circle", "ellipse", "text"}


def make_css_standalone(css: str) -> str:
    """Retarget HTML wrapper selectors to the extracted SVG root."""
    wrapper_ids = set(re.findall(r"#([A-Za-z_][\w-]*)\s+svg\b", css))
    for wrapper_id in wrapper_ids:
        css = re.sub(rf"#{re.escape(wrapper_id)}\s+svg\b", ".plan-root", css)
        css = re.sub(rf"#{re.escape(wrapper_id)}\b", ".plan-root", css)
    return css


def current_html_plans() -> list[Path]:
    result = list((PACKAGE / "plans/sectors").glob("*/*.html"))
    result += list((PACKAGE / "plans/overview").glob("*/current/*.html"))
    return sorted(result)


def passport_by_source() -> dict[str, dict]:
    data = json.loads(PASSPORTS.read_text(encoding="utf-8"))
    result: dict[str, dict] = {}
    for passport in data["passports"]:
        source = (PASSPORTS.parent / passport["source_detail"]).resolve()
        result[str(source)] = passport
        result[str(source.with_suffix(".html"))] = passport
    return result


def extract_svg(document: str, source: Path) -> tuple[str, str]:
    decoded = html.unescape(document)
    candidates = re.findall(r"<svg\b[\s\S]*?</svg>", decoded, flags=re.IGNORECASE)
    if not candidates:
        raise ValueError(f"no SVG found in {source}")
    svg = max(candidates, key=len)
    styles = re.findall(r"<style\b[^>]*>([\s\S]*?)</style>", decoded, flags=re.IGNORECASE)
    linked_css = source.parent / "technical-sector-plan.css"
    if linked_css.exists():
        styles.append(linked_css.read_text(encoding="utf-8"))
    # Preserve first occurrence order while avoiding repeated iframe/viewer CSS.
    unique_styles = list(dict.fromkeys(style.strip() for style in styles if style.strip()))
    return svg, make_css_standalone("\n\n".join(unique_styles))


def slug(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_-]+", "-", value).strip("-").lower()
    return value or "plan"


def add_root_attributes(svg: str, plan_id: str, passport: dict | None) -> str:
    match = re.match(r"<svg\b([^>]*)>", svg, flags=re.IGNORECASE)
    if not match:
        raise ValueError("invalid SVG root")
    attrs = match.group(1)
    additions: list[str] = []
    required = {
        "xmlns": "http://www.w3.org/2000/svg",
        "id": f"plan-{slug(plan_id)}",
        "class": "plan-root",
        "data-plan-style-id": STYLE_ID,
        "data-scale": "relative",
        "data-scale-policy": "legacy-local; metric-handoff-authoritative",
        "data-grid-size": "1",
        "data-grid-unit": "svg-unit",
        "data-plan-id": plan_id,
    }
    if passport:
        required.update(
            {
                "data-sector-id": passport["sector_id"],
                "data-level": passport["level"],
                "data-parent-bounds-xz": ",".join(map(str, passport["parent_boundary_xz"])),
                "data-local-origin-xyz": ",".join(map(str, passport["local_origin_xyz"])),
                "data-anchor-ids": ",".join(anchor["id"] for anchor in passport.get("anchors", [])),
            }
        )
    for key, value in required.items():
        if not re.search(rf"\b{re.escape(key)}\s*=", attrs):
            additions.append(f' {key}="{html.escape(value, quote=True)}"')
    return svg[: match.start()] + f"<svg{attrs}{''.join(additions)}>" + svg[match.end() :]


def infer_kind(tag: str, attrs: str) -> str:
    classes = " ".join(re.findall(r'\bclass\s*=\s*["\']([^"\']+)', attrs, re.I)).lower()
    semantic = classes
    if tag == "text":
        return "label"
    if "door" in semantic or "gap" in semantic or "opening" in semantic:
        return "opening"
    if any(token in semantic for token in ("wall", "partition", "barrier")):
        return "wall"
    if any(token in semantic for token in ("equipment", "work", "machine", "capsule", "rack")):
        return "equipment"
    if any(token in semantic for token in ("room", "corridor", "shaft", "zone", "support", "service")):
        return "space"
    if tag in {"line", "polyline"}:
        return "annotation"
    return "geometry"


def annotate_shapes(svg: str, plan_id: str) -> str:
    counters: dict[str, int] = {}
    id_pattern = re.compile(r"\bid\s*=", re.I)
    class_pattern = re.compile(r"\bclass\s*=", re.I)
    kind_pattern = re.compile(r"\bdata-kind\s*=", re.I)

    def replace(match: re.Match[str]) -> str:
        tag, attrs = match.group(1).lower(), match.group(2)
        if tag not in SHAPES:
            return match.group(0)
        self_closing = attrs.rstrip().endswith("/")
        if self_closing:
            attrs = attrs.rstrip()[:-1].rstrip()
        kind = infer_kind(tag, attrs)
        counters[kind] = counters.get(kind, 0) + 1
        additions = ""
        if not id_pattern.search(attrs):
            additions += f' id="{slug(plan_id)}-{kind}-{counters[kind]:03d}"'
        if not class_pattern.search(attrs):
            additions += f' class="{kind}"'
        if not kind_pattern.search(attrs):
            additions += f' data-kind="{kind}"'
        close = " /" if self_closing else ""
        return f"<{tag}{attrs}{additions}{close}>"

    return re.sub(r"<(rect|line|path|polygon|polyline|circle|ellipse|text)\b([^>]*)>", replace, svg, flags=re.I)


def embed_metadata_and_style(svg: str, css: str, plan_id: str, passport: dict | None) -> str:
    payload = {
        "schema": "complex-v3-svg-plan-metadata-v1",
        "plan_id": plan_id,
        "style_id": STYLE_ID,
        "geometry_policy": "preserve-approved-plan; metric-handoff-is-authoritative",
    }
    if passport:
        payload.update(
            {
                "sector_id": passport["sector_id"],
                "level": passport["level"],
                "parent_boundary_xz": passport["parent_boundary_xz"],
                "local_origin_xyz": passport["local_origin_xyz"],
                "anchors": passport.get("anchors", []),
                "neighbors": passport.get("neighbors", []),
            }
        )
    block = (
        f'\n  <metadata id="{slug(plan_id)}-metadata">{html.escape(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))}</metadata>'
        f'\n  <defs id="{slug(plan_id)}-style-defs"><style><![CDATA[\n{css}\n]]></style></defs>\n'
    )
    root_end = svg.find(">") + 1
    return svg[:root_end] + block + svg[root_end:]


def wrap_semantic_layer(svg: str, plan_id: str) -> str:
    root_end = svg.find(">") + 1
    close = svg.lower().rfind("</svg>")
    body = svg[root_end:close]
    # One ordered source layer keeps the approved z-order intact. Individual
    # elements retain semantic data-kind values for editor filtering.
    wrapped = (
        f'\n  <g id="{slug(plan_id)}-source-layer" class="layer source-geometry" '
        'data-layer="source-geometry">'
        f"{body}\n  </g>\n"
    )
    return svg[:root_end] + wrapped + svg[close:]


def repair_malformed_self_closing(svg: str) -> str:
    """Repair the first migration's attribute placement after a `/` marker."""
    pattern = re.compile(
        r'(<(?:rect|line|path|polygon|polyline|circle|ellipse|text)\b[^>]*?)/\s+'
        r'((?:(?:id|class|data-kind)="[^"]+"\s*)+)>',
        flags=re.I,
    )
    return pattern.sub(lambda match: f"{match.group(1)} {match.group(2).rstrip()} />", svg)


def normalize_text_file(svg: str) -> str:
    return "\n".join(line.rstrip() for line in svg.splitlines()) + "\n"


def migrate(source: Path, passports: dict[str, dict]) -> Path:
    plan_id = source.stem
    passport = passports.get(str(source.resolve()))
    target = source.with_suffix(".svg")
    document = source.read_text(encoding="utf-8")
    if 'name="map-viewer-source"' in document and target.exists():
        migrated = repair_malformed_self_closing(target.read_text(encoding="utf-8"))
        target.write_text(normalize_text_file(migrated), encoding="utf-8")
        return target
    svg, css = extract_svg(document, source)
    svg = add_root_attributes(svg, plan_id, passport)
    svg = annotate_shapes(svg, plan_id)
    svg = embed_metadata_and_style(svg, css, plan_id, passport)
    svg = wrap_semantic_layer(svg, plan_id)
    target.write_text(normalize_text_file(svg), encoding="utf-8")
    return target


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", type=Path, help="HTML plans; defaults to all current complex plans")
    args = parser.parse_args()
    passports = passport_by_source()
    sources = [path.resolve() for path in args.paths] if args.paths else current_html_plans()
    for source in sources:
        print(migrate(source, passports).relative_to(ROOT))


if __name__ == "__main__":
    main()
