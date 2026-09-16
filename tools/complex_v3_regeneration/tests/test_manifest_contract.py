from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from tools.complex_v3_regeneration.manifest_contract import validate_manifest_document


ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "tools" / "complex_v3_regeneration" / "sector_generation_manifest.json"


class ManifestContractTests(unittest.TestCase):
    def test_production_manifest_is_complete_and_portable(self) -> None:
        document = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(validate_manifest_document(document, ROOT, production=True), [])

    def test_absolute_source_and_false_ready_state_are_rejected(self) -> None:
        document = json.loads(MANIFEST.read_text(encoding="utf-8"))
        broken = copy.deepcopy(document)
        broken["sectors"][0]["source_svg"] = "D:/machine/source.svg"
        broken["sectors"][0]["status"] = "blocked"
        broken["sectors"][0]["blockers"] = ["missing"]
        errors = validate_manifest_document(broken, ROOT, production=True)
        self.assertTrue(any("portable relative path" in error for error in errors))
        self.assertTrue(any("not production-ready" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
