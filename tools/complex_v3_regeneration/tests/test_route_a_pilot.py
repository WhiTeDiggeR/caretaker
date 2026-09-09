from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
PROJECT = TOOLS.parents[1]
SPEC = importlib.util.spec_from_file_location("safe_route_a", TOOLS / "safe_regenerate.py")
SAFE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SAFE)


@unittest.skipUnless(os.environ.get("SVG_TOOL_ROOT") and os.environ.get("STAIR_TOOL_ROOT"), "canonical generator paths are not configured")
class RouteAPilotTests(unittest.TestCase):
    def test_noop_impossible_shaft_and_missing_dimension_preserve_live(self) -> None:
        with tempfile.TemporaryDirectory(prefix=".ra-", dir=PROJECT) as temporary:
            root = Path(temporary)
            manifest = json.loads((TOOLS / "pilots/route_a_vertical/pilot_generation_manifest.json").read_text(encoding="utf-8"))
            manifest["project_root"] = ".."
            upper = manifest["sectors"][0]
            upper["output_resource_dir"] = f"res://{root.name}/live"
            path = root / "manifest.json"
            def run(index: int) -> tuple[int, dict]:
                path.write_text(json.dumps(manifest), encoding="utf-8")
                report_path = root / f"report-{index}.json"
                code = SAFE.main(["--sector", "U-ROUTE-A", "--manifest", str(path), "--svg-tool-root", os.environ["SVG_TOOL_ROOT"], "--stair-tool-root", os.environ["STAIR_TOOL_ROOT"], "--backend", str(TOOLS / "regenerate_sector.py"), "--composition-validator", str(TOOLS.parent / "complex_v3_composition_validator/validate_composition.py"), "--python", os.sys.executable, "--report", str(report_path)])
                return code, json.loads(report_path.read_text(encoding="utf-8"))
            def snapshot() -> dict:
                return {str(p.relative_to(root / "live")): hashlib.sha256(p.read_bytes()).hexdigest() for p in (root / "live").rglob("*") if p.is_file()}
            code, report = run(1)
            self.assertEqual(code, 0, report)
            baseline = snapshot()
            code, report = run(2)
            self.assertEqual(code, 0, report)
            self.assertEqual(baseline, snapshot())
            args = upper["vertical_generators"][0]["args"]
            index = args.index("--shaft-width")
            args[index + 1] = "0.1"
            code, report = run(3)
            self.assertEqual(code, 2, report)
            self.assertFalse(report["ready"])
            self.assertEqual(baseline, snapshot())
            del args[index:index + 2]
            code, report = run(4)
            self.assertEqual(code, 2, report)
            self.assertFalse(report["ready"])
            self.assertEqual(baseline, snapshot())
