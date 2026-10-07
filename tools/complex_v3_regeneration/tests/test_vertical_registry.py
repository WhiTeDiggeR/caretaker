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
        self.assertEqual(self.items["VT-FREIGHT-LIFT"]["status"], registry.OPENINGS_READY)
        for vertical_id in ("VT-MAIN-STAIR", "VT-OLD-STAIR", "VT-SERVICE-STAIR", "VT-EAST-STAIR"):
            self.assertEqual(self.items[vertical_id]["status"], registry.GENERATED, vertical_id)
        self.assertEqual(self.items["VT-OLD-INCLINE"]["status"], registry.UNRESOLVED)

    def test_a_broken_definition_is_reported_as_invalid_not_ignored(self) -> None:
        definitions = copy.deepcopy(self.definitions)
        definitions["VT-ROUTE-A"]["generator"]["levels"]["lower"]["sector_id"] = "NO-SUCH-SECTOR"
        items = {item["id"]: item for item in registry.build_registry(self.manifest, self.transitions, self.handoff, definitions, ROOT)}
        self.assertEqual(items["VT-ROUTE-A"]["status"], registry.INVALID)
        self.assertIn("NO-SUCH-SECTOR", items["VT-ROUTE-A"]["detail"])

    def test_summary_is_blocking_until_everything_is_resolved(self) -> None:
        summary = registry.summarize(list(self.items.values()))
        self.assertEqual(summary["status"], "ready_with_blocking_vertical_diagnostics")
        self.assertEqual(summary["generated_vertical_geometry"], ["VT-EAST-STAIR", "VT-FREIGHT-LIFT", "VT-MAIN-ELEVATOR", "VT-MAIN-STAIR", "VT-OLD-STAIR", "VT-ROUTE-A", "VT-SERVICE-STAIR"])
        self.assertIn("VT-OLD-INCLINE (unresolved)", summary["blocking_reason"])
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


import importlib.util
import tempfile

from tools.complex_v3_regeneration.tests.test_vertical_resolver import svg as marked_svg

_SPEC = importlib.util.spec_from_file_location("build_sector_manifest", ROOT / "tools/complex_v3_regeneration/build_sector_manifest.py")
BUILDER = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(BUILDER)  # type: ignore[union-attr]


def shaft_and_door(kind: str, role: str, door: tuple, vertical_id: str) -> str:
    inner = marked_svg((0.0, 0.0, 6.0, 7.0), kind, role, door, vertical_id=vertical_id)
    return inner.replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-60 0 20 20">', "").replace("</svg>", "")


class FlightChainTests(unittest.TestCase):
    """A shaft climbing through three levels is two flights, each hosted by its own upper sector."""

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        wall = ["--wall-height", "1.5", "--ceiling-thickness", "0.2"]
        self.manifest = {"sectors": [
            {"sector_id": "T", "level": "LV-T", "source_svg": "t.svg", "metric_settings": {"elevation_m": -6.0}, "shared_args": wall},
            {"sector_id": "L", "level": "LV-L", "source_svg": "l.svg", "metric_settings": {"elevation_m": -3.0}, "shared_args": wall},
            {"sector_id": "U", "level": "LV-U", "source_svg": "u.svg", "metric_settings": {"elevation_m": 0.0}, "shared_args": wall},
        ]}
        self.transitions = {"level_datums": {"LV-U": 0.0, "LV-L": -3.0, "LV-T": -6.0}, "transitions": [{"id": "VT-CHAIN", "kind": "continuous_emergency_stair", "connects": ["LV-U", "LV-L", "LV-T"]}]}
        north, south = (2.25, 0.0, 3.75, 0.0), (2.25, 7.0, 3.75, 7.0)
        wrap = lambda body: f'<svg xmlns="http://www.w3.org/2000/svg">{body}</svg>'  # noqa: E731
        (self.root / "t.svg").write_text(wrap(shaft_and_door("ceiling-opening", "entry", north, "VT-CHAIN-A")), encoding="utf-8")
        (self.root / "l.svg").write_text(wrap(
            shaft_and_door("floor-opening", "exit", north, "VT-CHAIN-A") + shaft_and_door("ceiling-opening", "entry", south, "VT-CHAIN-B").replace('id="shaft0"', 'id="shaftB"').replace('id="door"', 'id="doorB"')), encoding="utf-8")
        (self.root / "u.svg").write_text(wrap(shaft_and_door("floor-opening", "exit", south, "VT-CHAIN-B")), encoding="utf-8")
        self.definitions = {
            "VT-CHAIN-A": {"host_sector_id": "L", "generator": {"generator_id": "a", "source": "svg", "vertical_id": "VT-CHAIN-A", "transition_id": "VT-CHAIN", "levels": {"upper": {"sector_id": "L"}, "lower": {"sector_id": "T"}}, "args": []}},
            "VT-CHAIN-B": {"host_sector_id": "U", "generator": {"generator_id": "b", "source": "svg", "vertical_id": "VT-CHAIN-B", "transition_id": "VT-CHAIN", "levels": {"upper": {"sector_id": "U"}, "lower": {"sector_id": "L"}}, "args": []}},
        }

    def tearDown(self) -> None:
        self.temp.cleanup()

    def entries(self) -> list:
        return registry.build_registry(self.manifest, self.transitions, {"spaces": []}, self.definitions, self.root)

    def test_all_flights_resolved_makes_the_transition_generated(self) -> None:
        (item,) = self.entries()
        self.assertEqual(item["status"], registry.GENERATED, item.get("detail"))
        self.assertEqual(item["owner"], "sector:L, sector:U")
        self.assertEqual(len(item["summary"]), 2)
        self.assertEqual(registry.defined_transition_ids(self.definitions), {"VT-CHAIN"})

    def test_one_broken_flight_makes_the_transition_invalid_and_names_the_flight(self) -> None:
        (self.root / "u.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"/>', encoding="utf-8")
        (item,) = self.entries()
        self.assertEqual(item["status"], registry.INVALID)
        self.assertIn("VT-CHAIN-B", item["detail"])

    def test_a_sector_cannot_host_two_generators(self) -> None:
        definitions = Path(self.temp.name) / "definitions.json"
        definitions.write_text(json.dumps({"stairs": list(self.definitions.values())}), encoding="utf-8")
        both_on_l = json.loads(definitions.read_text(encoding="utf-8"))
        both_on_l["stairs"][1]["host_sector_id"] = "L"
        definitions.write_text(json.dumps(both_on_l), encoding="utf-8")
        original = BUILDER.VERTICAL_DEFINITIONS
        BUILDER.VERTICAL_DEFINITIONS = definitions
        try:
            with self.assertRaisesRegex(ValueError, "more than one stair generator"):
                BUILDER.apply_vertical_definitions({"L": {"vertical_generators": []}, "U": {"vertical_generators": []}})
        finally:
            BUILDER.VERTICAL_DEFINITIONS = original
