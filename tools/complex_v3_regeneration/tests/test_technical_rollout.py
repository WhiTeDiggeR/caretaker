from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


class TechnicalRolloutTests(unittest.TestCase):
    def test_inventory_and_single_shared_owner(self) -> None:
        manifest = read("tools/complex_v3_regeneration/rollouts/technical_generation_manifest.json")
        self.assertEqual({s["sector_id"] for s in manifest["sectors"]}, {"T-EAST-VERTICAL", "T-ENERGY", "T-FREIGHT", "T-OLD-ACCESS", "T-UTILITIES", "T-WORKSHOP"})
        interface = read("tools/complex_v3_regeneration/rollouts/technical_circulation_interface.json")
        self.assertFalse(interface["generated_sector_geometry"])
        self.assertEqual(interface["architecture_owner"], "complex_v3_infrastructure")
        self.assertEqual(interface["combined_validation"], "pending_T18")
        self.assertEqual(interface["objects"], [])   # the old placed objects were removed on purpose

    def test_authored_content_is_empty_and_every_canonical_door_has_anchors(self) -> None:
        manifest = read("tools/complex_v3_regeneration/rollouts/technical_generation_manifest.json")
        import xml.etree.ElementTree as ET
        for sector in manifest["sectors"]:
            slug = sector["sector_id"].lower().replace("-", "_")
            self.assertEqual(read(f"scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/{slug}/object_bindings.json")["bindings"], [])
            frames = {a["anchor_id"] for a in read(f"gen/t/{slug}/anchor_frames.json")["anchors"]}
            svg = ET.parse(ROOT / f"docs/design/complex_v4/plans/generation/technical/{slug}.svg").getroot()
            for el in svg.iter():
                if el.get("data-godot-type") == "door":
                    for role in ("center", "threshold_inside", "threshold_outside"):
                        self.assertIn(f"svg:{el.get('id')}:door:{role}", frames, (slug, el.get("id")))

    def test_portal_clearance_footprints_remain_unoccupied(self) -> None:
        handoff = read("docs/design/complex_v3/handoff/geometry/complex-handoff.json")
        dressing = read("scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json")
        portals = handoff["internal_portals"] + handoff["external_portals"]
        for sector in dressing["sectors"]:
            if not sector["sector_id"].startswith("T-") or sector["sector_id"] == "T-CIRCULATION":
                continue
            local_spaces = {p["space_id"] for p in sector["placements"]}
            for portal in portals:
                if portal.get("state") == "closed" or portal.get("traversable") is False:
                    continue
                if not (set(portal.get("between", [])) | {portal.get("space")}) & local_spaces:
                    continue
                a, b = portal["segment_xz"]
                x0, x1 = min(a[0], b[0]), max(a[0], b[0])
                z0, z1 = min(a[1], b[1]), max(a[1], b[1])
                if x0 == x1:
                    x0, x1 = x0 - .3, x1 + .3
                else:
                    z0, z1 = z0 - .3, z1 + .3
                for p in sector["placements"]:
                    if p["kind"] == "open_portal_frame":
                        continue
                    x, _, z = p["position"]
                    w, d = p["footprint_xz"]
                    self.assertFalse(min(x+w/2,x1)-max(x-w/2,x0)>1e-6 and min(z+d/2,z1)-max(z-d/2,z0)>1e-6, (p["object_id"], portal["id"]))


if __name__ == "__main__":
    unittest.main()
