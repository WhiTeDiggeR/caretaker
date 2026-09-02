from __future__ import annotations

import sys
import tempfile
import unittest
import json
import copy
from unittest.mock import patch
from pathlib import Path


MODULE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(MODULE_DIR))
sys.path.insert(0, str(MODULE_DIR.parent / "scripts"))
import generate_set_dressing as generator

from set_dressing_migration import (  # noqa: E402
    apply_correction,
    compare_snapshots,
    correction_between,
    object_id_for,
    parse_scene_transforms,
)


class SetDressingMigrationTests(unittest.TestCase):
    def test_object_id_is_stable_and_not_the_placement_id(self) -> None:
        placement_id = "U-MEDBAY/triage::wall_terminal::intake_terminal"
        self.assertEqual(object_id_for(placement_id), object_id_for(placement_id))
        self.assertTrue(object_id_for(placement_id).startswith("OBJ-SET-"))
        self.assertNotEqual(object_id_for(placement_id), placement_id)

    def test_authored_correction_survives_a_changed_seed(self) -> None:
        old_seed = {"position": [1.0, 2.0, 3.0], "rotation_y": 0.5, "scale": [1.0, 1.0, 1.0]}
        authored = {"position": [1.25, 2.0, 2.5], "rotation_y": 0.75, "scale": [1.0, 1.2, 1.0]}
        correction = correction_between(old_seed, authored)
        new_seed = {"position": [5.0, 2.0, 3.0], "rotation_y": 1.0, "scale": [2.0, 1.0, 1.0]}
        self.assertEqual(apply_correction(new_seed, correction), {
            "position": [5.25, 2.0, 2.5],
            "rotation_y": 1.25,
            "scale": [2.0, 1.2, 1.0],
        })

    def test_parser_reads_legacy_instance_and_authored_wrapper(self) -> None:
        text = '''[gd_scene format=3]

[node name="Legacy" parent="." instance=ExtResource("1")]
position = Vector3(1, 2, 3)
rotation = Vector3(0, 0.5, 0)
metadata/placement_id = "legacy"

[node name="Wrapper" type="Node3D" parent="."]
position = Vector3(4, 5, 6)
scale = Vector3(2, 1, 1)
metadata/placement_id = "wrapper"

[node name="Content" parent="Wrapper" instance=ExtResource("1")]
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scene.tscn"
            path.write_text(text, encoding="utf-8")
            parsed = parse_scene_transforms(path)
        self.assertEqual(parsed["legacy"]["rotation_y"], 0.5)
        self.assertEqual(parsed["wrapper"]["scale"], [2.0, 1.0, 1.0])

    def test_snapshot_comparison_blocks_transform_drift(self) -> None:
        before = {"objects": [{"object_id": "OBJ-A", "transform": {"position": [0, 0, 0], "rotation_y": 0, "scale": [1, 1, 1]}}]}
        after = {"objects": [{"object_id": "OBJ-A", "transform": {"position": [0.01, 0, 0], "rotation_y": 0, "scale": [1, 1, 1]}}]}
        self.assertEqual(compare_snapshots(before, after)["status"], "failed")

    def test_duplicate_ids_cannot_pass_audit(self) -> None:
        record = {"object_id": "X", "transform": {"position": [0, 0, 0], "rotation_y": 0, "scale": [1, 1, 1]}}
        with self.assertRaises(ValueError):
            compare_snapshots({"objects": [record, record]}, {"objects": [record]})

    def test_text_parser_blocks_lossy_transforms_and_duplicate_ids(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scene.tscn"
            for properties in [
                'transform = Transform3D(1,0,0,0,1,0,0,0,1,1,2,3)',
                'rotation = Vector3(0.1, 0, 0)',
                'position = Vector3(nan, 0, 0)',
            ]:
                path.write_text('[node name="A" parent="."]\nmetadata/placement_id = "A"\n' + properties, encoding="utf-8")
                with self.assertRaises(ValueError):
                    parse_scene_transforms(path)
            path.write_text('[node name="A" parent="."]\nmetadata/placement_id = "A"\n[node name="B" parent="."]\nmetadata/placement_id = "A"', encoding="utf-8")
            with self.assertRaises(ValueError):
                parse_scene_transforms(path)

    def test_portal_identity_is_intent_not_invented_anchor(self) -> None:
        manifest = {"sectors": [{"placements": [{"id": "P-1", "kind": "open_portal_frame", "space_id": "S", "position": [0, 0, 0]}]}]}
        generator.enrich_manifest(manifest, {})
        binding = manifest["sectors"][0]["placements"][0]["binding"]
        self.assertEqual(binding["mode"], "unresolved")
        self.assertEqual(binding["portal_id"], "P-1")
        self.assertNotIn("anchor_id", binding)

    def test_seed_generation_never_writes_authored_edits_or_bindings(self) -> None:
        seed = {"source": "test", "sectors": [
            {"sector_id": "A", "placements": [{"id": "p-a", "position": [99, 0, 0]}]},
            {"sector_id": "B", "placements": [{"id": "p-b", "position": [0, 0, 0]}]},
        ]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authored = root / "set_dressing_manifest.json"
            authored.write_text(json.dumps({"schema_version": "2.0.0", "sectors": []}), encoding="utf-8")
            # These represent arbitrary Godot edits, deleted seed objects and a repaired binding.
            extra = root / "hand_edited.tscn"
            extra.write_text('transform = Transform3D(custom)\nmaterial_override = custom\n[node name="New"]', encoding="utf-8")
            bindings = root / "a.bindings.json"
            bindings.write_text('{"anchor_id":"EXPLICIT-REPAIR-ID"}', encoding="utf-8")
            correction = root / "authored_corrections.json"
            correction.write_text('{"custom_author_correction":12}', encoding="utf-8")
            expected = {path: path.read_bytes() for path in (authored, extra, bindings, correction)}
            with patch.object(generator, "OUTPUT", root), patch.object(generator, "MANIFEST", authored), patch.object(generator, "make_manifest", return_value=copy.deepcopy(seed)):
                with patch.object(sys, "argv", ["generate", "--sector-id", "A"]):
                    generator.main()
                    first = (root / "seed/a.seed.json").read_bytes()
                    generator.main()
                    self.assertEqual(first, (root / "seed/a.seed.json").read_bytes())
                self.assertFalse((root / "seed/b.seed.json").exists())
                with patch.object(sys, "argv", ["generate", "--migrate-authored"]):
                    with self.assertRaises(SystemExit):
                        generator.main()
            for path, contents in expected.items():
                self.assertEqual(contents, path.read_bytes())

    def test_legacy_bootstrap_preserves_actual_transform_against_changed_seed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "dressing"
            output.mkdir()
            scene = output / "a.tscn"
            scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://asset.tscn" id="1"]\n[node name="Dressing" type="Node3D"]\n[node name="Object" parent="." instance=ExtResource("1")]\nposition = Vector3(-73, -6, 15)\nmetadata/placement_id = "P-1"\n', encoding="utf-8")
            old = {"schema_version": "1.0", "sectors": [{"sector_id": "A", "family": "medical", "dressing_scene": "res://dressing/a.tscn", "placements": [{"id": "P-1", "space_id": "space", "scene": "res://asset.tscn", "kind": "open_portal_frame", "position": [-73, -6, 15], "rotation_y": 0}]}]}
            manifest = output / "set_dressing_manifest.json"
            manifest.write_text(json.dumps(old), encoding="utf-8")
            new = copy.deepcopy(old)
            new["schema_version"] = "2.0.0"
            new["sectors"][0]["placements"][0]["position"] = [-62, -6, 8.666]
            with patch.multiple(generator, ROOT=root, OUTPUT=output, MANIFEST=manifest, CORRECTIONS=output / "authored_corrections.json", BINDINGS=root / "bindings", MIGRATION_REPORT=output / "migration/report.json"), patch.object(generator, "make_manifest", return_value=new), patch.object(sys, "argv", ["generate", "--migrate-authored"]):
                generator.main()
                self.assertEqual(parse_scene_transforms(scene)["P-1"]["position"], [-73, -6, 15])
                saved = scene.read_bytes()
                with self.assertRaises(SystemExit):
                    generator.main()
                self.assertEqual(saved, scene.read_bytes())


if __name__ == "__main__":
    unittest.main()
