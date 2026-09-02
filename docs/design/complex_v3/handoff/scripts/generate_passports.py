#!/usr/bin/env python3
"""Generate reviewable sector passports from approved overview data."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OVERVIEW = ROOT / "overview" / "metric-overview.json"
TOPOLOGY = ROOT / "overview" / "topology.json"
METADATA = ROOT / "passports" / "sector-metadata.json"
OUT_JSON = ROOT / "passports" / "sector-passports.json"
OUT_MD = ROOT / "passports" / "sector-passports.md"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    overview = load(OVERVIEW)
    topology = load(TOPOLOGY)
    metadata = load(METADATA)

    levels = {item["id"]: item for item in overview["levels"]}
    envelopes = {item["id"]: item for item in overview["sector_envelopes"]}
    anchors = {item["id"]: item for item in overview["anchors"]}
    defaults = metadata["default_clearances"]
    forbidden = topology.get("forbidden_direct_connections", [])
    connections = topology["connections"]

    passports: list[dict] = []
    for item in metadata["sectors"]:
        sector_id = item["id"]
        envelope = envelopes[sector_id]
        level = levels[envelope["level"]]
        bounds = envelope["bounds_xz"]
        relevant_connections = []
        neighbors = []
        for edge in connections:
            if sector_id not in (edge["from"], edge["to"]):
                continue
            other = edge["to"] if edge["from"] == sector_id else edge["from"]
            record = {
                "connection_id": edge["id"],
                "neighbor": other,
                "kind": edge["kind"],
                "traversable": edge["traversable"],
            }
            if "state" in edge:
                record["state"] = edge["state"]
            if "anchor" in edge:
                record["anchor"] = edge["anchor"]
            relevant_connections.append(record)
            neighbors.append(other)

        anchor_records = []
        for anchor_id in item.get("anchors", []):
            anchor = anchors[anchor_id]
            record = {"id": anchor_id, "tolerance": anchor["tolerance"]}
            if "position_xz" in anchor:
                record["position_xz"] = anchor["position_xz"]
            if "centerline_z" in anchor:
                record["centerline_z"] = anchor["centerline_z"]
            anchor_records.append(record)

        forbidden_here = [
            edge for edge in forbidden if sector_id in (edge["from"], edge["to"])
        ]
        clearance_profile = item["clearance"]
        passport = {
            "id": f"PASS-{sector_id}",
            "sector_id": sector_id,
            "level": envelope["level"],
            "detail_id": f"DETAIL-{sector_id}",
            "parent_artifact": "OVERVIEW-DATA-01",
            "plan_style_id": metadata["plan_style_id"],
            "source_detail": str(Path(item["source"]).with_suffix(".svg")).replace("\\", "/"),
            "source_use": item.get("source_use", "full sector geometry"),
            "parent_boundary_xz": bounds,
            "local_origin_xyz": [bounds[0], level["floor_y"], bounds[1]],
            "neighbors": sorted(set(neighbors)),
            "required_connections": relevant_connections,
            "forbidden_direct_connections": forbidden_here,
            "preserved_intermediate_volumes": [
                connection["kind"]
                for connection in relevant_connections
                if any(token in connection["kind"] for token in ("airlock", "transition", "threshold", "vestibule", "stair", "lift", "tunnel"))
            ],
            "anchors": anchor_records,
            "allowed_internal_subdivision": item["subdivisions"],
            "clearance_profile": clearance_profile,
            "required_clearances": defaults[clearance_profile],
            "hidden_or_inaccessible_reserved_volumes": item.get("reserved", []),
            "geometry_status": "provisional-metric; exact structured layout in complex-handoff.json",
            "status": "verified"
        }
        passports.append(passport)

    output = {
        "schema_version": "1.0",
        "artifact_id": "PASSPORTS-01",
        "map_id": overview["map_id"],
        "plan_style_id": metadata["plan_style_id"],
        "status": "verified",
        "passport_count": len(passports),
        "passports": passports,
    }
    OUT_JSON.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Комплекс v3 — паспорта секторов",
        "",
        "Артефакт: `PASSPORTS-01`",
        "",
        "Статус: `verified`; точная структурированная геометрия подключается из `geometry/complex-handoff.json`.",
        "",
    ]
    for passport in passports:
        bounds = passport["parent_boundary_xz"]
        lines.extend([
            f"## {passport['sector_id']}",
            "",
            f"- Passport ID: `{passport['id']}`",
            f"- Detail ID: `{passport['detail_id']}`",
            f"- Level: `{passport['level']}`",
            f"- Plan style: `{passport['plan_style_id']}`",
            f"- Source: `{passport['source_detail']}` ({passport['source_use']})",
            f"- Parent boundary XZ: `[{bounds[0]}, {bounds[1]}] → [{bounds[2]}, {bounds[3]}] m`",
            f"- Local origin XYZ: `{passport['local_origin_xyz']}`",
            f"- Neighbors: {', '.join(f'`{value}`' for value in passport['neighbors']) or 'нет'}",
            f"- Allowed subdivisions: {', '.join(f'`{value}`' for value in passport['allowed_internal_subdivision'])}",
            f"- Clearance profile: `{passport['clearance_profile']}` — {passport['required_clearances']}",
            f"- Reserved volumes: {', '.join(f'`{value}`' for value in passport['hidden_or_inaccessible_reserved_volumes']) or 'нет'}",
        ])
        if passport["anchors"]:
            lines.append("- Anchors: " + ", ".join(f"`{value['id']}`" for value in passport["anchors"]))
        lines.extend(["", "Required connections:", ""])
        for connection in passport["required_connections"]:
            state = f", state `{connection['state']}`" if "state" in connection else ""
            lines.append(
                f"- `{connection['connection_id']}` → `{connection['neighbor']}`: "
                f"`{connection['kind']}`, traversable `{str(connection['traversable']).lower()}`{state}."
            )
        lines.extend(["", "---", ""])
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"OK: generated {len(passports)} passports")


if __name__ == "__main__":
    main()
