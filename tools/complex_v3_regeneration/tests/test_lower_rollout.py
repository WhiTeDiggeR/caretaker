from __future__ import annotations

import importlib.util
import json
import math
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[3]
TOOLS = PROJECT / "tools/complex_v3_regeneration"
SPEC = importlib.util.spec_from_file_location("build_floor_rollout_lower", TOOLS / "build_floor_rollout.py")
assert SPEC and SPEC.loader
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


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
        expected_objects = {
            placement["object_id"]
            for sector in self.dressing["sectors"] if sector["sector_id"] in expected
            for placement in sector["placements"]
        }
        actual_objects: list[str] = []
        for sector_id in expected:
            slug = sector_id.lower().replace("-", "_")
            authored = PROJECT / f"scenes/complex_v3_regeneration/rollout/lower/AuthoredContent/{slug}"
            composition = json.loads((authored / "composition.json").read_text(encoding="utf-8"))
            bindings = json.loads((authored / "object_bindings.json").read_text(encoding="utf-8"))
            bound = [item["object_ref"]["object_id"] for item in bindings["bindings"]]
            self.assertEqual(set(bound), {item["object_id"] for item in composition["objects"]})
            self.assertTrue(all(item["on_missing_anchor"] == "block" for item in bindings["bindings"]))
            self.assertTrue(all((PROJECT / item["object_ref"]["scene"].removeprefix("res://")).is_file() for item in bindings["bindings"]))
            actual_objects.extend(bound)
        self.assertEqual(len(actual_objects), 110)
        self.assertEqual(set(actual_objects), expected_objects)
        self.assertEqual(len(actual_objects), len(set(actual_objects)))

    def test_portal_centers_widths_and_neighbor_ids_match_handoff(self) -> None:
        for sector in self.manifest["sectors"]:
            sector_id = sector["sector_id"]
            slug = sector_id.lower().replace("-", "_")
            frames_doc = json.loads((PROJECT / f"gen/l/{slug}/anchor_frames.json").read_text(encoding="utf-8"))
            frames = {item["anchor_id"]: item for item in frames_doc["anchors"]}
            local_spaces = {item["id"] for item in self.handoff["spaces"] if item["sector_id"] == sector_id}
            portals = [item for item in self.handoff["internal_portals"] if any(value in local_spaces for value in item["between"])]
            portals += [item for item in self.handoff["external_portals"] if item.get("space") in local_spaces]
            for portal in portals:
                a, b = portal["segment_xz"]
                midpoint = [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5]
                if BUILDER.portal_is_traversable(portal):
                    base = f"svg:{BUILDER.stable_id('d', portal['id'])}:door"
                    for role in ("center", "threshold_inside", "threshold_outside"):
                        self.assertIn(base + ":" + role, frames)
                    center = frames[base + ":center"]
                    self.assertTrue(math.isclose(center["origin"][0], midpoint[0], abs_tol=1e-6))
                    self.assertTrue(math.isclose(center["origin"][2], midpoint[1], abs_tol=1e-6))
                    self.assertTrue(math.isclose(center["bounds"]["width_m"], math.dist(a, b), abs_tol=1e-6))
                else:
                    marker = f"svg:{BUILDER.stable_id('p', portal['id'])}:point"
                    self.assertIn(marker, frames)
                    self.assertEqual(frames[marker]["role"], "sealed_portal")
                    self.assertEqual(frames[marker]["metadata"]["declared_anchor_id"], portal["id"])
                    self.assertNotIn(f"svg:{BUILDER.stable_id('d', portal['id'])}:door:center", frames)

    def test_closed_portals_keep_solid_wall_and_authored_semantics(self) -> None:
        closed = [
            item for item in self.handoff["external_portals"]
            if item.get("state") == "closed" and any(space["sector_id"] in self.sector_ids and space["id"] == item.get("space") for space in self.handoff["spaces"])
        ]
        self.assertEqual({item["id"] for item in closed}, {
            "PX-E-L13-L-CHAMBER-2", "PX-E-L14-L-CHAMBER-3", "PX-E-L16-L-CHAMBER-5",
        })
        for portal in closed:
            sector_id = next(space["sector_id"] for space in self.handoff["spaces"] if space["id"] == portal["space"])
            slug = sector_id.lower().replace("-", "_")
            composition = json.loads((PROJECT / f"scenes/complex_v3_regeneration/rollout/lower/AuthoredContent/{slug}/composition.json").read_text(encoding="utf-8"))
            frames = json.loads((PROJECT / f"gen/l/{slug}/anchor_frames.json").read_text(encoding="utf-8"))
            frame_ids = {item["anchor_id"] for item in frames["anchors"]}
            sealed_object = next(item for item in composition["objects"] if item.get("portal_semantics", {}).get("portal_id") == portal["id"])
            self.assertEqual(sealed_object["portal_semantics"], {"portal_id": portal["id"], "state": "closed", "traversable": False})
            self.assertEqual(sealed_object["placement_mode"], "wall")
            self.assertFalse(any(f"svg:{BUILDER.stable_id('d', portal['id'])}:door:" in value for value in frame_ids))
            self.assertFalse(any(f"svg:{BUILDER.stable_id('d', portal['id'])}:door:center" in infra.get("opening_anchor_ids", []) for infra in composition["infrastructure"]))


if __name__ == "__main__":
    unittest.main()
