"""Remove every placed object of the 30 production sectors (user decision 2026-10-08: sectors were redrawn, objects are re-placed from scratch).

Empties, but keeps the files and their schema so every contract and tool still works:
  - set_dressing seeds and manifest placements, authored corrections, migration evidence;
  - set-dressing sub-scenes (root node and metadata only);
  - object bindings (blockout bindings and rollout AuthoredContent) and rollout compositions (objects, spaces, infrastructure).
Pilot fixtures (scenes/complex_v3_regeneration/pilots) are test inputs and are left alone.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLOCKOUT = ROOT / "scenes/complex_v3_blockout"
DRESSING = BLOCKOUT / "set_dressing"
ROLLOUT = ROOT / "scenes/complex_v3_regeneration/rollout"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    count = {"seeds": 0, "scenes": 0, "bindings": 0, "compositions": 0}
    for path in sorted((DRESSING / "seed").glob("*.seed.json")):
        data = load(path)
        data["placements"] = []
        dump(path, data)
        count["seeds"] += 1
    manifest = load(DRESSING / "set_dressing_manifest.json")
    for sector in manifest["sectors"]:
        sector["placements"] = []
    dump(DRESSING / "set_dressing_manifest.json", manifest)
    corrections = load(DRESSING / "authored_corrections.json")
    corrections["objects"] = []
    dump(DRESSING / "authored_corrections.json", corrections)
    for path in sorted((DRESSING / "sectors").glob("*_dressing.tscn")):
        text = path.read_text(encoding="utf-8")
        root = re.search(r'\[node name="[^"]+" type="Node3D"\]\n(?:metadata/[^\n]*\n)*', text)
        header = root.group(0) if root else None
        if header is None:
            raise SystemExit(f"unexpected scene layout: {path}")
        path.write_text("[gd_scene format=3]\n\n" + header, encoding="utf-8", newline="\n")
        count["scenes"] += 1
    for path in sorted((BLOCKOUT / "bindings").glob("*.bindings.json")):
        data = load(path)
        data["bindings"] = []
        dump(path, data)
        count["bindings"] += 1
    for path in sorted(ROLLOUT.glob("*/AuthoredContent/*/object_bindings.json")):
        data = load(path)
        data["bindings"] = []
        dump(path, data)
        count["bindings"] += 1
    for path in sorted(ROLLOUT.glob("*/AuthoredContent/*/composition.json")):
        data = load(path)
        data["objects"] = []
        data["spaces"] = []
        data["infrastructure"] = []
        data["anchors"] = []
        data["declared_warnings"] = []
        dump(path, data)
        count["compositions"] += 1
    migration = DRESSING / "migration"
    for name in ("before_transforms.json", "after_transforms.json", "migration_report.json"):
        path = migration / name
        if path.exists():
            path.unlink()
    print(count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
