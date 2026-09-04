from __future__ import annotations

import importlib.util
import json
import os
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1]
PROJECT = TOOLS.parents[1]
PILOT = PROJECT / "scenes" / "complex_v3_regeneration" / "pilots" / "u_medbay"
MANIFEST = TOOLS / "pilots" / "u_medbay" / "pilot_generation_manifest.json"
VALIDATOR = TOOLS.parent / "complex_v3_composition_validator" / "validate_composition.py"
SPEC = importlib.util.spec_from_file_location("safe_regenerate_pilot", TOOLS / "safe_regenerate.py")
assert SPEC and SPEC.loader
SAFE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SAFE)


@unittest.skipUnless(os.environ.get("SVG_TOOL_ROOT"), "SVG_TOOL_ROOT is not configured")
class UMedbayPilotPipelineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix=".u-medbay-pilot-scenario-", dir=PROJECT)
        self.root = Path(self.temp.name)
        self.source = self.root / "source.svg"
        shutil.copy2(PILOT / "source" / "u_medbay_pilot.svg", self.source)
        authored = self.root / "AuthoredContent"
        authored.mkdir()
        shutil.copy2(PILOT / "AuthoredContent" / "composition.json", authored / "composition.json")
        shutil.copy2(PILOT / "AuthoredContent" / "object_bindings.json", authored / "object_bindings.json")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["project_root"] = ".."
        sector = manifest["sectors"][0]
        relative = self.root.name
        sector["source_svg"] = f"{relative}/source.svg"
        sector["output_resource_dir"] = f"res://{relative}/live"
        sector["safe_regeneration"] = {
            "composition_input": f"{relative}/AuthoredContent/composition.json",
            "bindings_input": f"{relative}/AuthoredContent/object_bindings.json",
        }
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        self.run_index = 0

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_safe(self) -> tuple[int, dict, dict | None]:
        self.run_index += 1
        report_path = self.root / f"safe-{self.run_index}.json"
        code = SAFE.main([
            "--sector", "U-MEDBAY", "--manifest", str(self.manifest),
            "--svg-tool-root", os.environ["SVG_TOOL_ROOT"],
            "--backend", str(TOOLS / "regenerate_sector.py"),
            "--composition-validator", str(VALIDATOR), "--python", os.environ.get("PYTHON_BIN", os.sys.executable),
            "--report", str(report_path),
        ])
        report = json.loads(report_path.read_text(encoding="utf-8"))
        composition = None
        artifact = report.get("validation_artifacts", {}).get("resolved_composition.json")
        if artifact:
            composition = json.loads(Path(artifact["path"]).read_text(encoding="utf-8"))
        return code, report, composition

    def edit_element(self, element_id: str, changes: dict[str, str] | None = None, *, remove: bool = False) -> None:
        tree = ET.parse(self.source)
        root = tree.getroot()
        target = next((item for item in root.iter() if item.get("id") == element_id), None)
        self.assertIsNotNone(target)
        if remove:
            parent = next(item for item in root.iter() if target in list(item))
            parent.remove(target)
        else:
            assert target is not None and changes is not None
            for key, value in changes.items():
                target.set(key, value)
        ET.register_namespace("", "http://www.w3.org/2000/svg")
        tree.write(self.source, encoding="utf-8", xml_declaration=False)

    @staticmethod
    def objects(document: dict) -> dict[str, dict]:
        return {item["object_id"]: item for item in document["objects"]}

    def assert_clean(self, code: int, report: dict, composition: dict | None) -> dict[str, dict]:
        self.assertEqual(code, 0, report)
        self.assertTrue(report["ready"])
        self.assertFalse(report["agent_invoked"])
        self.assertIsNotNone(composition)
        validation = json.loads(Path(report["validation_artifacts"]["validation_report.json"]["path"]).read_text(encoding="utf-8"))
        self.assertEqual(validation["status"], "clean")
        self.assertEqual(validation["summary"]["blocking_count"], 0)
        return self.objects(composition or {})

    def test_move_resize_door_remove_and_generation_failure(self) -> None:
        code, report, composition = self.run_safe()
        baseline = self.assert_clean(code, report, composition)
        live = self.root / "live"
        free_bounds = baseline["OBJ-U-MEDBAY-FREE-CRATE-01"]["bounds"]
        baseline_wall = baseline["OBJ-U-MEDBAY-WALL-TERMINAL-01"]["resolved_transform"]["origin"]
        baseline_beacon = baseline["OBJ-U-MEDBAY-DOOR-BEACON-01"]["resolved_transform"]["origin"]
        baseline_floor = baseline["OBJ-U-MEDBAY-FLOOR-CART-01"]["resolved_transform"]["origin"]
        door_id = baseline["OBJ-U-MEDBAY-DOOR-BEACON-01"]["anchor_id"]

        self.edit_element("u-medbay-wall-west-corridor", {"x1": "-86.432", "x2": "-86.432"})
        self.edit_element("u-medbay-door-procedure-corridor", {"x1": "-86.432", "x2": "-86.432"})
        self.edit_element("u-medbay-door-observation-corridor", {"x1": "-86.432", "x2": "-86.432"})
        moved = self.assert_clean(*self.run_safe())
        self.assertAlmostEqual(moved["OBJ-U-MEDBAY-WALL-TERMINAL-01"]["resolved_transform"]["origin"][0], baseline_wall[0] + 0.2)
        self.assertEqual(moved["OBJ-U-MEDBAY-FREE-CRATE-01"]["bounds"], free_bounds)

        self.edit_element("u-medbay-wall-west-corridor", {"x1": "-86.632", "x2": "-86.632", "y2": "14.5"})
        self.edit_element("u-medbay-door-procedure-corridor", {"x1": "-86.632", "x2": "-86.632"})
        self.edit_element("u-medbay-door-observation-corridor", {"x1": "-86.632", "x2": "-86.632"})
        resized = self.assert_clean(*self.run_safe())
        self.assertNotEqual(resized["OBJ-U-MEDBAY-WALL-TERMINAL-01"]["resolved_transform"]["origin"][2], baseline_wall[2])
        self.assertEqual(resized["OBJ-U-MEDBAY-WALL-TERMINAL-01"]["anchor_id"], "svg:u-medbay-wall-west-corridor:wall")

        self.edit_element("u-medbay-wall-west-corridor", {"y2": "15"})
        self.edit_element("u-medbay-door-external-east", {"y1": "11.35", "y2": "12.55"})
        door_moved = self.assert_clean(*self.run_safe())
        self.assertAlmostEqual(door_moved["OBJ-U-MEDBAY-DOOR-BEACON-01"]["resolved_transform"]["origin"][2], baseline_beacon[2] + 0.3)
        self.assertEqual(door_moved["OBJ-U-MEDBAY-DOOR-BEACON-01"]["anchor_id"], door_id)
        self.assertEqual(door_moved["OBJ-U-MEDBAY-FREE-CRATE-01"]["bounds"], free_bounds)

        self.edit_element("u-medbay-door-external-east", {"y1": "11.05", "y2": "12.25"})
        self.edit_element("u-medbay-floor-procedure-room", remove=True)
        before_removed = SAFE.path_hash(live)
        code, removed_report, removed_composition = self.run_safe()
        self.assertEqual(code, 2)
        self.assertEqual(removed_report["live_hash_before"], before_removed)
        self.assertEqual(removed_report["live_hash_after"], before_removed)
        self.assertFalse(removed_report["agent_invoked"])
        queue = json.loads(Path(removed_report["validation_artifacts"]["repair_queue.json"]["path"]).read_text(encoding="utf-8"))
        missing = [item for item in queue["items"] if item["code"] == "missing_anchor" and item["object_id"] == "OBJ-U-MEDBAY-FLOOR-CART-01"]
        self.assertEqual(len(missing), 1)
        self.assertEqual(missing[0]["previous_anchor_ref"]["anchor_id"], "svg:u-medbay-floor-procedure-room:floor")
        self.assertEqual(missing[0]["candidate_anchor_ids"], [])
        removed_floor = self.objects(removed_composition or {})["OBJ-U-MEDBAY-FLOOR-CART-01"]
        self.assertEqual(removed_floor["bounds"], baseline["OBJ-U-MEDBAY-FLOOR-CART-01"]["bounds"])
        self.assertNotIn("resolved_transform", removed_floor)

        self.source.write_text("<svg viewBox='broken'/>", encoding="utf-8")
        before_failure = SAFE.path_hash(live)
        code, failed, _ = self.run_safe()
        self.assertEqual(code, 2)
        self.assertFalse(failed["ready"])
        self.assertFalse(failed["agent_invoked"])
        self.assertEqual(failed["live_hash_before"], before_failure)
        self.assertEqual(failed["live_hash_after"], before_failure)
        self.assertEqual(SAFE.path_hash(live), before_failure)


if __name__ == "__main__":
    unittest.main()
