"""Format checks of the Bowser dream S plans (#191) that do not need the svg-plan-to-godot generator."""
import io
import json
import sys
import xml.etree.ElementTree as ET
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

    def test_complex_v4_plans_satisfy_the_shared_format_rules(self) -> None:
        manifest = json.loads(plans.PRODUCTION_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["sectors"]), 32)
        for sector in manifest["sectors"]:
            root = ET.parse(plans.ROOT / sector["source_svg"]).getroot()
            errors, _ = plans.format_errors(root, sector["sector_id"], sector["metric_settings"]["elevation_m"],
                                            "--strict-ceiling-alignment" in sector["shared_args"])
            self.assertEqual(errors, [], sector["sector_id"])

    def test_converter_settings_match_the_complex_strict_settings(self) -> None:
        self.assertEqual(plans.SHARED_ARGS, plans.production_shared_args())
        self.assertIn("--strict-ceiling-alignment", plans.SHARED_ARGS)

    def test_floor_edge_off_the_wall_axis_is_rejected(self) -> None:
        text = plans.render(plans.PLANS[1]).replace('x="45.5" y="-9.5" width="24.5"', 'x="46" y="-9.5" width="24"', 1)
        self.assertTrue(any("off the centre line of wall" in error for error in _check_text(text)))

    def test_ceiling_below_the_wall_tops_is_rejected(self) -> None:
        text = plans.render(plans.PLANS[1]).replace('data-ceiling-elevation="13.2"', 'data-ceiling-elevation="12"', 1)
        self.assertTrue(any("does not meet the top of wall" in error for error in _check_text(text)))

    def test_unknown_type_and_vertical_markup_are_rejected(self) -> None:
        text = plans.render(plans.PLANS[0]).replace('data-godot-type="wall"', 'data-godot-type="railing"', 1)
        self.assertTrue(any("unknown data-godot-type" in error for error in _check_text(text)))
        text = plans.render(plans.PLANS[0]).replace('data-godot-type="wall"', 'data-godot-type="wall" data-vertical-id="VT-X"', 1)
        self.assertTrue(any("data-vertical-*" in error for error in _check_text(text)))

    def test_marker_id_must_follow_its_anchor(self) -> None:
        text = plans.render(plans.PLANS[1]).replace('id="bowser-s-high-marker-gate"', 'id="bowser-s-high-marker-01"', 1)
        self.assertTrue(any("does not follow its anchor" in error for error in _check_text(text)))

    def test_generation_reports_are_verified(self) -> None:
        plan = plans.PLANS[1]
        sid = "bowser-s-high"
        handoff = {"anchor_frames": [{"anchor_id": f"svg:{sid}-marker-{m.key}:point", "type": "point", "role": "gameplay_hook"}
                                     for m in plan.markers], "anchor_frame_issues": []}
        counts = {"input_floor": 6, "input_wall": 22, "input_door": 5, "input_ceiling": 1, "input_marker": 10,
                  "ceiling_openings_requested": 1, "ceiling_openings_applied": 1, "ceiling_polygons_before_normalization": 1,
                  "ceiling_wall_alignment_issues": 0, "wall_volume_overlaps": 0}
        conversion = {"generator_version": "1.19.0", "errors": [], "counts": counts, "spatial_handoff": handoff}
        preflight = {"summary": {"unrecognized": 0, "invalid": 0}, "spatial_handoff": handoff}
        self.assertEqual(plans.verify_generation(plan, preflight, conversion), [])
        invented = dict(conversion, counts=dict(counts, ceiling_polygons_before_normalization=7))
        self.assertTrue(any("ceiling polygons" in error for error in plans.verify_generation(plan, preflight, invented)))
        lost = {"anchor_frames": handoff["anchor_frames"][1:], "anchor_frame_issues": []}
        errors = plans.verify_generation(plan, dict(preflight, spatial_handoff=lost), dict(conversion, spatial_handoff=lost, generator_version="1.18.2"))
        self.assertTrue(any("is missing" in error for error in errors))
        self.assertTrue(any("older than 1.19.0" in error for error in errors))

    def test_collision_winding_reuses_the_complex_backend(self) -> None:
        scene = '[sub_resource type="ConcavePolygonShape3D" id="ConcaveFloor_a"]\ndata = PackedVector3Array(0, 0, 0, 0, 0, 1, 1, 0, 0)\n'
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "scene.tscn"
            path.write_text(scene, encoding="utf-8")
            plans._normalize_collision_winding(path)
            self.assertIn("PackedVector3Array(0, 0, 0, 1, 0, 0, 0, 0, 1)", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
