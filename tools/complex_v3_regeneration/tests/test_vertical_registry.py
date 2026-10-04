"""Every consumer reads the vertical state from one registry instead of hard-coded lists."""
import copy
import json
import unittest
from pathlib import Path

from tools.complex_v3_regeneration import vertical_registry as registry

ROOT = Path(__file__).resolve().parents[3]


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class VerticalRegistryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = read(registry.MANIFEST)
        cls.transitions = read(registry.TRANSITIONS)
        cls.handoff = read(registry.HANDOFF)
        cls.definitions = registry.load_definitions()
        cls.items = {item["id"]: item for item in registry.build_registry(cls.manifest, cls.transitions, cls.handoff, cls.definitions, ROOT)}

    def test_every_transition_has_a_status_and_an_owner(self) -> None:
        self.assertEqual(set(self.items), {item["id"] for item in self.transitions["transitions"]})
        self.assertTrue(all(item["status"] and item["owner"] for item in self.items.values()))

    def test_stairs_come_from_markup_lifts_from_openings_and_the_rest_is_unresolved(self) -> None:
        self.assertEqual(self.items["VT-ROUTE-A"]["status"], registry.GENERATED)
        self.assertEqual(self.items["VT-ROUTE-A"]["owner"], "sector:U-ROUTE-A")
        self.assertEqual(self.items["VT-MAIN-ELEVATOR"]["status"], registry.OPENINGS_READY)
        self.assertEqual(self.items["VT-FREIGHT-LIFT"]["status"], registry.MARKUP_INCOMPLETE)
        self.assertTrue(self.items["VT-FREIGHT-LIFT"]["missing"])
        for vertical_id in ("VT-MAIN-STAIR", "VT-OLD-STAIR", "VT-SERVICE-STAIR", "VT-EAST-STAIR", "VT-OLD-INCLINE"):
            self.assertEqual(self.items[vertical_id]["status"], registry.UNRESOLVED, vertical_id)

    def test_a_broken_definition_is_reported_as_invalid_not_ignored(self) -> None:
        definitions = copy.deepcopy(self.definitions)
        definitions["VT-ROUTE-A"]["generator"]["levels"]["lower"]["sector_id"] = "NO-SUCH-SECTOR"
        items = {item["id"]: item for item in registry.build_registry(self.manifest, self.transitions, self.handoff, definitions, ROOT)}
        self.assertEqual(items["VT-ROUTE-A"]["status"], registry.INVALID)
        self.assertIn("NO-SUCH-SECTOR", items["VT-ROUTE-A"]["detail"])

    def test_summary_is_blocking_until_everything_is_resolved(self) -> None:
        summary = registry.summarize(list(self.items.values()))
        self.assertEqual(summary["status"], "ready_with_blocking_vertical_diagnostics")
        self.assertEqual(summary["generated_vertical_geometry"], ["VT-MAIN-ELEVATOR", "VT-ROUTE-A"])
        self.assertIn("VT-FREIGHT-LIFT (markup_incomplete)", summary["blocking_reason"])
        done = [dict(item, status=registry.GENERATED) for item in self.items.values()]
        ready = registry.summarize(done)
        self.assertEqual((ready["status"], ready["unresolved_vertical_geometry"], ready["blocking_reason"]), ("ready", [], ""))

    def test_shared_report_matches_the_registry(self) -> None:
        report = read(ROOT / "gen/shared/generation_report.json")
        summary = registry.summarize(list(self.items.values()))
        self.assertEqual(report["status"], summary["status"])
        self.assertEqual(report["generated_vertical_geometry"], summary["generated_vertical_geometry"])
        self.assertEqual(report["unresolved_vertical_geometry"], summary["unresolved_vertical_geometry"])


if __name__ == "__main__":
    unittest.main()
