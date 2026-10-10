"""A door onto a stair must match the stair opening exactly."""
import unittest

from tools.complex_v3_regeneration import regenerate_sector as backend


def door(anchor_id: str, centre_x: float, width: float, z: float = 6.0, y: float = 0.0) -> dict:
    return {"anchor_id": anchor_id, "type": "door", "role": "center", "origin": [centre_x, y, z],
            "forward": [-1.0, 0.0, 0.0], "bounds": {"kind": "portal", "width_m": width}}


def stair_exit(centre_x: float, width: float = 1.5, z: float = 6.01) -> dict:
    return {"anchor_id": "AF-STAIR-EXIT", "type": "stair_exit", "role": "upper_exit", "origin": [centre_x, 0.0, z],
            "forward": [0.0, 0.0, -1.0], "bounds": {"clear_width_m": width}}


class StairDoorAlignmentTests(unittest.TestCase):
    def test_matching_door_passes(self) -> None:
        backend.check_stair_door_alignment([door("D", -51.4, 1.5), stair_exit(-51.4)])

    def test_wider_shifted_door_is_rejected_with_the_expected_opening(self) -> None:
        with self.assertRaises(backend.RegenerationError) as caught:
            backend.check_stair_door_alignment([door("svg:door-stair", -51.033, 2.266), stair_exit(-51.4)])
        message = str(caught.exception)
        self.assertIn("svg:door-stair", message)
        self.assertIn("set the door to -52.150..-50.650", message)

    def test_door_elsewhere_or_on_another_level_is_ignored(self) -> None:
        backend.check_stair_door_alignment([door("far", -40.0, 2.0), door("level", -51.4, 2.5, y=-6.0), door("wall", -51.4, 2.5, z=9.0), stair_exit(-51.4)])

    def test_door_not_overlapping_the_stair_is_ignored(self) -> None:
        backend.check_stair_door_alignment([door("beside", -57.0, 1.5), stair_exit(-51.4)])

    def test_sector_without_stairs_is_unaffected(self) -> None:
        backend.check_stair_door_alignment([door("D", -51.4, 3.0)])


if __name__ == "__main__":
    unittest.main()
