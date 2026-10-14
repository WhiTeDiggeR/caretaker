"""Post-generation work survives plan edits: stable wall / door / floor IDs and room finishes (#206).

The end-to-end scenario: bind an object to a wall, a door and a floor of a room, give the room a finish class, change the
plan elsewhere (move a wall of another room, add a partition in a third one), rebuild. The bindings still resolve to the same
geometry and the room keeps its materials. Without the generation tools the generated scene is a minimal stand-in in the
converter's format; with SVG_TOOL_ROOT the real inspector also checks the anchor frames.
"""
from __future__ import annotations

import copy
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools/complex_v4"


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


BUILD = _load("build_canonical_from_approved_206", TOOLS / "build_canonical_from_approved.py")
FINISHES = _load("room_finishes_206", TOOLS / "room_finishes.py")
SECTOR = "U-SECURITY"
ROOM = "U-SECURITY/dezhurnaya"
BOUND = {  # binding role -> (stable id, anchor type)
    "wall": (f"{ROOM}:north", "wall"),
    "door": (f"{ROOM}:door:vhodnoy-tambur", "door:center"),
    "floor": (f"{ROOM}:floor", "floor"),
}


def elements(svg: str) -> dict[str, ET.Element]:
    return {el.get("id", ""): el for el in ET.fromstring(svg).iter() if el.get("data-godot-type")}


def by_stable(svg: str) -> dict[str, ET.Element]:
    found = {}
    for el in elements(svg).values():
        stable = el.get("data-stable-id") or el.get("data-surface-side-id")
        if stable:
            found[stable] = el
    return found


def anchor_origin(el: ET.Element) -> tuple[float, ...]:
    """Origin of the anchor of a plan element (line centre / rect corner), enough to tell whether it moved."""
    if el.get("x1") is not None:
        return tuple(round((float(el.get(a, 0)) + float(el.get(b, 0))) / 2, 4) for a, b in (("x1", "x2"), ("y1", "y2")))
    return tuple(round(float(el.get(key, 0)), 4) for key in ("x", "y", "width", "height"))


def fake_generated_scene(svg: str) -> str:
    """The architecture scene the converter writes for an SVG, reduced to what the finish stage reads."""
    lines = ['[gd_scene load_steps=4 format=3]', ""]
    for index, surface in enumerate(("floor", "ceiling", "wall"), start=1):
        lines += [f'[ext_resource type="Material" path="res://gen/u/u_security/Generated/Architecture/{surface}_material.tres" id="{index}_{surface}_material"]', ""]
    lines += ['[node name="u_security_generated" type="Node3D"]', ""]
    parents = {"floor": "Floors", "ceiling": "Ceilings", "wall": "Walls"}
    for parent in parents.values():
        lines += [f'[node name="{parent}" type="Node3D" parent="."]', "", f'[node name="Visual" type="Node3D" parent="{parent}"]', ""]
    for number, (ident, el) in enumerate(elements(svg).items(), start=1):
        surface = el.get("data-godot-type", "")
        if surface not in parents:
            continue
        material = {"floor": 1, "ceiling": 2, "wall": 3}[surface]
        lines += [f'[node name="{surface.title()}_{number:03d}_{ident.replace("-", "_")}" type="MeshInstance3D" parent="{parents[surface]}/Visual"]',
                  f'mesh = ExtResource("part_{number}_mesh")', f'material_override = ExtResource("{material}_{surface}_material")',
                  f'metadata/source_id = "{ident}"', ""]
    return "\n".join(lines)


def node_materials(scene: str) -> dict[str, str]:
    """source_id -> material path of every mesh of a scene."""
    paths = dict((ident, path) for path, ident in re.findall(r'\[ext_resource type="Material" path="([^"]+)" id="([^"]+)"\]', scene))
    result = {}
    for block in scene.split("\n\n"):
        source = re.search(r'metadata/source_id = "([^"]+)"', block)
        material = re.search(r'material_override = ExtResource\("([^"]+)"\)', block)
        if source and material:
            result[source.group(1)] = paths[material.group(1)]
    return result


class RoomFinishRegenerationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.registration = json.loads(BUILD.REGISTRATION.read_text(encoding="utf-8"))
        self.finishes = copy.deepcopy(FINISHES.load_registry())
        self.finishes["sectors"] = {SECTOR: {"default": "utility", "rooms": {"dezhurnaya": "medical"}}}

    def build(self, registration: dict[str, Any]) -> str:
        svg, _report, _target = BUILD.build_sector(SECTOR, registration["sectors"][SECTOR], registration, self.finishes)
        return svg

    def edited_registration(self) -> dict[str, Any]:
        """The same plan with a moved wall (the cargo-zone room grows 1 m south) and a new partition in the armoury."""
        edited = copy.deepcopy(self.registration)
        amendments = edited["sectors"][SECTOR].setdefault("amendments", [])
        before = self.build(self.registration)
        cargo = next(el for el in elements(before).values()
                     if el.get("data-godot-type") == "floor" and el.get("data-space-id") == "U-SECURITY/k-gruzovoy-zone")
        amendments.append({"id": "T206-grow", "op": "rect_grow", "ids": [cargo.get("data-source-id")], "side": "s", "by_m": 1.0})
        amendments.append({"id": "T206-wall", "op": "wall_add", "segments_m": [[-28.222, 40.0, -24.0, 40.0]]})
        return edited

    def test_registry_is_valid_and_materials_are_outside_gen(self) -> None:
        registry = FINISHES.load_registry()
        self.assertEqual(FINISHES.validate_registry(registry), [])
        for value in registry["classes"].values():
            for path in value["materials"].values():
                self.assertTrue(path.startswith("res://materials/complex_v4/finish/"), path)

    def test_stable_ids_are_unique_and_keep_the_geometry_of_all_sectors(self) -> None:
        canonical = ROOT / "docs/design/complex_v4/plans/generation"
        # committed SVGs built with the shared-face ownership rule (D-49, #205) are compared with the whole-complex build
        complex_build = {sector_id: svg for sector_id, svg, _report, _target in BUILD.build_all(self.registration)}
        for sector_id, entry in self.registration["sectors"].items():
            svg, _report, target = BUILD.build_sector(sector_id, entry, self.registration)
            if "data-shared-faces=" in target.read_text(encoding="utf-8"):
                svg = complex_build[sector_id]
            built = list(elements(svg).values())
            ids = [el.get("id") for el in built]
            self.assertEqual(len(ids), len(set(ids)), sector_id)
            stable = [el.get("data-stable-id") or el.get("data-surface-side-id") for el in built if el.get("data-godot-type") != "ignore"]
            self.assertTrue(all(stable), sector_id)
            self.assertEqual(len(stable), len(set(stable)), sector_id)
            self.assertTrue(all(el.get("data-wall-rooms") for el in built if el.get("data-godot-type") in {"door", "opening", "window"}), sector_id)
            committed = list(elements(target.read_text(encoding="utf-8")).values())
            self.assertEqual(wall_cover(built), wall_cover(committed), f"{sector_id}: wall geometry changed")
            self.assertEqual(non_wall(built), non_wall(committed), f"{sector_id}: non-wall geometry changed")

    def test_bindings_and_finishes_survive_a_plan_edit_elsewhere(self) -> None:
        before, after = self.build(self.registration), self.build(self.edited_registration())
        self.assertNotEqual(before, after)
        old, new = by_stable(before), by_stable(after)
        # the plan really changed: a wall of another room moved and a partition appeared
        self.assertNotEqual(anchor_origin(old["U-SECURITY/k-gruzovoy-zone:south"]), anchor_origin(new["U-SECURITY/k-gruzovoy-zone:south"]))
        self.assertIn("U-SECURITY/line:amendment-T206-wall-1", new)
        # every element of the old plan keeps its ID: positional numbering would have shifted them
        self.assertLessEqual(set(elements(before)), set(elements(after)))
        # the object's bindings resolve to the same anchors at the same place
        for role, (stable, kind) in BOUND.items():
            self.assertIn(stable, old, role)
            self.assertEqual(old[stable].get("id"), new[stable].get("id"), role)
            self.assertEqual(f"svg:{new[stable].get('id')}:{kind}", f"svg:{BUILD.element_id(stable)}:{kind}", role)
            self.assertEqual(anchor_origin(old[stable]), anchor_origin(new[stable]), role)
        # the room keeps its finish materials on the floor, the ceiling and its walls
        scenes = {}
        for label, svg in (("before", before), ("after", after)):
            with tempfile.TemporaryDirectory() as temporary:
                source, scene = Path(temporary) / "plan.svg", Path(temporary) / "scene.tscn"
                source.write_text(svg, encoding="utf-8")
                scene.write_text(fake_generated_scene(svg), encoding="utf-8")
                assignments, changed = FINISHES.apply(scene, source, self.finishes)
                self.assertTrue(changed and assignments, label)
                scenes[label] = node_materials(scene.read_text(encoding="utf-8"))
        medical = self.finishes["classes"]["medical"]["materials"]
        for stable, surface in ((f"{ROOM}:floor", "floor"), (f"{ROOM}:ceiling", "ceiling"), (f"{ROOM}:north", "wall"), (f"{ROOM}:south", "wall")):
            ident = BUILD.element_id(stable)
            self.assertEqual(scenes["before"][ident], medical[surface], stable)
            self.assertEqual(scenes["after"][ident], medical[surface], stable)
        unchanged = set(scenes["before"]) & set(scenes["after"])
        self.assertEqual({k: scenes["before"][k] for k in unchanged}, {k: scenes["after"][k] for k in unchanged})

    def test_finish_stage_is_idempotent_and_reverts_to_the_package_material(self) -> None:
        svg = self.build(self.registration)
        with tempfile.TemporaryDirectory() as temporary:
            source, scene = Path(temporary) / "plan.svg", Path(temporary) / "scene.tscn"
            source.write_text(svg, encoding="utf-8")
            original = fake_generated_scene(svg)
            scene.write_text(original, encoding="utf-8")
            FINISHES.apply(scene, source, self.finishes)
            once = scene.read_text(encoding="utf-8")
            self.assertIn('metadata/finish_class = "medical"', once)
            self.assertFalse(FINISHES.apply(scene, source, self.finishes)[1])
            self.assertEqual(scene.read_text(encoding="utf-8"), once)
            bare = copy.deepcopy(self.finishes)
            bare["sectors"] = {}
            source.write_text(BUILD.build_sector(SECTOR, self.registration["sectors"][SECTOR], self.registration, bare)[0], encoding="utf-8")
            FINISHES.apply(scene, source, bare)
            reverted = scene.read_text(encoding="utf-8")
            self.assertNotIn("finish_", reverted)
            self.assertEqual(node_materials(reverted), node_materials(original))

    def test_shared_wall_takes_the_class_with_the_smaller_priority(self) -> None:
        svg = self.build(self.registration)
        plan = FINISHES.plan_finishes_from_text(svg, self.finishes)
        shared = BUILD.element_id(f"{ROOM}:north")   # dezhurnaya (medical) | vhodnoy-tambur (utility)
        self.assertEqual(plan[shared], ("wall", "medical"))
        own = BUILD.element_id("U-SECURITY/oruzheynaya:north")
        self.assertEqual(plan[own], ("wall", "utility"))

    @unittest.skipUnless(os.environ.get("SVG_TOOL_ROOT"), "SVG_TOOL_ROOT is not set")
    def test_real_inspector_keeps_bound_anchor_frames(self) -> None:
        regenerate = _load("regenerate_sector_206", TOOLS / "regenerate_sector.py")
        inspector = regenerate.find_script(Path(os.environ["SVG_TOOL_ROOT"]).resolve(), "inspect_svg_plan.py")
        manifest = json.loads((TOOLS / "sector_generation_manifest.json").read_text(encoding="utf-8"))
        sector = next(item for item in manifest["sectors"] if item["sector_id"] == SECTOR)
        metric = sector["metric_settings"]
        frames = {}
        for label, svg in (("before", self.build(self.registration)), ("after", self.build(self.edited_registration()))):
            with tempfile.TemporaryDirectory() as temporary:
                source, report = Path(temporary) / "u_security.svg", Path(temporary) / "inspection.json"
                source.write_text(svg, encoding="utf-8")
                command = [sys.executable, str(inspector), str(source), "--profile", sector["profile"], "--scale", str(metric["scale_m_per_svg_unit"]),
                           "--origin", metric["origin"], "--elevation", str(metric["elevation_m"]), *sector["shared_args"],
                           "--json", "--output-json", str(report), "--strict"]
                completed = subprocess.run(command, text=True, encoding="utf-8", errors="replace", capture_output=True)
                self.assertEqual(completed.returncode, 0, f"{label}: {completed.stdout[-2000:]}{completed.stderr[-2000:]}")
                handoff = json.loads(report.read_text(encoding="utf-8")).get("spatial_handoff", {})
                frames[label] = {frame["anchor_id"]: frame for frame in handoff.get("anchor_frames", [])}
        for role, (stable, kind) in BOUND.items():
            anchor = f"svg:{BUILD.element_id(stable)}:{kind}"
            self.assertIn(anchor, frames["before"], role)
            self.assertIn(anchor, frames["after"], role)
            for key in ("origin", "normal", "forward"):
                self.assertEqual(frames["before"][anchor][key], frames["after"][anchor][key], f"{role}.{key}")


