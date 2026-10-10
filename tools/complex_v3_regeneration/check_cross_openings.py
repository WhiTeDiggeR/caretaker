"""Report openings drawn in one sector whose wall continues in a neighbouring sector without a matching opening."""
import json, glob
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
TOL = 0.3


def load():
    data = {}
    for p in glob.glob(str(ROOT / "docs/design/complex_v4/review/data/*.json")):
        r = json.load(open(p, encoding="utf-8"))
        data[r["sector_id"]] = r
    return data


def edges(rooms):
    out = []
    for m in rooms:
        x, z, w, h = m["world_m"]
        out += [("h", z, x, x + w), ("h", z + h, x, x + w), ("v", x, z, z + h), ("v", x + w, z, z + h)]
    return out


def main():
    data = load()
    missing = []
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
                matched = any(abs((q["world_m"][1] if horiz else q["world_m"][0]) - fixed) < TOL and
                              min(q["world_m"][0::2] if horiz else q["world_m"][1::2]) <= lo + 0.3 and
                              max(q["world_m"][0::2] if horiz else q["world_m"][1::2]) >= hi - 0.3 and q["type"] != "window"
                              for q in r2["openings"])
                if not matched:
                    missing.append((sid, oid, o["type"], o["width_m"], [round(v, 2) for v in o["world_m"]]))
    for m in missing:
        print(f"{m[0]:22s} открытие {m[2]} {m[3]} м {m[4]} — у {m[1]} на этой стене проёма нет")
    print("итого:", len(missing))


if __name__ == "__main__":
    main()
