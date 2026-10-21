"""Shaft closures do not run into each other: the exit threshold of a stair stays out of the shaft lining (#243)."""
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import vertical_closures as closures  # noqa: E402

ROOT = HERE.parents[2]
# surface_conflict_check.gd reports a crossing deeper than 0.01 m; any overlap of solid boxes is a defect here
TOUCH_M = 1e-6


def penetration(a: closures.Box, b: closures.Box) -> float:
    """Smallest overlap of two boxes over the three axes (<= 0 when they only touch or are apart)."""
    return min(min(a.center[i] + a.size[i] / 2, b.center[i] + b.size[i] / 2) - max(a.center[i] - a.size[i] / 2, b.center[i] - b.size[i] / 2)
               for i in range(3))


def shaft(exit_side: str, exit_point: tuple[float, float, float]) -> tuple[list[closures.Box], closures.Box]:
    rect, elevation = (10.0, 20.0, 14.0, 28.0), 0.0
    side = {"north": "N", "south": "S", "west": "W", "east": "E"}[exit_side]
    linings = closures.lining_boxes(rect, -6.0, elevation, "Lining", frozenset({side}),
                                    elevation - closures.FLOOR_THICKNESS_M + 2 * closures.Z_FIGHT_OFFSET_M)
    threshold = closures.threshold_box(rect, exit_side, exit_point, elevation, "Threshold")
    assert threshold is not None
    return linings, threshold


class ThresholdLiningTests(unittest.TestCase):
    EXITS = {"north": (12.0, 0.0, 20.3), "south": (12.0, 0.0, 27.7), "west": (10.3, 0.0, 24.0), "east": (13.7, 0.0, 24.0)}

    def test_threshold_does_not_enter_the_lining_on_any_exit_side(self) -> None:
        for exit_side, point in self.EXITS.items():
            linings, threshold = shaft(exit_side, point)
            for lining in linings:
                self.assertLessEqual(penetration(lining, threshold), TOUCH_M, f"{exit_side}: {lining.name}")

    def test_threshold_still_reaches_both_side_linings(self) -> None:
        # no slit between the threshold and the side linings: their faces touch
        for exit_side, point in self.EXITS.items():
            linings, threshold = shaft(exit_side, point)
            across = 0 if exit_side in ("north", "south") else 2
            touching = [b for b in linings if abs(penetration(b, threshold)) <= TOUCH_M
                        and abs(b.center[across] - threshold.center[across]) > threshold.size[across] / 2]
            self.assertEqual(len(touching), 2, exit_side)


class GeneratedShaftTests(unittest.TestCase):
    """The thresholds of the committed stairs, rebuilt with the current rule, against their committed linings."""

    def test_rebuilt_thresholds_stay_out_of_the_committed_linings(self) -> None:
        manifest = json.loads((ROOT / "tools/complex_v4/sector_generation_manifest.json").read_text(encoding="utf-8"))
        checked = 0
        for sector in manifest["sectors"]:
            report = json.loads((ROOT / sector["output_resource_dir"].removeprefix("res://") / "regeneration_report.json").read_text(encoding="utf-8"))
            boxes = [closures.Box(c["name"], c["kind"], tuple(c["center"]), tuple(c["size"])) for c in report.get("vertical_closures", [])]
            elevation = float(sector["metric_settings"]["elevation_m"])
            for opening in closures.openings(ROOT / sector["source_svg"], "floor-opening"):
                old = next((b for b in boxes if b.kind == "threshold" and b.name.endswith(opening["vertical_id"])), None)
                if old is None:
                    continue
                x0, z0, x1, z1 = opening["rect"]
                lo_x, hi_x = old.center[0] - old.size[0] / 2, old.center[0] + old.size[0] / 2
                lo_z, hi_z = old.center[2] - old.size[2] / 2, old.center[2] + old.size[2] / 2
                # the exit side is the opening edge the strip lies on; its far edge is where the flight ends
                if old.size[2] < old.size[0]:
                    side, point = ("north", (0.0, 0.0, hi_z)) if abs(lo_z - z0) < abs(hi_z - z1) else ("south", (0.0, 0.0, lo_z))
                else:
                    side, point = ("west", (hi_x, 0.0, 0.0)) if abs(lo_x - x0) < abs(hi_x - x1) else ("east", (lo_x, 0.0, 0.0))
                rebuilt = closures.threshold_box(opening["rect"], side, point, elevation, old.name)
                self.assertIsNotNone(rebuilt, old.name)
                for lining in (b for b in boxes if b.kind == "lining" and opening["vertical_id"] in b.name):
                    self.assertLessEqual(penetration(lining, rebuilt), TOUCH_M, f"{sector['sector_id']}: {lining.name}")
                checked += 1
        self.assertGreaterEqual(checked, 6)


if __name__ == "__main__":
    unittest.main()
