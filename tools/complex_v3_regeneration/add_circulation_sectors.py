"""One-off: register U-CIRCULATION and L-CIRCULATION as production sectors (32 in total).

They own the passenger corridor / heavy trunk of their level (G-03 decision D-39) and are modelled on T-CIRCULATION:
catalog entry, passport, empty set-dressing / bindings / compositions, zone scene, assembly instance.
Run once; it refuses to run twice.
"""
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLOCKOUT = ROOT / "scenes/complex_v3_blockout"
DATA = ROOT / "docs/design/complex_v4/review/data"
NEW = {
    "U-CIRCULATION": {"level": "LV-U", "folder": "upper", "code": "u", "elevation": 0.0},
    "L-CIRCULATION": {"level": "LV-L", "folder": "lower", "code": "l", "elevation": -6.0},
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def neighbours(sector_id: str, level: str) -> list[str]:
    own = load(DATA / f"{sector_id.lower()}.json")["rooms"]
    found = set()
    for path in DATA.glob("*.json"):
        other = load(path)
        if other["sector_id"] == sector_id or other["level"] != level:
            continue
        for a in own:
            ax, az, aw, ah = a["world_m"]
            for b in other["rooms"]:
                bx, bz, bw, bh = b["world_m"]
                if min(ax + aw, bx + bw) - max(ax, bx) > -0.3 and min(az + ah, bz + bh) - max(az, bz) > -0.3:
                    found.add(other["sector_id"])
    return sorted(found)


def main() -> int:
    catalog_path = BLOCKOUT / "sector_catalog.json"
    catalog = load(catalog_path)
    if any(item["sector_id"] in NEW for item in catalog["sectors"]):
        raise SystemExit("already registered")
    passports_path = ROOT / "docs/design/complex_v3/handoff/passports/sector-passports.json"
    passports = load(passports_path)
    dressing_path = BLOCKOUT / "set_dressing/set_dressing_manifest.json"
    dressing = load(dressing_path)
    t_catalog = next(s for s in catalog["sectors"] if s["sector_id"] == "T-CIRCULATION")
    t_passport = next(s for s in passports["passports"] if s["sector_id"] == "T-CIRCULATION")
    t_dressing = next(s for s in dressing["sectors"] if s["sector_id"] == "T-CIRCULATION")
    t_zone = (BLOCKOUT / "zones/technical/t_circulation.tscn").read_text(encoding="utf-8")
    assembly_path = BLOCKOUT / "complex_v3_blockout.tscn"
    assembly = assembly_path.read_text(encoding="utf-8")
    for sector_id, info in NEW.items():
        slug = sector_id.lower().replace("-", "_")
        rep = load(DATA / f"{sector_id.lower()}.json")
        xs = [m["world_m"][0] for m in rep["rooms"]] + [m["world_m"][0] + m["world_m"][2] for m in rep["rooms"]]
        zs = [m["world_m"][1] for m in rep["rooms"]] + [m["world_m"][1] + m["world_m"][3] for m in rep["rooms"]]
        near = neighbours(sector_id, info["level"])
        scene = f"res://scenes/complex_v3_blockout/zones/{info['folder']}/{slug}.tscn"
        entry = copy.deepcopy(t_catalog)
        entry.update(sector_id=sector_id, level=info["level"], scene=scene, space_count=0, neighbors=near,
                     focus_xyz=[round((min(xs) + max(xs)) / 2, 1), info["elevation"] + 1.5, round((min(zs) + max(zs)) / 2, 1)],
                     standalone_infrastructure_preview=False)
        catalog["sectors"].append(entry)
        passport = copy.deepcopy(t_passport)
        passport.update(id=f"PASS-{sector_id}", sector_id=sector_id, level=info["level"], detail_id=f"DETAIL-{sector_id}",
                        source_detail="synthetic: built from the overview of the level (docs/design/complex_v4)",
                        parent_boundary_xz=[round(min(xs), 2), round(min(zs), 2), round(max(xs) - min(xs), 2), round(max(zs) - min(zs), 2)],
                        local_origin_xyz=[round(min(xs), 2), info["elevation"], round(min(zs), 2)], neighbors=near,
                        required_connections=[], forbidden_direct_connections=[], preserved_intermediate_volumes=[], anchors=[])
        passports["passports"].append(passport)
        place = copy.deepcopy(t_dressing)
        place.update(sector_id=sector_id, zone_scene=scene, dressing_scene=f"res://scenes/complex_v3_blockout/set_dressing/sectors/{slug}_dressing.tscn", placements=[])
        dressing["sectors"].append(place)
        seed = load(BLOCKOUT / "set_dressing/seed/t_circulation.seed.json")
        seed.update(sector_id=sector_id, placements=[])
        dump(BLOCKOUT / f"set_dressing/seed/{slug}.seed.json", seed)
        (BLOCKOUT / f"set_dressing/sectors/{slug}_dressing.tscn").write_text(
            f'[gd_scene format=3]\n\n[node name="{slug.upper()}_SetDressing" type="Node3D"]\nmetadata/sector_id = "{sector_id}"\nmetadata/material_family = "utility"\n',
            encoding="utf-8", newline="\n")
        bindings = load(BLOCKOUT / "bindings/t_circulation.bindings.json")
        bindings.update(sector_id=sector_id, bindings=[])
        dump(BLOCKOUT / f"bindings/{slug}.bindings.json", bindings)
        base = ROOT / f"scenes/complex_v3_regeneration/rollout/{info['folder']}/AuthoredContent/{slug}"
        composition = load(ROOT / "scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/t_circulation/composition.json")
        composition.update(sector_id=sector_id, objects=[], spaces=[], infrastructure=[], anchors=[], declared_warnings=[],
                           sector_bounds={"min": [round(min(xs) - 0.15, 2), info["elevation"] - 0.2, round(min(zs) - 0.15, 2)],
                                          "max": [round(max(xs) + 0.15, 2), info["elevation"] + 4.7, round(max(zs) + 0.15, 2)]})
        dump(base / "composition.json", composition)
        rollout_bindings = load(ROOT / "scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/t_circulation/object_bindings.json")
        rollout_bindings.update(sector_id=sector_id, bindings=[])
        dump(base / "object_bindings.json", rollout_bindings)
        zone = t_zone.replace("T-CIRCULATION", sector_id).replace("T_CIRCULATION", sector_id.replace("-", "_")).replace("t_circulation", slug)
        zone = zone.replace("gen/t/", f"gen/{info['code']}/").replace("rollout/technical/", f"rollout/{info['folder']}/")
        (BLOCKOUT / f"zones/{info['folder']}/{slug}.tscn").write_text(zone, encoding="utf-8", newline="\n")
        resource_id = f"{33 if info['code'] == 'u' else 34}_{slug}"
        ext = f'[ext_resource type="PackedScene" path="{scene}" id="{resource_id}"]\n'
        last_ext = list(re.finditer(r"\[ext_resource [^\n]*\n", assembly))[-1]
        assembly = assembly[:last_ext.end()] + ext + assembly[last_ext.end():]
        node = f'[node name="{sector_id.replace("-", "_")}" parent="Zones" instance=ExtResource("{resource_id}")]\n'
        anchor = '[node name="L_EAST_STAIR"' if info["code"] == "l" else '[node name="U_CONTROL"'
        assembly = assembly.replace(anchor, node + anchor, 1)
    catalog["sector_count"] = len(catalog["sectors"])
    assembly = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + len(NEW)}", assembly, count=1)
    dump(catalog_path, catalog)
    passports["passport_count"] = len(passports["passports"])
    dump(passports_path, passports)
    dressing["sector_count"] = len(dressing["sectors"])
    dump(dressing_path, dressing)
    assembly_path.write_text(assembly, encoding="utf-8", newline="\n")
    print("registered", ", ".join(NEW))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
