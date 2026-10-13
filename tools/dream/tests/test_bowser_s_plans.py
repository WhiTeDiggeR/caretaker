"""Format checks of the Bowser dream S plans (#191) that do not need the svg-plan-to-godot generator."""
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bowser_s_plans as plans  # noqa: E402


def _check_text(text: str) -> list[str]:
    errors: list[str] = []
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "plan.svg"
        path.write_text(text, encoding="utf-8")
        plans.check_plan(path, errors, set(), set())
    return errors


class BowserSPlansTests(unittest.TestCase):
    def test_committed_plans_pass_and_match_the_specification(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output):
            code = plans.check()
        self.assertEqual(code, 0, output.getvalue())
        self.assertIn("warnings=0 errors=0", output.getvalue())

    def test_every_blockout_hook_has_an_anchor(self) -> None:
        hooks = {marker.hook for plan in plans.PLANS for marker in plan.markers}
        for hook in ("SealHall/Seal", "SealHall/SealSlot", "SealHall/SideDoor", "Yard/Ambush/WakeLine",
                     "Yard/Ambush/GuardSpawnNorth", "Yard/Ambush/GuardSpawnSouth", "Yard/Ambush/HallThreshold",
                     "Yard/Remains", "Yard/Remains/WeaponSpot", "Terrace/SilhouetteSpot", "Spawn", "Bastion/Gate"):
            self.assertIn(hook, hooks)

    def test_door_off_its_wall_is_rejected(self) -> None:
        text = plans.render(plans.PLANS[1]).replace('x1="45.5" y1="-2" x2="45.5" y2="2"', 'x1="44" y1="-2" x2="44" y2="2"', 1)
        self.assertTrue(any("must lie on exactly one wall" in error for error in _check_text(text)))

    def test_marker_outside_floors_is_rejected(self) -> None:
        text = plans.render(plans.PLANS[1]).replace('cx="80" cy="-25"', 'cx="100" cy="-40"', 1)
        self.assertTrue(any("neither on a floor" in error for error in _check_text(text)))

    def test_floor_without_space_id_is_rejected(self) -> None:
        text = plans.render(plans.PLANS[0]).replace('data-space-id="DREAM-S/terrace" ', "", 1)
        self.assertTrue(any("has no data-space-id" in error for error in _check_text(text)))


if __name__ == "__main__":
    unittest.main()
