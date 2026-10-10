"""Lift shafts are cuts in floors and ceilings marked in the plans; the validator reports gaps."""
import tempfile
import unittest
from pathlib import Path

from tools.complex_v3_regeneration import validate_verticals as validator

RECT = (-6.72, -0.07, -2.28, 4.82)
LEVELS = {"LV-U": 0.0, "LV-L": -6.0, "LV-T": -11.5}


def shaft(kind: str, rect: tuple = RECT, vertical_id: str = "VT-LIFT", element_id: str = "s") -> str:
    x0, z0, x1, z1 = rect
    return (
        f'<rect id="{element_id}" data-godot-type="{kind}" data-vertical-id="{vertical_id}" data-vertical-role="shaft" '
        f'x="{x0}" y="{z0}" width="{round(x1 - x0, 6)}" height="{round(z1 - z0, 6)}"/>'
    )


class ValidateLiftTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.manifest = {"sectors": [
            {"sector_id": "A", "level": "LV-U", "source_svg": "a.svg"},
            {"sector_id": "B", "level": "LV-L", "source_svg": "b.svg"},
            {"sector_id": "C", "level": "LV-T", "source_svg": "c.svg"},
        ]}
        self.transitions = {
            "level_datums": LEVELS,
            "transitions": [
                {"id": "VT-LIFT", "kind": "passenger_elevator", "stops": ["LV-U", "LV-L"], "pass_through": ["LV-T"], "clear_opening_bounds_xz": list(RECT)},
                {"id": "VT-STAIR", "kind": "main_stair", "connects": ["LV-U", "LV-L"]},
            ],
        }
        self.handoff = {"spaces": [{"id": "C/room", "bounds_xz": [-7, -1, -2, 5], "floor_y": -11.5}]}
        self.write("a", shaft("floor-opening"))
        self.write("b", shaft("floor-opening", element_id="f") + shaft("ceiling-opening", element_id="c"))
        self.write("c", shaft("ceiling-opening"))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, name: str, body: str) -> None:
        (self.root / f"{name}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg">{body}</svg>', encoding="utf-8")

    def run_check(self) -> list:
        return validator.validate_lifts(self.manifest, self.transitions, self.handoff, self.root)

    def test_complete_markup_is_clean_and_stairs_are_ignored(self) -> None:
        self.assertEqual(self.run_check(), [])

    def test_missing_cuts_are_listed_per_level_with_candidate_rooms(self) -> None:
        self.write("c", "")
        diagnostics = self.run_check()
        self.assertEqual(len(diagnostics), 1)
        self.assertIn("VT-LIFT LV-T: no ceiling-opening marked", diagnostics[0])
        self.assertIn("C/room", diagnostics[0])

    def test_top_level_needs_only_a_floor_cut_and_bottom_only_a_ceiling_cut(self) -> None:
        self.write("a", shaft("floor-opening") + shaft("ceiling-opening", element_id="extra"))
        self.write("c", shaft("ceiling-opening") + shaft("floor-opening", element_id="extra"))
        diagnostics = self.run_check()
        self.assertEqual(len(diagnostics), 2)
        self.assertTrue(all("unexpected" in line for line in diagnostics))

    def test_footprints_must_match_between_levels_and_the_canonical_opening(self) -> None:
        self.write("b", shaft("floor-opening", (-6.0, -0.07, -2.28, 4.82), element_id="f") + shaft("ceiling-opening", element_id="c"))
        self.assertTrue(any("differs from" in line for line in self.run_check()))
        shifted = (-3.7, 1.0, 0.7, 5.9)
        for name, kinds in (("a", ["floor-opening"]), ("b", ["floor-opening", "ceiling-opening"]), ("c", ["ceiling-opening"])):
            self.write(name, "".join(shaft(kind, shifted, element_id=f"{kind}") for kind in kinds))
        self.assertTrue(any("canonical clear opening" in line for line in self.run_check()))

    def test_duplicate_cut_on_one_level_is_reported(self) -> None:
        self.write("a", shaft("floor-opening") + shaft("floor-opening", element_id="second"))
        self.assertTrue(any("2 floor-opening elements" in line for line in self.run_check()))

    def test_cli_exit_code_reflects_the_report(self) -> None:
        self.assertEqual(validator.main(["--project-root", str(self.root), "--manifest", str(self.write_json("manifest", self.manifest)),
                                         "--transitions", str(self.write_json("transitions", self.transitions)),
                                         "--handoff", str(self.write_json("handoff", self.handoff))]), 0)

    def write_json(self, name: str, value: dict) -> Path:
        import json
        path = self.root / f"{name}.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path


if __name__ == "__main__":
    unittest.main()
