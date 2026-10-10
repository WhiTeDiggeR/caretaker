"""Height consistency of the canonical sectors.

Hard rule (D-43): the slab between two floors is at least 1.0 m thick, i.e. level spacing minus the highest wall of the lower
floor stays >= MIN_SLAB_M.
Hard rule (D-46): every sector of a floor has the floor wall height (U/L 5.0 m, T 4.5 m).
Warning: sectors of one floor have different wall heights (the height is a per-sector setting, so rooms of equal purpose next to
each other can end up with ceilings of different height). Neighbouring sectors that touch each other with different heights are listed.
"""
import json
import sys
from itertools import combinations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "docs/design/complex_v4/review/data"
ELEVATION = {"LV-U": 0.0, "LV-L": -6.0, "LV-T": -11.5}
ORDER = ["LV-U", "LV-L", "LV-T"]
MIN_SLAB_M = 1.0
FLOOR_HEIGHT_M = {"LV-U": 5.0, "LV-L": 5.0, "LV-T": 4.5}  # D-46: one wall height per floor
TOUCH_M = 0.05


def load() -> dict[str, dict]:
    return {p.stem.upper(): json.loads(p.read_text(encoding="utf-8")) for p in sorted(DATA.glob("*.json"))}


def slab_errors(sectors: dict[str, dict]) -> list[str]:
    errors = []
    for upper, lower in zip(ORDER, ORDER[1:]):
        tallest = max((s["wall_height_m"] for s in sectors.values() if s["level"] == lower), default=0.0)
        slab = ELEVATION[upper] - ELEVATION[lower] - tallest
        if slab < MIN_SLAB_M - 1e-9:
            errors.append(f"slab between {upper} and {lower} is {slab:.2f} m (< {MIN_SLAB_M} m): tallest wall of {lower} is {tallest} m")
    return errors


def uniform_height_errors(sectors: dict[str, dict]) -> list[str]:
    return [f"{sid}: wall height {s['wall_height_m']} m, the policy for {s['level']} is {FLOOR_HEIGHT_M[s['level']]} m"
            for sid, s in sectors.items() if abs(s["wall_height_m"] - FLOOR_HEIGHT_M[s["level"]]) > 1e-9]


def _touch(a: list[float], b: list[float]) -> bool:
    ax, az, aw, ah = a
    bx, bz, bw, bh = b
    overlap_x = min(ax + aw, bx + bw) - max(ax, bx)
    overlap_z = min(az + ah, bz + bh) - max(az, bz)
    return (overlap_x > TOUCH_M and overlap_z >= -TOUCH_M and abs(overlap_z) <= TOUCH_M + 1e-9) or \
           (overlap_z > TOUCH_M and overlap_x >= -TOUCH_M and abs(overlap_x) <= TOUCH_M + 1e-9)


def height_warnings(sectors: dict[str, dict]) -> list[str]:
    warnings = []
    for level in ORDER:
        group = {sid: s for sid, s in sectors.items() if s["level"] == level}
        heights = sorted({s["wall_height_m"] for s in group.values()})
        if len(heights) > 1:
            by = ", ".join(f"{h} m: {sum(1 for s in group.values() if s['wall_height_m'] == h)}" for h in heights)
            warnings.append(f"{level}: {len(heights)} different wall heights ({by})")
        for (a_id, a), (b_id, b) in combinations(group.items(), 2):
            if a["wall_height_m"] == b["wall_height_m"]:
                continue
            if any(_touch(ra["world_m"], rb["world_m"]) for ra in a["rooms"] for rb in b["rooms"]):
                warnings.append(f"{level}: {a_id} ({a['wall_height_m']} m) touches {b_id} ({b['wall_height_m']} m)")
    return warnings


def main() -> int:
    sectors = load()
    errors = slab_errors(sectors) + uniform_height_errors(sectors)
    warnings = height_warnings(sectors)
    for line in errors:
        print("ERROR  ", line)
    for line in warnings:
        print("WARNING", line)
    print(f"sectors={len(sectors)} errors={len(errors)} warnings={len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
