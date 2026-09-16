from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("vertical_mapper",ROOT/"tools/complex_v3_regeneration/rollouts/map_vertical_ports.py")
assert SPEC and SPEC.loader
MAPPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MAPPER)


class VerticalPortMappingTests(unittest.TestCase):
    def test_reverse_preserves_side_and_no_projection(self) -> None:
        bounds = [0,0,6,8]
        segment = [[1,0],[3,0]]
        self.assertEqual(MAPPER.shaft_side(segment,bounds),"north")
        self.assertEqual(MAPPER.shaft_side(list(reversed(segment)),bounds),"north")
        self.assertIsNone(MAPPER.shaft_side([[1,3],[3,3]],bounds))
        self.assertIsNone(MAPPER.shaft_side([[-2,0],[3,0]],bounds))

    def test_source_conflicts_are_blocking_and_pass_through_has_no_stop(self) -> None:
        h = json.loads((ROOT/"docs/design/complex_v3/handoff/geometry/complex-handoff.json").read_text(encoding="utf-8"))
        v = json.loads((ROOT/"docs/design/complex_v3/handoff/vertical/vertical-transitions.json").read_text(encoding="utf-8"))
        result = MAPPER.map_ports(h,v)
        self.assertEqual(result["status"],"blocked")
        self.assertFalse(result["anchor_frames_emitted"])
        main = next(t for t in result["transitions"] if t["transition_id"] == "VT-MAIN-ELEVATOR")
        self.assertEqual(main["pass_through_without_stop"],["LV-T"])
        self.assertNotIn("LV-T",{p["level"] for p in main["ports"]})
        freight = next(t for t in result["transitions"] if t["transition_id"] == "VT-FREIGHT-LIFT")
        threshold = next(p for p in freight["ports"] if p["portal_source_id"] == "P-U-FREIGHT-03")
        self.assertEqual(threshold["status"],"external_threshold")
        self.assertIsNone(threshold["shaft_side"])
        self.assertTrue(any(d["code"] == "explicit_space_mapping_missing" for d in result["diagnostics"]))
        self.assertTrue(any(d["code"] == "generator_boundary_port_missing" for d in result["diagnostics"]))
        h["internal_portals"].reverse()
        h["external_portals"].reverse()
        self.assertEqual(result,MAPPER.map_ports(h,v))


if __name__ == "__main__":
    unittest.main()
