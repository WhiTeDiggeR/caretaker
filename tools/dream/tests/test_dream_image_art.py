"""The relief art of the dream images (#217) is up to date with the sketches of #198."""
import io
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dream_image_art  # noqa: E402


class DreamImageArtTests(unittest.TestCase):
    def test_committed_art_matches_the_sketches(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output):
            code = dream_image_art.main(["--check"])
        self.assertEqual(code, 0, output.getvalue())

    def test_art_drops_the_glyph_skeleton(self) -> None:
        targets = dream_image_art.targets()
        self.assertEqual(len(targets), 8)
        for path, text in targets.items():
            self.assertNotIn('opacity="0.7"', text, path.name)
            self.assertNotIn("#fffaf0", text, path.name)
            self.assertIn('fill="url(#stone)"', text, path.name)
            self.assertNotIn('rx="14"', text, path.name)  # the square frame gave way to the medallion


if __name__ == "__main__":
    unittest.main()
