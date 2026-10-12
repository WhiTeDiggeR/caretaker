"""Compare vertical shafts (stairs, lifts) between levels in the canonical SVGs."""
import json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "docs/design/complex_v4/review/data"
GEN = ROOT / "docs/design/complex_v4/plans/generation"
FOLDER = {"LV-U": "upper", "LV-L": "lower", "LV-T": "technical"}


def room(sector, slug):
    r = json.loads((DATA / (sector.lower() + ".json")).read_text(encoding="utf-8"))
    for m in r["rooms"]:
        if m["space_id"].split("/")[1] == slug:
            return [round(v, 2) for v in m["world_m"]], r["level"]
    return None, r["level"]


def cuts(sector, level):
    p = GEN / FOLDER[level] / (sector.lower().replace("-", "_") + ".svg")
    out = []
    for m in re.finditer(r'<rect id="[^"]*" class="opening" data-godot-type="([^"]+)"[^>]*data-vertical-id="([^"]+)"[^>]*x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)"', p.read_text(encoding="utf-8")):
        out.append((m.group(2), m.group(1), [float(m.group(i)) for i in (3, 4, 5, 6)]))
    return out


GROUPS = {
    "Главный лифт": [("U-CENTRAL-CORE", "lift"), ("L-CENTRAL-CORE", "lift"), ("T-EAST-VERTICAL", "shahta")],
    "Главная лестница": [("U-CENTRAL-CORE", "glavnaya-lestnica"), ("L-CENTRAL-CORE", "glavnaya-lestnica")],
    "Лестница маршрута А": [("U-ROUTE-A", None), ("L-ARCHIVE-A", None)],
    "Восточная лестница": [("U-EAST-SUPPORT", "avariynaya-lestnica"), ("L-EAST-STAIR", "avariynaya-lestnica"), ("T-EAST-VERTICAL", "vostochnaya")],
    "Старая лестница": [("L-OLD-CORE", "staraya-lestnica"), ("T-OLD-ACCESS", "staraya-lestnica")],
    "Лестница служебной развязки": [("L-SERVICE-INTERCHANGE", "lestnica"), ("T-UTILITIES", "lestnica")],
    "Грузовой лифт": [("U-FREIGHT", "gruzovoy-lift"), ("L-FREIGHT-SERVICE", "gruzovoy-lift"), ("T-FREIGHT", "gruzovoy-lift")],
}
if __name__ == "__main__":
    for name, items in GROUPS.items():
        print("==", name)
        for sector, slug in items:
            if slug:
                rect, lv = room(sector, slug)
                print(f"   {sector:24s} комната {slug:22s} {rect}")
            r = json.loads((DATA / (sector.lower() + ".json")).read_text(encoding="utf-8"))
            for vid, kind, rc in cuts(sector, r["level"]):
                print(f"   {sector:24s}   проём {kind:16s} {vid:18s} {rc}")
