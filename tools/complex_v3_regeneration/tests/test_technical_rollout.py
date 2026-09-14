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
        dressing = read("scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json")
        authored = next(s for s in dressing["sectors"] if s["sector_id"] == "T-CIRCULATION")["placements"][0]
        self.assertEqual(interface["objects"][0]["object_id"], authored["object_id"])
        self.assertEqual(interface["objects"][0]["world_transform"]["position"], authored["position"])

    def test_authored_identity_equipment_support_and_shared_routes(self) -> None:
        manifest = read("tools/complex_v3_regeneration/rollouts/technical_generation_manifest.json")
        dressing = read("scenes/complex_v3_blockout/set_dressing/set_dressing_manifest.json")
        handoff = read("docs/design/complex_v3/handoff/geometry/complex-handoff.json")
        routes = [r for r in handoff["route_spaces"] if r["level"] == "LV-T"]
        all_ids = []
        for sector in manifest["sectors"]:
            sid = sector["sector_id"]
            slug = sid.lower().replace("-", "_")
            authored = next(s for s in dressing["sectors"] if s["sector_id"] == sid)
            bindings = read(f"scenes/complex_v3_regeneration/rollout/technical/AuthoredContent/{slug}/object_bindings.json")["bindings"]
            by_id = {b["object_ref"]["object_id"]: b for b in bindings}
            self.assertEqual(set(by_id), {p["object_id"] for p in authored["placements"]})
            all_ids.extend(by_id)
            for p in authored["placements"]:
                binding = by_id[p["object_id"]]
                self.assertEqual(binding["on_missing_anchor"], "block")
                if p["kind"] == "open_portal_frame":
                    continue
                # Reviewed props have explicit single-space floor support, not a
                # guessed wall or an implicit multi-anchor construction.
                self.assertEqual(binding["anchor_ref"]["expected_type"], "floor")
                self.assertTrue(p["space_id"])
                x, _, z = p["position"]
                width, depth = p["footprint_xz"]
                for route in routes:
                    x0, z0, x1, z1 = route["bounds_xz"]
                    overlap_x = min(x + width / 2, x1) - max(x - width / 2, x0)
                    overlap_z = min(z + depth / 2, z1) - max(z - depth / 2, z0)
                    self.assertFalse(overlap_x > 1e-6 and overlap_z > 1e-6, (p["object_id"], route["id"]))
        self.assertEqual(len(all_ids), 58)
        self.assertEqual(len(set(all_ids)), 58)

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
