from __future__ import annotations

import importlib.util
import json
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location(
    "shared_contract",
    ROOT / "tools/complex_v3_regeneration/rollouts/build_shared_contract.py",
)
assert SPEC and SPEC.loader
CONTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTRACT)


class SharedContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.handoff = json.loads(CONTRACT.HANDOFF.read_text(encoding="utf-8"))
        self.vertical = json.loads(CONTRACT.VERTICAL.read_text(encoding="utf-8"))
        self.ports = json.loads(CONTRACT.PORT_REPORT.read_text(encoding="utf-8"))

    def test_frames_are_unique_stable_and_well_formed(self) -> None:
        result = CONTRACT.build_frames(self.handoff, self.vertical, self.ports)
        anchors = result["anchors"]
        self.assertEqual(len(anchors), 69)
        self.assertEqual(len({item["anchor_id"] for item in anchors}), len(anchors))
        self.assertEqual(anchors, sorted(anchors, key=lambda item: item["anchor_id"]))
        self.assertEqual(result, CONTRACT.build_frames(self.handoff, self.vertical, self.ports))
        for item in anchors:
            self.assertIn(item["type"], {"point", "door", "floor", "shaft", "stair_entry", "stair_exit"})
            for key in ("origin", "forward", "normal", "up"):
                self.assertEqual(len(item[key]), 3)
            for key in ("forward", "normal", "up"):
                self.assertAlmostEqual(math.sqrt(sum(value * value for value in item[key])), 1.0, places=6)
            self.assertAlmostEqual(sum(a * b for a, b in zip(item["forward"], item["up"])), 0.0, places=6)

    def test_single_owner_package_contains_no_duplicate_geometry(self) -> None:
        report = json.loads((ROOT / "gen/shared/generation_report.json").read_text(encoding="utf-8"))
        scene = (ROOT / "gen/shared/Generated/Infrastructure/shared_infrastructure_generated.tscn").read_text(encoding="utf-8")
        self.assertEqual(report["geometry_policy"], "external_single_owner")
        self.assertEqual(report["geometry_owners"]["horizontal_routes"], "sector_rollouts")
        self.assertEqual(report["geometry_owners"]["VT-ROUTE-A"], "route_a_vertical_pilot")
        self.assertFalse(report["generated_vertical_geometry"])
        self.assertTrue(report["unresolved_vertical_geometry"])
        self.assertTrue(report["connector_aliases"])
        self.assertNotIn("CollisionShape3D", scene)
        self.assertNotIn("MeshInstance3D", scene)
        self.assertIn('metadata/geometry_policy = "external_single_owner"', scene)


if __name__ == "__main__":
    unittest.main()
