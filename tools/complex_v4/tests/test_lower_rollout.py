from __future__ import annotations

import importlib.util
import json
import math
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[3]
TOOLS = PROJECT / "tools/complex_v4"
SPEC = importlib.util.spec_from_file_location("build_floor_rollout_lower", TOOLS / "build_floor_rollout.py")
assert SPEC and SPEC.loader
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


def canonical_door_ids(folder: str, slug: str) -> list[str]:
    """Door elements of the canonical v4 SVG of a sector; each one must have door anchors in the generated package."""
    import xml.etree.ElementTree as ET
    root = ET.parse(PROJECT / f"docs/design/complex_v4/plans/generation/{folder}/{slug}.svg").getroot()
    return [el.get("id") for el in root.iter() if el.get("data-godot-type") == "door"]


class LowerRolloutTests(unittest.TestCase):
    def test_ambiguous_portal_semantics_block(self) -> None:
        for portal in ({"id":"bad", "state":"unknown"}, {"id":"bad", "state":"closed", "traversable":True}, {"id":"bad", "state":"openable", "traversable":"false"}):
            with self.subTest(portal=portal), self.assertRaises(BUILDER.BuildError):
                BUILDER.portal_is_traversable(portal)

    @classmethod
    def setUpClass(cls) -> None:
        cls.handoff = json.loads(BUILDER.HANDOFF.read_text(encoding="utf-8"))
        cls.dressing = json.loads(BUILDER.DRESSING.read_text(encoding="utf-8"))
        cls.manifest_path = TOOLS / "rollouts/lower_generation_manifest.json"
        cls.manifest = json.loads(cls.manifest_path.read_text(encoding="utf-8"))
        cls.sector_ids = {item["sector_id"] for item in cls.manifest["sectors"]}

    def test_inventory_and_authored_identity_are_complete(self) -> None:
        expected = {
            item["id"] for item in self.handoff["sectors"]
            if item["level"] == "LV-L" and item["id"] != "L-ARCHIVE-A"
        }
        self.assertEqual(self.sector_ids, expected)
        self.assertEqual(self.manifest["sector_count"], 11)
        for sector_id in expected:
            slug = sector_id.lower().replace("-", "_")
            authored = PROJECT / f"scenes/complex_v4/regeneration/rollout/lower/AuthoredContent/{slug}"
            composition = json.loads((authored / "composition.json").read_text(encoding="utf-8"))
            bindings = json.loads((authored / "object_bindings.json").read_text(encoding="utf-8"))
            # the old placed objects were removed on purpose (sectors were redrawn); they are placed again from scratch
            self.assertEqual(composition["objects"], [])
            self.assertEqual(bindings["bindings"], [])

    def test_every_canonical_door_has_door_anchors(self) -> None:
        for sector in self.manifest["sectors"]:
            slug = sector["sector_id"].lower().replace("-", "_")
            frames_doc = json.loads((PROJECT / f"gen/l/{slug}/anchor_frames.json").read_text(encoding="utf-8"))
            frames = {item["anchor_id"] for item in frames_doc["anchors"]}
            for door_id in canonical_door_ids("lower", slug):
                for role in ("center", "threshold_inside", "threshold_outside"):
                    self.assertIn(f"svg:{door_id}:door:{role}", frames, (slug, door_id))


if __name__ == "__main__":
    unittest.main()
