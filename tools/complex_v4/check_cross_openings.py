"""Report openings drawn in one sector whose wall continues in a neighbouring sector without a matching opening.

A wall shared by two sectors is drawn only by its owner (#205, ``shared_faces`` in the extraction reports): the
neighbour has no wall there, so the owner's opening opens it from both sides. Every opening the neighbour left to
the owner must have a matching owner opening."""
import json, glob
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
TOL = 0.3


def load():
    data = {}
    for p in glob.glob(str(ROOT / "docs/design/complex_v4/review/data/*.json")):
        r = json.loads(Path(p).read_text(encoding="utf-8"))
        data[r["sector_id"]] = r
    return data


def edges(rooms):
    out = []
    for m in rooms:
        x, z, w, h = m["world_m"]
        out += [("h", z, x, x + w), ("h", z + h, x, x + w), ("v", x, z, z + h), ("v", x + w, z, z + h)]
    return out


def owner_spans(report, owner):
    """Wall spans this sector left to ``owner``: (orient, fixed, lo, hi)."""
    faces = report.get("shared_faces", {})
    out = []
    for w in faces.get("dropped_walls", []) + faces.get("trimmed_walls", []):
        if owner not in w["owner"]:
            continue
        a, b, c, d = w["world_m"]
        horiz = abs(b - d) < 1e-6
        fixed, lo, hi = (b, min(a, c), max(a, c)) if horiz else (a, min(b, d), max(b, d))
        kept = w.get("pieces_m", [])
        cuts = [[lo, hi]]
        for k_lo, k_hi in kept:
            cuts = [part for c_lo, c_hi in cuts for part in ([c_lo, min(c_hi, k_lo)], [max(c_lo, k_hi), c_hi]) if part[1] - part[0] > 1e-6]
        out += [("h" if horiz else "v", fixed, c_lo, c_hi) for c_lo, c_hi in cuts]
    return out


def find_missing(data):
    missing = []
    for sid, r in data.items():
        for o in r.get("shared_faces", {}).get("dropped_openings", []):
            if not o.get("owner_opening"):
                missing.append((sid, o["owner"], o["type"], "-", o["world_m"]))
    for sid, r in data.items():
        for o in r["openings"]:
            if o["type"] == "window":
                continue
            a, b, c, d = o["world_m"]
            horiz = abs(b - d) < 1e-6
            fixed = b if horiz else a
            lo, hi = sorted((a, c) if horiz else (b, d))
            for oid, r2 in data.items():
                if oid == sid or r2["level"] != r["level"]:
                    continue
                cover = [e for e in edges(r2["rooms"]) if e[0] == ("h" if horiz else "v") and abs(e[1] - fixed) < TOL and e[2] <= lo + 0.2 and e[3] >= hi - 0.2]
                if not cover:
                    continue
                if any(e[0] == ("h" if horiz else "v") and abs(e[1] - fixed) < TOL and e[2] <= lo + 0.2 and e[3] >= hi - 0.2 for e in owner_spans(r2, sid)):
                    continue        # the neighbour left this wall to this sector: one wall, one opening
                matched = any(abs((q["world_m"][1] if horiz else q["world_m"][0]) - fixed) < TOL and
                              min(q["world_m"][0::2] if horiz else q["world_m"][1::2]) <= lo + 0.3 and
                              max(q["world_m"][0::2] if horiz else q["world_m"][1::2]) >= hi - 0.3 and q["type"] != "window"
                              for q in r2["openings"])
                if not matched:
                    missing.append((sid, oid, o["type"], o["width_m"], [round(v, 2) for v in o["world_m"]]))
    return missing


def main():
    missing = find_missing(load())
    for m in missing:
        print(f"{m[0]:22s} открытие {m[2]} {m[3]} м {m[4]} — у {m[1]} на этой стене проёма нет")
    print("итого:", len(missing))
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
