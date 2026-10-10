"""The committed production manifest must be exactly what its builder produces."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("build_sector_manifest", TOOLS / "build_sector_manifest.py")
assert SPEC and SPEC.loader
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class ManifestReproducibleTests(unittest.TestCase):
    def test_committed_manifest_equals_builder_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            rebuilt = Path(temp) / "manifest.json"
            self.assertEqual(BUILDER.main(["--output", str(rebuilt)]), 0)
            self.assertEqual(
                json.loads(rebuilt.read_text(encoding="utf-8")),
                json.loads((TOOLS / "sector_generation_manifest.json").read_text(encoding="utf-8")),
                "sector_generation_manifest.json is hand-edited or stale; change its sources "
                "(rollouts/*.json, pilots, vertical_definitions.json) and rebuild with build_sector_manifest.py",
            )


if __name__ == "__main__":
    unittest.main()
