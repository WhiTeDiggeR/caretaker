@tool
extends Node3D
class_name ComplexV3Blockout

const HANDOFF_PATH := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const SECTOR_CATALOG_PATH := "res://scenes/complex_v3_blockout/sector_catalog.json"
const EXPECTED_COUNTS := {
	"route_spaces": 7,
	"anchors": 7,
	"transitions": 8,
}

@export var include_ceilings := true
@export var build_collisions := true
@export var show_space_labels := false

var _handoff: Dictionary = {}
var _neighbors: Dictionary[String, PackedStringArray] = {}
var _sector_focus: Dictionary[String, Vector3] = {}
var _scope := "FULL"
var _selected_sector_id := ""
var _level_filter := "ALL"


func _enter_tree() -> void:
	_apply_part_options()


func _ready() -> void:
	_handoff = _load_json(HANDOFF_PATH)
	_compile_sector_catalog()
	set_meta("map_id", str(_handoff.get("map_id", "")))
	set_meta("units", str(_handoff.get("units", "")))
	set_meta("composition", "30 sector scenes + shared infrastructure")
	show_full_complex()


func _apply_part_options() -> void:
	for part: ComplexV3BlockoutPart in _get_parts():
		if Engine.is_editor_hint():
			part.editor_preview_enabled = false
		part.include_ceilings = include_ceilings
		part.build_collisions = build_collisions
		part.show_space_labels = show_space_labels
		part.preview_main_core_verticals_when_standalone = false


func _get_parts() -> Array[ComplexV3BlockoutPart]:
	var result: Array[ComplexV3BlockoutPart] = []
	var zones := get_node_or_null("Zones")
	if zones != null:
		for child: Node in zones.get_children():
			if child is ComplexV3BlockoutPart:
				result.append(child as ComplexV3BlockoutPart)
	var infrastructure := get_node_or_null("Infrastructure")
	if infrastructure is ComplexV3BlockoutPart:
		result.append(infrastructure as ComplexV3BlockoutPart)
	return result


func _get_zone_parts() -> Array[ComplexV3BlockoutPart]:
	var result: Array[ComplexV3BlockoutPart] = []
	for part: ComplexV3BlockoutPart in _get_parts():
		if part.build_room_spaces and not part.get_primary_sector_id().is_empty():
			result.append(part)
	return result


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть handoff: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _compile_sector_catalog() -> void:
	_neighbors.clear()
	_sector_focus.clear()
	var catalog := _load_json(SECTOR_CATALOG_PATH)
	for sector_value: Variant in catalog.get("sectors", []):
		var sector := sector_value as Dictionary
		var sector_id := str(sector["sector_id"])
		var neighbors := PackedStringArray()
		for neighbor: Variant in sector.get("neighbors", []):
			neighbors.append(str(neighbor))
		neighbors.sort()
		_neighbors[sector_id] = neighbors
		var focus: Array = sector["focus_xyz"]
		_sector_focus[sector_id] = Vector3(float(focus[0]), float(focus[1]), float(focus[2]))


func get_build_stats() -> Dictionary:
	var totals: Dictionary[String, int] = {}
	for part: ComplexV3BlockoutPart in _get_parts():
		for key: String in part.get_build_stats():
			totals[key] = totals.get(key, 0) + int(part.get_build_stats()[key])
	return totals


func get_portal_passages() -> Array[Dictionary]:
	var passages: Array[Dictionary] = []
	for part: ComplexV3BlockoutPart in _get_zone_parts():
		passages.append_array(part.get_portal_passages())
	return passages


func validate_against_handoff() -> PackedStringArray:
	var errors := PackedStringArray()
	var sector_ids := get_sector_ids()
	if sector_ids.size() != 30:
		errors.append("Expected 30 sector scenes, found %d" % sector_ids.size())
	var seen := PackedStringArray()
	for part: ComplexV3BlockoutPart in _get_parts():
		for error: String in part.validate_against_handoff():
			errors.append("%s: %s" % [part.name, error])
		var sector_id := part.get_primary_sector_id()
		if not sector_id.is_empty():
			if seen.has(sector_id):
				errors.append("Duplicate sector scene: %s" % sector_id)
			seen.append(sector_id)
	var stats := get_build_stats()
	var expected_spaces := (_handoff.get("spaces", []) as Array).size()
	if int(stats.get("spaces", 0)) != expected_spaces:
		errors.append("Expected %d spaces, built %d" % [expected_spaces, int(stats.get("spaces", 0))])
	for key: String in EXPECTED_COUNTS:
		if int(stats.get(key, 0)) != int(EXPECTED_COUNTS[key]):
			errors.append("Expected %d %s, built %d" % [int(EXPECTED_COUNTS[key]), key, int(stats.get(key, 0))])
	var expected_portals := (_handoff.get("internal_portals", []) as Array).size()
	for portal_value: Variant in _handoff.get("external_portals", []):
		if bool((portal_value as Dictionary).get("traversable", true)):
			expected_portals += 1
	if get_portal_passages().size() != expected_portals:
		errors.append("Expected %d traversable portals, found %d" % [expected_portals, get_portal_passages().size()])
	return errors


func get_sector_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for part: ComplexV3BlockoutPart in _get_zone_parts():
		result.append(part.get_primary_sector_id())
	result.sort()
	return result


func get_sector_neighbors(sector_id: String) -> PackedStringArray:
	var neighbors: PackedStringArray = _neighbors.get(sector_id, PackedStringArray())
	return neighbors.duplicate()


func get_sector_focus(sector_id: String) -> Vector3:
	return _sector_focus.get(sector_id, Vector3.ZERO)


func show_full_complex() -> void:
	_scope = "FULL"
	_selected_sector_id = ""
	for part: ComplexV3BlockoutPart in _get_parts():
		part.visible = true
	_apply_level_filter()


func show_sector(sector_id: String) -> void:
	_scope = "SECTOR"
	_selected_sector_id = sector_id
	_set_visible_sectors(PackedStringArray([sector_id]), sector_id == "T-CIRCULATION")


func show_sector_with_neighbors(sector_id: String) -> void:
	_scope = "NEIGHBORS"
	_selected_sector_id = sector_id
	var visible_sectors := get_sector_neighbors(sector_id)
	visible_sectors.append(sector_id)
	_set_visible_sectors(visible_sectors, true)


func _set_visible_sectors(visible_sectors: PackedStringArray, show_infrastructure: bool) -> void:
	for part: ComplexV3BlockoutPart in _get_zone_parts():
		part.visible = visible_sectors.has(part.get_primary_sector_id())
	var infrastructure := get_node_or_null("Infrastructure") as ComplexV3BlockoutPart
	if infrastructure != null:
		infrastructure.visible = show_infrastructure
	_apply_level_filter()


func set_level_filter(level_id: String) -> void:
	_level_filter = level_id
	_apply_level_filter()


func _apply_level_filter() -> void:
	for part: ComplexV3BlockoutPart in _get_parts():
		part.set_level_filter(_level_filter)


func get_view_state() -> Dictionary:
	return {
		"scope": _scope,
		"sector_id": _selected_sector_id,
		"level": _level_filter,
	}
