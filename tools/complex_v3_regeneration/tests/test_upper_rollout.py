from __future__ import annotations

import hashlib
import importlib.util
import json
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[3]
TOOLS = PROJECT / "tools/complex_v3_regeneration"
SPEC = importlib.util.spec_from_file_location("build_floor_rollout", TOOLS / "build_floor_rollout.py")
assert SPEC and SPEC.loader
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class UpperRolloutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.handoff = json.loads(BUILDER.HANDOFF.read_text(encoding="utf-8"))
        cls.dressing = json.loads(BUILDER.DRESSING.read_text(encoding="utf-8"))
        cls.manifest_path = TOOLS / "rollouts/upper_generation_manifest.json"
        cls.manifest = json.loads(cls.manifest_path.read_text(encoding="utf-8"))

    def test_inventory_excludes_pilots_and_preserves_all_authored_ids(self) -> None:
        expected_sectors = {
            item["id"] for item in self.handoff["sectors"]
            if item["level"] == "LV-U" and item["id"] not in BUILDER.PILOTS["upper"]
        }
        actual_sectors = {item["sector_id"] for item in self.manifest["sectors"]}
        self.assertEqual(actual_sectors, expected_sectors)
        self.assertEqual(self.manifest["sector_count"], 9)

        expected_ids = {
            placement["object_id"]
            for sector in self.dressing["sectors"] if sector["sector_id"] in expected_sectors
            for placement in sector["placements"]
        }
        actual_ids: list[str] = []
        for sector in self.manifest["sectors"]:
            slug = sector["sector_id"].lower().replace("-", "_")
            authored = PROJECT / f"scenes/complex_v3_regeneration/rollout/upper/AuthoredContent/{slug}"
            composition = json.loads((authored / "composition.json").read_text(encoding="utf-8"))
            bindings = json.loads((authored / "object_bindings.json").read_text(encoding="utf-8"))
            self.assertEqual({item["object_id"] for item in composition["objects"]}, {item["object_ref"]["object_id"] for item in bindings["bindings"]})
            self.assertTrue(all(item["on_missing_anchor"] == "block" for item in bindings["bindings"]))
            actual_ids.extend(item["object_id"] for item in composition["objects"])
        self.assertEqual(len(actual_ids), 149)
        self.assertEqual(set(actual_ids), expected_ids)
        self.assertEqual(len(actual_ids), len(set(actual_ids)))

    def test_generated_anchor_ids_are_unique_and_portals_match_handoff(self) -> None:
        all_ids: list[str] = []
        for sector in self.manifest["sectors"]:
            slug = sector["sector_id"].lower().replace("-", "_")
            frames = json.loads((PROJECT / f"gen/u/{slug}/anchor_frames.json").read_text(encoding="utf-8"))
            self.assertEqual(frames["sector_id"], sector["sector_id"])
            ids = [item["anchor_id"] for item in frames["anchors"]]
            self.assertEqual(len(ids), len(set(ids)))
            self.assertFalse(any(":hinge" in anchor_id for anchor_id in ids))
            all_ids.extend(ids)

            local_spaces = {item["id"] for item in self.handoff["spaces"] if item["sector_id"] == sector["sector_id"]}
            portals = [item for item in self.handoff["internal_portals"] if any(value in local_spaces for value in item["between"])]
            portals += [item for item in self.handoff["external_portals"] if item.get("space") in local_spaces]
            for portal in portals:
                base = f"svg:{BUILDER.stable_id('d', portal['id'])}:door"
                self.assertIn(base + ":center", ids)
                self.assertIn(base + ":threshold_inside", ids)
                self.assertIn(base + ":threshold_outside", ids)

        self.assertEqual(len(all_ids), len(set(all_ids)))

    def test_semantic_ids_do_not_depend_on_dimensions_or_order(self) -> None:
        self.assertEqual(BUILDER.stable_id("f", "SPACE-A"), BUILDER.stable_id("f", "SPACE-A"))
        original = [
            {"id": "SPACE-A", "bounds_xz": [0, 0, 3, 2]},
            {"id": "SPACE-B", "bounds_xz": [3, 0, 5, 2]},
        ]
        resized = [
            {"id": "SPACE-B", "bounds_xz": [4, 0, 7, 2]},
            {"id": "SPACE-A", "bounds_xz": [0, 0, 4, 2]},
        ]
        original_semantics = {tuple(item["contributors"]): item["id"] for item in BUILDER.edges(original)}
        resized_semantics = {tuple(item["contributors"]): item["id"] for item in BUILDER.edges(resized)}
        for semantic in original_semantics.keys() & resized_semantics.keys():
            self.assertEqual(original_semantics[semantic], resized_semantics[semantic])

    def test_sources_and_manifest_are_deterministic(self) -> None:
        tracked = [self.manifest_path]
        tracked.extend(PROJECT / item["source_svg"] for item in self.manifest["sectors"])
        before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in tracked}
        self.assertEqual(BUILDER.main_for(["--level", "upper"]), 0)
        after = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in tracked}
        self.assertEqual(after, before)


if not hasattr(BUILDER, "main_for"):
    def _main_for(argv: list[str]) -> int:
        import sys
        previous = sys.argv
        try:
            sys.argv = [str(TOOLS / "build_floor_rollout.py"), *argv]
            return BUILDER.main()
        finally:
            sys.argv = previous
    BUILDER.main_for = _main_for


if __name__ == "__main__":
    unittest.main()
