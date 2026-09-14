from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("shared_audit", ROOT/"tools/complex_v3_regeneration/rollouts/audit_shared_inputs.py")
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class SharedAuditTests(unittest.TestCase):
    def test_ownership_no_fabricated_geometry_or_readiness(self) -> None:
        h = json.loads((ROOT/"docs/design/complex_v3/handoff/geometry/complex-handoff.json").read_text(encoding="utf-8"))
        v = json.loads((ROOT/"docs/design/complex_v3/handoff/vertical/vertical-transitions.json").read_text(encoding="utf-8"))
        report = AUDIT.audit(h,v)
        self.assertEqual(len(report["owners"]),47)
        self.assertEqual(len(report["verticals"]),8)
        self.assertEqual(len(report["sector_shared_bounds_candidates"]),5)
        self.assertFalse(report["geometry_generated"])
        self.assertEqual(report["status"],"not_ready_for_combined_assembly")
        self.assertEqual(report["combined_collision_verification"],"not_run")
        self.assertTrue(all(not x["authored_sector_copy_allowed"] for x in report["owners"]))
        for connector in report["connectors"]:
            if connector["zero_length"]:
                self.assertEqual(connector["geometry_policy"],"no_corridor_prism")
                self.assertTrue(connector["portal_source_refs"])
        ids = {x["source_id"] for x in report["diagnostics"] if x["code"] == "explicit_stair_port_orientation_missing"}
        self.assertEqual(ids,{"VT-MAIN-STAIR","VT-OLD-STAIR","VT-SERVICE-STAIR","VT-EAST-STAIR"})
        self.assertEqual(report,AUDIT.audit(h,v))


if __name__ == "__main__":
    unittest.main()
