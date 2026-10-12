#!/usr/bin/env python3
"""Single source of truth for the state of every vertical transition.

Stairs defined in `vertical_definitions.json` are resolved from the SVG plans
(`vertical_resolver.py`); lift shafts are validated from the plans' openings
(`validate_verticals.py`); everything else is unresolved. The shared infrastructure
report, the input audit and the port mapper read this instead of hard-coded lists.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

try:
    from .validate_verticals import LIFT_KINDS, validate_lifts
    from .vertical_resolver import VerticalError, resolve_stair
except ImportError:
    try:
        from tools.complex_v4.validate_verticals import LIFT_KINDS, validate_lifts
        from tools.complex_v4.vertical_resolver import VerticalError, resolve_stair
    except ImportError:
        from validate_verticals import LIFT_KINDS, validate_lifts
        from vertical_resolver import VerticalError, resolve_stair

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/complex_v4/sector_generation_manifest.json"
DEFINITIONS = ROOT / "tools/complex_v4/vertical_definitions.json"
TRANSITIONS = ROOT / "docs/design/complex_v4/handoff/vertical/vertical-transitions.json"
HANDOFF = ROOT / "docs/design/complex_v4/handoff/geometry/complex-handoff.json"

GENERATED = "generated"
OPENINGS_READY = "openings_ready"
MARKUP_INCOMPLETE = "markup_incomplete"
UNRESOLVED = "unresolved"
INVALID = "invalid"
CLOSED = "closed"  # story-closed transition: deliberately has no geometry (decision D-44)
RESOLVED_STATUSES = {GENERATED, OPENINGS_READY}


def load_definitions(path: Path = DEFINITIONS) -> dict[str, dict[str, Any]]:
    """Map vertical_id -> {"host_sector_id", "generator"} for SVG-derived stairs.

    A transition that climbs through several levels (a chain of flights in one shaft) is described by one
    definition per flight; each has its own vertical_id (the markup id) and the shared `transition_id`.
    """
    document = json.loads(path.read_text(encoding="utf-8"))
    return {item["generator"]["vertical_id"]: item for item in document["stairs"]}


def transition_of(definition: dict[str, Any]) -> str:
    generator = definition["generator"]
    return str(generator.get("transition_id", generator["vertical_id"]))


def defined_transition_ids(definitions: dict[str, dict[str, Any]] | None = None) -> set[str]:
    return {transition_of(item) for item in (definitions if definitions is not None else load_definitions()).values()}


def build_registry(
    manifest: dict[str, Any], transitions: dict[str, Any], handoff: dict[str, Any],
    definitions: dict[str, dict[str, Any]], project_root: Path = ROOT,
) -> list[dict[str, Any]]:
    sectors = {item["sector_id"]: item for item in manifest["sectors"] if isinstance(item, dict)}
    lift_diagnostics = validate_lifts(manifest, transitions, handoff, project_root)
    registry: list[dict[str, Any]] = []
    for transition in transitions["transitions"]:
        vertical_id = transition["id"]
        kind = transition.get("kind", "")
        entry: dict[str, Any] = {"id": vertical_id, "kind": kind, "owner": "complex_v4_infrastructure", "detail": ""}
        flights = [item for item in definitions.values() if transition_of(item) == vertical_id]
        if flights:
            entry["owner"] = ", ".join(f"sector:{item['host_sector_id']}" for item in flights)
            summaries, errors = [], []
            for definition in flights:
                try:
                    summaries.append(resolve_stair(definition["generator"], sectors, project_root)["summary"])
                except (VerticalError, KeyError, OSError) as exc:
                    errors.append(f"{definition['generator']['vertical_id']}: {exc}")
            if errors:
                entry.update(status=INVALID, detail="; ".join(errors))
            else:
                entry.update(status=GENERATED, summary=summaries[0] if len(summaries) == 1 else summaries)
        elif kind in LIFT_KINDS:
            missing = [line for line in lift_diagnostics if line.startswith(vertical_id)]
            entry["owner"] = "sector_svg_openings"
            if missing:
                entry.update(status=MARKUP_INCOMPLETE, detail="; ".join(missing), missing=missing)
            else:
                entry.update(status=OPENINGS_READY)
        elif transition.get("closed"):
            entry.update(status=CLOSED, detail=str(transition.get("closed_reason", "closed transition without geometry")))
        elif kind.endswith("incline") or "incline" in kind:
            entry.update(status=UNRESOLVED, detail="non-port transition: separate geometry is required")
        else:
            entry.update(status=UNRESOLVED, detail="no vertical definition: add data-vertical-* markup to the plans and an entry to vertical_definitions.json")
        registry.append(entry)
    return registry


def load_registry(project_root: Path = ROOT) -> list[dict[str, Any]]:
    read = lambda path: json.loads(path.read_text(encoding="utf-8"))  # noqa: E731
    return build_registry(read(project_root / MANIFEST.relative_to(ROOT)), read(project_root / TRANSITIONS.relative_to(ROOT)),
                          read(project_root / HANDOFF.relative_to(ROOT)), load_definitions(project_root / DEFINITIONS.relative_to(ROOT)), project_root)


def summarize(registry: list[dict[str, Any]]) -> dict[str, Any]:
    """Fields for the shared infrastructure report, derived from the registry."""
    resolved = sorted(item["id"] for item in registry if item["status"] in RESOLVED_STATUSES)
    closed = sorted(item["id"] for item in registry if item["status"] == CLOSED)
    unresolved = sorted(item["id"] for item in registry if item["status"] not in RESOLVED_STATUSES | {CLOSED})
    owners = {item["id"]: item["owner"] for item in registry}
    reason = ""
    if unresolved:
        reason = "Verticals still without resolved geometry: " + ", ".join(
            f"{item['id']} ({item['status']})" for item in registry if item["status"] not in RESOLVED_STATUSES | {CLOSED}
        )
    return {
        "status": "ready" if not unresolved else "ready_with_blocking_vertical_diagnostics",
        "generated_vertical_geometry": resolved,
        "unresolved_vertical_geometry": unresolved,
        "closed_vertical_geometry": closed,
        "owners": owners,
        "blocking_reason": reason,
        "verticals": [{key: item[key] for key in ("id", "kind", "status", "owner", "detail") if key in item} for item in registry],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print the registry as JSON")
    options = parser.parse_args(argv)
    registry = load_registry()
    if options.json:
        print(json.dumps(summarize(registry), ensure_ascii=False, indent=2))
    else:
        for item in registry:
            print(f"{item['status']:<18} {item['id']:<20} {item['owner']:<28} {item['detail']}"[:230])
    unresolved = [item for item in registry if item["status"] not in RESOLVED_STATUSES]
    print(f"VERTICALS resolved={len(registry) - len(unresolved)} unresolved={len(unresolved)}")
    return 2 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
