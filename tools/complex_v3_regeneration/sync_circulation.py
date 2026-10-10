"""Give every circulation sector (U-/L-/T-CIRCULATION) the same openings that its neighbours have on its walls.

The corridors and heavy trunks belong to their own sector; every door or opening a neighbour draws on a wall shared
with a trunk must exist on both sides, otherwise the trunk's solid wall closes the doorway.
Run: python tools/complex_v3_regeneration/sync_circulation.py  (then build_canonical_from_approved.py).
"""
import xml.etree.ElementTree as ET
import _shift as S
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "docs/design/complex_v4/plans/generation"
FOLDER = {"U": "upper", "L": "lower", "T": "technical"}
CIRC = {"U-CIRCULATION": "U", "L-CIRCULATION": "L", "T-CIRCULATION": "T"}
TOL = 0.3


def svg_lines(sector, level):
    path = GEN / FOLDER[level] / (sector.lower().replace("-", "_") + ".svg")
    out = []
    for el in ET.parse(path).getroot().iter():
        if el.tag.endswith("line") and el.get("data-godot-type") in ("door", "opening"):
            out.append({"kind": el.get("data-godot-type"), "type": el.get("data-door-type"), "height": el.get("data-door-height"),
                        "p": [float(el.get(k)) for k in ("x1", "y1", "x2", "y2")]})
    return out


def main():
    reg, nl = S.load()
    for cid, level in CIRC.items():
        entry = reg["sectors"][cid]
        keep = [a for a in entry["amendments"] if not str(a["id"]).startswith("AUTO")]
        rooms = [a["rect_m"] for a in keep if a["op"] == "room_add"]
        edges = []
        for x, z, w, h in rooms:
            edges += [("h", z, x, x + w), ("h", z + h, x, x + w), ("v", x, z, z + h), ("v", x + w, z, z + h)]
        found, n = set(), 0
        for sid, e in reg["sectors"].items():
            if sid in CIRC or e["level"] != level:
                continue
            for ln in svg_lines(sid, level):
                x1, y1, x2, y2 = ln["p"]
                for orient, fixed, lo, hi in edges:
                    if orient == "h" and abs(y1 - fixed) < TOL and abs(y2 - fixed) < TOL:
                        a, b = sorted((x1, x2))
                        ok = a >= lo - 0.1 and b <= hi + 0.1
                        at = [round(max(a, lo), 3), fixed, round(min(b, hi), 3), fixed]
                    elif orient == "v" and abs(x1 - fixed) < TOL and abs(x2 - fixed) < TOL:
                        a, b = sorted((y1, y2))
                        ok = a >= lo - 0.1 and b <= hi + 0.1
                        at = [fixed, round(max(a, lo), 3), fixed, round(min(b, hi), 3)]
                    else:
                        continue
                    key = tuple(at)
                    if ok and key not in found and (at[2] - at[0]) + (at[3] - at[1]) > 0.5:
                        found.add(key)
                        n += 1
                        am = {"id": f"AUTO-{n:02d}", "op": "door_add", "at_m": at, "kind": ln["kind"], "force": False}
                        if ln["kind"] == "door":
                            am["height_m"] = float(ln["height"] or 2.8)
                        if ln["type"]:
                            am["type"] = ln["type"]
                        keep.append(am)
        entry["amendments"] = keep
        print(f"{cid}: {n} matching openings")
    S.save(reg, nl)


if __name__ == "__main__":
    main()