def wall_cover(items: list[ET.Element]) -> dict[tuple[str, float], list[tuple[float, float]]]:
    """Union of the wall lines on each grid line (splitting a wall must not change what is covered)."""
    lines: dict[tuple[str, float], list[list[float]]] = {}
    for el in items:
        if el.get("data-godot-type") != "wall":
            continue
        x1, y1, x2, y2 = (float(el.get(key, 0)) for key in ("x1", "y1", "x2", "y2"))
        key, span = (("h", round(y1, 3)), sorted((x1, x2))) if abs(y1 - y2) < 1e-9 else (("v", round(x1, 3)), sorted((y1, y2)))
        lines.setdefault(key, []).append(span)
    cover = {}
    for key, spans in lines.items():
        spans.sort()
        merged = [list(spans[0])]
        for lo, hi in spans[1:]:
            if lo <= merged[-1][1] + 1e-6:
                merged[-1][1] = max(merged[-1][1], hi)
            else:
                merged.append([lo, hi])
        cover[key] = [(round(lo, 3), round(hi, 3)) for lo, hi in merged]
    return cover


def non_wall(items: list[ET.Element]) -> list[tuple[str | None, ...]]:
    keys = ("data-godot-type", "x", "y", "width", "height", "x1", "y1", "x2", "y2", "data-inside-side", "data-door-height",
            "data-door-type", "data-vertical-id", "data-source-id", "data-ceiling-elevation")
    return sorted((tuple(el.get(key) or "" for key in keys) for el in items if el.get("data-godot-type") != "wall"))


if __name__ == "__main__":
    unittest.main()
