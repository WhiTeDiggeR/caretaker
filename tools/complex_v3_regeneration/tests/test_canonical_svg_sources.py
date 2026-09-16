from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("canonical_sources", ROOT / "tools/complex_v3_regeneration/validate_canonical_sources.py")
assert SPEC and SPEC.loader
CANONICAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CANONICAL)


class CanonicalSvgSourceTests(unittest.TestCase):
    def test_all_30_sources_have_explicit_metric_semantics(self) -> None:
        manifest = json.loads(CANONICAL.MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(CANONICAL.validate_structure(ROOT, manifest), [])
        sources = [item["source_svg"] for item in manifest["sectors"]]
        self.assertEqual(len(sources), 30)
        self.assertEqual(len(set(sources)), 30)
        self.assertTrue(all(path.startswith(CANONICAL.CANONICAL_PREFIX) for path in sources))

    def test_presentation_plans_are_never_generator_inputs(self) -> None:
        presentation = list((ROOT / "docs/design/complex_v3/plans/sectors").rglob("*.svg"))
        presentation += list((ROOT / "docs/design/complex_v3/plans/overview").rglob("*.svg"))
        self.assertTrue(presentation)
        for path in presentation:
            text = path.read_text(encoding="utf-8")
            self.assertIn('data-presentation-only="true"', text, str(path))
            self.assertIn('data-generator-input="false"', text, str(path))
            self.assertIn("presentation_only=true generator_input=false", text, str(path))

    def test_editor_default_manifest_resolves_canonical_source(self) -> None:
        plugin = (ROOT / "addons/complex_v3_regeneration_editor/plugin.gd").read_text(encoding="utf-8")
        self.assertIn("res://tools/complex_v3_regeneration/sector_generation_manifest.json", plugin)
        manifest = json.loads(CANONICAL.MANIFEST.read_text(encoding="utf-8"))
        control = next(item for item in manifest["sectors"] if item["sector_id"] == "U-CONTROL")
        self.assertEqual(control["source_svg"], "docs/design/complex_v3/plans/generation/upper/u_control.svg")


if __name__ == "__main__":
    unittest.main()
