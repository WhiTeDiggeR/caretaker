"""Verify Route A source geometry and generated anchor identities against handoff."""
from __future__ import annotations

import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[4]
PILOT = PROJECT / "scenes/complex_v3_regeneration/pilots/route_a_vertical"


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def close(a: list, b: list) -> bool:
    return len(a) == len(b) and all(math.isclose(x, y, abs_tol=1e-6) for x, y in zip(a, b))


def main() -> int:
    handoff = read(PROJECT / "docs/design/complex_v3/handoff/geometry/complex-handoff.json")
    errors = []
    counts = {}
    all_ids = []
    for sector, stem, output in [("U-ROUTE-A", "u_route_a", "u"), ("L-ARCHIVE-A", "l_archive_a", "l")]:
        level = "upper" if stem == "u_route_a" else "lower"
        elements = list(ET.parse(PROJECT / f"docs/design/complex_v3/plans/generation/{level}/{stem}.svg").getroot().iter())
        svg_ids = [item.get("id") for item in elements if item.get("id")]
        if len(svg_ids) != len(set(svg_ids)):
            errors.append(f"{sector}: duplicate SVG IDs")
        spaces = {s["id"]: s for s in handoff["spaces"] if s.get("sector_id") == sector}
        floors = [e for e in elements if e.get("data-godot-type") == "floor"]
        if {e.get("data-space-id") for e in floors} != set(spaces):
            errors.append(f"{sector}: floor/space set mismatch")
        for floor in floors:
            x, z, width, depth = [float(floor.get(k)) for k in ("x", "y", "width", "height")]
            if not close([x, z, x + width, z + depth], spaces[floor.get("data-space-id")]["bounds_xz"]):
                errors.append(f"{floor.get('id')}: handoff bounds mismatch")
        portals = {p["id"]: p for key in ("internal_portals", "external_portals") for p in handoff[key]}
        doors = [e for e in elements if e.get("data-godot-type") == "door"]
        for door in doors:
            portal = portals[door.get("data-handoff-id")]
            actual = [float(door.get(k)) for k in ("x1", "y1", "x2", "y2")]
            if not close(actual, sum(portal["segment_xz"], [])):
                errors.append(f"{door.get('id')}: portal segment mismatch")
            if door.get("data-inside-side") not in {"normal", "opposite"} or door.get("data-hinge-side"):
                errors.append(f"{door.get('id')}: guessed door side")
        anchors = read(PROJECT / f"scenes/cv3_route_a/{output}/anchor_frames.json")["anchors"]
        ids = [a["anchor_id"] for a in anchors]
        all_ids.extend(ids)
        if any(":hinge" in value for value in ids):
            errors.append(f"{sector}: guessed hinge")
        counts[sector] = {"spaces": len(floors), "doors": len(doors), "anchors": len(anchors)}
    if len(all_ids) != len(set(all_ids)):
        errors.append("duplicate IDs across upper/lower packages")
    physics = read(PILOT / "reports/combined-physics.json")
    if physics["status"] != "passed" or physics["stair_shapes"] < 100:
        errors.append("combined physics proof missing or failed")
    report = {"schema_id": "caretaker.route_a_handoff_verification", "schema_version": "1.0.0", "status": "blocked" if errors else "passed", "counts": counts, "errors": errors}
    (PILOT / "reports/handoff-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(report, ensure_ascii=False))
    return 2 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
