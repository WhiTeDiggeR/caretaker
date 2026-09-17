from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "tools/complex_v3_regeneration/sector_generation_manifest.json"
CATALOG = ROOT / "scenes/complex_v3_blockout/sector_catalog.json"
GENERATOR = ROOT / "scenes/complex_v3_blockout/scripts/generate_sector_scenes.py"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ProductionSectorSceneTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

    def test_all_sector_scenes_use_one_generated_package(self) -> None:
        by_id = {item["sector_id"]: item for item in self.manifest["sectors"]}
        self.assertEqual(len(by_id), 30)
        for catalog_entry in self.catalog["sectors"]:
            sector = by_id[catalog_entry["sector_id"]]
            scene = ROOT / catalog_entry["scene"].removeprefix("res://")
            content = scene.read_text(encoding="utf-8")
            package = sector["output_resource_dir"]
            architecture = f'{package}/Generated/Architecture/{sector["scene_name"]}.tscn'
            self.assertIn("geometry_source = 1", content, scene)
            self.assertIn(f'path="{architecture}"', content, scene)
            self.assertEqual(content.count('[node name="Generated"'), 1, scene)
            self.assertEqual(content.count('[node name="Architecture" parent="Generated"'), 1, scene)
            self.assertEqual(content.count('[node name="Stairs"'), 1, scene)
            self.assertEqual(content.count('[node name="AuthoredContent"'), 1, scene)
            self.assertEqual(content.count('[node name="AnchorRegistry"'), 1, scene)
            self.assertNotIn("editor_preview_enabled = true", content, scene)
            self.assertTrue((ROOT / architecture.removeprefix("res://")).is_file(), architecture)

    def test_regeneration_preserves_authored_bytes_and_is_deterministic(self) -> None:
        authored = [ROOT / item["authored_scene"].removeprefix("res://") for item in self.manifest["sectors"]]
        sector_scenes = [ROOT / item["sector_scene"].removeprefix("res://") for item in self.manifest["sectors"]]
        authored_before = {path: digest(path) for path in authored}
        sectors_before = {path: digest(path) for path in sector_scenes}
        subprocess.run([sys.executable, str(GENERATOR)], cwd=ROOT, check=True, capture_output=True, text=True)
        self.assertEqual({path: digest(path) for path in authored}, authored_before)
        self.assertEqual({path: digest(path) for path in sector_scenes}, sectors_before)


if __name__ == "__main__":
    unittest.main()
