"""Authored bindings survive regeneration and lost ones are reported (#224).

The predicted anchor frames must equal the converter's real frames for every sector whose package is built from its
current SVG; the bindings of the placed sectors must resolve; a renamed element or a room that no longer holds an object
must be reported by object and anchor ID; once the package is regenerated the same bindings resolve from it.
"""
from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("check_bindings_224", ROOT / "tools/complex_v4/check_bindings.py")
assert SPEC and SPEC.loader
CHECK = importlib.util.module_from_spec(SPEC)
sys.modules["check_bindings_224"] = CHECK
SPEC.loader.exec_module(CHECK)

PILOT = "U-EMERGENCY"
CAPSULE_HALL = "u-emergency--kapsulnyy-zal-avariynogo-blo"
AIRLOCK_DOOR = "u-emergency--germotambur--door--kapsulnyy-zal-avariynogo-blo"
FRAME_KEYS = ("type", "role", "status", "forward", "normal", "up", "placement_limits")


def sectors() -> list[dict]:
    return CHECK.read_json(CHECK.MANIFEST)["sectors"]


def pilot() -> dict:
    return next(sector for sector in sectors() if sector["sector_id"] == PILOT)


class PredictedFramesTests(unittest.TestCase):
    def test_predicted_frames_equal_the_converter_output(self) -> None:
        compared = 0
        for sector in sectors():
            svg = ROOT / sector["source_svg"]
            package = CHECK.res_path(sector["output_resource_dir"])
            if CHECK.read_json(package / "generation_manifest.json")["source"]["sha256"] != CHECK.sha256_file(svg):
                continue  # waits for regeneration
            live = {frame["anchor_id"]: frame for frame in CHECK.read_json(package / "anchor_frames.json")["anchors"]
                    if frame["anchor_id"].startswith("svg:") and frame["type"] in ("wall", "door", "floor", "ceiling")}
            predicted = {frame["anchor_id"]: frame for frame in CHECK.predict_anchor_frames(svg.read_text(encoding="utf-8"), sector)["anchors"]}
            self.assertEqual(set(predicted), set(live), sector["sector_id"])
            for anchor_id, frame in live.items():
                guess = predicted[anchor_id]
                for key in FRAME_KEYS:
                    self.assertEqual(guess[key], frame[key], (anchor_id, key))
                for axis in range(3):
                    self.assertAlmostEqual(guess["origin"][axis], frame["origin"][axis], places=5, msg=anchor_id)
                # Holes of stair shafts come from the vertical closures, not from the plan element.
                self.assertEqual({k: v for k, v in guess["bounds"].items() if k != "holes_xz"},
                                 {k: v for k, v in frame["bounds"].items() if k != "holes_xz"}, anchor_id)
                compared += 1
        self.assertGreater(compared, 1000)


class BindingCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

    def _variant(self, svg_text: str, regenerated: bool = False) -> dict:
        """The pilot sector with another canonical SVG; `regenerated` builds its package from that SVG."""
        sector = copy.deepcopy(pilot())
        svg = Path(self.temp.name) / "plan.svg"
        svg.write_text(svg_text, encoding="utf-8")
        sector["source_svg"] = str(svg)
        if regenerated:
            package = Path(self.temp.name) / "package"
            package.mkdir()
            frames = CHECK.predict_anchor_frames(svg_text, sector)
            (package / "anchor_frames.json").write_text(json.dumps(frames), encoding="utf-8")
            (package / "generation_manifest.json").write_text(json.dumps({"source": {"sha256": CHECK.sha256_file(svg)}}), encoding="utf-8")
            sector["output_resource_dir"] = str(package)
        return sector

    def _svg(self) -> str:
        return (ROOT / pilot()["source_svg"]).read_text(encoding="utf-8")

    def test_every_sector_passes(self) -> None:
        self.assertEqual(CHECK.main([]), 0)

    def test_pilot_bindings_resolve(self) -> None:
        result = CHECK.check_sector(pilot())
        self.assertEqual(result["errors"], [])
        statuses = {entry["status"] for entry in result["bindings"]}
        self.assertLessEqual(statuses, {"ok", "pending"})
        self.assertGreaterEqual(len(result["bindings"]), 20)
        anchors = {entry["anchor_id"] for entry in result["bindings"]}
        self.assertIn(f"svg:{AIRLOCK_DOOR}:door:center", anchors)
        self.assertIn(f"svg:{CAPSULE_HALL}--floor:floor", anchors)

    def test_bindings_resolve_from_the_regenerated_package(self) -> None:
        result = CHECK.check_sector(self._variant(self._svg(), regenerated=True))
        self.assertEqual(result["errors"], [])
        self.assertEqual({entry["status"] for entry in result["bindings"]}, {"ok"})

    def test_renamed_element_is_reported_lost(self) -> None:
        svg = self._svg().replace(f'id="{AIRLOCK_DOOR}"', 'id="u-emergency--renamed-door"')
        for regenerated in (False, True):
            result = CHECK.check_sector(self._variant(svg, regenerated))
            lost = {entry["object_id"] for entry in result["bindings"] if entry["status"] == "lost"}
            self.assertEqual(lost, {"u-emergency/airlock-door-a"}, regenerated)

    def _resized_hall(self, width: float) -> str:
        hall = 'x="-107.778" y="-8.222" width="21.111" height="18.889"'
        self.assertGreaterEqual(self._svg().count(hall), 2)  # floor and ceiling of the capsule hall
        return self._svg().replace(hall, f'x="-107.778" y="-8.222" width="{width}" height="18.889"')

    def test_objects_keep_their_distance_to_the_nearer_wall(self) -> None:
        sector = self._variant(self._resized_hall(15.111), regenerated=True)
        frames = {frame["anchor_id"]: frame for frame in CHECK.predict_anchor_frames(Path(sector["source_svg"]).read_text(encoding="utf-8"), sector)["anchors"]}
        bindings = {item["object_ref"]["object_id"]: item for item in CHECK.read_json(ROOT / sector["safe_regeneration"]["bindings_input"])["bindings"]}
        east, west = (CHECK.RESOLVE.resolve_binding(bindings[item], frames[bindings[item]["anchor_ref"]["anchor_id"]])
                      for item in ("u-emergency/capsule-n10", "u-emergency/capsule-n01"))
        self.assertAlmostEqual(east["origin"][0], -89.7 - 6.0, places=3)  # follows the east wall 6 m west
        self.assertAlmostEqual(west["origin"][0], -105.9, places=3)  # stays at the west wall

    def test_object_that_no_longer_fits_is_reported(self) -> None:
        result = CHECK.check_sector(self._variant(self._resized_hall(2.5), regenerated=True))
        invalid = {entry["object_id"] for entry in result["bindings"] if entry["status"] == "invalid"}
        self.assertIn("u-emergency/capsule-n10", invalid)
        self.assertIn("u-emergency/lamp-n3", invalid)
        self.assertNotIn("u-emergency/airlock-door-a", invalid)

    def test_authored_scene_must_stand_where_its_bindings_put_it(self) -> None:
        sector = pilot()
        bindings = CHECK.read_json(ROOT / sector["safe_regeneration"]["bindings_input"])
        moved = copy.deepcopy(bindings)
        capsule = next(item for item in moved["bindings"] if item["object_ref"]["object_id"] == "u-emergency/capsule-n01")
        capsule["placement"]["surface"]["u"]["distance_m"] += 0.5
        path = Path(self.temp.name) / "bindings.json"
        path.write_text(json.dumps(moved), encoding="utf-8")
        variant = copy.deepcopy(sector)
        variant["safe_regeneration"] = dict(sector["safe_regeneration"], bindings_input=str(path))
        errors = CHECK.check_sector(variant)["errors"]
        self.assertTrue(any("capsule-n01: authored transform differs" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
