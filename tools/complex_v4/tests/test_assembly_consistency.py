"""Cross-sector consistency of the generated complex: stairs against doors and shafts, floor heights, slab thickness.

These checks guard against errors that every single sector can pass on its own: a stair that stops metres short of its
entry door, an entry door drawn on the wrong flight, or a slab that is too thin under a tall hall.
"""
import sys
import unittest
import warnings
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_floor_heights as heights  # noqa: E402
import check_stair_fit as stair_fit  # noqa: E402
import vertical_resolver as resolver  # noqa: E402

MAX_DOOR_GAP_M = 0.4


class StairFitTests(unittest.TestCase):
    def test_every_stair_meets_its_entry_and_exit_doors(self) -> None:
        rows, _ = stair_fit.check(MAX_DOOR_GAP_M)
        self.assertGreaterEqual(len(rows), 6)
        problems = [f"{row['vertical']} {gap['role']} {gap.get('sector')}: {gap.get('door_distance_m', gap.get('error'))} m"
                    for row in rows for gap in row["gaps"] if gap.get("error") or gap["door_distance_m"] > MAX_DOOR_GAP_M]
        self.assertEqual(problems, [], "stair is further than %.1f m from its door" % MAX_DOOR_GAP_M)

    def test_u_turn_landing_fills_the_shaft(self) -> None:
        fit = resolver.u_turn_fit((0.0, 0.0, 6.4, 11.9), "south", 6.0, 1.8, ["--target-riser", "0.15", "--max-riser", "0.15", "--target-tread", "0.3", "--flight-gap", "0.7"], 0.01)
        self.assertAlmostEqual(fit["flight_run"] + fit["landing_depth"], 11.9, places=2)
        self.assertAlmostEqual(fit["entry_center"], 3.2 + 1.25, places=3)
        self.assertAlmostEqual(fit["exit_center"], 3.2 - 1.25, places=3)

    def test_u_turn_rejects_a_shaft_that_is_too_short_or_narrow(self) -> None:
        arguments = ["--target-riser", "0.15", "--max-riser", "0.15", "--target-tread", "0.25"]
        with self.assertRaises(resolver.VerticalError):
            resolver.u_turn_fit((0.0, 0.0, 6.0, 5.5), "north", 6.0, 1.8, arguments, 0.01)
        with self.assertRaises(resolver.VerticalError):
            resolver.u_turn_fit((0.0, 0.0, 3.0, 9.0), "north", 6.0, 1.8, arguments, 0.01)


class HeightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sectors = heights.load()

    def test_slab_between_floors_is_at_least_one_metre(self) -> None:
        self.assertEqual(heights.slab_errors(self.sectors), [])

    def test_every_floor_has_its_policy_height(self) -> None:
        self.assertEqual(heights.uniform_height_errors(self.sectors), [])

    def test_every_canonical_sector_has_a_wall_height(self) -> None:
        self.assertEqual(len(self.sectors), 32)
        for sector_id, sector in self.sectors.items():
            self.assertGreater(sector["wall_height_m"], 2.2, sector_id)

    def test_height_differences_inside_a_floor_are_reported(self) -> None:
        for line in heights.height_warnings(self.sectors):
            warnings.warn(line, stacklevel=1)


class StairPackageTests(unittest.TestCase):
    """Generated stair packages: continuous flights, a landing that spans the shaft, shaft walls that overlap the lower ceiling."""

    @classmethod
    def setUpClass(cls) -> None:
        import json
        root = Path(__file__).resolve().parents[3]
        cls.manifest = json.loads((root / "tools/complex_v4/sector_generation_manifest.json").read_text(encoding="utf-8"))
        cls.sectors = {item["sector_id"]: item for item in cls.manifest["sectors"]}
        cls.root = root
        cls.reports = []
        for sector in cls.manifest["sectors"]:
            for generator in sector.get("vertical_generators", []):
                path = root / sector["output_resource_dir"].removeprefix("res://") / "Generated/Stairs" / generator["generator_id"] / "generation_report.json"
                cls.reports.append((sector["sector_id"], generator, json.loads(path.read_text(encoding="utf-8"))))

    @staticmethod
    def wall_height(sector: dict) -> float:
        arguments = sector["shared_args"]
        return float(arguments[arguments.index("--wall-height") + 1])

    def test_manifest_wall_height_is_the_height_drawn_in_the_plan(self) -> None:
        import re
        for sector_id, sector in self.sectors.items():
            text = (self.root / sector["source_svg"]).read_text(encoding="utf-8")
            drawn = {float(v) for v in re.findall(r'data-wall-height="([0-9.]+)"', text)}
            self.assertEqual(drawn, {self.wall_height(sector)}, sector_id)

    def test_shaft_walls_overlap_the_lower_walls_and_reach_the_upper_floor(self) -> None:
        self.assertGreaterEqual(len(self.reports), 6)
        for sector_id, generator, report in self.reports:
            lower = self.sectors[generator["levels"]["lower"]["sector_id"]]
            settings = report["settings"]
            self.assertAlmostEqual(settings["shaft_wall_bottom"], self.wall_height(lower), places=2, msg=f"{generator['vertical_id']}: shaft wall must start where the lower walls end")
            self.assertAlmostEqual(settings["shaft_wall_top"], settings["floor_height"], places=2, msg=generator["vertical_id"])

    def test_flights_are_continuous_and_the_landing_spans_the_shaft(self) -> None:
        for sector_id, generator, report in self.reports:
            layout, settings = report["selected_layout"], report["settings"]
            label = generator["vertical_id"]
            flights = layout["flights"]
            self.assertEqual(len(flights), 2, label)
            self.assertAlmostEqual(flights[0]["top_y"], flights[1]["base_y"], places=3, msg=f"{label}: the second flight starts at the landing level")
            self.assertAlmostEqual(flights[1]["top_y"], settings["floor_height"], places=3, msg=label)
            length = settings["shaft_length"] if layout["lower_entry_side"] in ("north", "south") else settings["shaft_width"]
            self.assertAlmostEqual(max(f["run"] for f in flights) + settings["landing_depth"], length, delta=0.01, msg=f"{label}: flights and landing must fill the shaft")


if __name__ == "__main__":
    unittest.main()
