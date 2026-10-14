"""Walls and slabs shared by two sectors are drawn once (#205)."""
import unittest

from tools.complex_v4 import build_canonical_from_approved as builder
from tools.complex_v4 import check_cross_openings, check_shared_faces


def owner(walls: list[tuple[str, str, float, float, float]]) -> dict:
    return {"sector_id": "A-CIRCULATION", "edges": [], "openings": [],
            "walls": [{"id": wid, "orient": o, "fixed": f, "lo": lo, "hi": hi} for wid, o, f, lo, hi in walls]}


def wall(wid: str, q: tuple[float, float, float, float]) -> dict:
    return {"id": wid, "surface": wid, "normal": "normal", "source": "", "q": q}


def faces() -> dict:
    return {"dropped_walls": [], "trimmed_walls": []}


class OwnershipRuleTests(unittest.TestCase):
    def test_circulation_owns_and_ties_go_to_the_smaller_id(self) -> None:
        ranked = sorted(["U-MEDBAY", "U-CIRCULATION", "U-EMERGENCY"], key=lambda s: builder.shared_face_rank(s, {}))
        self.assertEqual(ranked, ["U-CIRCULATION", "U-EMERGENCY", "U-MEDBAY"])
        self.assertEqual(builder.shared_face_rank("U-MEDBAY", {"shared_face_rank": 0})[0], 0)

    def test_collinear_wall_of_the_owner_is_dropped(self) -> None:
        report = faces()
        kept = builder.resolve_owned_walls([wall("b-wall-01", (0.0, 5.0, 10.0, 5.0))], [owner([("a-wall-01", "h", 5.0, -2.0, 12.0)])], report)
        self.assertEqual(kept, [])
        self.assertEqual(report["dropped_walls"][0]["id"], "b-wall-01")

    def test_wall_continuing_past_the_owner_keeps_the_rest_beyond_its_end_box(self) -> None:
        report = faces()
        kept = builder.resolve_owned_walls([wall("b-wall-01", (0.0, 5.0, 10.0, 5.0))], [owner([("a-wall-01", "h", 5.0, 0.0, 4.0)])], report)
        self.assertEqual([w["q"] for w in kept], [(4.0 + builder.WALL_THICKNESS_M, 5.0, 10.0, 5.0)])

    def test_wall_ending_on_the_owner_wall_stops_at_its_face(self) -> None:
        report = faces()
        kept = builder.resolve_owned_walls([wall("b-wall-02", (3.0, 0.0, 3.0, 5.0))], [owner([("a-wall-01", "h", 5.0, 0.0, 10.0)])], report)
        self.assertEqual([w["q"] for w in kept], [(3.0, 0.0, 3.0, 5.0 - builder.WALL_THICKNESS_M)])

    def test_unrelated_wall_is_untouched(self) -> None:
        source = wall("b-wall-03", (0.0, 9.0, 4.0, 9.0))
        self.assertEqual(builder.resolve_owned_walls([source], [owner([("a-wall-01", "h", 5.0, 0.0, 10.0)])], faces()), [source])

    def test_opening_leaves_a_perpendicular_wall_box(self) -> None:
        walls = [wall("w", (0.0, 0.0, 0.0, 5.0))]
        lo, hi = builder.clear_opening_corners("h", 5.0, 0.1, 1.9, walls)
        self.assertAlmostEqual(lo, builder.OPENING_JAMB_CLEAR_M)
        self.assertAlmostEqual(hi - lo, 1.8)


class CanonicalSourcesTests(unittest.TestCase):
    def test_canonical_svgs_have_no_shared_or_flickering_faces(self) -> None:
        findings = check_shared_faces.find(check_shared_faces.load_sectors())
        self.assertEqual(findings, [], "\n".join(str(item) for item in findings[:20]))

    def test_openings_on_shared_walls_open_from_both_sides(self) -> None:
        missing = check_cross_openings.find_missing(check_cross_openings.load())
        self.assertEqual(missing, [], "\n".join(str(item) for item in missing[:20]))


if __name__ == "__main__":
    unittest.main()
